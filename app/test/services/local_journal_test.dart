import 'dart:io';
import 'package:smartnotes/application/journal_lifecycle.dart';
import '../helpers/local_services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/inference_cancelled.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/data/datasources/local/sqlite_journal_entry_service.dart';
import 'package:smartnotes/data/services/journal_archive_service.dart';
import 'package:smartnotes/data/services/local_entry_search_service.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_embedding_service.dart';
import 'package:smartnotes/domain/services/i_file_storage_service.dart';
import 'package:smartnotes/domain/services/i_audio_recording_service.dart';
import 'package:smartnotes/domain/services/i_note_processing_service.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/processed_audio.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart';
import 'package:smartnotes/domain/entities/entry_write_failure.dart';
import 'package:smartnotes/data/services/local_entry_draft_repository.dart';
import 'package:smartnotes/domain/services/i_entry_draft_repository.dart';

class MockFiles extends Mock implements IFileStorageService {}

class MockEmbeddings extends Mock implements IEmbeddingService {}

class MockRecording extends Mock implements IAudioRecordingService {}

class MockProcessing extends Mock implements ProcessAudioNoteUseCase {}

class MockNoteProcessing extends Mock implements INoteProcessingService {}

List<double> vector(int dimension) => List.generate(
  LocalDatabase.embeddingDimensions,
  (i) => i == dimension ? 1.0 : 0.0,
);

