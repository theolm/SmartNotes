import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartnotes/data/services/speech_model_service.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';

void main() {
  late Directory directory;
  final bytes = List<int>.generate(16, (i) => i);
  late SpeechModel model;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('speech-model-test-');
    model = SpeechModel(
      id: 'test',
      name: 'Test',
      fileName: 'model.bin',
      url: 'https://example.com/model.bin',
      bytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );
  });
  tearDown(() => directory.delete(recursive: true));
  SpeechModelService service(http.Client client) =>
      SpeechModelService.forTesting(
        client,
        model: model,
        directory: () async => directory,
      );
  File getFile() => File('${directory.path}/speech_models/model.bin');
  Future<void> partial(List<int> data) async {
    final file = File('${getFile().path}.part');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data);
  }

  test(
    'deleting installed speech weights never hashes removed or alternative artifacts',
    () async {
      final other = SpeechModel(
        id: 'other',
        name: 'Other',
        fileName: 'other.bin',
        url: model.url,
        bytes: model.bytes,
        sha256: model.sha256,
      );
      await getFile().parent.create(recursive: true);
      await getFile().writeAsBytes(bytes);
      final removed = File('${getFile().parent.path}/${other.fileName}');
      await removed.writeAsBytes(bytes);
      var hashes = 0;
      final client = MockClient((_) async => throw StateError('No network'));
      addTearDown(client.close);
      final models = SpeechModelService.forTesting(
        client,
        model: model,
        catalog: [model, other],
        directory: () async => directory,
        hash: (_) async {
          hashes++;
          return model.sha256;
        },
      );
      await models.remove(other.id);
      expect(await removed.exists(), false);
      expect(await getFile().exists(), true);
      expect(hashes, 0);
    },
  );

  test(
    'only complete SHA-256 verified weights become available offline',
    () async {
      var calls = 0;
      final models = service(
        MockClient((_) async {
          calls++;
          return http.Response.bytes(bytes, 200);
        }),
      );
      expect(await models.isReady(), false);
      await expectLater(models.requireModelPath(), throwsStateError);
      final progress = <int>[];
      await models.download(
        onProgress: (received, _) => progress.add(received),
      );
      expect(progress.last, bytes.length);
      expect(await models.requireModelPath(), getFile().path);
      await models.download(onProgress: (_, _) {});
      expect(calls, 1);
      // A new service/launch validates the installed file without a network call.
      expect(
        await service(
          MockClient((_) async => throw StateError('offline')),
        ).isReady(),
        true,
      );
    },
  );

  test(
    'resumes a partial download using Range and validates the result',
    () async {
      await partial(bytes.sublist(0, 5));
      final models = service(
        MockClient((request) async {
          expect(request.headers['Range'], 'bytes=5-');
          return http.Response.bytes(
            bytes.sublist(5),
            206,
            headers: {'content-range': 'bytes 5-15/16'},
          );
        }),
      );
      await models.download(onProgress: (_, _) {});
      expect(await getFile().readAsBytes(), bytes);
    },
  );

  test(
    'server ignoring Range restarts instead of appending duplicate bytes',
    () async {
      await partial(bytes.sublist(0, 5));
      final models = service(
        MockClient((_) async => http.Response.bytes(bytes, 200)),
      );
      await models.download(onProgress: (_, _) {});
      expect(await getFile().readAsBytes(), bytes);
    },
  );

  test(
    'installed same-size corruption is rejected on the next readiness check',
    () async {
      final models = service(
        MockClient((_) async => http.Response.bytes(bytes, 200)),
      );
      await models.download(onProgress: (_, _) {});
      await getFile().writeAsBytes(List.filled(bytes.length, 99));
      await getFile().setLastModified(
        DateTime.now().add(const Duration(seconds: 1)),
      );
      expect(await models.isReady(), false);
      await expectLater(models.requireModelPath(), throwsStateError);
    },
  );

  test('rejects a wrong range without promoting partial weights', () async {
    await partial(bytes.sublist(0, 5));
    final models = service(
      MockClient(
        (_) async => http.Response.bytes(
          bytes,
          206,
          headers: {'content-range': 'bytes 0-15/16'},
        ),
      ),
    );
    await expectLater(
      models.download(onProgress: (_, _) {}),
      throwsA(isA<HttpException>()),
    );
    expect(await models.isReady(), false);
    expect(await File('${getFile().path}.part').length(), 5);
  });

  test(
    'corrupt weights are never marked ready and retry can recover',
    () async {
      var corrupt = true;
      final models = service(
        MockClient(
          (_) async =>
              http.Response.bytes(corrupt ? List.filled(16, 99) : bytes, 200),
        ),
      );
      await expectLater(
        models.download(onProgress: (_, _) {}),
        throwsFormatException,
      );
      expect(await models.isReady(), false);
      expect(await File('${getFile().path}.part').exists(), false);
      corrupt = false;
      await models.download(onProgress: (_, _) {});
      expect(await models.isReady(), true);
    },
  );

  test('interrupted stream keeps partial bytes for retry', () async {
    final client = MockClient.streaming(
      (_, _) async => http.StreamedResponse(
        Stream<List<int>>.multi((controller) {
          controller.add(bytes.sublist(0, 5));
          controller.addError(const SocketException('Connection lost'));
          controller.close();
        }),
        200,
      ),
    );
    final models = service(client);
    await expectLater(
      models.download(onProgress: (_, _) {}),
      throwsA(isA<SocketException>()),
    );
    expect(await File('${getFile().path}.part').length(), 5);
    expect(await models.isReady(), false);
  });

  test(
    'cancellation preserves partial bytes without publishing a model',
    () async {
      final stream = StreamController<List<int>>();
      final models = service(
        MockClient.streaming(
          (_, _) async => http.StreamedResponse(stream.stream, 200),
        ),
      );
      final progress = Completer<void>();
      final job = models.download(
        onProgress: (received, _) {
          if (received > 0 && !progress.isCompleted) progress.complete();
        },
      );
      final expectation = expectLater(
        job,
        throwsA(isA<ModelDownloadCancelled>()),
      );
      stream.add(bytes.sublist(0, 5));
      await progress.future;
      models.cancelDownload();
      await stream.close();
      await expectation;
      expect(await models.isReady(), false);
      expect(await File('${getFile().path}.part').length(), 5);
    },
  );
}
