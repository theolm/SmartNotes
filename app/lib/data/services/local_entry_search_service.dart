import 'package:injectable/injectable.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/domain/entities/search_result.dart';
import 'package:smartnotes/domain/entities/search_options.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/embedding_pipeline.dart';
import 'package:smartnotes/domain/entities/inference_cancelled.dart';
import 'package:smartnotes/domain/entities/search_index_status.dart';
import 'package:smartnotes/domain/services/i_embedding_service.dart';
import 'package:smartnotes/domain/services/i_entry_search_service.dart';

@LazySingleton(as: IEntrySearchService)
class LocalEntrySearchService implements IEntrySearchService {
  LocalEntrySearchService(this._database, this._embeddings);
  final LocalDatabase _database;
  final IEmbeddingService _embeddings;
  int _revision = 0;
  int _queryRevision = 0;
  Future<void>? _indexing;
  bool _indexRequested = false;
  bool _retryFailures = false;
  final _queries = <String, List<double>>{};

  @override
  void cancelTextSearch() => _database.cancelTextSearch();

  @override
  Future<List<SearchResult>> searchText(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) => _database.searchText(query, options: options);

  @override
  Future<List<SearchResult>> searchSemantic(
    String query, {
    bool Function()? isCancelled,
    SearchOptions options = const SearchOptions(),
  }) async {
    final queryRevision = ++_queryRevision;
    final revision = _revision;
    bool cancelled() =>
        isCancelled?.call() == true ||
        queryRevision != _queryRevision ||
        revision != _revision;
    try {
      checkInferenceCancelled(cancelled);
      if (query.trim().isEmpty) return [];
      if (query.length > 4000) {
        throw const AiFailure(AiFailureCode.queryTooLong);
      }
      final generation = await _database.indexGeneration();
      checkInferenceCancelled(cancelled);
      final key = '${EmbeddingPipeline.id}:$generation:$query';
      final vector =
          _queries[key] ??
          await _embeddings.embedQuery(query, isCancelled: cancelled);
      checkInferenceCancelled(cancelled);
      final currentGeneration = await _database.indexGeneration();
      if (cancelled() || generation != currentGeneration) {
        return [];
      }
      if (_queries.length >= 20) _queries.remove(_queries.keys.first);
      _queries[key] = vector;
      final results = await _database.searchVector(vector, options: options);
      return cancelled() ? [] : results;
    } on InferenceCancelled {
      return [];
    }
  }

  @override
  Future<void> indexPending({bool retryFailures = false}) {
    _indexRequested = true;
    _retryFailures = _retryFailures || retryFailures;
    return _indexing ??= _drainIndexRequests().whenComplete(
      () => _indexing = null,
    );
  }

  Future<void> _drainIndexRequests() async {
    while (_indexRequested) {
      _indexRequested = false;
      final retry = _retryFailures;
      _retryFailures = false;
      await _runIndexing(retryFailures: retry);
    }
  }

  Future<void> _runIndexing({required bool retryFailures}) async {
    final revision = _revision;
    final contentRevision = _database.contentRevision;
    bool cancelled() {
      if (revision != _revision) return true;
      if (contentRevision != _database.contentRevision) {
        // Refresh the snapshot after edits/deletes/imports, not just discard it.
        _indexRequested = true;
        _retryFailures = _retryFailures || retryFailures;
        return true;
      }
      return false;
    }

    final generation = await _database.indexGeneration();
    final pending = await _database.pendingEntries(
      retryFailures: retryFailures,
    );
    for (final entry in pending) {
      if (cancelled()) {
        return;
      }
      try {
        final source = entrySource(entry);
        final passages = <({String text, int start})>[];
        final vectors = await _embeddings.embedDocument(
          source,
          isCancelled: cancelled,
          onPassage: (text, start) => passages.add((text: text, start: start)),
        );
        if (cancelled()) {
          return;
        }
        await _database.indexEntry(
          entry,
          vectors,
          generation: generation,
          passages: passages,
        );
      } catch (error) {
        if (cancelled()) {
          return;
        }
        // Existing journals remain pending while setup/repair is incomplete.
        if (error is AiFailure && error.code == AiFailureCode.modelMissing) {
          return;
        }
        await _database.markIndexFailed(entry, generation: generation);
        // One damaged note must not prevent indexing the rest of the journal.
      }
    }
  }

  @override
  Future<void> rebuild() async {
    _revision++;
    _queries.clear();
    await _indexing;
    await _database.resetIndex();
    await indexPending();
  }

  @override
  Stream<SearchIndexStatus> watchIndexStatus() => _database.watchIndexStatus();
}
