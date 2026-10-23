import 'dart:async';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/application/journal_lifecycle.dart';
import 'package:auto_route/auto_route.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/presentation/screens/home/home_screen.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/screens/home/widgets/timeline_item.dart';
import 'package:smartnotes/presentation/screens/home/widgets/day_header.dart';
import 'package:smartnotes/presentation/screens/home/widgets/sound_waveform.dart';
import 'package:smartnotes/domain/services/i_audio_recording_service.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';

import '../helpers/nav_bar_inset.dart';
import '../helpers/local_services.dart';

class MockJournalEntryService extends Mock implements IJournalEntryService {}

class MockAudioRecordingService extends Mock
    implements IAudioRecordingService {}

class MockProcessAudioNoteUseCase extends Mock
    implements ProcessAudioNoteUseCase {}

class MockStackRouter extends Mock implements StackRouter {}

class _Settings extends Mock implements ISettingsService {}

class _Auth extends Mock implements ILocalAuthService {}

class _Search extends MemorySearch {
  _Search(super.entries);
  Future<List<SearchResult>>? response;

  @override
  Future<List<SearchResult>> searchSemantic(
    String query, {
    bool Function()? isCancelled,
    SearchOptions options = const SearchOptions(),
  }) =>
      response ??
      super.searchSemantic(query, isCancelled: isCancelled, options: options);
}

class _TestableHomeScreen extends StatelessWidget {
  const _TestableHomeScreen({required this.store, this.router});

  final HomeStore store;
  final StackRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: withNavBarInset(
        router == null
            ? const HomeScreen()
            : StackRouterScope(
                controller: router!,
                stateHash: 0,
                child: const HomeScreen(),
              ),
      ),
    );
  }
}

