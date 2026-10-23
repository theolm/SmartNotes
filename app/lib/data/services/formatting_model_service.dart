import 'package:smartnotes/data/services/model_verification.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/services/i_formatting_model_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';
import 'package:smartnotes/domain/services/i_platform_model_downloader.dart';
import 'package:smartnotes/data/services/unsupported_platform_model_downloader.dart';

enum FormattingModelProblem { notReady, inUse, storage }

class FormattingModelException implements Exception {
  const FormattingModelException(this.problem);

  final FormattingModelProblem problem;
}

@LazySingleton(as: IFormattingModelService)
class FormattingModelService implements IFormattingModelService {
  FormattingModelService(
    http.Client client,
    ISettingsService settings,
    LocalInferenceQueue queue,
    DeviceProfileService device,
    IPlatformModelDownloader downloader,
    ModelVerificationStore verificationStore,
  ) : this._(
        client,
        FormattingModel.catalog,
        getApplicationSupportDirectory,
        settings,
        queue,
        device,
        downloader,
        verificationStore,
      );

  FormattingModelService.forTesting(
    http.Client client, {
    required FormattingModel model,
    required Future<Directory> Function() directory,
    List<FormattingModel>? catalog,
    ISettingsService? settings,
    LocalInferenceQueue? queue,
    DeviceProfileService? device,
    IPlatformModelDownloader? platformDownloader,
    ModelVerificationStore? verificationStore,
    Future<String> Function(File)? hash,
  }) : this._(
         client,
         catalog ?? [model],
         directory,
         settings,
         queue ?? LocalInferenceQueue(),
         device,
         platformDownloader ?? const UnsupportedPlatformModelDownloader(),
         verificationStore,
         hash,
       );

  FormattingModelService._(
    http.Client client,
    this.catalog,
    this._directory,
    this._settings,
    this._queue,
    this._device,
    IPlatformModelDownloader downloader,
    ModelVerificationStore? verificationStore, [
    Future<String> Function(File)? hash,
  ]) {
    for (final model in catalog) {
      _workers[model.id] = LocalModelDownload(
        client,
        model: model,
        directory: _directory,
        folder: 'formatting_models',
        platformDownloader: downloader,
        freeStorage: _device?.freeStorage,
        verificationStore: verificationStore,
        legacySignature: _settings?.getFormattingModelSignature,
        hash: hash,
      );
    }
  }

  @override
  final List<FormattingModel> catalog;
  final Future<Directory> Function() _directory;
  final ISettingsService? _settings;
  final LocalInferenceQueue _queue;
  final DeviceProfileService? _device;
  final _workers = <String, LocalModelDownload>{};
  String? _downloading;
  int _downloadGeneration = 0;
  int _cancelGeneration = 0;
  final _removing = <String>{};

  @override
  String? get configuredModelId => _settings?.getFormattingModelId();

  @override
  String get activeModelId => configuredModelId ?? '';

  @override
  FormattingModel? get activeModel => _find(activeModelId);

  FormattingModel? _find(String id) {
    for (final item in catalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<bool> isReady([String? modelId]) async {
    final id = modelId ?? activeModelId;
    if (id.isEmpty) return false;
    final worker = _workers[id];
    return worker != null && await worker.isReady();
  }

  @override
  Future<ModelCheckState> readiness({
    String? modelId,
    bool verify = false,
  }) async {
    final worker = _workers[modelId ?? activeModelId];
    return worker == null
        ? ModelCheckState.missing
        : await worker.readiness(verify: verify);
  }

  @override
  Future<String> requireModelPath() async {
    final id = activeModelId;
    if (id.isEmpty || !await isReady()) {
      throw const FormattingModelException(FormattingModelProblem.notReady);
    }
    return _workers[id]!.requireModelPath();
  }

  @override
  Future<bool> isPresent(String modelId) async {
    final item = _find(modelId);
    return item != null && await storedBytes(modelId) == item.bytes;
  }

  @override
  Future<int> storedBytes(String modelId, {bool partial = false}) async {
    final item = _find(modelId);
    if (item == null) return 0;
    final file = File(
      p.join(
        (await _directory()).path,
        'formatting_models',
        '${item.fileName}${partial ? '.part' : ''}',
      ),
    );
    final local = await file.exists() ? await file.length() : 0;
    if (!partial) return local;
    final retained = await _workers[modelId]!.retainedPlatformBytes();
    return local > retained ? local : retained;
  }

  @override
  Future<void> activate(String modelId) => _queue.run(() async {
    final item = _find(modelId);
    if (item == null || !await isReady(modelId)) {
      throw const FormattingModelException(FormattingModelProblem.notReady);
    }
    await _settings?.setFormattingModelId(modelId);
  });

  @override
  Future<void> remove(String modelId) => _queue.run(() async {
    if (modelId == activeModelId || modelId == _downloading) {
      throw const FormattingModelException(FormattingModelProblem.inUse);
    }
    final item = _find(modelId);
    if (item == null) return;
    _removing.add(modelId);
    try {
      final root = await _directory();
      for (final suffix in ['', '.part']) {
        final file = File(
          p.join(root.path, 'formatting_models', '${item.fileName}$suffix'),
        );
        if (await file.exists()) await file.delete();
      }
      await _workers[modelId]!.verification.invalidate();
    } finally {
      _removing.remove(modelId);
    }
  });

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    final id = modelId ?? activeModelId;
    final worker = _workers[id];
    if (worker == null) throw ArgumentError.value(id);
    if (_downloading != null || _removing.contains(id)) {
      throw const FormattingModelException(FormattingModelProblem.inUse);
    }
    final generation = ++_downloadGeneration;
    _downloading = id;
    try {
      if (!await isReady(id) && !await worker.hasActivePlatformTransfer()) {
        final partial = await storedBytes(id, partial: true);
        final free = await _device?.freeStorage();
        final remaining =
            worker.model.bytes - (partial <= worker.model.bytes ? partial : 0);
        if (free != null &&
            remaining > 0 &&
            free < remaining + 64 * 1024 * 1024) {
          throw const FormattingModelException(FormattingModelProblem.storage);
        }
      }
      // A cancel can arrive while preflight awaits storage or file stats.
      if (_cancelGeneration >= generation) {
        throw const ModelDownloadCancelled();
      }
      await worker.download(onProgress: onProgress);
    } finally {
      _downloading = null;
    }
  }

  @override
  void cancelDownload() {
    _cancelGeneration = _downloadGeneration;
    _workers[_downloading]?.cancelDownload();
  }
}
