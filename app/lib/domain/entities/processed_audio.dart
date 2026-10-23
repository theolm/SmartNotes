import 'package:freezed_annotation/freezed_annotation.dart';

part 'processed_audio.freezed.dart';
part 'processed_audio.g.dart';

@freezed
abstract class ProcessedAudio with _$ProcessedAudio {
  const factory ProcessedAudio({
    required String title,
    required String markdown,
    required String transcription,
    required String subTitle,
  }) = _ProcessedAudio;

  factory ProcessedAudio.fromJson(Map<String, Object?> json) =>
      _$ProcessedAudioFromJson(json);
}
