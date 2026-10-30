import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:smartnotes/core/utils/log.dart' show logger;
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';
import 'package:smartnotes/domain/services/i_entry_search_service.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import 'package:smartnotes/data/services/processing_feedback_service.dart';
import 'package:smartnotes/domain/entities/processing_feedback.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';

/// Application-owned background work; never tied to a screen's lifetime.
@lazySingleton
class JournalLifecycle {
  JournalLifecycle(
    this._journal,
    this._processing,
    this._search,
    this._models, {
    ProcessingFeedbackService? feedback,
    // Named injection keeps manually constructed lifecycle tests lightweight.
    ISpeechModelService? speechModels,
  }) : _feedback = feedback ?? ProcessingFeedbackService.unsupported(),
       // ignore: prefer_initializing_formals
       _speechModels = speechModels;

  final IJournalEntryService _journal;
  final ProcessAudioNoteUseCase _processing;
  final IEntrySearchService _search;
  final IEmbeddingModelService _models;
  final ProcessingFeedbackService _feedback;
  final ISpeechModelService? _speechModels;
  final _running = <String, Future<void>>{};
  StreamSubscription<List<JournalEntry>>? _entriesSubscription;
  StreamSubscription<bool>? _modelsSubscription;
  bool _started = false;
  bool _recovered = false;
  bool _indexRequested = false;
  Future<void>? _indexing;

  /// Idempotent and non-blocking. The first journal snapshot is the recovery
  /// boundary; later snapshots only request derived-index work.
  void start() {
    if (_started) return;
    _started = true;
    _modelsSubscription = _models.readinessChanges.listen(
      (ready) {
        if (ready) _requestIndex();
      },
      onError: _logBackgroundError,
    );
    _entriesSubscription = _journal.watchAll().listen(
      (entries) {
        if (!_recovered) {
          _recovered = true;
          unawaited(_recover(entries));
        }
        _requestIndex();
      },
      onError: _logBackgroundError,
    );
  }

  void _requestIndex() {
    if (!_started) return;
    _indexRequested = true;
    _indexing ??= _drainIndexRequests().whenComplete(() => _indexing = null);
  }

  Future<void> _drainIndexRequests() async {
    while (_started && _indexRequested) {
      _indexRequested = false;
      try {
        if (await _models.isReady() && _started) {
          // Failed sources remain excluded until an explicit user retry.
          await _search.indexPending();
        }
      } catch (error, stackTrace) {
        _logBackgroundError(error, stackTrace);
      }
    }
  }

  /// Shared by capture, explicit retries, and startup recovery. Concurrent
  /// requests for the same entry join the existing job, not another inference.
  Future<void> processEntry(JournalEntry entry) => _running.putIfAbsent(
    entry.id,
    () => _processEntry(entry).whenComplete(() {
      _running.remove(entry.id);
    }),
  );

  Future<void> _processEntry(JournalEntry entry) async {
    final job = await _feedback.begin(
      entry.id,
      _speechModels?.model.name ?? 'Whisper',
    );
    try {
      final persisted = await _journal.update(
        entry.copyWith(status: EntryStatus.processing),
        expected: entry,
      );
      await _feedback.update(
        ProcessingPhase.transcribing,
        _speechModels?.model.name ?? 'Whisper',
        job: job,
      );
      await _processing.process(persisted);
      await _feedback.update(
        ProcessingPhase.preparingSearch,
        _models.model.name,
        job: job,
      );
      _requestIndex();
      await _indexing;
      await _feedback.finish(job: job);
    } catch (error) {
      await _feedback.finish(failed: true, job: job);
      try {
        final latest = await _journal.getById(entry.id);
        if (latest != null &&
            latest.status == EntryStatus.processing &&
            !(error is AiFailure && error.code == AiFailureCode.busy)) {
          await _journal.update(
            latest.copyWith(status: EntryStatus.error),
            expected: latest,
          );
        }
      } catch (_) {
        // Preserve persisted state if storage is unavailable.
      }
      rethrow;
    }
  }

  Future<void> _recover(
    List<JournalEntry> entries, {
    bool includeErrors = false,
  }) async {
    for (final entry in entries) {
      if (!_started) return;
      if (entry.status != EntryStatus.processing &&
          !(includeErrors && entry.status == EntryStatus.error)) {
        continue;
      }
      try {
        await processEntry(entry);
      } catch (error, stackTrace) {
        _logBackgroundError(error, stackTrace);
      }
    }
  }

  /// Explicit user command, using current storage rather than a UI snapshot.
  Future<void> retryRecordings() async {
    final entries = await _journal.watchAll().first;
    await _recover(entries, includeErrors: true);
  }

  void _logBackgroundError(Object error, StackTrace stackTrace) {
    logger.e(
      'Journal background work failed',
      stackTrace: stackTrace,
    );
  }

  @disposeMethod
  Future<void> dispose() async {
    _started = false;
    _indexRequested = false;
    await _entriesSubscription?.cancel();
    await _modelsSubscription?.cancel();
    await _indexing;
    await Future.wait(
      _running.values.map((job) => job.catchError((Object _) {})),
    );
  }
}
