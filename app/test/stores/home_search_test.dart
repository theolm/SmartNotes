import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' hide when;
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/application/journal_lifecycle.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/search_index_status.dart';
import 'package:smartnotes/domain/services/i_audio_recording_service.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import '../helpers/local_services.dart';

class _Journal extends Mock implements IJournalEntryService {}

class _Audio extends Mock implements IAudioRecordingService {}

class _Process extends Mock implements ProcessAudioNoteUseCase {}

class _Search extends MemorySearch {
  final index = StreamController<SearchIndexStatus>.broadcast();
  final wordCalls = <({String query, SearchOptions options})>[];
  final meaningCalls = <({String query, SearchOptions options})>[];
  Future<List<SearchResult>> Function(String, SearchOptions)? words;
  Future<List<SearchResult>> Function(String, SearchOptions, bool Function()?)?
  meaning;
  @override
  Stream<SearchIndexStatus> watchIndexStatus() => index.stream;
  @override
  Future<List<SearchResult>> searchText(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) async {
    wordCalls.add((query: query, options: options));
    return await words?.call(query, options) ?? [];
  }

  @override
  Future<List<SearchResult>> searchSemantic(
    String query, {
    SearchOptions options = const SearchOptions(),
    bool Function()? isCancelled,
  }) async {
    meaningCalls.add((query: query, options: options));
    return await meaning?.call(query, options, isCancelled) ?? [];
  }
}

