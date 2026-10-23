import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums/entry_status.dart';

part 'journal_entry.freezed.dart';
part 'journal_entry.g.dart';

@freezed
abstract class JournalEntry with _$JournalEntry {
  const factory JournalEntry({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required EntryStatus status,
    String? audioPath,
    String? transcription,
    String? formattedNote,
    String? title,
    String? languageCode,
    String? subTitle,
    DateTime? entryDate,
  }) = _JournalEntry;

  const JournalEntry._();

  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);

  DateTime get effectiveEntryDate => entryDate ?? createdAt;

  /// An explicitly empty edited note must not reveal the original again.
  String get body => formattedNote ?? transcription ?? '';
}
