import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/data/services/model_verification.dart';
import 'package:smartnotes/data/services/embedding_model_service.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';
import 'package:smartnotes/data/services/unsupported_platform_model_downloader.dart';

class _Platform extends UnsupportedPlatformModelDownloader {
  @override
  bool get supported => true;
  @override
  Future<bool> notificationsAllowed() async {
    await permission?.future;
    return allowed;
  }

  late ModelTransfer transfer;
  int starts = 0;
  int cancellations = 0;
  int permissionRequests = 0;
  Future<void> Function()? onStatus;
  bool allowed = true;
  Future<void> Function()? onStart;
  Completer<void>? permission;

  @override
  Future<bool> requestNotifications() async {
    permissionRequests++;
    await permission?.future;
    return allowed;
  }

  @override
  Future<void> start(
    LocalAiModel model,
    String folder, {
    bool repair = false,
  }) async {
    starts++;
    await onStart?.call();
  }

  @override
  Future<List<ModelTransfer>> status() async {
    await onStatus?.call();
    return [transfer];
  }

  @override
  Future<void> cancel(String id) async {
    cancellations++;
    setState(ModelTransferState.cancelled);
  }

  void setState(ModelTransferState state, {int received = 0}) {
    transfer = ModelTransfer(
      id: 'test',
      state: state,
      received: received,
      total: 16,
    );
  }
}

