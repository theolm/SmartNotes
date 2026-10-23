import 'dart:typed_data';
import 'dart:async';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:smartnotes/domain/entities/search_index_status.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';
import 'package:smartnotes/domain/services/i_entry_search_service.dart';
import 'package:smartnotes/domain/services/i_journal_archive_service.dart';
import 'package:smartnotes/application/journal_lifecycle.dart';

part 'local_data_store.g.dart';

enum LocalDataFailure {
  indexing,
  exporting,
  importing,
}

@singleton
// ignore: library_private_types_in_public_api
class LocalDataStore = _LocalDataStore with _$LocalDataStore;

abstract class _LocalDataStore with Store {
  _LocalDataStore(this._search, this._archive, this._models, this._lifecycle);
  final JournalLifecycle _lifecycle;
  final IEmbeddingModelService _models;
  final IEntrySearchService _search;
  final IJournalArchiveService _archive;

  @observable
  SearchIndexStatus indexStatus = const SearchIndexStatus();
  @observable
  bool modelReady = false;
  @observable
  bool modelChecking = true;
  @observable
  bool modelCheckFailed = false;
  Future<void>? _modelCheck;
  StreamSubscription<bool>? _readinessSubscription;
  StreamSubscription<SearchIndexStatus>? _subscription;
  @observable
  bool isBusy = false;
  @observable
  double? backupProgress;
  @observable
  LocalDataFailure? error;

  @action
  Future<void> load() async {
    try {
      _subscription ??= _search.watchIndexStatus().listen(
        (value) {
          runInAction(() => indexStatus = value);
        },
        onError: (Object _) {
          runInAction(() => error = LocalDataFailure.indexing);
        },
      );
      _readinessSubscription ??= _models.readinessChanges.listen((_) {
        unawaited(checkModel());
      });
      await checkModel();
    } catch (_) {
      error = LocalDataFailure.indexing;
    }
  }

  Future<void> checkModel() =>
      _modelCheck ??= _checkModel().whenComplete(() => _modelCheck = null);

  Future<void> _checkModel() async {
    runInAction(() {
      modelChecking = true;
      modelCheckFailed = false;
    });
    try {
      final result = await _models.readiness(verify: true);
      runInAction(() {
        modelReady = result == ModelCheckState.ready;
        modelCheckFailed = result == ModelCheckState.failed;
      });
    } catch (_) {
      runInAction(() {
        modelReady = false;
        modelCheckFailed = true;
      });
    } finally {
      runInAction(() => modelChecking = false);
    }
  }

  @action
  Future<void> retryRecordings() => _lifecycle.retryRecordings();

  @action
  Future<bool> indexNotes({bool rebuild = false}) async {
    if (isBusy || modelChecking || !modelReady) return false;
    isBusy = true;
    error = null;
    try {
      if (rebuild) {
        await _search.rebuild();
      } else {
        await _search.indexPending(retryFailures: true);
      }
      indexStatus = await _search.watchIndexStatus().first;
      return true;
    } catch (_) {
      error = LocalDataFailure.indexing;
      return false;
    } finally {
      isBusy = false;
    }
  }

  @action
  Future<Uint8List?> exportJournal() async {
    if (isBusy) return null;
    isBusy = true;
    error = null;
    try {
      backupProgress = null;
      return await _archive.export(
        onProgress: (value) {
          runInAction(() => backupProgress = value);
        },
      );
    } catch (_) {
      error = LocalDataFailure.exporting;
      return null;
    } finally {
      isBusy = false;
      backupProgress = null;
    }
  }

  @action
  Future<int?> importJournal(Uint8List bytes) async {
    if (isBusy) return null;
    isBusy = true;
    error = null;
    try {
      backupProgress = null;
      return await _archive.import(
        bytes,
        onProgress: (value) {
          runInAction(() => backupProgress = value);
        },
      );
    } catch (_) {
      error = LocalDataFailure.importing;
      return null;
    } finally {
      isBusy = false;
      backupProgress = null;
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _readinessSubscription?.cancel();
  }
}
