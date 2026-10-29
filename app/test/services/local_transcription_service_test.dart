import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_transcription_service.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';

class _Models extends Mock implements ISpeechModelService {}

class _Settings extends Mock implements ISettingsService {}

void main() {
  test(
    'ordinary and measured APIs preserve typed verification failures',
    () async {
      final models = _Models();
      final settings = _Settings();
      const failure = AiFailure(AiFailureCode.unavailable);
      when(() => models.requireModelPath()).thenThrow(failure);
      final service = LocalTranscriptionService(
        models,
        settings,
        LocalInferenceQueue(),
      );
      await expectLater(service.transcribe('fixture'), throwsA(same(failure)));
      await expectLater(
        service.transcribeMeasured('fixture'),
        throwsA(same(failure)),
      );
      verifyNever(() => settings.getAudioLanguage());
    },
  );

  test(
    'measurement waits for the existing queue lease and releases on failure',
    () async {
      final models = _Models();
      final settings = _Settings();
      final queue = LocalInferenceQueue();
      final blocker = Completer<void>();
      final existing = queue.run(() => blocker.future);
      const failure = AiFailure(AiFailureCode.unavailable);
      when(() => models.requireModelPath()).thenThrow(failure);
      final service = LocalTranscriptionService(models, settings, queue);
      final waiting = service.transcribeMeasured('fixture');
      final assertion = expectLater(waiting, throwsA(same(failure)));
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => models.requireModelPath());
      blocker.complete();
      await existing;
      await assertion;
      verify(() => models.requireModelPath()).called(1);
      expect(await queue.run(() async => 'next job'), 'next job');
    },
  );

  test(
    'English-only language guard still runs before touching audio',
    () async {
      final models = _Models();
      final settings = _Settings();
      when(() => models.requireModelPath()).thenAnswer((_) async => 'fixture');
      when(() => models.model).thenReturn(SpeechModel.smallEnglish);
      when(() => settings.getAudioLanguage()).thenReturn(null);
      final service = LocalTranscriptionService(
        models,
        settings,
        LocalInferenceQueue(),
      );
      await expectLater(
        service.transcribeMeasured('fixture'),
        throwsA(isA<AiFailure>()),
      );
    },
  );
}