void main() {
  final bytes = List<int>.generate(16, (i) => i);
  final model = LocalAiModel(
    id: 'test',
    name: 'Test',
    fileName: 'model.bin',
    url: 'https://example.com/model.bin',
    bytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
  );
  late Directory root;
  late _Platform platform;
  late LocalModelDownload installation;
  late MockClient client;
  File getFile() => File('${root.path}/models/model.bin');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('platform-download-');
    platform = _Platform()..setState(ModelTransferState.downloading);
    client = MockClient(
      (_) => throw StateError('Dart must not own mobile HTTP.'),
    );
    installation = LocalModelDownload(
      client,
      model: model,
      directory: () async => root,
      folder: 'models',
      platformDownloader: platform,
    );
  });
  tearDown(() async {
    client.close();
    await root.delete(recursive: true);
  });

  Future<void> promote() async {
    await getFile().parent.create(recursive: true);
    await getFile().writeAsBytes(bytes);
    platform.setState(ModelTransferState.completed, received: bytes.length);
  }

  Future<void> download() => installation.download(onProgress: (_, _) {});

  Future<Map<String, dynamic>> receipt() async => {
    'version': 1,
    'token': 'attempt',
    'modelId': model.id,
    'folder': 'models',
    'fileName': model.fileName,
    'digest': model.sha256,
    'size': model.bytes,
    'modified': (await getFile().stat()).modified.millisecondsSinceEpoch,
  };

  test(
    'native post-promotion receipt seeds cold readiness without a Dart hash',
    () async {
      await promote();
      final records = <String, String>{};
      final store = ModelVerificationStore.forTesting(
        read: (key) => records[key],
        write: (key, value) async {
          if (value == null) {
            records.remove(key);
          } else {
            records[key] = value;
          }
        },
      );
      platform.transfer = ModelTransfer.fromMap({
        'id': model.id,
        'state': 'completed',
        'received': model.bytes,
        'bytes': model.bytes,
        'token': 'attempt',
        'verification': await receipt(),
      });
      LocalModelDownload worker() => LocalModelDownload(
        client,
        model: model,
        directory: () async => root,
        folder: 'models',
        platformDownloader: platform,
        verificationStore: store,
        hash: (_) async =>
            throw StateError('Must not hash native verified artifact'),
      );
      expect(await worker().isReady(), true);
      expect(records, hasLength(1));
      platform.setState(ModelTransferState.failed);
      expect(await worker().isReady(), true);
    },
  );

  for (final field in [
    'version',
    'token',
    'modelId',
    'folder',
    'fileName',
    'digest',
    'size',
    'modified',
  ]) {
    test(
      'native receipt with mismatching $field never certifies an artifact',
      () async {
        await promote();
        final value = await receipt();
        value[field] = ['version', 'size', 'modified'].contains(field)
            ? -1
            : 'wrong';
        platform.transfer = ModelTransfer(
          id: model.id,
          state: ModelTransferState.completed,
          received: model.bytes,
          total: model.bytes,
          token: 'attempt',
          verification: value,
        );
        var hashes = 0;
        final worker = LocalModelDownload(
          client,
          model: model,
          directory: () async => root,
          folder: 'models',
          platformDownloader: platform,
          hash: (_) async {
            hashes++;
            return model.sha256;
          },
        );
        expect(await worker.cachedReady(), false);
        expect(hashes, 0);
        expect(await worker.isReady(), true);
        expect(hashes, 1);
      },
    );
  }

  test(
    'typed persisted state distinguishes transfer from verified completion',
    () {
      final state = ModelTransfer.fromMap({
        'id': 'test',
        'state': 'verifying',
        'received': 16,
        'bytes': 16,
        'retained': 7,
      });
      expect(state.state, ModelTransferState.verifying);
      expect(state.retainedBytes, 7);
      expect(state.state.isActive, true);
      expect(ModelTransferState.completed.isActive, false);
      expect(
        () => ModelTransfer.fromMap({'id': 'test', 'state': 'unknown'}),
        throwsArgumentError,
      );
    },
  );

  test('native completion is independently verified by Dart', () async {
    platform.onStart = promote;
    await download();
    expect(await installation.isReady(), true);
    expect(platform.starts, 1);
  });

  test('download respects an onboarding notification denial', () async {
    platform.setState(ModelTransferState.failed);
    platform.allowed = false;
    platform.onStart = promote;
    await download();
    expect(await installation.isReady(), true);
    expect(platform.permissionRequests, 0);
  });

  test('completed work is not started again after a Dart restart', () async {
    await promote();
    await download();
    expect(platform.starts, 0);
  });

  test(
    'completion during reattachment does not trigger a repair transfer',
    () async {
      platform.onStatus = () async {
        platform.onStatus = null;
        await promote();
      };
      await download();
      expect(platform.starts, 0);
      expect(await installation.isReady(), true);
    },
  );

  test(
    'restoring active work never prompts for notification permission',
    () async {
      platform.onStart = promote;
      await download();
      expect(platform.permissionRequests, 0);
    },
  );

  test(
    'cancelling during reattachment stops the pre-existing native transfer',
    () async {
      platform.permission = Completer<void>();
      final pending = download();
      await pumpEventQueue();
      installation.cancelDownload();
      platform.permission!.complete();
      await expectLater(pending, throwsA(isA<ModelDownloadCancelled>()));
      expect(platform.cancellations, 1);
      expect(platform.transfer.state, ModelTransferState.cancelled);
      expect(platform.starts, 0);
    },
  );

  test(
    'relaunch attaches to running native work and restores progress',
    () async {
      platform.setState(ModelTransferState.downloading, received: 7);
      final progress = <int>[];
      final pending = installation.download(
        onProgress: (received, _) {
          progress.add(received);
          if (received == 7) unawaited(promote());
        },
      );
      await pending;
      expect(progress.first, 7);
      expect(progress.last, 16);
      expect(platform.starts, 1);
      expect(await installation.isReady(), true);
    },
  );

  test(
    'app cancellation cancels durable work and preserves partial bytes',
    () async {
      final partial = File('${getFile().path}.part');
      await partial.parent.create(recursive: true);
      await partial.writeAsBytes(bytes.take(5).toList());
      final pending = installation.download(
        onProgress: (_, _) => installation.cancelDownload(),
      );
      await expectLater(pending, throwsA(isA<ModelDownloadCancelled>()));
      expect(platform.cancellations, 1);
      expect(await partial.length(), 5);
      expect(await installation.isReady(), false);
    },
  );

  test(
    'notification cancellation reconciles as cancellation, not failure',
    () async {
      platform.onStart = () async =>
          platform.setState(ModelTransferState.cancelled);
      await expectLater(download(), throwsA(isA<ModelDownloadCancelled>()));
      expect(platform.cancellations, 0);
    },
  );

  test('cancellation during permission prompt cannot enqueue work', () async {
    platform.setState(ModelTransferState.failed);
    platform.permission = Completer<void>();
    final pending = download();
    await pumpEventQueue();
    installation.cancelDownload();
    platform.permission!.complete();
    await expectLater(pending, throwsA(isA<ModelDownloadCancelled>()));
    expect(platform.starts, 0);
  });

  test('native failed state is surfaced without reporting ready', () async {
    platform.onStart = () async => platform.setState(ModelTransferState.failed);
    await expectLater(download(), throwsA(isA<FileSystemException>()));
    expect(await installation.isReady(), false);
  });

  test(
    'same-size corrupt native completion is never ready and can be repaired',
    () async {
      platform.onStart = () async {
        await getFile().parent.create(recursive: true);
        await getFile().writeAsBytes(List.filled(bytes.length, 99));
        platform.setState(ModelTransferState.completed, received: 16);
      };
      await expectLater(download(), throwsFormatException);
      expect(await installation.isReady(), false);
      platform.onStart = promote;
      await download();
      expect(await installation.isReady(), true);
    },
  );

  test(
    'verifying transfer does not expose readiness before promotion',
    () async {
      platform.setState(ModelTransferState.verifying, received: 16);
      var checked = false;
      await installation.download(
        onProgress: (_, _) {
          if (!checked) {
            checked = true;
            unawaited(() async {
              expect(await installation.isReady(), false);
              await promote();
            }());
          }
        },
      );
      expect(checked, true);
      expect(await installation.isReady(), true);
    },
  );

  test('a second Dart caller cannot create concurrent work', () async {
    platform.permission = Completer<void>();
    final pending = download();
    await expectLater(download(), throwsStateError);
    platform.onStart = promote;
    platform.permission!.complete();
    await pending;
    expect(platform.starts, 1);
  });

  test(
    'reopening embedding setup joins its still-running Dart installation',
    () async {
      final embeddings = EmbeddingModelService.forTesting(
        client,
        model: model,
        directory: () async => root,
        platformDownloader: platform,
      );
      addTearDown(embeddings.dispose);
      platform.permission = Completer<void>();
      final progress = <int>[];
      final events = <bool>[];
      final subscription = embeddings.readinessChanges.listen(events.add);
      addTearDown(subscription.cancel);
      final first = embeddings.download(onProgress: (_, _) {});
      final second = embeddings.download(
        onProgress: (received, _) => progress.add(received),
      );
      platform.onStart = () async {
        final destination = File('${root.path}/embedding_models/model.bin');
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(bytes);
        platform.setState(ModelTransferState.completed, received: 16);
      };
      platform.permission!.complete();
      await Future.wait([first, second]);
      await pumpEventQueue();
      expect(platform.starts, 1);
      expect(progress.last, 16);
      expect(events, [true]);
      expect(await embeddings.isReady(), true);
    },
  );
}
