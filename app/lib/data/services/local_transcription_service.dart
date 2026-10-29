import 'dart:io';
import 'package:smartnotes/core/utils/inference_trace.dart';

import 'package:flutter/foundation.dart';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/transcription_text.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_speech_acceleration_service.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';
import 'package:smartnotes/domain/services/i_transcription_service.dart';
import 'package:smartnotes/data/services/whisper_language_detector.dart';
import 'package:smartnotes/data/services/transcription_measurement.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/cpu_only_speech_acceleration_service.dart';
import 'package:smartnotes/data/services/whisper_transcriber.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';

/// Serializes native inference across entries to bound phone memory use.
@LazySingleton(as: ITranscriptionService)
class LocalTranscriptionService implements ITranscriptionService {
  LocalTranscriptionService(
    this._models,
    this._settings,
    this._queue, {
    ISpeechAccelerationService? acceleration,
    WhisperTranscriber? transcriber,
  }) : _acceleration = acceleration ?? const CpuOnlySpeechAccelerationService(),
       _transcriber = transcriber ?? const WhisperTranscriber();
  final ISpeechModelService _models;
  final ISettingsService _settings;
  final LocalInferenceQueue _queue;
  final ISpeechAccelerationService _acceleration;
  final WhisperTranscriber _transcriber;

  @override
  Future<String> transcribe(String audioPath) async {
    return (await transcribeMeasured(audioPath)).text;
  }

  /// Opt-in benchmark boundary; normal callers keep the domain's text-only API.
  /// No timing or transcript is logged, persisted, or sent off device here.
  Future<MeasuredTranscription> transcribeMeasured(String audioPath) {
    final total = Stopwatch()..start();
    return _queue.run(() {
      final queueWait = total.elapsed;
      return InferenceTrace.run(
        'speech.job',
        () => _transcribe(audioPath, total: total, queueWait: queueWait),
      );
    });
  }

  Future<MeasuredTranscription> _transcribe(
    String audioPath, {
    required Stopwatch total,
    required Duration queueWait,
  }) async {
    final stage = Stopwatch()..start();
    final modelPath = await InferenceTrace.run(
      'speech.verify',
      _models.requireModelPath,
    );
    final modelVerification = stage.elapsed;
    final model = _models.model;
    InferenceTrace.event('speech.model', {'model': model.id});
    final selectedLanguage = _settings.getAudioLanguage()?.trim();
    if (!model.supports(selectedLanguage)) {
      throw const AiFailure(AiFailureCode.unavailable);
    }
    final temporary = await getTemporaryDirectory();
    await temporary.create(recursive: true);
    final directory = await temporary.createTemp('local-stt-');
    final wav = p.join(directory.path, 'recording.wav');
    final pcm = p.join(directory.path, 'language.f32');
    var language = model.englishOnly
        ? 'en'
        : selectedLanguage == null || selectedLanguage.isEmpty
        ? 'auto'
        : selectedLanguage.toLowerCase().split(RegExp('[-_]')).first;
    final needsDetection =
        language == 'auto' && (Platform.isIOS || Platform.isMacOS);
    var audioConversion = Duration.zero;
    var languageDetection = Duration.zero;
    var whisperRequest = Duration.zero;
    var cleanup = Duration.zero;
    var backend = 'cpu';
    var usedFallback = false;
    String? gpuFailureCode;
    late final String text;
    try {
      stage.reset();
      // Pass an argument list: recordings and app directories may contain spaces.
      final session = await InferenceTrace.run(
        'speech.convert',
        () => FFmpegKit.executeWithArguments([
          '-nostdin',
          '-y',
          '-i',
          audioPath,
          '-ar',
          '16000',
          '-ac',
          '1',
          '-c:a',
          'pcm_s16le',
          wav,
          if (needsDetection) ...[
            '-t',
            '30',
            '-ar',
            '16000',
            '-ac',
            '1',
            '-f',
            'f32le',
            pcm,
          ],
        ]),
      );
      if (!ReturnCode.isSuccess(await session.getReturnCode())) {
        throw const AiFailure(AiFailureCode.unavailable);
      }
      audioConversion = stage.elapsed;
      if (needsDetection) {
        stage.reset();
        language = await detectWhisperLanguage(modelPath, pcm);
        languageDetection = stage.elapsed;
      }
      stage.reset();
      final result = await transcribeWithBackend(
        model: model,
        modelPath: modelPath,
        wav: wav,
        language: language,
      );
      text = result.text;
      backend = result.backend;
      usedFallback = result.fallback;
      gpuFailureCode = result.gpuFailureCode;
      whisperRequest = stage.elapsed;
    } finally {
      stage.reset();
      // Only owned conversion artifacts are removed; the recording is retained.
      try {
        await InferenceTrace.run(
          'speech.cleanup',
          () => directory.delete(recursive: true),
        );
      } on FileSystemException {
        // Cache cleanup must never discard a successful transcription.
      }
      cleanup = stage.elapsed;
    }
    return MeasuredTranscription(
      text,
      TranscriptionMeasurement(
        queueWait: queueWait,
        modelVerification: modelVerification,
        audioConversion: audioConversion,
        languageDetection: languageDetection,
        whisperRequest: whisperRequest,
        cleanup: cleanup,
        total: total.elapsed,
        backend: backend,
        fallback: usedFallback,
        gpuFailureCode: gpuFailureCode,
      ),
    );
  }

