import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartnotes/data/services/embedding_model_service.dart';
import 'package:smartnotes/data/services/formatting_model_service.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/data/services/speech_model_service.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';
import 'package:smartnotes/domain/services/i_local_model_installation.dart';

/// The same installation guarantees apply without depending on inference.
void main() {
  final bytes = List<int>.generate(16, (i) => i);
  final digest = sha256.convert(bytes).toString();
  final artifact = LocalAiModel(
    id: 'test',
    name: 'Test',
    fileName: 'model.bin',
    url: 'https://example.com/model.bin',
    bytes: bytes.length,
    sha256: digest,
  );
  final speech = SpeechModel(
    id: artifact.id,
    name: artifact.name,
    fileName: artifact.fileName,
    url: artifact.url,
    bytes: artifact.bytes,
    sha256: digest,
  );
  final formatting = FormattingModel(
    id: artifact.id,
    name: artifact.name,
    fileName: artifact.fileName,
    url: artifact.url,
    bytes: artifact.bytes,
    sha256: digest,
    kind: FormattingModelKind.light,
    quantization: 'Q8_0',
  );

  for (final folder in [
    'speech_models',
    'formatting_models',
    'embedding_models',
    'another_model',
  ]) {
    group(folder, () {
      late Directory directory;
      late http.Client client;
      late ILocalModelInstallation<LocalAiModel> installation;
      File getFile() => File('${directory.path}/$folder/model.bin');
      File partial() => File('${getFile().path}.part');

      void create(http.Client value) {
        client = value;
        installation = switch (folder) {
          'speech_models' => SpeechModelService.forTesting(
            client,
            model: speech,
            directory: () async => directory,
          ),
          'formatting_models' => FormattingModelService.forTesting(
            client,
            model: formatting,
            directory: () async => directory,
          ),
          'embedding_models' => EmbeddingModelService.forTesting(
            client,
            model: artifact,
            directory: () async => directory,
          ),
          _ => LocalModelDownload(
            client,
            model: artifact,
            directory: () async => directory,
            folder: folder,
          ),
        };
      }

      setUp(() async {
        directory = await Directory.systemTemp.createTemp('installation-test-');
        create(MockClient((_) async => http.Response.bytes(bytes, 200)));
      });
      tearDown(() async {
        if (installation case final EmbeddingModelService embeddings) {
          await embeddings.dispose();
        }
        client.close();
        await directory.delete(recursive: true);
      });

      Future<void> download() => installation.download(
        modelId: artifact.id,
        onProgress: (_, _) {},
      );

      if (folder == 'embedding_models') {
        test(
          'publishes readiness only after verified installation and repair',
          () async {
            final embeddings = installation as EmbeddingModelService;
            final events = <bool>[];
            final subscription = embeddings.readinessChanges.listen(events.add);
            addTearDown(subscription.cancel);
            await expectLater(
              embeddings.download(modelId: 'unknown', onProgress: (_, _) {}),
              throwsArgumentError,
            );
            await pumpEventQueue();
            expect(events, isEmpty);
            await download();
            await pumpEventQueue();
            expect(events, [true]);
            expect(await embeddings.isReady(), true);
            await getFile().delete();
            await download();
            await pumpEventQueue();
            expect(events, [true, false, true]);
          },
        );
      }

      test('exposes metadata and rejects unknown artifacts', () async {
        expect(installation.catalog.single.id, artifact.id);
        expect(installation.catalog.single.sha256, digest);
        expect(await installation.isReady('unknown'), false);
        await expectLater(
          installation.download(modelId: 'unknown', onProgress: (_, _) {}),
          throwsArgumentError,
        );
        expect(await getFile().exists(), false);
      });

      test('verifies, detects missing weights, and repairs them', () async {
        expect(await installation.isReady(artifact.id), false);
        await download();
        expect(await installation.isReady(artifact.id), true);
        await getFile().delete();
        expect(await installation.isReady(artifact.id), false);
        await download();
        expect(await installation.isReady(artifact.id), true);
      });

      test('rejects same-size corrupt installed weights', () async {
        await download();
        await getFile().writeAsBytes(List.filled(bytes.length, 99));
        await getFile().setLastModified(
          DateTime.now().add(const Duration(seconds: 1)),
        );
        expect(await installation.isReady(artifact.id), false);
        await download();
        expect(await getFile().readAsBytes(), bytes);
      });

      test('resumes partial weights and verifies before publishing', () async {
        await partial().parent.create(recursive: true);
        await partial().writeAsBytes(bytes.sublist(0, 5));
        client.close();
        create(
          MockClient((request) async {
            expect(request.headers['Range'], 'bytes=5-');
            return http.Response.bytes(
              bytes.sublist(5),
              206,
              headers: {'content-range': 'bytes 5-15/16'},
            );
          }),
        );
        await download();
        expect(await getFile().readAsBytes(), bytes);
        expect(await partial().exists(), false);
        expect(await installation.isReady(artifact.id), true);
      });

      test('never publishes corrupt downloads', () async {
        client.close();
        create(
          MockClient(
            (_) async => http.Response.bytes(
              List.filled(bytes.length, 99),
              200,
            ),
          ),
        );
        await expectLater(download(), throwsFormatException);
        expect(await installation.isReady(artifact.id), false);
        expect(await getFile().exists(), false);
        expect(await partial().exists(), false);
      });

      test('cancellation preserves partial weights for resume', () async {
        final stream = StreamController<List<int>>();
        client.close();
        create(
          MockClient.streaming(
            (_, _) async => http.StreamedResponse(stream.stream, 200),
          ),
        );
        final progress = Completer<void>();
        final job = installation.download(
          modelId: artifact.id,
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
        installation.cancelDownload();
        await stream.close();
        await expectation;
        expect(await installation.isReady(artifact.id), false);
        expect(await getFile().exists(), false);
        expect(await partial().readAsBytes(), bytes.sublist(0, 5));
      });
    });
  }
}
