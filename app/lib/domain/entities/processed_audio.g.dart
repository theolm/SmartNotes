// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processed_audio.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProcessedAudio _$ProcessedAudioFromJson(Map<String, dynamic> json) =>
    _ProcessedAudio(
      title: json['title'] as String,
      markdown: json['markdown'] as String,
      transcription: json['transcription'] as String,
      subTitle: json['subTitle'] as String,
    );

Map<String, dynamic> _$ProcessedAudioToJson(_ProcessedAudio instance) =>
    <String, dynamic>{
      'title': instance.title,
      'markdown': instance.markdown,
      'transcription': instance.transcription,
      'subTitle': instance.subTitle,
    };
