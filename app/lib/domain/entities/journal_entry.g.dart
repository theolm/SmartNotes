// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JournalEntry _$JournalEntryFromJson(Map<String, dynamic> json) =>
    _JournalEntry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      status: $enumDecode(_$EntryStatusEnumMap, json['status']),
      audioPath: json['audioPath'] as String?,
      transcription: json['transcription'] as String?,
      formattedNote: json['formattedNote'] as String?,
      title: json['title'] as String?,
      languageCode: json['languageCode'] as String?,
      subTitle: json['subTitle'] as String?,
      entryDate: json['entryDate'] == null
          ? null
          : DateTime.parse(json['entryDate'] as String),
    );

Map<String, dynamic> _$JournalEntryToJson(_JournalEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'status': _$EntryStatusEnumMap[instance.status]!,
      'audioPath': instance.audioPath,
      'transcription': instance.transcription,
      'formattedNote': instance.formattedNote,
      'title': instance.title,
      'languageCode': instance.languageCode,
      'subTitle': instance.subTitle,
      'entryDate': instance.entryDate?.toIso8601String(),
    };

const _$EntryStatusEnumMap = {
  EntryStatus.recording: 'recording',
  EntryStatus.processing: 'processing',
  EntryStatus.completed: 'completed',
  EntryStatus.error: 'error',
};