void main() {
  late Directory temporary;
  late Directory audio;
  late LocalDatabase database;
  late MockFiles files;
  late SqliteJournalEntryService journal;
  late MockEmbeddings embeddings;
  late LocalEntrySearchService search;
  late JournalArchiveService backups;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('smartnotes-test-');
    audio = await Directory(p.join(temporary.path, 'audio')).create();
    database = LocalDatabase();
    await database.open(path: p.join(temporary.path, 'journal.sqlite'));
    files = MockFiles();
    when(
      () => files.getAudioDirectoryPath(),
    ).thenAnswer((_) async => audio.path);
    when(() => files.deleteFile(any())).thenAnswer((i) async {
      final file = File(i.positionalArguments.first as String);
      if (await file.exists()) await file.delete();
    });
    journal = SqliteJournalEntryService(database, files);
    embeddings = MockEmbeddings();
    when(
      () =>
          embeddings.embedQuery(any(), isCancelled: any(named: 'isCancelled')),
    ).thenAnswer((_) async => vector(0));
    when(
      () => embeddings.embedDocument(
        any(),
        isCancelled: any(named: 'isCancelled'),
        onPassage: any(named: 'onPassage'),
      ),
    ).thenAnswer((_) async => [vector(0)]);
    search = LocalEntrySearchService(database, embeddings);
    backups = JournalArchiveService(database, files);
  });
  tearDown(() async {
    await database.close();
    await temporary.delete(recursive: true);
  });

  Future<JournalEntry> completed({String title = 'Travel plans'}) async {
    final path = p.join(audio.path, 'recording.m4a');
    await File(path).writeAsBytes([1, 2, 3]);
    final entry = await journal.create(audioPath: path);
    return journal.update(
      entry.copyWith(
        title: title,
        formattedNote: 'Visit São Paulo',
        transcription: 'Plan a trip',
        status: EntryStatus.completed,
      ),
    );
  }

  test(
    'typed conflicts cross the database isolate and never overwrite newer text',
    () async {
      final original = await completed();
      final newer = await journal.update(
        original.copyWith(formattedNote: 'Newer'),
        expected: original,
      );
      await expectLater(
        journal.update(original, expected: original),
        throwsA(
          isA<EntryWriteFailure>().having(
            (e) => e.kind,
            'kind',
            EntryWriteFailureKind.changed,
          ),
        ),
      );
      expect(await journal.getById(original.id), newer);
      await journal.delete(original.id);
      await expectLater(
        journal.update(original, expected: original),
        throwsA(
          isA<EntryWriteFailure>().having(
            (e) => e.kind,
            'kind',
            EntryWriteFailureKind.deleted,
          ),
        ),
      );
    },
  );

  test(
    'saved Undo updates search while draft and preview remain excluded',
    () async {
      final source = await completed();
      final formatting = MockNoteProcessing();
      when(
        () => formatting.formatTranscription(
          action: AiAction.organizedNote,
          transcription: source.body,
        ),
      ).thenAnswer(
        (_) async => ProcessedAudio(
          title: 'Proposed',
          subTitle: '',
          markdown: 'Distinctive proposal',
          transcription: source.body,
        ),
      );
      final store = EntryDetailStore(
        journal,
        ProcessAudioNoteUseCase(formatting, journal),
        MemoryFormattingModels(),
      );
      await store.loadEntry(source.id);
      await store.applyAiAction(AiAction.organizedNote);
      expect(await search.searchText('Distinctive'), isEmpty);
      expect(await store.acceptAiDraft(), true);
      expect(await search.searchText('Distinctive'), hasLength(1));
      expect(await store.undoAiAction(), true);
      expect(await search.searchText('Distinctive'), isEmpty);
      expect(await search.searchText('Paulo'), hasLength(1));
      final restored = await journal.getById(source.id);
      expect(restored!.transcription, source.transcription);
      expect(restored.audioPath, source.audioPath);
      expect(restored.formattedNote, source.formattedNote);
    },
  );

  test('entry deletion clears its separate recovery draft', () async {
    final source = await completed();
    final drafts = LocalEntryDraftRepository.inDirectory(
      Directory(p.join(temporary.path, 'drafts')),
    );
    await drafts.write(
      EntryEditDraft(
        source: source,
        title: '',
        subtitle: '',
        body: 'Draft only',
        entryDate: source.effectiveEntryDate,
      ),
    );
    expect(await search.searchText('Draft only'), isEmpty);
    final archive = ZipDecoder().decodeBytes(await backups.export());
    expect(archive.files.any((file) => file.name.contains('draft')), false);
    final manifest = archive.files.singleWhere(
      (file) => file.name == 'journal.json',
    );
    expect(utf8.decode(manifest.content), isNot(contains('Draft only')));
    final withDrafts = SqliteJournalEntryService(database, files, drafts);
    await withDrafts.delete(source.id);
    expect(await drafts.read(source.id), isNull);
  });

  test(
    'superseded semantic query is cancelled and cannot publish or cache',
    () async {
      final entry = await completed();
      await search.indexPending();
      final started = Completer<void>();
      final release = Completer<void>();
      late bool Function() cancelled;
      when(
        () => embeddings.embedQuery(
          'old',
          isCancelled: any(named: 'isCancelled'),
        ),
      ).thenAnswer((invocation) async {
        cancelled = invocation.namedArguments[#isCancelled] as bool Function();
        if (!started.isCompleted) started.complete();
        await release.future;
        if (cancelled()) throw InferenceCancelled();
        return vector(0);
      });
      final old = search.searchSemantic('old');
      await started.future;
      expect((await search.searchSemantic('new')).single.entry.id, entry.id);
      expect(cancelled(), true);
      release.complete();
      expect(await old, isEmpty);
      expect((await search.searchSemantic('old')).single.entry.id, entry.id);
      verify(
        () => embeddings.embedQuery(
          'old',
          isCancelled: any(named: 'isCancelled'),
        ),
      ).called(2);
    },
  );

  for (final action in ['edit', 'delete', 'rebuild']) {
    test(
      '$action cancels obsolete indexing and refreshes pending work',
      () async {
        final entry = await completed();
        final started = Completer<void>();
        final release = Completer<void>();
        var calls = 0;
        late bool Function() cancelled;
        when(
          () => embeddings.embedDocument(
            any(),
            isCancelled: any(named: 'isCancelled'),
            onPassage: any(named: 'onPassage'),
          ),
        ).thenAnswer((invocation) async {
          calls++;
          if (calls == 1) {
            cancelled =
                invocation.namedArguments[#isCancelled] as bool Function();
            started.complete();
            await release.future;
            if (cancelled()) throw InferenceCancelled();
          }
          return [vector(0)];
        });
        final indexing = search.indexPending();
        await started.future;
        Future<void>? rebuilding;
        if (action == 'delete') {
          await journal.delete(entry.id);
        } else if (action == 'rebuild') {
          rebuilding = search.rebuild();
        } else {
          await journal.update(entry.copyWith(formattedNote: 'Updated note'));
        }
        expect(cancelled(), true);
        release.complete();
        await indexing;
        await rebuilding;
        final status = await database.indexStatus();
        expect(status.failed, 0);
        expect(status.pending, 0);
        expect(status.indexed, action == 'delete' ? 0 : 1);
        expect(calls, action == 'delete' ? 1 : 2);
      },
    );
  }

  test('local CRUD persists dates and resolves relative audio paths', () async {
    final entry = await completed();
    final edited = await journal.update(
      entry.copyWith(entryDate: DateTime(2020, 2, 3)),
    );
    final loaded = await journal.getById(entry.id);
    expect(loaded, edited);
    expect((await database.all()).single.audioPath, 'recording.m4a');
    await database.close();
    database = LocalDatabase();
    await database.open(path: p.join(temporary.path, 'journal.sqlite'));
    expect((await database.all()).single.title, 'Travel plans');
  });
  test(
    'watchAll supports independent listeners and publishes updates',
    () async {
      final first = journal.watchAll().take(2).toList();
      final second = journal.watchAll().take(2).toList();
      await pumpEventQueue();
      await journal.create(audioPath: p.join(audio.path, 'recording.m4a'));
      expect((await first).last, hasLength(1));
      expect((await second).last, hasLength(1));
    },
  );
  test(
    'watchById publishes only its entry through update and deletion',
    () async {
      final entry = await completed();
      final events = <JournalEntry?>[];
      final subscription = journal.watchById(entry.id).listen(events.add);
      await pumpEventQueue();
      final renamed = await journal.update(
        entry.copyWith(title: 'Renamed'),
        expected: entry,
      );
      await pumpEventQueue();
      await journal.delete(entry.id);
      await pumpEventQueue();
      await subscription.cancel();
      expect(events.map((item) => item?.title), [
        'Travel plans',
        'Renamed',
        null,
      ]);
      expect(renamed.id, entry.id);
    },
  );

  test(
    'FTS5 searches accents safely and never interprets SQL or FTS syntax',
    () async {
      await completed();
      expect(await search.searchText('sao'), hasLength(1));
      expect(await search.searchText('travel'), hasLength(1));
      expect(await search.searchText('" OR 1=1; --'), isEmpty);
      expect(await search.searchText('!!!'), isEmpty);
    },
  );
  test(
    'both engines page across all dates beyond old candidate limits',
    () async {
      final from = DateTime.parse('2026-10-08T00:00:00-03:00');
      final until = DateTime.parse('2026-10-09T00:00:00-03:00');
      final generation = await database.indexGeneration();
      for (var i = 0; i < 133; i++) {
        final entry = JournalEntry(
          id: i.toString().padLeft(3, '0'),
          createdAt: DateTime.utc(2010),
          updatedAt: DateTime.utc(2026),
          entryDate: i < 100
              ? from.subtract(const Duration(days: 1))
              : i == 130
              ? until
              : i == 131
              ? from.subtract(const Duration(microseconds: 1))
              : i == 132
              ? until.subtract(const Duration(microseconds: 1))
              : from,
          transcription: 'Journal memory',
          status: EntryStatus.completed,
        );
        await database.insertEntry(entry);
        await database.indexEntry(entry, [vector(0)], generation: generation);
      }
      final expected = List.generate(133, (i) => i.toString().padLeft(3, '0'));
      for (final meaning in [false, true]) {
        final ids = <String>[];
        for (var offset = 0; ; offset += 17) {
          final options = SearchOptions(
            offset: offset,
            limit: 17,
          );
          final page = meaning
              ? await database.searchVector(vector(0), options: options)
              : await database.searchText('journal', options: options);
          ids.addAll(page.map((r) => r.entry.id));
          if (page.length < 17) break;
        }
        expect(ids, expected, reason: 'meaning=$meaning');
      }
      final allWords = await database.searchText(
        'journal',
        options: const SearchOptions(offset: 100, limit: 40),
      );
      expect(allWords, hasLength(33));
    },
  );
  test(
    'text search returns a late passage, accent-insensitive highlights and its source',
    () async {
      final saved = await completed();
      await journal.update(
        saved.copyWith(
          title: 'A day',
          formattedNote:
              '${'Unrelated opening. ' * 100}Meet Júlia at the café tomorrow.',
          transcription: 'The original mentions a telescope.',
        ),
      );
      final note = (await search.searchText('julia')).single;
      expect(note.sources, {SearchSource.note});
      expect(
        note.excerpt,
        contains('${SearchResult.matchStart}Júlia${SearchResult.matchEnd}'),
      );
      expect(note.excerpt.length, lessThan(500));
      expect(note.byMeaning, false);
      final original = (await search.searchText('telesco')).single;
      expect(original.sources, {SearchSource.original});
      expect(original.excerpt, contains('telescope'));
      final title = (await search.searchText('day')).single;
      expect(title.sources, {SearchSource.title});
    },
  );

  test(
    'semantic result exposes the winning chunk, not the note beginning',
    () async {
      final saved = await completed();
      final entry = await journal.update(
        saved.copyWith(
          title: null,
          formattedNote: 'Current words.',
          transcription: 'Original memory of the ocean.',
        ),
      );
      final source = entrySource(entry);
      await database.indexEntry(
        entry,
        [vector(1), vector(0)],
        generation: await database.indexGeneration(),
        passages: [
          (text: entry.body, start: 0),
          (
            text: entry.transcription!,
            start: source.indexOf(entry.transcription!),
          ),
        ],
      );
      final results = await search.searchSemantic('ocean');
      expect(results, hasLength(1));
      expect(results.single.byMeaning, true);
      expect(results.single.sources, {SearchSource.original});
      expect(results.single.excerpt, entry.transcription);
      expect(results.single.score, closeTo(0, 0.0001));
      await journal.delete(entry.id);
      final inspection = sqlite3.open(p.join(temporary.path, 'journal.sqlite'));
      expect(inspection.select('SELECT * FROM chunk_passages'), isEmpty);
      inspection.close();
    },
  );
  test(
    'semantic search rejects results weaker than the calibrated distance',
    () async {
      final entry = await completed();
      await database.indexEntry(
        entry,
        [vector(1)],
        generation: await database.indexGeneration(),
      );
      // Orthogonal vectors sit at cosine distance 1, beyond the cutoff.
      expect(await database.searchVector(vector(0)), isEmpty);
      await database.indexEntry(
        entry,
        [vector(0)],
        generation: await database.indexGeneration(),
      );
      expect(await database.searchVector(vector(0)), hasLength(1));
    },
  );
  test(
    'real vec0 KNN returns notes and edit/delete invalidates vectors',
    () async {
      final entry = await completed();
      await search.indexPending();
      expect(
        (await search.searchSemantic('vacation')).single.entry.id,
        entry.id,
      );
      verify(
        () => embeddings.embedQuery(
          any(),
          isCancelled: any(named: 'isCancelled'),
        ),
      ).called(1);
      verify(
        () => embeddings.embedDocument(
          any(),
          isCancelled: any(named: 'isCancelled'),
          onPassage: any(named: 'onPassage'),
        ),
      ).called(1);
      await journal.update(entry.copyWith(entryDate: DateTime(2010)));
      await search.indexPending();
      verifyNever(
        () => embeddings.embedDocument(
          any(),
          isCancelled: any(named: 'isCancelled'),
          onPassage: any(named: 'onPassage'),
        ),
      );
      await journal.update(entry.copyWith(title: 'Changed'));
      expect(await database.searchVector(vector(0)), isEmpty);
      await search.indexPending();
      expect(await database.searchVector(vector(0)), hasLength(1));
      await journal.delete(entry.id);
      expect(await database.searchVector(vector(0)), isEmpty);
      expect(await journal.getById(entry.id), isNull);
      expect(await File(entry.audioPath!).exists(), false);
      await expectLater(journal.update(entry), throwsStateError);
    },
  );
  test(
    'stale indexing response cannot index an edited or deleted note',
    () async {
      final entry = await completed();
      await journal.update(entry.copyWith(title: 'Changed'));
      await database.indexEntry(entry, [
        vector(0),
      ], generation: await database.indexGeneration());
      expect(await database.searchVector(vector(0)), isEmpty);
    },
  );
  test('indexing works without credentials', () async {
    await completed();
    await search.indexPending();
    expect(await database.pendingEntries(), isEmpty);
    expect((await database.indexStatus()).indexed, 1);
  });
  test('source indexes the original once and retains it after edits', () async {
    final entry = await completed();
    final raw = entry.copyWith(
      title: null,
      formattedNote: null,
      transcription: '  Original  ',
    );
    expect(raw.body, '  Original  ');
    expect(entrySource(raw), 'Original');
    expect(entrySource(raw.copyWith(formattedNote: 'Original\n')), 'Original');
    expect(
      entrySource(raw.copyWith(formattedNote: 'Edited')),
      'Edited\n\nOriginal',
    );
    expect(entrySource(raw.copyWith(formattedNote: '')), 'Original');
    final saved = await journal.update(raw);
    await search.indexPending();
    verify(
      () => embeddings.embedDocument(
        'Original',
        isCancelled: any(named: 'isCancelled'),
        onPassage: any(named: 'onPassage'),
      ),
    ).called(1);
    await journal.update(saved.copyWith(formattedNote: 'Edited'));
    expect((await database.indexStatus()).pending, 1);
    await search.indexPending();
    expect(await search.searchText('Original'), hasLength(1));
    expect(await search.searchText('Edited'), hasLength(1));
  });

  test(
    'pipeline migration recalculates legacy source hashes before reindexing',
    () async {
      final entry = await completed();
      final rawNote = await journal.update(
        entry.copyWith(formattedNote: entry.transcription),
      );
      await search.indexPending();
      await database.close();
      final path = p.join(temporary.path, 'journal.sqlite');
      final raw = sqlite3.open(path);
      raw.execute(
        "UPDATE embedding_pipeline SET identity = 'legacy-duplicated-source'",
      );
      raw.execute("UPDATE entries SET source_hash = 'legacy-hash'");
      raw.close();
      database = LocalDatabase();
      await database.open(path: path);
      search = LocalEntrySearchService(database, embeddings);
      expect((await database.indexStatus()).pending, 1);
      expect(
        (await database.entry(entry.id))!.formattedNote,
        rawNote.formattedNote,
      );
      await search.indexPending();
      expect((await database.indexStatus()).indexed, 1);
      expect(await search.searchSemantic('Original'), hasLength(1));
    },
  );

  test(
    'drafts do not invalidate vectors and stale acceptance cannot overwrite or resurrect',
    () async {
      final source = await completed();
      final processing = MockNoteProcessing();
      when(
        () => processing.formatTranscription(
          action: AiAction.organizedNote,
          transcription: source.body,
        ),
      ).thenAnswer(
        (_) async => ProcessedAudio(
          title: 'Draft title',
          subTitle: 'Draft subtitle',
          markdown: 'Draft body',
          transcription: source.body,
        ),
      );
      final useCase = ProcessAudioNoteUseCase(processing, journal);
      await search.indexPending();
      final draft = await useCase.applyAiAction(source, AiAction.organizedNote);
      expect((await journal.getById(source.id))!.body, source.body);
      expect((await database.indexStatus()).indexed, 1);
      final edited = await journal.update(
        source.copyWith(formattedNote: 'Manual edit'),
        expected: source,
      );
      await expectLater(useCase.acceptAiDraft(source, draft), throwsStateError);
      expect((await journal.getById(source.id))!.body, 'Manual edit');
      await expectLater(useCase.restoreTranscription(source), throwsStateError);
      final restored = await useCase.restoreTranscription(edited);
      expect(restored.body, source.transcription);
      expect(restored.title, source.title);
      await journal.delete(source.id);
      await expectLater(
        useCase.acceptAiDraft(restored, draft),
        throwsStateError,
      );
      expect(await journal.getById(source.id), isNull);
    },
  );

  test(
    'transcript-only notes survive relaunch and backup round trips',
    () async {
      final original = await completed();
      final raw = await journal.update(
        original.copyWith(title: null, subTitle: null, formattedNote: null),
      );
      final bytes = await backups.export();
      await journal.delete(raw.id);
      await backups.import(bytes);
      final restored = await journal.getById(raw.id);
      expect(restored!.formattedNote, isNull);
      expect(restored.body, raw.transcription);
      expect(await search.searchText('trip'), hasLength(1));
      await database.close();
      database = LocalDatabase();
      await database.open(path: p.join(temporary.path, 'journal.sqlite'));
      expect((await database.entry(raw.id))!.body, raw.body);
    },
  );
  test(
    'missing model keeps entries pending for automatic indexing after setup',
    () async {
      await completed();
      when(
        () => embeddings.embedDocument(
          any(),
          isCancelled: any(named: 'isCancelled'),
          onPassage: any(named: 'onPassage'),
        ),
      ).thenThrow(const AiFailure(AiFailureCode.modelMissing));
      await search.indexPending();
      expect((await database.indexStatus()).pending, 1);
      expect((await database.indexStatus()).failed, 0);
    },
  );
  test(
    'schema v1 upgrade removes old vectors but preserves all journal content',
    () async {
      final entry = await completed();
      await search.indexPending();
      await database.close();
      final path = p.join(temporary.path, 'journal.sqlite');
      final raw = sqlite3.open(path);
      raw.execute('DROP TABLE embedding_pipeline');
      raw.execute(
        "UPDATE indexed_entries SET model = 'text-embedding-3-small'",
      );
      raw.execute('PRAGMA user_version = 1');
      raw.close();
      database = LocalDatabase();
      await database.open(path: path);
      expect(
        (await database.entry(entry.id))!.transcription,
        entry.transcription,
      );
      expect(
        (await database.entry(entry.id))!.formattedNote,
        entry.formattedNote,
      );
      expect(await database.searchText('sao'), hasLength(1));
      expect(await database.searchVector(vector(0)), isEmpty);
      expect((await database.indexStatus()).pending, 1);
      expect(await File(entry.audioPath!).readAsBytes(), [1, 2, 3]);
    },
  );
  test(
    'generation fences late vectors and failure markers after reset',
    () async {
      final entry = await completed();
      final generation = await database.indexGeneration();
      await database.resetIndex();
      await database.indexEntry(entry, [vector(0)], generation: generation);
      await database.markIndexFailed(entry, generation: generation);
      expect(await database.searchVector(vector(0)), isEmpty);
      expect((await database.indexStatus()).pending, 1);
      expect((await database.indexStatus()).failed, 0);
    },
  );
  test('one failed entry does not block other notes in the backlog', () async {
    final first = await completed(title: 'First');
    await completed(title: 'Second');
    when(
      () => embeddings.embedDocument(
        any(),
        isCancelled: any(named: 'isCancelled'),
        onPassage: any(named: 'onPassage'),
      ),
    ).thenAnswer((call) async {
      if ((call.positionalArguments.first as String).startsWith(first.title!)) {
        throw StateError('Invalid vector');
      }
      return [vector(0)];
    });
    await search.indexPending();
    final status = await database.indexStatus();
    expect(status.indexed, 1);
    expect(status.failed, 1);
    expect(status.isIncomplete, true);
  });
  test('query cache is invalidated by rebuild', () async {
    await completed();
    await search.indexPending();
    await search.searchSemantic('vacation');
    await search.searchSemantic('vacation');
    verify(
      () => embeddings.embedQuery(
        'vacation',
        isCancelled: any(named: 'isCancelled'),
      ),
    ).called(1);
    await search.rebuild();
    await search.searchSemantic('vacation');
    verify(
      () => embeddings.embedQuery(
        'vacation',
        isCancelled: any(named: 'isCancelled'),
      ),
    ).called(1);
  });
  test(
    'index progress stream publishes changes and can be cancelled',
    () async {
      await completed();
      final statuses = <int>[];
      final subscription = database.watchIndexStatus().listen(
        (s) => statuses.add(s.indexed),
      );
      await pumpEventQueue();
      await search.indexPending();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(statuses.first, 0);
      expect(statuses.last, 1);
      await subscription.cancel();
      expect((await database.watchIndexStatus().first).indexed, 1);
    },
  );
  test('failed index migration rolls back every derived deletion', () async {
    await completed();
    await search.indexPending();
    await database.close();
    final path = p.join(temporary.path, 'journal.sqlite');
    final raw = sqlite3.open(path);
    raw.execute("UPDATE embedding_pipeline SET identity='old-space'");
    raw.execute(
      "CREATE TRIGGER fail_migration BEFORE DELETE ON chunks BEGIN SELECT RAISE(ABORT, 'disk failure simulation'); END",
    );
    raw.close();
    database = LocalDatabase();
    await expectLater(database.open(path: path), throwsStateError);
    final check = sqlite3.open(path);
    expect(check.select('SELECT COUNT(*) AS n FROM chunks').single['n'], 1);
    expect(check.select('SELECT COUNT(*) AS n FROM entries').single['n'], 1);
    expect(
      check
          .select('SELECT identity FROM embedding_pipeline')
          .single['identity'],
      'old-space',
    );
    check.execute('DROP TRIGGER fail_migration');
    check.close();
    await database.open(path: path);
    expect((await database.indexStatus()).pending, 1);
    expect(await database.searchVector(vector(0)), isEmpty);
  });
  test(
    'failed embedding leaves saved notes searchable by text and retryable',
    () async {
      await completed();
      when(
        () => embeddings.embedDocument(
          any(),
          isCancelled: any(named: 'isCancelled'),
          onPassage: any(named: 'onPassage'),
        ),
      ).thenThrow(Exception('Unavailable'));
      await search.indexPending();
      expect(await database.pendingEntries(retryFailures: true), hasLength(1));
      expect(await database.pendingEntries(), isEmpty);
      await search.indexPending();
      verify(
        () => embeddings.embedDocument(
          any(),
          isCancelled: any(named: 'isCancelled'),
          onPassage: any(named: 'onPassage'),
        ),
      ).called(1);
      expect(await search.searchText('travel'), hasLength(1));
    },
  );
  test(
    'backup round trip includes audio and excludes keys and derived index',
    () async {
      final entry = await completed();
      await search.indexPending();
      final bytes = await backups.export();
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.files.map((f) => f.name), contains('journal.json'));
      expect(
        utf8.decode(archive.findFile('journal.json')!.content),
        isNot(contains('test-key')),
      );
      await journal.delete(entry.id);
      expect(await backups.import(bytes), 1);
      final restored = await journal.getById(entry.id);
      expect(restored!.title, entry.title);
      expect(await File(restored.audioPath!).readAsBytes(), [1, 2, 3]);
      expect(await database.pendingEntries(), hasLength(1));
    },
  );
  test(
    'malicious backup paths fail before changing files or existing notes',
    () async {
      final entry = await completed();
      final json = entry.copyWith(audioPath: '../../secret.m4a').toJson();
      final bytes = utf8.encode(
        jsonEncode({
          'format': 'smartnotes',
          'version': 1,
          'entries': [json],
        }),
      );
      final archive = Archive()
        ..addFile(ArchiveFile('journal.json', bytes.length, bytes));
      await expectLater(
        backups.import(ZipEncoder().encodeBytes(archive)),
        throwsFormatException,
      );
      expect((await journal.getById(entry.id))!.title, entry.title);
      expect(await audio.list().length, 1);
    },
  );
  test('unsupported archive version is rejected', () async {
    final bytes = utf8.encode(
      jsonEncode({
        'format': 'smartnotes',
        'version': 999,
        'entries': <dynamic>[],
      }),
    );
    final archive = Archive()
      ..addFile(ArchiveFile('journal.json', bytes.length, bytes));
    await expectLater(
      backups.import(ZipEncoder().encodeBytes(archive)),
      throwsFormatException,
    );
  });
  test('atomic import rolls back all notes on a failing record', () async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: 'imported',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
    );
    await expectLater(
      database.importEntries([entry, entry.copyWith(id: '')]),
      throwsStateError,
    );
    expect(await database.all(), isEmpty);
  });

  test(
    'late AI snapshot cannot overwrite a date edit or imported content',
    () async {
      final original = await completed();
      final edited = await journal.update(
        original.copyWith(entryDate: DateTime(2020)),
      );
      await expectLater(
        journal.update(
          original.copyWith(title: 'Late AI response'),
          expected: original,
        ),
        throwsStateError,
      );
      expect((await journal.getById(original.id))!.entryDate, edited.entryDate);
      final imported = edited.copyWith(
        title: 'Restored backup',
        formattedNote: 'Restored text',
      );
      await database.importEntries([imported]);
      await expectLater(
        journal.update(
          edited.copyWith(title: 'Late AI response'),
          expected: edited,
        ),
        throwsStateError,
      );
      expect((await journal.getById(original.id))!.title, 'Restored backup');
    },
  );

  test(
    'shared stream serializes slow audio resolution without stale publication',
    () async {
      final original = await completed();
      final watcherFiles = MockFiles();
      final firstRequested = Completer<void>();
      final secondRequested = Completer<void>();
      final firstPath = Completer<String>();
      final secondPath = Completer<String>();
      var requests = 0;
      when(() => watcherFiles.getAudioDirectoryPath()).thenAnswer((_) {
        if (requests++ == 0) {
          firstRequested.complete();
          return firstPath.future;
        }
        secondRequested.complete();
        return secondPath.future;
      });
      final watcher = SqliteJournalEntryService(database, watcherFiles);
      final snapshots = <List<JournalEntry>>[];
      final subscription = watcher.watchAll().listen(snapshots.add);
      await firstRequested.future;
      await journal.update(original.copyWith(title: 'Latest note'));
      firstPath.complete(audio.path);
      await secondRequested.future;
      secondPath.complete(audio.path);
      await pumpEventQueue();
      await subscription.cancel();
      expect(snapshots, isNotEmpty);
      expect(
        snapshots.every((snapshot) => snapshot.single.title == 'Latest note'),
        true,
      );
    },
  );

  test(
    'failed indexing is retried only explicitly, including after reopen',
    () async {
      final original = await completed();
      when(
        () => embeddings.embedDocument(
          any(),
          isCancelled: any(named: 'isCancelled'),
          onPassage: any(named: 'onPassage'),
        ),
      ).thenThrow(Exception('Unavailable'));
      await search.indexPending();
      await journal.update(original.copyWith(entryDate: DateTime(2020)));
      await search.indexPending();
      verify(
        () => embeddings.embedDocument(
          any(),
          isCancelled: any(named: 'isCancelled'),
          onPassage: any(named: 'onPassage'),
        ),
      ).called(1);
      final retrySearch = LocalEntrySearchService(database, embeddings);
      await retrySearch.indexPending();
      verifyNever(
        () => embeddings.embedDocument(
          any(),
          isCancelled: any(named: 'isCancelled'),
          onPassage: any(named: 'onPassage'),
        ),
      );
      when(
        () => embeddings.embedDocument(
          any(),
          isCancelled: any(named: 'isCancelled'),
          onPassage: any(named: 'onPassage'),
        ),
      ).thenAnswer((_) async => [vector(0)]);
      await retrySearch.indexPending(retryFailures: true);
      expect(await database.searchVector(vector(0)), hasLength(1));
    },
  );

  test(
    'Home retry refuses a stale pre-import snapshot before starting AI',
    () async {
      final original = await completed();
      final processing = MockProcessing();
      final home = HomeStore(
        journal,
        MockRecording(),
        JournalLifecycle(journal, processing, search, MemoryEmbeddingModels()),
        search,
      );
      await pumpEventQueue();
      final restored = original.copyWith(
        title: 'Restored note',
        audioPath: 'recording.m4a',
      );
      await database.importEntries([restored]);
      await home.retryProcessing(original);
      expect((await journal.getById(original.id))!.title, 'Restored note');
      expect(
        (await journal.getById(original.id))!.status,
        EntryStatus.completed,
      );
      verifyZeroInteractions(processing);
      home.dispose();
    },
  );
}
