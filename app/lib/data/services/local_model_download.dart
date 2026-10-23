import 'dart:async';
import 'dart:io';
import 'package:smartnotes/data/services/model_verification.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';
import 'package:smartnotes/domain/services/i_local_model_installation.dart';
import 'package:smartnotes/domain/services/i_platform_model_downloader.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:smartnotes/data/services/unsupported_platform_model_downloader.dart';

/// Shared streaming download and integrity checks for all local AI weights.
class LocalModelDownload implements ILocalModelInstallation<LocalAiModel> {
  LocalModelDownload(
    this._client, {
    required this.model,
    required this.directory,
    required this.folder,
    IPlatformModelDownloader? platformDownloader,
    this.freeStorage,
    ModelVerificationStore? verificationStore,
    String? Function()? legacySignature,
    Future<String> Function(File)? hash,
  }) : verification = ModelVerification(
         model: model,
         folder: folder,
         store: verificationStore,
         legacySignature: legacySignature,
         hash: hash,
       ),
       _platform =
           platformDownloader ?? const UnsupportedPlatformModelDownloader();
  final IPlatformModelDownloader _platform;
  final Future<int?> Function()? freeStorage;
  final http.Client _client;
  final Future<Directory> Function() directory;
  final LocalAiModel model;
  @override
  List<LocalAiModel> get catalog => [model];
  final String folder;
  Completer<void>? _abort;
  bool _cancelled = false;
  final ModelVerification verification;
  static const _deviceChannel = MethodChannel('dev.theolm.smartnotes/device');

  Future<File> _file() async =>
      File(p.join((await directory()).path, folder, model.fileName));

  /// iOS backs up Application Support by default. Model weights are replaceable
  /// downloads, so exclude both their directory and each verified artifact.
  Future<void> _excludeFromAppleBackup(String path) async {
    if (!Platform.isIOS) return;
    await _deviceChannel.invokeMethod<void>('excludeFromBackup', path);
  }

  Future<bool> _valid(File file) => verification.validatePartial(file);

  /// This probe never reads artifact contents, even on legacy installations.
  Future<bool> cachedReady() async {
    final file = await _file();
    if (await verification.cached(file)) return true;
    if (!_platform.supported) return false;
    final transfers = await _platform.status();
    final transfer = transfers.where((item) => item.id == model.id).firstOrNull;
    final receipt = transfer?.verification;
    final stat = await file.stat();
    if (transfer?.state != ModelTransferState.completed ||
        receipt == null ||
        receipt['version'] != 1 ||
        receipt['token'] != transfer?.token ||
        transfer?.token == null ||
        receipt['modelId'] != model.id ||
        receipt['folder'] != folder ||
        receipt['fileName'] != model.fileName ||
        receipt['digest'] != model.sha256 ||
        receipt['size'] != model.bytes ||
        stat.type != FileSystemEntityType.file ||
        stat.size != model.bytes ||
        receipt['modified'] != stat.modified.millisecondsSinceEpoch) {
      return false;
    }
    await verification.remember(stat);
    return true;
  }

  @override
  Future<bool> isReady([String? modelId]) async =>
      await readiness(modelId: modelId, verify: true) == ModelCheckState.ready;

  @override
  Future<ModelCheckState> readiness({
    String? modelId,
    bool verify = false,
  }) async {
    if (modelId != null && modelId != model.id) return ModelCheckState.missing;
    try {
      if (await cachedReady()) return ModelCheckState.ready;
      if (verify) await verification.verify(await _file());
      return verification.state;
    } catch (_) {
      verification.state = ModelCheckState.failed;
      return ModelCheckState.failed;
    }
  }

  Future<String> requireModelPath() async {
    if (!await isReady()) {
      throw StateError(
        'Local model is missing or corrupt. Complete model setup.',
      );
    }
    final file = await _file();
    await _excludeFromAppleBackup(file.parent.path);
    await _excludeFromAppleBackup(file.path);
    return file.path;
  }

  @override
  void cancelDownload() {
    _cancelled = true;
    if (_abort != null && !_abort!.isCompleted) _abort!.complete();
  }

