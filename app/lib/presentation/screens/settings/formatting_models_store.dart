import 'dart:async';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/formatting_model_service.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/services/i_formatting_model_service.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';

part 'formatting_models_store.g.dart';

enum FormattingDownloadState {
  checking,
  available,
  queued,
  downloading,
  verifying,
  ready,
  failed,
  cancelled,
}

@singleton
// ignore: library_private_types_in_public_api
class FormattingModelsStore = _FormattingModelsStore
    with _$FormattingModelsStore;

abstract class _FormattingModelsStore with Store {
  _FormattingModelsStore(
    this._models,
    this._device, {
    ModelDownloadsStore? downloads,
  }) : downloads = downloads ?? ModelDownloadsStore.unsupported();
  final ModelDownloadsStore downloads;
  final IFormattingModelService _models;
  final DeviceProfileService _device;
  List<FormattingModel> get catalog => _models.catalog;

  @observable
  String activeId = '';
  @observable
  DeviceProfile profile = const DeviceProfile();
  @observable
  bool loading = false;
  @observable
  bool busy = false;
  @observable
  bool downloading = false;
  @observable
  String? activatingId;
  @observable
  Object? error;

  final states = ObservableMap<String, FormattingDownloadState>();
  final received = ObservableMap<String, int>();
  final stored = ObservableMap<String, int>();
  final partial = ObservableMap<String, int>();
  final _queue = <String>[];
  final _waiters = <String, Completer<void>>{};
  String? _current;

  FormattingModel? _find(String id) {
    for (final model in catalog) {
      if (model.id == id) return model;
    }
    return null;
  }

  FormattingModel? get activeModel => _find(activeId);
  bool ready(String id) => states[id] == FormattingDownloadState.ready;

  @computed
  FormattingRecommendation get recommendation =>
      FormattingRecommendationPolicy.recommend(profile);

  @computed
  bool get activeReady {
    final model = activeModel;
    return model != null && ready(activeId);
  }

  /// Recommendation order is stable; activating a model does not reorder rows.
  @computed
  List<FormattingModel> get orderedCatalog {
    final recommended = recommendation.model.id;
    final result = [...catalog];
    result.sort(
      (a, b) => a.id == recommended
          ? -1
          : b.id == recommended
          ? 1
          : catalog.indexOf(a).compareTo(catalog.indexOf(b)),
    );
    return result;
  }

  @computed
  bool get activeUnavailable =>
      activeId.isNotEmpty &&
      !activeReady &&
      states[activeId] != FormattingDownloadState.checking;

  @computed
  int get installedCount => states.values
      .where((state) => state == FormattingDownloadState.ready)
      .length;

  @computed
  int get installedBytes =>
      stored.values.fold(0, (a, b) => a + b) +
      partial.values.fold(0, (a, b) => a + b);

  @action
  Future<void> load() async {
    if (busy || loading) return;
    loading = true;
    error = null;
    try {
      profile = await _device.read();
      activeId = _models.activeModelId;
      await refresh();
    } catch (failure) {
      error = failure;
    } finally {
      loading = false;
    }
  }

  @action
  Future<void> refresh() async {
    final active = _models.activeModelId;
    for (final model in catalog) {
      final state = states[model.id];
      if (state == FormattingDownloadState.queued ||
          state == FormattingDownloadState.checking ||
          state == FormattingDownloadState.downloading ||
          state == FormattingDownloadState.verifying) {
        continue;
      }
      final probe = model.id == active
          ? await _models.readiness(modelId: model.id)
          : null;
      final installed = probe == null
          ? await _models.isPresent(model.id)
          : probe == ModelCheckState.ready;
      states[model.id] = installed
          ? FormattingDownloadState.ready
          : FormattingDownloadState.available;
      if (probe == ModelCheckState.unchecked ||
          probe == ModelCheckState.checking) {
        states[model.id] = FormattingDownloadState.checking;
        unawaited(_check(model.id));
      } else if (probe == ModelCheckState.failed) {
        states[model.id] = FormattingDownloadState.failed;
        error = StateError('Model check failed');
      }
      stored[model.id] = await _models.storedBytes(model.id);
      final bytes = await _models.storedBytes(model.id, partial: true);
      partial[model.id] = bytes <= model.bytes ? bytes : 0;
      received.remove(model.id);
    }
    activeId = _models.activeModelId;
    reconcileTransfers(await downloads.refresh());
  }

  Future<void> _check(String id) async {
    try {
      final result = await _models.readiness(modelId: id, verify: true);
      runInAction(() {
        states[id] = result == ModelCheckState.ready
            ? FormattingDownloadState.ready
            : FormattingDownloadState.available;
        if (result == ModelCheckState.failed) {
          states[id] = FormattingDownloadState.failed;
          error = StateError('Model check failed');
        }
      });
    } catch (_) {
      runInAction(() {
        states[id] = FormattingDownloadState.failed;
        error = StateError('Model check failed');
      });
    }
  }