void main() {
  late _Search search;
  late HomeStore store;
  late StreamController<List<JournalEntry>> updates;
  final date = DateTime(2026, 10, 8);
  JournalEntry entry(int id) => JournalEntry(
    id: '$id',
    createdAt: date,
    updatedAt: date,
    entryDate: date.add(Duration(days: id)),
    status: EntryStatus.completed,
    transcription: 'Entry $id',
  );
  SearchResult hit(int id, {bool meaning = false}) => SearchResult(
    entry: entry(id),
    excerpt: meaning ? 'Semantic evidence' : 'Literal evidence',
    sources: {SearchSource.note},
    score: id.toDouble(),
    byMeaning: meaning,
  );
  List<SearchResult> page(List<SearchResult> all, SearchOptions options) =>
      all.skip(options.offset).take(options.limit).toList();
  List<String> ids() => store.displayedEntries.map((e) => e.id).toList();

  setUp(() {
    final journal = _Journal();
    updates = StreamController<List<JournalEntry>>.broadcast();
    when(() => journal.watchAll()).thenAnswer((_) => updates.stream);
    when(
      () => journal.watchSearchMaintenance(),
    ).thenAnswer((_) => const Stream.empty());
    search = _Search();
    store = HomeStore(
      journal,
      _Audio(),
      JournalLifecycle(journal, _Process(), search, MemoryEmbeddingModels()),
      search,
    );
    store.entries = ObservableList.of(List.generate(200, entry));
  });
  tearDown(() async {
    store.dispose();
    await search.index.close();
    await updates.close();
  });

  testWidgets(
    'typing debounces words, retains results, and never starts inference',
    (tester) async {
      search.words = (_, options) async => page([hit(0)], options);
      for (final query in ['m', 'me', 'memory']) {
        store.submitSearch(query);
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(search.wordCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 250));
      expect(search.wordCalls, hasLength(1));
      expect(search.meaningCalls, isEmpty);
      expect(ids(), ['0']);
      final next = Completer<List<SearchResult>>();
      search.words = (_, _) => next.future;
      store.submitSearch('new');
      expect(ids(), ['0']);
      await tester.pump(const Duration(milliseconds: 250));
      next.complete([hit(1)]);
      await tester.pump();
      expect(ids(), ['1']);
    },
  );

  test(
    'edits retain loaded pages and require refresh before offset continuation',
    () async {
      search.words = (_, options) async =>
          page(List.generate(45, hit), options);
      store.submitSearch('memory');
      await store.runSearch();
      await store.loadMore();
      final before = ids();
      final scrollRevision = store.searchScrollRevision;
      updates.add(
        List.generate(
          200,
          (i) => i == 0 ? entry(i).copyWith(transcription: 'Edited') : entry(i),
        ),
      );
      await pumpEventQueue();
      expect(ids(), before);
      expect(store.displayedEntries.first.body, 'Edited');
      expect(store.searchScrollRevision, scrollRevision);
      expect(store.searchNeedsRefresh, true);
      final calls = search.wordCalls.length;
      await store.loadMore();
      expect(search.wordCalls.length, calls);
      await store.runSearch();
      expect(store.searchNeedsRefresh, false);
      expect(store.searchScrollRevision, greaterThan(scrollRevision));
    },
  );

  test(
    'an index rebuild with unchanged counts still invalidates continuation',
    () async {
      store.submitSearch('memory');
      final run = store.runSearch();
      search.index.add(const SearchIndexStatus(indexed: 30, generation: 1));
      await run;
      await pumpEventQueue();
      search.index.add(const SearchIndexStatus(indexed: 30, generation: 2));
      await pumpEventQueue();
      expect(store.searchNeedsRefresh, true);
    },
  );

  testWidgets('clearing or disposing cancels queued typing', (tester) async {
    store.submitSearch('unused');
    store.clearSearch();
    await tester.pump(const Duration(milliseconds: 300));
    store.submitSearch('unused');
    store.dispose();
    await tester.pump(const Duration(milliseconds: 300));
    expect(search.wordCalls, isEmpty);
  });

  test(
    'submit complements words, deduplicates and preserves rank instead of date',
    () async {
      search.words = (_, _) async => [hit(0), hit(2)];
      final pending = Completer<List<SearchResult>>();
      search.meaning = (_, _, _) => pending.future;
      store.submitSearch('memory');
      final run = store.runSearch();
      await pumpEventQueue();
      expect(ids(), ['0', '2']);
      expect(store.isSearchingMeaning, true);
      pending.complete([hit(2, meaning: true), hit(1, meaning: true)]);
      await run;
      expect(ids(), ['0', '2', '1']);
      expect(store.searchResultFor(entry(2))!.byMeaning, false);
      await store.runSearch();
      expect(search.wordCalls, hasLength(1));
      expect(search.meaningCalls, hasLength(1));
      store.clearSearch();
      expect(ids().first, '199');
    },
  );

  test(
    'meaning failure keeps word results and retries only missing work',
    () async {
      search.words = (_, _) async => [hit(0)];
      search.meaning = (_, _, _) async =>
          throw const AiFailure(AiFailureCode.modelMissing);
      store.submitSearch('memory');
      await store.runSearch();
      expect(ids(), ['0']);
      expect(store.meaningError, AiFailureCode.modelMissing.name);
      expect(store.searchError, isNull);
      search.meaning = (_, _, _) async => [hit(1, meaning: true)];
      await store.runSearch();
      expect(ids(), ['0', '1']);
      expect(store.meaningError, isNull);
      expect(search.wordCalls, hasLength(1));
    },
  );

  for (final action in ['type', 'clear', 'dispose', 'words']) {
    test(
      '$action invalidates semantic work without publishing stale passages',
      () async {
        final pending = Completer<List<SearchResult>>();
        late bool Function() cancelled;
        search.meaning = (_, options, cancel) {
          cancelled = cancel!;
          return pending.future;
        };
        store.submitSearch('old');
        final run = store.runSearch();
        await pumpEventQueue();
        expect(cancelled(), false);
        switch (action) {
          case 'type':
            store.submitSearch('new');
          case 'clear':
            store.clearSearch();
          case 'dispose':
            store.dispose();
          case 'words':
            store.useWordResults();
        }
        expect(cancelled(), true);
        pending.complete([hit(10, meaning: true)]);
        await run;
        expect(
          store.searchResults?.any((r) => r.entry.id == '10') ?? false,
          false,
        );
      },
    );
  }

  test('late word responses cannot overwrite a different query', () async {
    final old = Completer<List<SearchResult>>();
    search.words = (query, _) async => query == 'old' ? old.future : [hit(1)];
    store.submitSearch('old');
    final first = store.runSearch();
    store.submitSearch('new');
    await store.runSearch();
    old.complete([hit(0)]);
    await first;
    expect(ids(), ['1']);
    expect(search.meaningCalls.map((c) => c.query), ['new']);
  });

  test(
    'continuation passes former 100/20 limits without duplicates or reordered rows',
    () async {
      final words = List.generate(110, hit);
      final meaning = List.generate(80, (i) => hit(i + 70, meaning: true));
      search.words = (_, options) async => page(words, options);
      search.meaning = (_, options, _) async => page(meaning, options);
      store.submitSearch('memory');
      await store.runSearch();
      while (store.hasMoreResults) {
        final before = ids();
        await store.loadMore();
        expect(ids().take(before.length), before);
      }
      expect(ids(), hasLength(150));
      expect(ids().toSet(), List.generate(150, (i) => '$i').toSet());
      expect(store.searchResultFor(entry(80))!.byMeaning, false);
    },
  );

  test(
    'failed page retries the same offset, retaining already visible results',
    () async {
      final all = List.generate(45, hit);
      var fail = true;
      search.words = (_, options) async {
        if (fail && options.offset == 20) throw StateError('failed page');
        return page(all, options);
      };
      store.submitSearch('memory');
      await store.runSearch();
      final before = ids();
      await store.loadMore();
      expect(ids(), before);
      expect(store.loadMoreError, isNotNull);
      fail = false;
      await store.loadMore();
      expect(ids(), hasLength(40));
      expect(search.wordCalls.map((c) => c.options.offset), [0, 20, 20]);
      expect(store.loadMoreError, isNull);
    },
  );

  test(
    'query change discards an in-flight page and restarts at offset zero',
    () async {
      final pending = Completer<List<SearchResult>>();
      search.words = (_, options) async =>
          options.offset == 0 ? List.generate(21, hit) : pending.future;
      store.submitSearch('memory');
      await store.runSearch();
      final more = store.loadMore();
      store.submitSearch('another');
      await store.runSearch();
      await pumpEventQueue();
      pending.complete([hit(99)]);
      await more;
      expect(ids(), isNot(contains('99')));
      expect(search.wordCalls.last.options.offset, 0);
    },
  );

  test(
    'index changes require refresh before continuing offset pages',
    () async {
      search.meaning = (_, options, _) async =>
          page(List.generate(30, (i) => hit(i, meaning: true)), options);
      store.submitSearch('memory');
      final run = store.runSearch();
      search.index.add(const SearchIndexStatus(indexed: 30));
      await run;
      await pumpEventQueue();
      search.index.add(const SearchIndexStatus(indexed: 31));
      await pumpEventQueue();
      expect(store.searchNeedsRefresh, true);
      final calls = search.meaningCalls.length;
      await store.loadMore();
      expect(search.meaningCalls.length, calls);
      await store.runSearch();
      expect(store.searchNeedsRefresh, false);
    },
  );
}
