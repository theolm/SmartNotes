import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smartnotes/data/services/cpu_only_speech_acceleration_service.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/gpu_circuit_store.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_transcription_service.dart';
import 'package:smartnotes/data/services/speech_acceleration_service.dart';
import 'package:smartnotes/data/services/speech_model_service.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';

class _Settings extends Mock implements ISettingsService {}

/// Explicitly approved public/synthetic fixtures only. No DI or journal startup.
/// Build Android with -PsmartnotesApplicationId=dev.theolm.smartnotes.sttbenchmark.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const modelPath = String.fromEnvironment('STT_BENCHMARK_MODEL_PATH');
  const audioPath = String.fromEnvironment('STT_BENCHMARK_AUDIO_PATH');
  const audioHash = String.fromEnvironment('STT_BENCHMARK_AUDIO_SHA256');
  const modelId = String.fromEnvironment(
    'STT_BENCHMARK_MODEL_ID',
    defaultValue: 'whisper-base-q8_0',
  );
  const language = String.fromEnvironment(
    'STT_BENCHMARK_LANGUAGE',
    defaultValue: 'en',
  );
  const approved = bool.fromEnvironment('STT_BENCHMARK_APPROVED_FIXTURE');
  const backend = String.fromEnvironment(
    'STT_BENCHMARK_BACKEND',
    defaultValue: 'cpu',
  );
  testWidgets(
    'measures complete CPU transcription without private content in the report',
    (tester) async {
      final info = await PackageInfo.fromPlatform();
      expect(info.packageName, 'dev.theolm.smartnotes.sttbenchmark');
      expect(approved, isTrue);
      final model = SpeechModel.find(modelId);
      expect(model, isNotNull);
      expect(model!.supports(language == 'auto' ? null : language), isTrue);
      expect(
        (await sha256.bind(File(audioPath).openRead()).first).toString(),
        audioHash,
      );
      final temp = await getTemporaryDirectory();
      final directory = await temp.createTemp('stt-benchmark-');
      addTearDown(() => directory.delete(recursive: true));
      final target = File(
        p.join(directory.path, 'speech_models', model.fileName),
      );
      await target.parent.create();
      await File(modelPath).copy(target.path);
      final settings = _Settings();
      when(() => settings.getAudioLanguage()).thenReturn(
        language == 'auto' ? null : language,
      );
      when(() => settings.getSpeechGpuPreferred()).thenReturn(true);
      final client = MockClient((_) async => throw StateError('Offline only'));
      addTearDown(client.close);
      final models = SpeechModelService.forTesting(
        client,
        model: model,
        settings: settings,
        directory: () async => directory,
      );
      // Validate the pinned model before the measured runs.
      expect(await models.isReady(), isTrue);
      final acceleration = backend == 'gpu'
          ? SpeechAccelerationService(
              settings,
              DeviceProfileService(),
              GpuCircuitStore.at(File('${directory.path}/circuit.json')),
            )
          : const CpuOnlySpeechAccelerationService();
      final service = LocalTranscriptionService(
        models,
        settings,
        LocalInferenceQueue(),
        acceleration: acceleration,
      );
      final rows = <Map<String, Object>>[];
      for (var i = 0; i < 4; i++) {
        final result = await service.transcribeMeasured(audioPath);
        expect(result.text.trim(), isNotEmpty);
        if (backend == 'gpu' && i > 0) {
          expect(result.measurement.backend, 'vulkan');
          expect(result.measurement.fallback, isFalse);
        }
        rows.add({
          'iteration': i,
          'warmup': i == 0,
          ...result.measurement.toJson(),
        });
        await Future<void>.delayed(const Duration(seconds: 10));
      }
      // Reports contain hashes and timings, not paths or transcript text.
      // ignore: avoid_print
      print(
        'STT_BENCHMARK ${jsonEncode({
          'schema_version': 1,
          'model_id': model.id,
          'model_sha256': model.sha256,
          'audio_sha256': audioHash,
          'language': language,
          'requested_backend': backend,
          'model_residency': 'load and free on every request',
          'runs': rows,
        })}',
      );
    },
    skip:
        !approved ||
        modelPath.isEmpty ||
        audioPath.isEmpty ||
        audioHash.isEmpty,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