  Future<void> _downloadInBackground(void Function(int, int) onProgress) async {
    final platform = _platform;
    Future<void> checkCancelled() async {
      if (!_cancelled) return;
      // The native work may predate this Dart waiter, including during preflight.
      await platform.cancel(model.id);
      throw const ModelDownloadCancelled();
    }

    await checkCancelled();
    if (!await hasActivePlatformTransfer()) {
      final partial = File('${(await _file()).path}.part');
      final local = await partial.exists() ? await partial.length() : 0;
      final retained = await retainedPlatformBytes();
      final stored = local > retained ? local : retained;
      final free = await freeStorage?.call();
      final remaining = model.bytes - (stored <= model.bytes ? stored : 0);
      if (free != null &&
          remaining > 0 &&
          free < remaining + 64 * 1024 * 1024) {
        throw const FileSystemException('Not enough storage for the model.');
      }
    }
    await checkCancelled();
    final before = (await platform.status())
        .where((item) => item.id == model.id)
        .firstOrNull;
    // Permission is explained and requested during onboarding. Downloads never
    // interrupt a later user action with an unsolicited system prompt.
    await platform.notificationsAllowed();
    await checkCancelled();
    if (before?.state == ModelTransferState.completed && await isReady()) {
      onProgress(model.bytes, model.bytes);
      return;
    }
    await platform.start(
      model,
      folder,
      repair: before?.state == ModelTransferState.completed,
    );
    while (true) {
      if (_cancelled) {
        await platform.cancel(model.id);
        throw const ModelDownloadCancelled();
      }
      final transfers = await platform.status();
      final transfer = transfers
          .where((item) => item.id == model.id)
          .firstOrNull;
      if (transfer == null) throw StateError('Model transfer disappeared.');
      onProgress(transfer.received, model.bytes);
      switch (transfer.state) {
        case ModelTransferState.completed:
          // Never trust a native completion record over the actual artifact.
          if (!await isReady()) {
            throw const FormatException('Local model integrity check failed.');
          }
          return;
        case ModelTransferState.cancelled:
          throw const ModelDownloadCancelled();
        case ModelTransferState.failed:
          throw FileSystemException(transfer.error ?? 'Model download failed.');
        default:
          await Future.any([
            Future<void>.delayed(const Duration(milliseconds: 500)),
            _abort!.future,
          ]);
      }
    }
  }

  Future<bool> hasActivePlatformTransfer() async =>
      (await _platform.status()).any(
        (transfer) => transfer.id == model.id && transfer.state.isActive,
      );

  Future<int> retainedPlatformBytes() async {
    final transfers = await _platform.status();
    return transfers
            .where((item) => item.id == model.id)
            .firstOrNull
            ?.retainedBytes ??
        0;
  }

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    if (modelId != null && modelId != model.id) {
      throw ArgumentError.value(modelId, 'modelId');
    }
    if (_abort != null) {
      throw StateError('A model download is already running.');
    }
    _abort = Completer<void>();
    _cancelled = false;
    IOSink? sink;
    try {
      if (await isReady()) {
        onProgress(model.bytes, model.bytes);
        return;
      }
      if (_platform.supported) {
        await _downloadInBackground(onProgress);
        return;
      }
      final destination = await _file();
      await destination.parent.create(recursive: true);
      await _excludeFromAppleBackup(destination.parent.path);
      final partial = File('${destination.path}.part');
      var received = await partial.exists() ? await partial.length() : 0;
      if (received > model.bytes) {
        await partial.delete();
        received = 0;
      }
      if (received < model.bytes) {
        final request = http.AbortableRequest(
          'GET',
          Uri.parse(model.url),
          abortTrigger: _abort!.future,
        );
        if (received > 0) request.headers['Range'] = 'bytes=$received-';
        final response = await _client
            .send(request)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          received = 0;
        } else if (response.statusCode != 206 ||
            response.headers['content-range'] !=
                'bytes $received-${model.bytes - 1}/${model.bytes}') {
          await response.stream.drain<void>().timeout(
            const Duration(seconds: 30),
          );
          throw HttpException(
            'Could not download the local model (${response.statusCode}).',
          );
        }
        sink = partial.openWrite(
          mode: received == 0 ? FileMode.write : FileMode.append,
        );
        onProgress(received, model.bytes);
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          if (_cancelled) throw const ModelDownloadCancelled();
          received += chunk.length;
          if (received > model.bytes) {
            throw const FormatException('Invalid model size.');
          }
          sink.add(chunk);
          // Bound write buffering rather than keeping the model in Dart memory.
          await sink.flush();
          onProgress(received, model.bytes);
        }
        await sink.close();
        sink = null;
      }
      if (_cancelled) throw const ModelDownloadCancelled();
      if (!await _valid(partial)) {
        if (await partial.exists()) await partial.delete();
        throw const FormatException(
          'Local model integrity check failed. Please download again.',
        );
      }
      if (_cancelled) throw const ModelDownloadCancelled();
      await partial.rename(destination.path);
      await verification.remember(await destination.stat());
      await _excludeFromAppleBackup(destination.path);
      onProgress(model.bytes, model.bytes);
    } catch (_) {
      if (_cancelled) throw const ModelDownloadCancelled();
      rethrow;
    } finally {
      try {
        await sink?.close();
      } finally {
        if (!_abort!.isCompleted) _abort!.complete();
        _abort = null;
      }
    }
  }
}
