import 'package:smartnotes/domain/entities/ai_failure.dart';

/// Whisper's non-speech annotations are not journal content.
String requireSpeechTranscription(String raw) {
  final text = raw
      .replaceAll(
        RegExp(r'\[(?:BLANK_AUDIO|NO_SPEECH|SILENCE)\]', caseSensitive: false),
        '',
      )
      .trim();
  if (text.isEmpty) throw const AiFailure(AiFailureCode.noSpeech);
  return text;
}
