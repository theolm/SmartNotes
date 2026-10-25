import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';
import 'package:smartnotes/domain/services/i_embedding_model_catalog.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';

part 'embedding_models_store.g.dart';

enum EmbeddingCatalogFailure { load, download, activation, removal }

@singleton
// ignore: library_private_types_in_public_api
class EmbeddingModelsStore = _EmbeddingModelsStore with _$EmbeddingModelsStore;

abstract class _EmbeddingModelsStore with Store {
  _EmbeddingModelsStore(this._models, this.downloads);
  final IEmbeddingModelService _models;
  final ModelDownloadsStore downloads;
  IEmbeddingModelCatalog? get _catalog =>
      _models is IEmbeddingModelCatalog ? _models : null;
  List<EmbeddingModel> get catalog =>
      _catalog?.catalog.whereType<EmbeddingModel>().toList() ??
      [EmbeddingModel.qwen];

  @observable
  String activeId = EmbeddingModel.qwen.id;
  @observable
  bool selectionLoaded = false;
  @observable
  bool loading = false;
  @observable
  String? activatingId;
  @observable
  String? removingId;
  @observable
  String? downloadingId;
  @observable
  EmbeddingCatalogFailure? failure;
  final states = ObservableMap<String, ModelCheckState>();
  final received = ObservableMap<String, int>();
  final partial = ObservableMap<String, int>();
  final failedDownloads = ObservableSet<String>();
  final _checking = <String>{};
  final _progressClock = Stopwatch()..start();

  @computed
  bool get changing => activatingId != null || removingId != null;
  @computed
  EmbeddingModel? get activeModel => selectionLoaded
      ? catalog.where((m) => m.id == activeId).firstOrNull
      : null;
  @computed
  ModelCheckState get activeState =>
      states[activeId] ?? ModelCheckState.unchecked;
  bool ready(String id) => states[id] == ModelCheckState.ready;

  @action
  Future<void> load() async {
    if (loading) return;
    loading = true;
    failure = null;
    try {
      // Resolve the persisted selection before showing a model name. The
      // in-memory default is not evidence that Qwen is actually selected.
      final activeState = await _models.readiness();
      activeId = _models.model.id;
      selectionLoaded = true;
      if (!_checking.contains(activeId) && downloadingId != activeId) {
        states[activeId] = activeState;
        if (activeState == ModelCheckState.unchecked) {
          unawaited(verify(activeId));
        }
      }
      // Cached probes first; no full hash on the critical path to visible rows.
      for (final model in catalog) {
        if (downloadingId == model.id) continue;
        if (model.id != activeId && !_checking.contains(model.id)) {
          final state = await _models.readiness(modelId: model.id);
          states[model.id] = state;
          if (state == ModelCheckState.unchecked) unawaited(verify(model.id));
        }
        partial[model.id] =
            await _catalog?.storedBytes(model.id, partial: true) ?? 0;
      }
      activeId = _models.model.id;
      for (final transfer in await downloads.refresh()) {
        if (transfer.state.isActive &&
            catalog.any((m) => m.id == transfer.id)) {
          unawaited(download(transfer.id));
          break;
        }
      }
    } catch (_) {
      failure = EmbeddingCatalogFailure.load;
    } finally {
      loading = false;
    }
  }

  @action
  Future<void> verify(String id) async {
    if (!_checking.add(id)) return;
    states[id] = ModelCheckState.checking;
    try {
      states[id] = await _models.readiness(modelId: id, verify: true);
      activeId = _models.model.id;
    } catch (_) {
      states[id] = ModelCheckState.failed;
    } finally {
      _checking.remove(id);
    }
  }

  @action
  Future<void> download(String id) async {
    if (downloadingId != null || changing) return;
    final model = catalog.where((m) => m.id == id).firstOrNull;
    if (model == null || !model.available) return;
    downloadingId = id;
    failure = null;
    failedDownloads.remove(id);
    received[id] = partial[id] ?? 0;
    try {
      await _models.download(
        modelId: id,
        onProgress: (bytes, total) {
          // Platform callbacks can arrive much faster than frames can render.
          if (bytes != total && _progressClock.elapsedMilliseconds < 100) {
            return;
          }
          _progressClock.reset();
          runInAction(() => received[id] = bytes);
        },
      );
      await verify(id);
      if (!ready(id)) throw StateError('Search model verification failed.');
      partial[id] = 0;
    } on ModelDownloadCancelled {
      // Cancellation is not a failed installation. Retained bytes are resumable.
    } catch (_) {
      failedDownloads.add(id);
      failure = EmbeddingCatalogFailure.download;
    } finally {
      partial[id] = await _catalog?.storedBytes(id, partial: true) ?? 0;
      downloadingId = null;
    }
  }

  void cancelDownload() => _models.cancelDownload();

  @action
  Future<void> activate(String id) async {
    if (changing || id == activeId || !ready(id)) return;
    if (!(EmbeddingModel.find(id)?.available ?? false)) return;
    activatingId = id;
    failure = null;
    try {
      await _catalog?.activate(id);
      activeId = _models.model.id;
    } catch (_) {
      failure = EmbeddingCatalogFailure.activation;
    } finally {
      activatingId = null;
    }
  }

  @action
  Future<void> remove(String id) async {
    if (changing || id == activeId || id == downloadingId) return;
    removingId = id;
    failure = null;
    try {
      await _catalog?.remove(id);
      states[id] = ModelCheckState.missing;
      partial[id] = 0;
    } catch (_) {
      failure = EmbeddingCatalogFailure.removal;
    } finally {
      removingId = null;
    }
  }
}
