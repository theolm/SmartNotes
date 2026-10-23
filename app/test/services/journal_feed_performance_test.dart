import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/data/datasources/local/sqlite_journal_entry_service.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/services/i_file_storage_service.dart';

class Files extends Mock implements IFileStorageService {}

class CountingDatabase extends LocalDatabase {
  final events = StreamController<String?>.broadcast();
  int fullReads = 0;
  int targetedReads = 0;
  final rows = <String, JournalEntry>{};
  @override
  Stream<String?> get entryChanges => events.stream;
  @override
  Future<List<JournalEntry>> all() async {
    fullReads++;
    return rows.values.toList();
  }

  @override
  Future<JournalEntry?> entry(String id) async {
    targetedReads++;
    return rows[id];
  }
}

void main() {
  test(
    'two journal consumers share one initial read and one refresh',
    () async {
      final database = CountingDatabase();
      final files = Files();
      when(
        () => files.getAudioDirectoryPath(),
      ).thenAnswer((_) async => '/audio');
      final journal = SqliteJournalEntryService(database, files);
      final home = journal.watchAll().listen((_) {});
      final lifecycle = journal.watchAll().listen((_) {});
      await pumpEventQueue();
      expect(database.fullReads, 1);
      database.events.add(null);
      await pumpEventQueue();
      expect(database.fullReads, 2);
      await home.cancel();
      await lifecycle.cancel();
      await database.events.close();
    },
  );

  test(
    'writes are incremental, replayed to late consumers, and import reconciles',
    () async {
      final database = CountingDatabase();
      final files = Files();
      when(
        () => files.getAudioDirectoryPath(),
      ).thenAnswer((_) async => '/audio');
      final journal = SqliteJournalEntryService(database, files);
      final snapshots = <List<JournalEntry>>[];
      final home = journal.watchAll().listen(snapshots.add);
      await pumpEventQueue();
      final date = DateTime(2026);
      final entry = JournalEntry(
        id: 'fixture',
        createdAt: date,
        updatedAt: date,
        status: EntryStatus.completed,
      );
      database.rows[entry.id] = entry;
      database.events.add(entry.id);
      await pumpEventQueue();
      expect(database.fullReads, 1);
      expect(database.targetedReads, 1);
      final lifecycle = journal.watchAll().listen((_) {});
      expect(await journal.watchAll().first, [entry]);
      expect(database.fullReads, 1);
      database.rows.clear();
      database.events.add(entry.id);
      await pumpEventQueue();
      expect(snapshots.last, isEmpty);
      expect(database.fullReads, 1);
      database.rows[entry.id] = entry;
      database.events.add(null);
      await pumpEventQueue();
      expect(snapshots.last, [entry]);
      expect(database.fullReads, 2);
      await home.cancel();
      await lifecycle.cancel();
      expect(await journal.watchAll().first, [entry]);
      expect(database.fullReads, 3);
      await database.events.close();
    },
  );
}
