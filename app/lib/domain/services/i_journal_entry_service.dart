import 'package:smartnotes/domain/entities/journal_entry.dart';

abstract class IJournalEntryService {
  /// Resumable derived-search maintenance progress; null means idle.
  Stream<double?> watchSearchMaintenance();
  Stream<List<JournalEntry>> watchAll();

  /// Targeted subscription for a detail/edit surface. Avoids decoding the
  /// whole journal just to observe one entry.
  Stream<JournalEntry?> watchById(String id);
  Future<JournalEntry?> getById(String id);
  Future<JournalEntry> create({required String audioPath});

  /// Creates a completed, audio-free entry without invoking any model.
  /// The caller retains [id] across retries and recovery.
  Future<JournalEntry> createTyped({
    required String id,
    required String text,
    String? title,
    String? subTitle,
  });

  /// When [expected] is provided, refuse a stale write after an edit/import.
  Future<JournalEntry> update(JournalEntry entry, {JournalEntry? expected});
  Future<void> delete(String id);
}
