import 'package:smartnotes/domain/entities/journal_entry.dart';

/// A recoverable editing buffer, never a saved journal entry or search source.
class EntryEditDraft {
  const EntryEditDraft({
    required this.source,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.entryDate,
  });

  final JournalEntry source;
  final String title;
  final String subtitle;
  final String body;
  final DateTime entryDate;

  Map<String, dynamic> toJson() => {
    'source': source.toJson(),
    'title': title,
    'subtitle': subtitle,
    'body': body,
    'entryDate': entryDate.toIso8601String(),
  };

  factory EntryEditDraft.fromJson(Map<String, dynamic> json) => EntryEditDraft(
    source: JournalEntry.fromJson(
      Map<String, dynamic>.from(json['source'] as Map),
    ),
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    body: json['body'] as String,
    entryDate: DateTime.parse(json['entryDate'] as String),
  );
}

abstract class IEntryDraftRepository {
  Future<EntryEditDraft?> read(String id);
  Future<void> write(EntryEditDraft draft);
  Future<void> remove(String id);
}
