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

  /// When [expected] is provided, refuse a stale write after an edit/import.
  Future<JournalEntry> update(JournalEntry entry, {JournalEntry? expected});
  Future<void> delete(String id);
}