  void reconcileTransfers(List<ModelTransfer> transfers) {
    for (final transfer in transfers) {
      if (_find(transfer.id) == null ||
          _current == transfer.id ||
          _queue.contains(transfer.id) ||
          ready(transfer.id)) {
        continue;
      }
      if (transfer.state.isActive) {
        received[transfer.id] = transfer.received;
        states[transfer.id] = FormattingDownloadState.queued;
        _queue.add(transfer.id);
        if (!downloading) unawaited(_drain());
      } else if (transfer.state == ModelTransferState.cancelled) {
        states[transfer.id] = FormattingDownloadState.cancelled;
      } else if (transfer.state == ModelTransferState.failed) {
        states[transfer.id] = FormattingDownloadState.failed;
      }
    }
  }

  Future<void> downloadOne(String id) {
    if (busy || loading || states[id] == FormattingDownloadState.checking) {
      return Future<void>.value();
    }
    final model = _find(id);
    if (model == null || ready(id)) return Future<void>.value();
    final existing = _waiters[id];
    if (existing != null) return existing.future;
    if (_current == id || _queue.contains(id)) return Future<void>.value();
    final waiter = Completer<void>();
    _waiters[id] = waiter;
    _queue.add(id);
    states[id] = FormattingDownloadState.queued;
    error = null;
    if (!downloading) unawaited(_drain());
    return waiter.future;
  }

  void cancelDownload(String id) {
    if (_current == id) {
      _models.cancelDownload();
      return;
    }
    if (_queue.remove(id)) {
      states[id] = FormattingDownloadState.cancelled;
      _complete(id);
    }
  }

  void _complete(String id) {
    final waiter = _waiters.remove(id);
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  Future<void> _drain() async {
    if (downloading) return;
    downloading = true;
    try {
      while (_queue.isNotEmpty) {
        final id = _queue.removeAt(0);
        final model = _find(id);
        if (model == null) {
          _complete(id);
          continue;
        }
        if (ready(id)) {
          _complete(id);
          continue;
        }
        _current = id;
        states[id] = FormattingDownloadState.downloading;
        error = null;
        try {
          await _models.download(
            modelId: id,
            onProgress: (bytes, total) => runInAction(() {
              received[id] = bytes;
              states[id] = bytes == total
                  ? FormattingDownloadState.verifying
                  : FormattingDownloadState.downloading;
            }),
          );
          if (!await _models.isReady(id)) {
            throw StateError('Model verification failed');
          }
          states[id] = FormattingDownloadState.ready;
          stored[id] = model.bytes;
          partial[id] = 0;
          // The first download makes formatting usable. A later row tap remains
          // the explicit way to switch models.
          if (!activeReady) {
            try {
              await _models.activate(id);
              activeId = id;
            } catch (failure) {
              error = failure;
            }
          }
          _complete(id);
        } on ModelDownloadCancelled {
          states[id] = FormattingDownloadState.cancelled;
          _complete(id);
        } catch (failure) {
          states[id] = FormattingDownloadState.failed;
          error = failure;
          _complete(id);
          if (failure is FormattingModelException &&
              failure.problem == FormattingModelProblem.storage) {
            for (final queuedId in _queue) {
              states[queuedId] = FormattingDownloadState.cancelled;
              _complete(queuedId);
            }
            _queue.clear();
            break;
          }
        } finally {
          if (!ready(id)) {
            final bytes = await _models.storedBytes(id, partial: true);
            partial[id] = bytes;
            received.remove(id);
          }
          _current = null;
        }
      }
    } finally {
      downloading = false;
      _current = null;
      for (final id in _queue) {
        states[id] = FormattingDownloadState.cancelled;
        _complete(id);
      }
      _queue.clear();
    }
  }

  @action
  Future<bool> activate(String id) async {
    if (busy || loading) return false;
    final model = _find(id);
    if (model == null || !ready(id)) return false;
    busy = true;
    activatingId = id;
    error = null;
    try {
      await _models.activate(id);
      activeId = id;
      return true;
    } catch (failure) {
      error = failure;
      if (failure is FormattingModelException &&
          failure.problem == FormattingModelProblem.notReady) {
        // A same-size corrupt artifact still looked installed. Offer repair.
        states[id] = FormattingDownloadState.available;
      }
      return false;
    } finally {
      activatingId = null;
      busy = false;
    }
  }

  @action
  Future<void> remove(String id) async {
    if (busy || loading || _current == id || _queue.contains(id)) return;
    if (id == activeId) return;
    busy = true;
    error = null;
    try {
      await _models.remove(id);
      states[id] = FormattingDownloadState.available;
      stored[id] = 0;
      partial[id] = 0;
      await refresh();
    } catch (failure) {
      error = failure;
    } finally {
      busy = false;
    }
  }
}
