import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smartnotes/data/services/local_transcription_service.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/speech_model_service.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

class MockSettings extends Mock implements ISettingsService {}

/// Opt-in native smoke test. Supply a base Q8 model and the upstream JFK sample
/// with --dart-define=STT_MODEL_PATH=... and --dart-define=STT_AUDIO_PATH=... .
/// Never reads/writes the user's journal, API key, or installed speech model.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const modelPath = String.fromEnvironment('STT_MODEL_PATH');
  const audioPath = String.fromEnvironment('STT_AUDIO_PATH');
  const portuguesePath = String.fromEnvironment('STT_PORTUGUESE_AUDIO_PATH');
  testWidgets(
    'whisper.cpp transcribes with auto and explicit language offline',
    (tester) async {
      expect(
        await const Whisper(model: WhisperModel.base).getVersion(),
        isNotEmpty,
      );
      final temporary = await getTemporaryDirectory();
      await temporary.create(recursive: true);
      final directory = await temporary.createTemp('stt-native-test-');
      addTearDown(() => directory.delete(recursive: true));
      final weights = File(
        p.join(
          directory.path,
          'speech_models',
          SpeechModel.whisperBaseQ8.fileName,
        ),
      );
      await weights.parent.create(recursive: true);
      await File(modelPath).copy(weights.path);
      final client = MockClient(
        (_) async => throw StateError('Inference must be offline'),
      );
      addTearDown(client.close);
      final models = SpeechModelService.forTesting(
        client,
        model: SpeechModel.whisperBaseQ8,
        directory: () async => directory,
      );
      expect(await models.isReady(), true);
      final settings = MockSettings();
      final local = LocalTranscriptionService(
        models,
        settings,
        LocalInferenceQueue(),
      );
      final original = File(
        p.join(directory.path, 'recording with spaces.m4a'),
      );
      final encoding = await FFmpegKit.executeWithArguments([
        '-y',
        '-i',
        audioPath,
        '-c:a',
        'aac',
        original.path,
      ]);
      expect(ReturnCode.isSuccess(await encoding.getReturnCode()), true);
      for (final language in <String?>[null, 'en']) {
        when(() => settings.getAudioLanguage()).thenReturn(language);
        final text = await local.transcribe(original.path);
        expect(text.toLowerCase(), contains('ask not'));
        expect(text.toLowerCase(), contains('country'));
      }
      expect(await original.exists(), true);
      if (portuguesePath.isNotEmpty) {
        for (final language in <String?>[null, 'pt']) {
          when(() => settings.getAudioLanguage()).thenReturn(language);
          final text = (await local.transcribe(portuguesePath)).toLowerCase();
          expect(text, contains('nota'));
          expect(text, contains('projeto'));
          expect(text, isNot(contains('today')));
        }
      }
    },
    skip: modelPath.isEmpty || audioPath.isEmpty,
  );
}
