import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:injectable/injectable.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';

/// Thin adapter around the pinned whisper_ggml FFI entry point. Keeping the
/// native call here makes backend selection and fallback testable without a
/// device or a real model.
@injectable
class WhisperTranscriber {
  const WhisperTranscriber();

  Future<WhisperTranscribeResponse> transcribe({
    required SpeechModel model,
    required String modelPath,
    required String wav,
    required String language,
    required WhisperBackend backend,
  }) {
    return Whisper(
      model: switch (model.kind) {
        SpeechModelKind.base => WhisperModel.base,
        SpeechModelKind.smallEnglish => WhisperModel.smallEn,
        SpeechModelKind.mediumEnglish => WhisperModel.mediumEn,
        SpeechModelKind.small => WhisperModel.small,
        // The explicit verified path is authoritative, including Turbo.
        SpeechModelKind.turbo ||
        SpeechModelKind.large => WhisperModel.large,
      },
      backend: backend,
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
  }
}
