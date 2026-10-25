import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/local_embedding_service.dart';
import 'package:smartnotes/data/services/local_embedding_session.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/data/services/model_verification.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';
import 'package:smartnotes/domain/services/i_embedding_model_catalog.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';
import 'package:smartnotes/domain/services/i_platform_model_downloader.dart';

Future<void> disposeEmbeddingModelService(IEmbeddingModelService service) =>
    (service as EmbeddingModelService).dispose();

@LazySingleton(
  as: IEmbeddingModelService,
  dispose: disposeEmbeddingModelService,
)
class EmbeddingModelService implements IEmbeddingModelCatalog {
  EmbeddingModelService(
    http.Client client,
    IPlatformModelDownloader downloader,
    DeviceProfileService device,
    ModelVerificationStore verificationStore,
    LocalDatabase database,
    LocalInferenceQueue queue,
  ) : this._(
        client,
        getApplicationSupportDirectory,
        database,
        queue,
        null,
        platformDownloader: downloader,
        verificationStore: verificationStore,
        freeStorage: device.freeStorage,
      );

  EmbeddingModelService.forTesting(
    http.Client client, {
    required LocalAiModel model,
    required Future<Directory> Function() directory,
    IPlatformModelDownloader? platformDownloader,
    ModelVerificationStore? verificationStore,
    Future<String> Function(File)? hash,
    LocalDatabase? database,
    LocalInferenceQueue? queue,
    Future<void> Function(String, EmbeddingModel)? probe,
  }) : this._(
         client,
         directory,
         database,
         queue ?? LocalInferenceQueue(),
         probe,
         fixture: model,
         platformDownloader: platformDownloader,
         verificationStore: verificationStore,
         hash: hash,
       );

  EmbeddingModelService.catalogForTesting(
    http.Client client, {
    required Future<Directory> Function() directory,
    required LocalDatabase database,
    required LocalInferenceQueue queue,
    required Future<void> Function(String, EmbeddingModel) probe,
    required Future<String> Function(File) hash,
  }) : this._(client, directory, database, queue, probe, hash: hash);

  EmbeddingModelService._(
    http.Client client,
    this._directory,
    this._database,
    this._queue,
    this._probe, {
    LocalAiModel? fixture,
    IPlatformModelDownloader? platformDownloader,
    ModelVerificationStore? verificationStore,
    Future<int?> Function()? freeStorage,
    Future<String> Function(File)? hash,
  }) {
    for (final item in fixture == null ? catalog : [fixture]) {
      _workers[item.id] = LocalModelDownload(
        client,
        model: item,
        directory: _directory,
        folder: 'embedding_models',
        platformDownloader: platformDownloader,
        verificationStore: verificationStore,
        freeStorage: freeStorage,
        hash: hash,
      );
    }
    _fixture = fixture;
  }

  final Future<Directory> Function() _directory;
  final LocalDatabase? _database;
  final LocalInferenceQueue _queue;
  final Future<void> Function(String, EmbeddingModel)? _probe;
  LocalAiModel? _fixture;
  final _workers = <String, LocalModelDownload>{};
  final _readiness = StreamController<bool>.broadcast();
  Future<void>? _installation;
  String? _downloading;
  final _progress = <void Function(int, int)>[];
  bool? _lastReady;
  int _downloadGeneration = 0;
  int _cancelGeneration = 0;
  final _removing = <String>{};

  @override
  List<LocalAiModel> get catalog =>
      _fixture == null ? EmbeddingModel.catalog : [_fixture!];
  @override
  LocalAiModel get model =>
      _fixture ?? _database?.embeddingProfile ?? EmbeddingModel.qwen;
  String get _activeId => _fixture?.id ?? model.id;
  Future<void> _initialize() async => _database?.open();
  @override
  Stream<bool> get readinessChanges => _readiness.stream;

  @override
  Future<ModelCheckState> readiness({
    String? modelId,
    bool verify = false,
  }) async {
    await _initialize();
    final id = modelId ?? _activeId;
    final result =
        await _workers[id]?.readiness(verify: verify) ??
        ModelCheckState.missing;
    if (id == _activeId) {
      final ready = result == ModelCheckState.ready;
      if (_lastReady != ready && (ready || _lastReady == true)) _emit(ready);
      _lastReady = ready;
    }
    return result;
  }