void main() {
  late MockJournalEntryService mockJournalService;
  late MockAudioRecordingService mockAudioService;
  late MockProcessAudioNoteUseCase mockUseCase;
  late HomeStore store;
  late _Search search;

  late StreamController<List<JournalEntry>> entriesController;

  setUpAll(() {
    registerFallbackValue(
      JournalEntry(
        id: 'fallback',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: EntryStatus.completed,
      ),
    );
  });

  setUp(() {
    entriesController = StreamController<List<JournalEntry>>.broadcast();
    mockJournalService = MockJournalEntryService();
    when(
      () => mockJournalService.watchSearchMaintenance(),
    ).thenAnswer((_) => const Stream.empty());
    mockAudioService = MockAudioRecordingService();
    mockUseCase = MockProcessAudioNoteUseCase();
    when(
      () => mockAudioService.onStateChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockAudioService.onAmplitudeChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockAudioService.hasPermission()).thenAnswer((_) async => true);
    when(() => mockAudioService.start()).thenAnswer((_) async {});
    when(
      () => mockAudioService.stop(),
    ).thenAnswer((_) async => '/path/to/audio.m4a');
    when(
      () => mockJournalService.watchAll(),
    ).thenAnswer((_) => entriesController.stream);
    search = _Search(() => store.entries.toList());
    store = HomeStore(
      mockJournalService,
      mockAudioService,
      JournalLifecycle(
        mockJournalService,
        mockUseCase,
        MemorySearch(),
        MemoryEmbeddingModels(),
      ),
      search,
    );
    GetIt.I.registerSingleton<HomeStore>(store);
    GetIt.I.registerSingleton<AppStore>(
      AppStore(
        _Auth(),
        _Settings(),
        MemorySpeechModels(),
        MemoryEmbeddingModels(),
      ),
    );
  });

  tearDown(() {
    store.dispose();
    entriesController.close();
    GetIt.I.reset();
  });

  for (final width in [360.0, 1000.0]) {
    for (final body in ['', 'Short note']) {
      testWidgets('short cells fill the reading column at $width ($body)', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final date = DateTime(2026);
        final entry = JournalEntry(
          id: 'short',
          createdAt: date,
          updatedAt: date,
          status: EntryStatus.completed,
          transcription: body,
        );
        final router = MockStackRouter();
        when(
          () => router.push<Object?>(EntryDetailRoute(entryId: entry.id)),
        ).thenAnswer((_) async => null);
        await tester.pumpWidget(
          _TestableHomeScreen(store: store, router: router),
        );
        entriesController.add([entry]);
        await tester.pumpAndSettle();

        final list = tester.getRect(find.byType(ListView));
        final ink = find
            .descendant(
              of: find.byType(TimelineItem),
              matching: find.byType(InkWell),
            )
            .first;
        expect(tester.getSize(ink).width, list.width);
        expect(list.width, lessThanOrEqualTo(640));
        final right = Offset(list.right - 8, tester.getCenter(ink).dy);
        await tester.tapAt(right);
        await tester.pumpAndSettle();
        verify(
          () => router.push<Object?>(EntryDetailRoute(entryId: entry.id)),
        ).called(1);

        await tester.dragFrom(right, Offset(-list.width * 0.65, 0));
        await tester.pumpAndSettle();
        expect(find.text('Delete').hitTestable(), findsOneWidget);
      });
    }
  }

  testWidgets(
    'amplitude updates waveform without rebuilding journal Scaffold or timeline',
    (tester) async {
      await tester.pumpWidget(_TestableHomeScreen(store: store));
      final date = DateTime(2026);
      entriesController.add([
        JournalEntry(
          id: 'synthetic',
          createdAt: date,
          updatedAt: date,
          status: EntryStatus.completed,
        ),
      ]);
      store.isRecording = true;
      await tester.pump();
      await tester.pump();
      final scaffold = tester.widgetList<Scaffold>(find.byType(Scaffold)).last;
      final scaffolds = tester
          .widgetList<Scaffold>(find.byType(Scaffold))
          .toList();
      final item = tester.widget<TimelineItem>(find.byType(TimelineItem));
      for (var i = 1; i <= 20; i++) {
        store.amplitude = i / 20;
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          identical(
            tester.widgetList<Scaffold>(find.byType(Scaffold)).last,
            scaffold,
          ),
          true,
        );
        expect(
          identical(
            tester.widget<TimelineItem>(find.byType(TimelineItem)),
            item,
          ),
          true,
        );
        expect(
          tester.widget<SoundWaveform>(find.byType(SoundWaveform)).amplitude,
          i / 20,
        );
        expect(tester.widgetList<Scaffold>(find.byType(Scaffold)), scaffolds);
      }
      store.isRecording = false;
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a 10k-entry day builds only visible timeline entries', (
    tester,
  ) async {
    await tester.pumpWidget(_TestableHomeScreen(store: store));
    final date = DateTime(2026);
    entriesController.add(
      List.generate(
        10000,
        (i) => JournalEntry(
          id: 'synthetic-$i',
          createdAt: date,
          updatedAt: date,
          status: EntryStatus.completed,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(TimelineItem).evaluate().length,
      inInclusiveRange(1, 20),
    );
  });

  testWidgets('compact journal and unified search support large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    entriesController.add([]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Search words, or describe a memory.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'word results settle before related search and never show empty during inference',
    (
      tester,
    ) async {
      final date = DateTime(2026);
      entriesController.add([
        JournalEntry(
          id: 'entry',
          createdAt: date,
          updatedAt: date,
          status: EntryStatus.completed,
          transcription: 'A quiet evening',
        ),
      ]);
      await tester.pumpWidget(_TestableHomeScreen(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'absent topic');
      await tester.pumpAndSettle();
      expect(find.text('No entries match your search'), findsOneWidget);
      expect(find.text('Find related entries'), findsOneWidget);
      final pending = Completer<List<SearchResult>>();
      search.response = pending.future;
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.text('No entries match your search'), findsNothing);
      expect(find.text('Find related entries'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No entries match your search'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'another topic');
      await tester.pump();
      expect(find.text('No entries match your search'), findsNothing);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('ranked results can alternate dates without repeated day keys', (
    tester,
  ) async {
    final date = DateTime(2026);
    entriesController.add([
      for (var i = 0; i < 3; i++)
        JournalEntry(
          id: '$i',
          createdAt: date,
          updatedAt: date,
          entryDate: i == 1 ? date.add(const Duration(days: 1)) : date,
          status: EntryStatus.completed,
          title: 'Match $i',
        ),
    ]);
    await tester.pumpWidget(_TestableHomeScreen(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Match');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<TimelineItem>(find.byType(TimelineItem))
          .map((item) => item.entry.id),
      ['0', '1', '2'],
    );
    expect(find.byType(DayHeader), findsNothing);
    expect(find.text('Jan 1, 2026 00:00'), findsNWidgets(2));
    expect(find.text('Jan 2, 2026 00:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(DayHeader), findsNWidgets(2));
  });

  testWidgets(
    'search covers all dates and clearing text restores the journal',
    (tester) async {
      final now = DateTime.now();
      entriesController.add([
        for (final days in [0, 45])
          JournalEntry(
            id: '$days',
            createdAt: now,
            updatedAt: now,
            entryDate: now.subtract(Duration(days: days)),
            status: EntryStatus.completed,
            transcription: 'Memory $days',
          ),
      ]);
      await tester.pumpWidget(_TestableHomeScreen(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Memory');
      await tester.pumpAndSettle();
      expect(store.displayedEntries, hasLength(2));
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Memory',
      );
      await tester.tap(find.byTooltip('Clear search text'));
      await tester.pumpAndSettle();
      expect(store.searchQuery, isEmpty);
      expect(store.displayedEntries, hasLength(2));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(store.displayedEntries, hasLength(2));
    },
  );

  testWidgets(
    'load more appends word results while retaining the reading position',
    (tester) async {
      final now = DateTime(2026);
      entriesController.add(
        List.generate(
          45,
          (i) => JournalEntry(
            id: '$i',
            createdAt: now,
            updatedAt: now,
            status: EntryStatus.completed,
            transcription: 'Memory $i',
          ),
        ),
      );
      await tester.pumpWidget(_TestableHomeScreen(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Memory');
      await tester.pumpAndSettle();
      expect(store.displayedEntries, hasLength(20));
      await tester.scrollUntilVisible(
        find.text('Load more'),
        400,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      final offset = tester
          .widget<ListView>(find.byType(ListView))
          .controller!
          .offset;
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(store.displayedEntries, hasLength(40));
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        offset,
      );
      expect(store.meaningRequested, false);
    },
  );

  testWidgets(
    'search errors offer retry, model setup and word-search recovery',
    (tester) async {
      final date = DateTime(2026);
      final entry = JournalEntry(
        id: 'entry',
        createdAt: date,
        updatedAt: date,
        status: EntryStatus.completed,
        transcription: 'Ocean memory',
      );
      entriesController.add([entry]);
      await tester.pumpWidget(_TestableHomeScreen(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ocean');
      final failing = Completer<List<SearchResult>>();
      search.response = failing.future;
      await tester.testTextInput.receiveAction(TextInputAction.search);
      failing.completeError(const AiFailure(AiFailureCode.modelMissing));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Keep word results'), findsOneWidget);
      expect(find.text('Check model setup'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final retry = Completer<List<SearchResult>>();
      search.response = retry.future;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(store.isSearching, true);
      retry.completeError(const AiFailure(AiFailureCode.unavailable));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Keep word results'));
      await tester.tap(find.text('Keep word results'));
      await tester.pumpAndSettle();
      expect(store.meaningRequested, false);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Ocean',
      );
      expect(store.searchError, isNull);
      expect(store.displayedEntries.single.id, 'entry');
    },
  );

  testWidgets(
    'local recording does not request credentials',
    (tester) async {
      entriesController.add([]);
      await tester.pumpWidget(_TestableHomeScreen(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Set up your OpenAI key'), findsNothing);
      expect(store.isRecording, true);
      verify(() => mockAudioService.start()).called(1);
      verifyNever(
        () => mockJournalService.create(audioPath: any(named: 'audioPath')),
      );

      expect(find.byType(AlertDialog), findsNothing);
      expect(store.errorMessage, isNull);
    },
  );

  testWidgets('Settings remains available offline', (
    tester,
  ) async {
    entriesController.add([]);
    final router = MockStackRouter();
    when(
      () => router.push<Object?>(const SettingsRoute()),
    ).thenAnswer((_) async => null);
    await tester.pumpWidget(_TestableHomeScreen(store: store, router: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verify(() => router.push<Object?>(const SettingsRoute())).called(1);
    verifyZeroInteractions(mockAudioService);
  });

  testWidgets(
    'recording uses the local audio service',
    (tester) async {
      entriesController.add([]);
      await tester.pumpWidget(_TestableHomeScreen(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump(const Duration(milliseconds: 33));

      expect(store.isRecording, true);
      expect(find.byType(AlertDialog), findsNothing);
      verify(() => mockAudioService.start()).called(1);
    },
  );

  testWidgets('previews current words instead of the generated subtitle', (
    tester,
  ) async {
    final now = DateTime.now();
    final entries = [
      JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        title: 'Test Note',
        subTitle: 'Short summary of the note',
        transcription: 'The original words I want to remember.',
      ),
    ];
    entriesController.add(entries);

    await tester.pumpWidget(_TestableHomeScreen(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Test Note'), findsOneWidget);
    expect(find.text('Short summary of the note'), findsNothing);
    expect(find.text('The original words I want to remember.'), findsOneWidget);
  });

  testWidgets('renders empty state when no entries', (tester) async {
    entriesController.add([]);

    await tester.pumpWidget(_TestableHomeScreen(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Your journal is empty'), findsOneWidget);
  });

  testWidgets('swiping an entry reveals Delete and cancellation keeps it', (
    tester,
  ) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      title: 'Test Note',
    );
    entriesController.add([entry]);

    await tester.pumpWidget(_TestableHomeScreen(store: store));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Test Note'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete entry?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Test Note'), findsOneWidget);
    verifyNever(() => mockJournalService.delete(entry.id));
  });

  testWidgets('confirmation deletes entry through the reactive timeline', (
    tester,
  ) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      title: 'Test Note',
    );
    when(() => mockJournalService.delete(entry.id)).thenAnswer((_) async {
      entriesController.add([]);
    });
    entriesController.add([entry]);

    await tester.pumpWidget(_TestableHomeScreen(store: store));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Test Note'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();

    verify(() => mockJournalService.delete(entry.id)).called(1);
    expect(find.text('Your journal is empty'), findsOneWidget);
    expect(find.text('Entry deleted'), findsOneWidget);
  });

  testWidgets('a deletion failure keeps the entry visible and shows feedback', (
    tester,
  ) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      title: 'Test Note',
    );
    when(() => mockJournalService.delete(entry.id)).thenThrow(Exception());
    entriesController.add([entry]);

    await tester.pumpWidget(_TestableHomeScreen(store: store));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Test Note'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Note'), findsOneWidget);
    expect(find.text('Failed to delete entry'), findsOneWidget);
  });

  testWidgets('pads the timeline list clear of the navigation bar inset', (
    tester,
  ) async {
    final now = DateTime.now();
    entriesController.add([
      JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        title: 'Test Note',
      ),
    ]);

    await tester.pumpWidget(_TestableHomeScreen(store: store));
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));

    expect(
      listView.padding,
      const EdgeInsets.only(bottom: AppSpacing.section + kNavBarInset),
    );
  });

  testWidgets('tapping error entry opens bottom sheet with retry', (
    tester,
  ) async {
    final now = DateTime.now();
    final entries = [
      JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.error,
      ),
    ];
    entriesController.add(entries);

    await tester.pumpWidget(_TestableHomeScreen(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Processing failed'), findsOneWidget);

    await tester.tap(find.text('Processing failed'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'hides record FAB when search is active and shows it when closed',
    (tester) async {
      entriesController.add([]);

      await tester.pumpWidget(_TestableHomeScreen(store: store));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
    },
  );

  testWidgets('shows overlay while recording and blocks other interactions', (
    tester,
  ) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: 'recording-1',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.recording,
      audioPath: '/path/to/audio.m4a',
    );
    entriesController.add([]);
    when(
      () => mockJournalService.create(audioPath: any(named: 'audioPath')),
    ).thenAnswer((_) async => entry);
    when(
      () => mockJournalService.update(any(), expected: any(named: 'expected')),
    ).thenAnswer(
      (invocation) {
        final updated = invocation.positionalArguments.first as JournalEntry;
        return Future.value(updated);
      },
    );
    when(() => mockUseCase.process(any())).thenAnswer((_) async => entry);

    await tester.pumpWidget(_TestableHomeScreen(store: store));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic), findsOneWidget);

    unawaited(store.startRecording());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 33));

    expect(store.isRecording, isTrue);

    final overlay = find.byWidgetPredicate(
      (widget) =>
          widget is Container && widget.color != null && widget.color!.a == 0.3,
    );
    expect(overlay, findsOneWidget);

    await tester.tap(find.byIcon(Icons.search), warnIfMissed: false);
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);

    await store.stopRecording();
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color != null &&
            widget.color!.a == 0.3,
      ),
      findsNothing,
    );
  });
}
