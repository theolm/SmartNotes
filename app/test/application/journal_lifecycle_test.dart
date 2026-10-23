import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/application/journal_lifecycle.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_entry_search_service.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';

import '../helpers/local_services.dart';

class MockJournal extends Mock implements IJournalEntryService {}

class MockProcessing extends Mock implements ProcessAudioNoteUseCase {}

class MockSearch extends Mock implements IEntrySearchService {}

void main() {
  final now = DateTime(2026, 10, 19);
  final pending = JournalEntry(
    id: 'pending',
    createdAt: now,
    updatedAt: now,
    status: EntryStatus.processing,
    audioPath: '/audio/pending.m4a',
  );
  late StreamController<List<JournalEntry>> snapshots;
  late MockJournal journal;
  late MockProcessing processing;
  late MockSearch search;
  late MemoryEmbeddingModels models;
  late JournalLifecycle lifecycle;
  late Map<String, JournalEntry> saved;

  setUpAll(() => registerFallbackValue(pending));
  setUp(() {
    snapshots = StreamController<List<JournalEntry>>.broadcast();
    journal = MockJournal();
    processing = MockProcessing();
    search = MockSearch();
    models = MemoryEmbeddingModels();
    saved = {};
    when(() => journal.watchAll()).thenAnswer((_) => snapshots.stream);
    when(
      () => journal.update(any(), expected: any(named: 'expected')),
    ).thenAnswer((call) async {
      final entry = call.positionalArguments.single as JournalEntry;
      saved[entry.id] = entry;
      return entry;
    });
    when(
      () => journal.getById(any()),
    ).thenAnswer((call) async => saved[call.positionalArguments.single]);
    when(() => processing.process(any())).thenAnswer(
      (call) async => call.positionalArguments.single as JournalEntry,
    );
    when(() => search.indexPending()).thenAnswer((_) async {});
    lifecycle = JournalLifecycle(journal, processing, search, models);
  });
  tearDown(() async {
    await lifecycle.dispose();
    await snapshots.close();
    await models.readinessEvents.close();
  });

  test(
    'startup waits for storage, recovers once without any screen, and starts once',
    () async {
      lifecycle.start();
      lifecycle.start();
      verify(() => journal.watchAll()).called(1);
      verifyZeroInteractions(processing);
      snapshots.add([
        pending,
        pending.copyWith(id: 'failed', status: EntryStatus.error),
      ]);
      await pumpEventQueue();
      snapshots.add([pending]);
      await pumpEventQueue();
      verify(() => processing.process(pending)).called(1);
      verifyNever(
        () => processing.process(
          any(that: predicate<JournalEntry>((entry) => entry.id == 'failed')),
        ),
      );
    },
  );

  test(
    'entry changes index pending sources but never retry failed indexing',
    () async {
      lifecycle.start();
      snapshots.add([]);
      await pumpEventQueue();
      snapshots.add([pending.copyWith(status: EntryStatus.completed)]);
      await pumpEventQueue();
      verify(() => search.indexPending()).called(2);
      verifyNever(() => search.indexPending(retryFailures: true));
    },
  );

  test(
    'model repair resumes indexing without opening Settings or changing entries',
    () async {
      models.ready = false;
      lifecycle.start();
      snapshots.add([]);
      await pumpEventQueue();
      verifyNever(() => search.indexPending());
      await models.download(onProgress: (_, _) {});
      await pumpEventQueue();
      verify(() => search.indexPending()).called(1);
    },
  );

  test(
    'coalesces indexing triggers while preserving a later entry change',
    () async {
      final blocked = Completer<void>();
      var calls = 0;
      var active = 0;
      var maximum = 0;
      when(() => search.indexPending()).thenAnswer((_) async {
        calls++;
        active++;
        if (active > maximum) maximum = active;
        if (calls == 1) await blocked.future;
        active--;
      });
      lifecycle.start();
      snapshots.add([]);
      await pumpEventQueue();
      snapshots.add([]);
      snapshots.add([]);
      models.readinessEvents.add(true);
      await pumpEventQueue();
      expect(calls, 1);
      blocked.complete();
      await pumpEventQueue();
      expect(calls, 2);
      expect(maximum, 1);
    },
  );

  test('recovery and a concurrent explicit retry join one entry job', () async {
    final blocked = Completer<JournalEntry>();
    when(() => processing.process(pending)).thenAnswer((_) => blocked.future);
    lifecycle.start();
    snapshots.add([pending]);
    await pumpEventQueue();
    final explicit = lifecycle.processEntry(pending);
    verify(() => processing.process(pending)).called(1);
    blocked.complete(pending.copyWith(status: EntryStatus.completed));
    await explicit;
    verifyNever(() => processing.process(pending));
  });

  test(
    'failed recovery marks error and continues, without automatic retries',
    () async {
      final second = pending.copyWith(id: 'second');
      when(
        () => processing.process(pending),
      ).thenThrow(Exception('Broken audio'));
      lifecycle.start();
      snapshots.add([pending, second]);
      await pumpEventQueue();
      expect(saved[pending.id]!.status, EntryStatus.error);
      verify(() => processing.process(second)).called(1);
      snapshots.add([saved[pending.id]!, second]);
      await pumpEventQueue();
      verify(() => processing.process(pending)).called(1);
    },
  );

  test('busy inference does not mark another active job as failed', () async {
    when(
      () => processing.process(pending),
    ).thenThrow(const AiFailure(AiFailureCode.busy));
    lifecycle.start();
    snapshots.add([pending]);
    await pumpEventQueue();
    expect(saved[pending.id]!.status, EntryStatus.processing);
  });

  test(
    'explicit retry reads current storage and includes failed recordings',
    () async {
      lifecycle.start();
      snapshots.add([]);
      await pumpEventQueue();
      final failed = pending.copyWith(status: EntryStatus.error);
      final retry = lifecycle.retryRecordings();
      snapshots.add([failed]);
      await retry;
      verify(() => processing.process(pending)).called(1);
    },
  );

  test('background failures do not stop subsequent index requests', () async {
    when(
      () => search.indexPending(),
    ).thenThrow(Exception('Storage unavailable'));
    lifecycle.start();
    snapshots.add([]);
    await pumpEventQueue();
    when(() => search.indexPending()).thenAnswer((_) async {});
    snapshots.add([]);
    await pumpEventQueue();
    verify(() => search.indexPending()).called(2);
  });

  test('dispose unsubscribes background triggers', () async {
    lifecycle.start();
    snapshots.add([]);
    await pumpEventQueue();
    await lifecycle.dispose();
    snapshots.add([pending]);
    models.readinessEvents.add(true);
    await pumpEventQueue();
    verify(() => search.indexPending()).called(1);
    verifyZeroInteractions(processing);
  });
}
