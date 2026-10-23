import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';
import 'package:smartnotes/domain/services/i_transcription_service.dart';
import 'package:smartnotes/data/services/whisper_language_detector.dart';
import 'package:smartnotes/core/utils/log.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';

/// Serializes native inference across entries to bound phone memory use.
@LazySingleton(as: ITranscriptionService)
class LocalTranscriptionService implements ITranscriptionService {
  LocalTranscriptionService(this._models, this._settings, this._queue);
  final ISpeechModelService _models;
  final ISettingsService _settings;
  final LocalInferenceQueue _queue;

  @override
  Future<String> transcribe(String audioPath) {
    return _queue.run(() => _transcribe(audioPath));
  }

  Future<String> _transcribe(String audioPath) async {
    final modelPath = await _models.requireModelPath();
    final model = _models.model;
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
    try {
      // Pass an argument list: recordings and app directories may contain spaces.
      final session = await FFmpegKit.executeWithArguments([
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
      ]);
      if (!ReturnCode.isSuccess(await session.getReturnCode())) {
        throw const AiFailure(AiFailureCode.unavailable);
      }
      if (needsDetection) {
        language = await detectWhisperLanguage(modelPath, pcm);
      }
      final response =
          await Whisper(
            model: switch (model.kind) {
              SpeechModelKind.base => WhisperModel.base,
              SpeechModelKind.smallEnglish => WhisperModel.smallEn,
              SpeechModelKind.mediumEnglish => WhisperModel.mediumEn,
              SpeechModelKind.small => WhisperModel.small,
              // The explicit verified path is authoritative, including Turbo.
              SpeechModelKind.turbo ||
              SpeechModelKind.large => WhisperModel.large,
            },
          ).transcribe(
            modelPath: modelPath,
            transcribeRequest: TranscribeRequest(
              audio: wav,
              language: language,
              isTranslate: false,
              isNoTimestamps: true,
              isRealtime: false,
              keepModelLoaded: false,
            ),
          );
      // Transcripts contain private journal content: never log them in release.
      if (kDebugMode) {
        logger.d(
          'Local STT (${model.name}, language: $language) raw transcription:\n${response.text}',
        );
      }
      final text = response.text.trim();
      if (text.isEmpty) throw const AiFailure(AiFailureCode.noSpeech);
      return text;
    } finally {
      // Only owned conversion artifacts are removed; the recording is retained.
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        // Cache cleanup must never discard a successful transcription.
      }
    }
  }
}
