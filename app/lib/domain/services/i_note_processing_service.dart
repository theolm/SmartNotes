import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/processed_audio.dart';

abstract class INoteProcessingService {
  Future<String> transcribe(String audioPath);

  /// Returns null when no selected, installed formatting model is ready.
  Future<({String title, String subTitle})?> generateMetadata(
    String transcription,
  );

  Future<ProcessedAudio> formatTranscription({
    required AiAction action,
    required String transcription,
  });
}
