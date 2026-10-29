import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_transcription_service.dart';
import 'package:smartnotes/data/services/whisper_transcriber.dart';
import 'package:smartnotes/domain/entities/speech_acceleration.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_speech_acceleration_service.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

class _Models extends Mock implements ISpeechModelService {}

class _Settings extends Mock implements ISettingsService {}

class _Acceleration implements ISpeechAccelerationService {
  _Acceleration({this.markWritable = true});

  final bool markWritable;
  int beginCalls = 0;
  int completeCalls = 0;
  final failures = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<SpeechAccelerationStatus> status({
    bool refresh = false,
    bool probe = false,
  }) async => const SpeechAccelerationStatus(
    state: SpeechAccelerationState.available,
  );

  @override
  Future<SpeechBackendDecision> decide({
    required SpeechModel model,
    required Duration audioDuration,
  }) async => const SpeechBackendDecision(
    SpeechBackend.gpu,
    SpeechBackendReason.gpuReady,
  );

  @override
  Future<bool> beginGpuAttempt(SpeechModel model) async {
    beginCalls += 1;
    return markWritable;
  }

  @override
  Future<void> completeGpuAttempt() async {
    completeCalls += 1;
  }

  @override
  Future<void> recordGpuFailure({
    required SpeechModel model,
    required String code,
  }) async {
    failures.add(code);
  }

  @override
  Future<SpeechAccelerationStatus> resetCircuit() => status();
}

class _Transcriber extends WhisperTranscriber {
  _Transcriber(this.onTranscribe);
  final Future<WhisperTranscribeResponse> Function(WhisperBackend) onTranscribe;
  final calls = <WhisperBackend>[];

  @override
  Future<WhisperTranscribeResponse> transcribe({
    required SpeechModel model,
    required String modelPath,
    required String wav,
    required String language,
    required WhisperBackend backend,
  }) {
    calls.add(backend);
    return onTranscribe(backend);
  }
}

WhisperTranscribeResponse _response(String text, String backend) =>
    WhisperTranscribeResponse(
      type: 'transcribe',
      text: text,
      segments: null,
      backend: backend,
    );

void main() {
  late Directory directory;
  late String wav;
  late _Acceleration acceleration;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stt-backend-test-');
    wav = '${directory.path}/recording.wav';
    File(wav).writeAsBytesSync(List<int>.filled(44 + 32000 * 2, 0));
    acceleration = _Acceleration();
  });

  tearDown(() async => directory.delete(recursive: true));

  LocalTranscriptionService service(
    _Transcriber transcriber,
    _Acceleration? acceleration,
  ) => LocalTranscriptionService(
    _Models(),
    _Settings(),
    LocalInferenceQueue(),
    acceleration: acceleration,
    transcriber: transcriber,
  );

  test('recovers a recoverable GPU failure with exactly one CPU retry', () async {
    final transcriber = _Transcriber((backend) async {
      if (backend == WhisperBackend.vulkan) {
        throw const WhisperException('vulkan_init_failed', 'driver rejected');
      }
      return _response('transcript', 'cpu');
    });
    final result = await service(transcriber, acceleration).transcribeWithBackend(
      model: SpeechModel.small,
      modelPath: 'model.bin',
      wav: wav,
      language: 'en',
    );
    expect(result.text, 'transcript');
    expect(result.backend, 'cpu');
    expect(result.fallback, isTrue);
    expect(result.gpuFailureCode, 'vulkan_init_failed');
    expect(transcriber.calls, [WhisperBackend.vulkan, WhisperBackend.cpu]);
    expect(acceleration.beginCalls, 1);
    expect(acceleration.completeCalls, 1);
    expect(acceleration.failures, ['vulkan_init_failed']);
  });

  test('a successful GPU request never touches the CPU path', () async {
    final transcriber = _Transcriber(
      (backend) async => _response('gpu text', 'vulkan'),
    );
    final result = await service(
      transcriber,
      acceleration,
    ).transcribeWithBackend(
      model: SpeechModel.turbo,
      modelPath: 'model.bin',
      wav: wav,
      language: 'en',
    );
    expect(result.backend, 'vulkan');
    expect(result.fallback, isFalse);
    expect(transcriber.calls, [WhisperBackend.vulkan]);
    expect(acceleration.failures, isEmpty);
  });

  test('non-recoverable native failures are not retried on the CPU', () async {
    final transcriber = _Transcriber(
      (backend) async => throw const WhisperException('invalid_audio', 'bad wav'),
    );
    await expectLater(
      service(transcriber, acceleration).transcribeWithBackend(
        model: SpeechModel.small,
        modelPath: 'model.bin',
        wav: wav,
        language: 'en',
      ),
      throwsA(isA<WhisperException>()),
    );
    expect(transcriber.calls, [WhisperBackend.vulkan]);
    expect(acceleration.failures, isEmpty);
    expect(acceleration.completeCalls, 1);
  });

  test('an unwritable crash marker keeps the attempt on the CPU', () async {
    final transcriber = _Transcriber(
      (backend) async => _response('cpu text', 'cpu'),
    );
    final result = await service(
      transcriber,
      _Acceleration(markWritable: false),
    ).transcribeWithBackend(
      model: SpeechModel.turbo,
      modelPath: 'model.bin',
      wav: wav,
      language: 'en',
    );
    expect(result.backend, 'cpu');
    expect(result.fallback, isFalse);
    expect(transcriber.calls, [WhisperBackend.cpu]);
  });
}
