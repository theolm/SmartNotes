import 'package:smartnotes/domain/entities/journal_entry.dart';

/// A recoverable editing buffer, never a saved journal entry or search source.
class EntryEditDraft {
  const EntryEditDraft({
    required this.source,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.entryDate,
    this.creationId,
  }) : assert(source != null || creationId != null);

  /// New captures have no saved source. Existing draft JSON remains readable.
  final JournalEntry? source;
  final String? creationId;
  static const creationKey = 'new-typed-entry';
  String get id => source?.id ?? creationKey;
  final String title;
  final String subtitle;
  final String body;
  final DateTime entryDate;

  Map<String, dynamic> toJson() => {
    'source': source?.toJson(),
    if (creationId != null) 'creationId': creationId,
    'title': title,
    'subtitle': subtitle,
    'body': body,
    'entryDate': entryDate.toIso8601String(),
  };

  factory EntryEditDraft.fromJson(Map<String, dynamic> json) => EntryEditDraft(
    source: json['source'] == null
        ? null
        : JournalEntry.fromJson(
            Map<String, dynamic>.from(json['source'] as Map),
          ),
    creationId: json['creationId'] as String?,
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
