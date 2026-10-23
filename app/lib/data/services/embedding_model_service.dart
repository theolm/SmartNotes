import 'dart:async';
import 'package:smartnotes/data/services/model_verification.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';
import 'package:smartnotes/domain/services/i_platform_model_downloader.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';

Future<void> disposeEmbeddingModelService(IEmbeddingModelService service) =>
    (service as EmbeddingModelService).dispose();

@LazySingleton(
  as: IEmbeddingModelService,
  dispose: disposeEmbeddingModelService,
)
class EmbeddingModelService extends LocalModelDownload
    implements IEmbeddingModelService {
  EmbeddingModelService(
    super.client,
    IPlatformModelDownloader downloader,
    DeviceProfileService device,
    ModelVerificationStore verificationStore,
  ) : super(
        model: LocalAiModel.qwenEmbedding,
        directory: getApplicationSupportDirectory,
        folder: 'embedding_models',
        platformDownloader: downloader,
        freeStorage: device.freeStorage,
        verificationStore: verificationStore,
      );

  EmbeddingModelService.forTesting(
    super.client, {
    required super.model,
    required super.directory,
    super.platformDownloader,
    super.verificationStore,
    super.hash,
  }) : super(folder: 'embedding_models');

  final _readiness = StreamController<bool>.broadcast();
  Future<void>? _installation;
  bool? _lastReady;
  final _progress = <void Function(int, int)>[];

  @override
  Stream<bool> get readinessChanges => _readiness.stream;

  @override
  Future<ModelCheckState> readiness({
    String? modelId,
    bool verify = false,
  }) async {
    final result = await super.readiness(modelId: modelId, verify: verify);
    if (modelId != null && modelId != model.id) return result;
    final ready = result == ModelCheckState.ready;
    if (_lastReady != ready &&
        (ready || _lastReady == true) &&
        !_readiness.isClosed) {
      _lastReady = ready;
      _readiness.add(ready);
    }
    return result;
  }

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    if (modelId != null && modelId != model.id) {
      throw ArgumentError.value(modelId, 'modelId');
    }
    _progress.add(onProgress);
    try {
      // Leaving setup must not cancel installation. A newly opened screen joins
      // the same installation even while the original Dart waiter is alive.
      _installation ??= _install();
      await _installation;
    } finally {
      _progress.remove(onProgress);
    }
  }

  Future<void> _install() async {
    try {
      await super.download(
        onProgress: (received, total) {
          for (final listener in List.of(_progress)) {
            listener(received, total);
          }
        },
      );
      if (_lastReady != true && !_readiness.isClosed) _readiness.add(true);
      _lastReady = true;
    } finally {
      _installation = null;
    }
  }

  Future<void> dispose() => _readiness.close();
}