  /// Runs the selected backend with at most one CPU retry for a recoverable
  /// GPU failure. Exposed for tests without FFmpeg or a native library.
  @visibleForTesting
  Future<({String text, String backend, bool fallback, String? gpuFailureCode})>
  transcribeWithBackend({
    required SpeechModel model,
    required String modelPath,
    required String wav,
    required String language,
  }) async {
    final decision = await _acceleration.decide(
      model: model,
      audioDuration: _audioDuration(wav),
    );
    InferenceTrace.event('speech.decision', {
      'gpu': decision.usesGpu,
      'durationMs': _audioDuration(wav).inMilliseconds,
    });
    if (!decision.usesGpu) {
      return _runOn(WhisperBackend.cpu, model, modelPath, wav, language);
    }
    final marked = await _acceleration.beginGpuAttempt(model);
    if (!marked) {
      // The crash marker could not be written; this attempt must stay CPU.
      return _runOn(WhisperBackend.cpu, model, modelPath, wav, language);
    }
    WhisperException? gpuFailure;
    try {
      final result = await _runOn(
        WhisperBackend.vulkan,
        model,
        modelPath,
        wav,
        language,
      );
      return result;
    } on WhisperException catch (error) {
      gpuFailure = error;
    } finally {
      await _acceleration.completeGpuAttempt();
    }
    if (!_isRecoverableGpuFailure(gpuFailure.code)) {
      throw gpuFailure;
    }
    await _acceleration.recordGpuFailure(model: model, code: gpuFailure.code);
    InferenceTrace.event('speech.cpuFallback', {'code': gpuFailure.code});
    final retried = await _runOn(
      WhisperBackend.cpu,
      model,
      modelPath,
      wav,
      language,
    );
    return (
      text: retried.text,
      backend: retried.backend,
      fallback: true,
      gpuFailureCode: gpuFailure.code,
    );
  }

  Future<({String text, String backend, bool fallback, String? gpuFailureCode})>
  _runOn(
    WhisperBackend backend,
    SpeechModel model,
    String modelPath,
    String wav,
    String language,
  ) async {
    final response = await InferenceTrace.run(
      'speech.native.${backend.name}',
      () => _transcriber.transcribe(
        model: model,
        modelPath: modelPath,
        wav: wav,
        language: language,
        backend: backend,
      ),
    );
    InferenceTrace.event('speech.nativeReturned', {
      'backend': response.backend,
    });
    return (
      text: requireSpeechTranscription(response.text),
      backend: response.backend,
      fallback: false,
      gpuFailureCode: null,
    );
  }

  /// 16 kHz mono 16-bit PCM: 32,000 bytes per second, minus the WAV header.
  Duration _audioDuration(String wavPath) {
    final bytes = File(wavPath).lengthSync() - 44;
    if (bytes <= 0) return Duration.zero;
    return Duration(microseconds: bytes * 1000000 ~/ 32000);
  }

  bool _isRecoverableGpuFailure(String code) {
    return const {
      'vulkan_unavailable',
      'vulkan_init_failed',
      'vulkan_inference_failed',
      'native_library_unavailable',
    }.contains(code);
  }
}