  void _emit(bool ready) {
    if (!_readiness.isClosed) _readiness.add(ready);
  }

  @override
  Future<bool> isReady([String? modelId]) async =>
      await readiness(modelId: modelId, verify: true) == ModelCheckState.ready;

  @override
  Future<String> requireModelPath() async {
    await _initialize();
    return _workers[_activeId]!.requireModelPath();
  }

  @override
  Future<void> activate(String modelId) async {
    await _initialize();
    if (modelId == _activeId) return;
    final selected = EmbeddingModel.find(modelId);
    if (selected == null || !selected.available || _database == null) {
      throw const EmbeddingModelException(EmbeddingModelProblem.unsupported);
    }
    if (!await isReady(modelId)) {
      throw const EmbeddingModelException(EmbeddingModelProblem.notReady);
    }
    await _queue.run(() async {
      if (modelId == _activeId) return;
      final path = await _workers[modelId]!.requireModelPath();
      if (_probe != null) {
        await _probe(path, selected);
      } else {
        final session = LlamaEmbeddingSession(model: selected);
        try {
          await session.load(path);
          normalizeEmbedding(
            await session.embed(selected.query('Search readiness')),
            model: selected,
          );
        } finally {
          await session.dispose();
        }
      }
      await _database.selectEmbeddingModel(selected);
      // Also emitted when both old and new models are ready: identity changed.
      _lastReady = true;
      _emit(true);
    });
  }

  @override
  Future<int> storedBytes(String modelId, {bool partial = false}) async {
    final worker = _workers[modelId];
    if (worker == null) return 0;
    final file = File(
      p.join(
        (await _directory()).path,
        'embedding_models',
        '${worker.model.fileName}${partial ? '.part' : ''}',
      ),
    );
    final size = await file.exists() ? await file.length() : 0;
    if (!partial) return size;
    final retained = await worker.retainedPlatformBytes();
    return retained > size ? retained : size;
  }

  @override
  Future<void> remove(String modelId) => _queue.run(() async {
    await _initialize();
    if (modelId == _activeId || modelId == _downloading) {
      throw const EmbeddingModelException(EmbeddingModelProblem.inUse);
    }
    final worker = _workers[modelId];
    if (worker == null) return;
    _removing.add(modelId);
    try {
      for (final suffix in ['', '.part']) {
        final file = File(
          p.join(
            (await _directory()).path,
            'embedding_models',
            '${worker.model.fileName}$suffix',
          ),
        );
        if (await file.exists()) await file.delete();
      }
      await worker.verification.invalidate();
    } finally {
      _removing.remove(modelId);
    }
  });

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    final generation = ++_downloadGeneration;
    await _initialize();
    final id = modelId ?? _activeId;
    final worker = _workers[id];
    if (worker == null) throw ArgumentError.value(id, 'modelId');
    if (_removing.contains(id)) {
      throw const EmbeddingModelException(EmbeddingModelProblem.inUse);
    }
    if (_cancelGeneration >= generation) throw const ModelDownloadCancelled();
    if (_installation != null && _downloading != id) {
      throw const EmbeddingModelException(EmbeddingModelProblem.inUse);
    }
    if (_fixture == null && !(EmbeddingModel.find(id)?.available ?? false)) {
      throw const EmbeddingModelException(EmbeddingModelProblem.unsupported);
    }
    _progress.add(onProgress);
    _downloading = id;
    try {
      _installation ??= _install(worker, generation);
      await _installation;
    } finally {
      _progress.remove(onProgress);
    }
  }

  Future<void> _install(LocalModelDownload worker, int generation) async {
    try {
      await readiness(modelId: worker.model.id, verify: true);
      if (_cancelGeneration >= generation) throw const ModelDownloadCancelled();
      await worker.download(
        onProgress: (received, total) {
          for (final listener in List.of(_progress)) {
            listener(received, total);
          }
        },
      );
      if (worker.model.id == _activeId) {
        _lastReady = true;
        _emit(true);
      }
    } finally {
      _installation = null;
      _downloading = null;
    }
  }

  @override
  void cancelDownload() {
    _cancelGeneration = _downloadGeneration;
    _workers[_downloading]?.cancelDownload();
  }

  Future<void> dispose() => _readiness.close();
}
