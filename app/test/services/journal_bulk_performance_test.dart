import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/data/services/journal_archive_service.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/search_index_status.dart';
import 'package:smartnotes/domain/services/i_file_storage_service.dart';

class Files extends Mock implements IFileStorageService {}

class MeasuredDatabase extends LocalDatabase {
  int fullReads = 0;
  int statusReads = 0;
  @override
  Future<List<JournalEntry>> all() {
    fullReads++;
    return super.all();
  }

  @override
  Future<SearchIndexStatus> indexStatus() {
    statusReads++;
    return super.indexStatus();
  }
}

List<JournalEntry> fixture(int count) {
  final date = DateTime.utc(2026);
  return List.generate(
    count,
    (i) => JournalEntry(
      id: 'synthetic-$i',
      createdAt: date,
      updatedAt: date,
      status: EntryStatus.completed,
      title: 'Fixture $i',
      transcription: 'Generated performance fixture. ' * 10,
    ),
  );
}

void main() {
  late Directory temporary;
  late MeasuredDatabase database;
  late String path;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('journal-performance-');
    path = p.join(temporary.path, 'journal.sqlite');
    database = MeasuredDatabase();
    await database.open(path: path);
  });
  tearDown(() async {
    await database.close();
    await temporary.delete(recursive: true);
  });

  test(
    '10k-entry staged import serves reads before atomic publication',
    () async {
      final original = fixture(1).single;
      await database.insertEntry(original);
      var finished = false;
      final reads = <Future<void>>[];
      final publicationSnapshots = <int>[];
      final progress = <double>[];
      final watch = Stopwatch()..start();
      final importing = database
          .importJsonEntries(
            fixture(10000).map((e) => e.toJson()).toList(),
            onProgress: (value) {
              progress.add(value);
              if (progress.length == 1) {
                reads.add(
                  database.entry(original.id).then((entry) {
                    expect(finished, false);
                    expect(entry, original);
                  }),
                );
              }
              if (value == 0.9) {
                reads.add(
                  Future.doWhile(() async {
                    publicationSnapshots.add(
                      (await database.indexStatus()).pending,
                    );
                    return !finished;
                  }),
                );
              }
            },
          )
          .whenComplete(() => finished = true);
      await importing;
      await Future.wait(reads);
      expect(publicationSnapshots, isNotEmpty);
      expect(
        publicationSnapshots.every((count) => count == 1 || count == 10000),
        true,
      );
      expect(progress.length, inInclusiveRange(2, 401));
      expect(progress.last, 1);
      expect(await database.entry('synthetic-9999'), isNotNull);
      expect(database.fullReads, 0);
      // Only aggregate synthetic metrics, never note contents or paths.
      // ignore: avoid_print -- Aggregate metrics from generated data only.
      print(
        'Synthetic import: 10000 entries, ${watch.elapsedMilliseconds} ms; interactive read completed before publication.',
      );
    },
  );

  test(
    'failed final publication leaves the entire existing journal intact',
    () async {
      final original = fixture(1).single;
      await database.insertEntry(original);
      final raw = sqlite3.open(path);
      raw.execute(
        "CREATE TRIGGER fail_import BEFORE INSERT ON entries WHEN new.id='synthetic-1' BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      raw.close();
      await expectLater(
        database.importEntries([
          original.copyWith(title: 'Replacement'),
          ...fixture(30).skip(1),
        ]),
        throwsStateError,
      );
      expect(await database.entry(original.id), original);
      expect(await database.entry('synthetic-2'), isNull);
      expect(await database.searchText('Replacement'), isEmpty);
    },
  );

  test(
    'pipeline upgrade keeps notes readable and resumes bounded hash maintenance',
    () async {
      await database.importEntries(fixture(10000));
      await database.close();
      final raw = sqlite3.open(path);
      raw.execute(
        "UPDATE embedding_pipeline SET identity='synthetic-old-pipeline'",
      );
      raw.execute("UPDATE entries SET source_hash='obsolete'");
      raw.close();
      database = MeasuredDatabase();
      final maintenance = <double?>[];
      final subscription = database.watchSearchMaintenance().listen(
        maintenance.add,
      );
      await database.open(path: path);
      expect(await database.entry('synthetic-9999'), isNotNull);
      final during = sqlite3.open(path);
      expect(
        during
            .select('SELECT COUNT(*) AS n FROM source_hash_migration')
            .single['n'],
        greaterThan(0),
      );
      during.close();
      await database.close();
      await subscription.cancel();
      expect(maintenance, contains(0.0));
      expect(maintenance.last, isNull);
      final after = sqlite3.open(path);
      expect(
        after
            .select('SELECT COUNT(*) AS n FROM source_hash_migration')
            .single['n'],
        0,
      );
      expect(
        after
            .select(
              "SELECT COUNT(*) AS n FROM entries WHERE source_hash='obsolete'",
            )
            .single['n'],
        0,
      );
      after.close();
      database = MeasuredDatabase();
      await database.open(path: path);
    },
  );

  test(
    'export uses its own snapshot, not UI-isolate journal decoding',
    () async {
      await database.importEntries(fixture(1000));
      final files = Files();
      when(
        () => files.getAudioDirectoryPath(),
      ).thenAnswer((_) async => temporary.path);
      final archive = JournalArchiveService(database, files);
      final progress = <double>[];
      final bytes = await archive.export(onProgress: progress.add);
      expect(database.fullReads, 0);
      expect(bytes, isNotEmpty);
      expect(progress, isNotEmpty);
      expect(await archive.import(bytes), 1000);
      expect(await database.entry('synthetic-999'), isNotNull);
    },
  );

  test(
    'progress listener failures cannot report failure after a committed import',
    () async {
      await database.importJsonEntries(
        fixture(100).map((e) => e.toJson()).toList(),
        onProgress: (_) => throw StateError('Synthetic observer failure'),
      );
      expect(await database.entry('synthetic-99'), isNotNull);
    },
  );

  test(
    'hash repair resumes with unchanged pipeline identity after interruption',
    () async {
      await database.importEntries(fixture(100));
      await database.close();
      final raw = sqlite3.open(path);
      raw.execute("UPDATE entries SET source_hash='obsolete'");
      raw.execute('INSERT INTO source_hash_migration SELECT id FROM entries');
      raw.close();
      database = MeasuredDatabase();
      await database.open(path: path);
      await database.close();
      final after = sqlite3.open(path);
      expect(
        after
            .select('SELECT COUNT(*) AS n FROM source_hash_migration')
            .single['n'],
        0,
      );
      expect(
        after
            .select(
              "SELECT COUNT(*) AS n FROM entries WHERE source_hash='obsolete'",
            )
            .single['n'],
        0,
      );
      after.close();
      database = MeasuredDatabase();
      await database.open(path: path);
    },
  );

  test(
    '32 MiB audio backup streams recordings and retains version-1 round trip',
    () async {
      final chunk = Uint8List(64 * 1024);
      final entries = fixture(4);
      for (var i = 0; i < entries.length; i++) {
        final name = 'synthetic-$i.m4a';
        final file = File(
          p.join(temporary.path, name),
        ).openSync(mode: FileMode.write);
        try {
          for (var n = 0; n < 128; n++) {
            file.writeFromSync(chunk);
          }
        } finally {
          file.closeSync();
        }
        await database.insertEntry(entries[i].copyWith(audioPath: name));
      }
      final files = Files();
      when(
        () => files.getAudioDirectoryPath(),
      ).thenAnswer((_) async => temporary.path);
      final archive = JournalArchiveService(database, files);
      final baseline = ProcessInfo.currentRss;
      var peak = baseline;
      final sampler = Timer.periodic(const Duration(milliseconds: 5), (_) {
        final rss = ProcessInfo.currentRss;
        if (rss > peak) peak = rss;
      });
      try {
        final bytes = await archive.export();
        final contents = ZipDecoder().decodeBytes(bytes);
        expect(
          contents.files.where((f) => f.name.startsWith('audio/')),
          hasLength(4),
        );
        expect(
          contents.files.singleWhere((f) => f.name == 'journal.json').size,
          greaterThan(0),
        );
        expect(await archive.import(bytes), 4);
        expect(database.fullReads, 0);
        // Informational host-process RSS (includes harness and output ZIP), not an
        // Android memory budget or a deterministic performance assertion.
        // ignore: avoid_print -- Aggregate metrics from generated data only.
        print(
          'Synthetic 32 MiB audio backup round trip: sampled extra RSS ${(peak - baseline) ~/ (1024 * 1024)} MiB.',
        );
      } finally {
        sampler.cancel();
      }
    },
  );

  test(
    'status observers coalesce write bursts and retain the final state',
    () async {
      final statuses = <SearchIndexStatus>[];
      final subscription = database.watchIndexStatus().listen(statuses.add);
      await pumpEventQueue();
      for (final entry in fixture(40)) {
        await database.insertEntry(entry);
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(statuses.last.pending, 40);
      expect(database.statusReads, lessThan(10));
      await subscription.cancel();
    },
  );

  test(
    'database boundary discards text queries invalidated before dispatch',
    () async {
      await database.importEntries(fixture(1000));
      final pending = database.searchText('Fixture');
      database.cancelTextSearch();
      expect(await pending, isEmpty);
      expect(await database.searchText('Fixture'), hasLength(20));
    },
  );
}
