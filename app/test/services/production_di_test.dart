import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/domain/services/i_speech_acceleration_service.dart';
import 'package:smartnotes/domain/services/i_transcription_service.dart';
import 'package:smartnotes/domain/services/i_formatting_feedback_service.dart';
import 'package:smartnotes/domain/services/i_formatting_acceleration_service.dart';
import 'package:smartnotes/data/services/formatting_inference_runner.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'production DI resolves speech, formatting and settings without test-only bindings',
    () async {
      SharedPreferences.setMockInitialValues({});
      // The registration module creates AudioRecorder eagerly; a host test has
      // no native implementation. Answer its creation probe deterministically
      // instead of letting a late MissingPluginException fail the suite.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.record/messages'),
            (_) async => null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.llfbandit.record/messages'),
              null,
            ),
      );
      await configureDependencies();
      expect(getIt<ISpeechAccelerationService>(), isNotNull);
      expect(getIt<ITranscriptionService>(), isNotNull);
      expect(getIt<IFormattingFeedbackService>(), isNotNull);
      expect(getIt<IFormattingAccelerationService>(), isNotNull);
      expect(getIt<FormattingInferenceRunner>(), isNotNull);
      expect(getIt<ProcessAudioNoteUseCase>(), isNotNull);
      expect(getIt<SettingsStore>(), isNotNull);
      await getIt.reset();
    },
  );
}
