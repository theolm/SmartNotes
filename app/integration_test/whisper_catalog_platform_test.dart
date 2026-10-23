import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_transcription_service.dart';
import 'package:smartnotes/data/services/speech_model_service.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';

class _Settings extends Mock implements ISettingsService {}

/// Isolated, opt-in fixtures. Does not initialize DI, preferences, or the journal.
/// STT_CATALOG_ROOT contains speech_models/, jfk.wav, and portuguese.aiff.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const fixtureRoot = String.fromEnvironment('STT_CATALOG_ROOT');
  const fixtureUrl = String.fromEnvironment('STT_FIXTURE_URL');
  var root = fixtureRoot;
  setUpAll(() async {
    if (fixtureUrl.isEmpty) return;
    final directory = await Directory.systemTemp.createTemp('whisper-catalog-');
    root = directory.path;
    await Directory(p.join(root, 'speech_models')).create();
    final client = HttpClient();
    try {
      for (final name in [
        ...SpeechModel.catalog.map((m) => m.fileName),
        'jfk.wav',
        'portuguese.aiff',
      ]) {
        final response = await (await client.getUrl(
          Uri.parse('$fixtureUrl/$name'),
        )).close();
        expect(response.statusCode, 200);
        final target = File(
          p.join(root, name.endsWith('.bin') ? 'speech_models' : '', name),
        );
        await response.pipe(target.openWrite());
      }
    } finally {
      client.close(force: true);
    }
    addTearDown(() => directory.delete(recursive: true));
  });
  for (final model in SpeechModel.catalog) {
    testWidgets(
      '${model.name} loads pinned weights and transcribes offline',
      (tester) async {
        final settings = _Settings();
        when(() => settings.getAudioLanguage()).thenReturn('en');
        final client = MockClient(
          (_) async => throw StateError('Offline inference only'),
        );
        addTearDown(client.close);
        final models = SpeechModelService.forTesting(
          client,
          model: model,
          settings: settings,
          directory: () async => Directory(root),
        );
        expect(await models.isReady(), isTrue);
        final transcription = LocalTranscriptionService(
          models,
          settings,
          LocalInferenceQueue(),
        );
        final watch = Stopwatch()..start();
        final english = (await transcription.transcribe(
          p.join(root, 'jfk.wav'),
        )).toLowerCase();
        expect(english, contains('country'));
        expect(english, contains('ask not'));
        // Fixture text only; never benchmark or print the user's journal.
        // ignore: avoid_print
        print(
          'CATALOG ${model.id} en cold+transcribe ${watch.elapsedMilliseconds}ms',
        );
        if (!model.englishOnly) {
          for (final language in <String?>['pt', null]) {
            when(() => settings.getAudioLanguage()).thenReturn(language);
            watch.reset();
            final portuguese = (await transcription.transcribe(
              p.join(root, 'portuguese.aiff'),
            )).toLowerCase();
            expect(portuguese, contains('projeto'));
            expect(portuguese, contains('nota'));
            // ignore: avoid_print
            print(
              'CATALOG ${model.id} ${language ?? 'auto'} cold+transcribe ${watch.elapsedMilliseconds}ms',
            );
          }
        }
      },
      skip: fixtureRoot.isEmpty && fixtureUrl.isEmpty,
      timeout: const Timeout(Duration(minutes: 30)),
    );
  }
}
