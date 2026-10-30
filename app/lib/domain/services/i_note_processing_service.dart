import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/processed_audio.dart';

abstract class INoteProcessingService {
  Future<String> transcribe(String audioPath);

  /// Returns null when no selected, installed formatting model is ready.
  ///
  /// [languageCode] is the best-effort ISO 639-1 code of the spoken language,
  /// or null when it could not be determined.
  Future<({String title, String subTitle, String? languageCode})?>
  generateMetadata(String transcription);

  Future<ProcessedAudio> formatTranscription({
    required AiAction action,
    required String transcription,
  });
}
