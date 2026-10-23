import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/application/journal_lifecycle.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_audio_recording_service.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_screen.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart';
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_screen.dart';
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_store.dart';
import 'package:smartnotes/presentation/screens/home/home_screen.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/screens/home/widgets/record_fab.dart';
import 'package:smartnotes/presentation/screens/home/widgets/sound_waveform.dart';
import 'package:smartnotes/presentation/screens/home/widgets/timeline_item.dart';

import '../helpers/entry_experience_fakes.dart';
import '../helpers/local_services.dart';

class _Journal extends Mock implements IJournalEntryService {}

class _Audio extends Mock implements IAudioRecordingService {}

class _Process extends Mock implements ProcessAudioNoteUseCase {}

class _Settings extends Mock implements ISettingsService {}

class _Auth extends Mock implements ILocalAuthService {}

void main() {
  late _Journal journal;
  late _Audio audio;
  late HomeStore home;
  late AppRouter router;
  late MemoryEntryDrafts drafts;
  late List<JournalEntry> entries;
  late ValueNotifier<EdgeInsets> keyboard;
  late ValueNotifier<List<DisplayFeature>> features;
  var editCreations = 0;

  setUpAll(() {
    registerFallbackValue(
      JournalEntry(
        id: 'fallback',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        status: EntryStatus.completed,
      ),
    );
  });

  setUp(() {
    entries = List.generate(
      25,
      (i) => JournalEntry(
        id: '$i',
        title: 'Entry $i',
        transcription: 'Thought $i',
        createdAt: DateTime(2026, 10, 23, 12).subtract(Duration(hours: i)),
        updatedAt: DateTime(2026, 10, 23),
        status: EntryStatus.completed,
      ),
    );
    journal = _Journal();
    audio = _Audio();
    final process = _Process();
    final search = MemorySearch(() => entries);
    when(() => journal.watchAll()).thenAnswer((_) => Stream.value(entries));
    when(
      () => journal.watchSearchMaintenance(),
    ).thenAnswer((_) => const Stream.empty());
    when(() => journal.getById(any())).thenAnswer(
      (call) async => entries.firstWhere(
        (entry) => entry.id == call.positionalArguments.first,
      ),
    );
    when(
      () => journal.watchById(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => journal.update(any(), expected: any(named: 'expected')),
    ).thenAnswer(
      (call) async => call.positionalArguments.first as JournalEntry,
    );
    when(() => audio.hasPermission()).thenAnswer((_) async => true);
    when(() => audio.start()).thenAnswer((_) async {});
    when(
      () => audio.onAmplitudeChanged,
    ).thenAnswer((_) => const Stream.empty());
    home = HomeStore(
      journal,
      audio,
      JournalLifecycle(journal, process, search, MemoryEmbeddingModels()),
      search,
    );
    final app =
        AppStore(
            _Auth(),
            _Settings(),
            MemorySpeechModels(),
            MemoryEmbeddingModels(),
          )
          ..isInitialized = true
          ..hasCompletedOnboarding = true;
    drafts = MemoryEntryDrafts();
    keyboard = ValueNotifier(EdgeInsets.zero);
    features = ValueNotifier(const []);
    editCreations = 0;
    GetIt.I.registerSingleton<AppStore>(app);
    GetIt.I.registerSingleton<HomeStore>(home);
    GetIt.I.registerFactory<EntryDetailStore>(
      () => EntryDetailStore(journal, process, MemoryFormattingModels()),
    );
    GetIt.I.registerFactory<EntryEditStore>(() {
      editCreations++;
      return EntryEditStore(journal, drafts);
    });
    router = AppRouter();
  });

  tearDown(() async {
    router.dispose();
    home.dispose();
    keyboard.dispose();
    features.dispose();
    await GetIt.I.reset();
  });

  Future<void> resize(
    WidgetTester tester,
    double width, {
    double height = 800,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    if (home.isRecording) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> mount(
    WidgetTester tester, {
    double width = 1000,
    double scale = 1,
    String? initialEntry,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, width);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(
          deepLinkBuilder: initialEntry == null
              ? null
              : (_) => DeepLink([
                  HomeRoute(
                    children: [
                      const JournalEmptyRoute(),
                      EntryDetailRoute(entryId: initialEntry),
                    ],
                  ),
                ]),
        ),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => ValueListenableBuilder(
          valueListenable: keyboard,
          builder: (context, insets, _) => ValueListenableBuilder(
            valueListenable: features,
            builder: (context, folds, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: insets,
                displayFeatures: folds,
              ),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String id) async {
    await tester.tap(
      find.descendant(
        of: find.byType(TimelineItem),
        matching: find.text('Entry $id'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> edit(WidgetTester tester) async {
    final nested = router.innerRouterOf<StackRouter>(HomeRoute.name)!;
    unawaited(nested.push<void>(EntryEditRoute(entryId: '0')));
    await tester.pumpAndSettle();
  }

  testWidgets('wide starts private and selection survives folding and Back', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Select an entry'), findsOneWidget);
    expect(find.byType(EntryDetailScreen), findsNothing);
    await open(tester, '0');
    final detail = tester.state(find.byType(EntryDetailScreen));
    expect(find.byType(HomeScreen), findsOneWidget);
    await resize(tester, 390);
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.state(find.byType(EntryDetailScreen)), same(detail));
    await resize(tester, 700);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.state(find.byType(EntryDetailScreen)), same(detail));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Select an entry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing retains session, selection, and text through resize and expansion',
    (tester) async {
      await mount(tester);
      await open(tester, '0');
      await edit(tester);
      await tester.enterText(find.byType(TextFormField), 'Unsaved thoughts');
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.byType(TextField),
        ),
      );
      field.controller!.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 7,
      );
      final editor = tester.state(find.byType(EntryEditScreen));
      for (final width in [390.0, 700.0, 1200.0]) {
        await resize(tester, width);
        expect(tester.state(find.byType(EntryEditScreen)), same(editor));
        expect(field.controller!.text, 'Unsaved thoughts');
        expect(
          field.controller!.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7),
        );
      }
      await tester.tap(find.byTooltip('Expand editor'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);
      await tester.tap(find.byTooltip('Show journal alongside editor'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(editCreations, 1);
      expect(find.text('Resume draft?'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'switching notes asks before discarding edits and replaces detail',
    (tester) async {
      await mount(tester);
      await open(tester, '0');
      await edit(tester);
      await tester.enterText(find.byType(TextFormField), 'Keep this draft');
      await open(tester, '1');
      expect(find.text('Keep editing'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryEditScreen), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Keep this draft'),
        findsOneWidget,
      );
      await open(tester, '1');
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryEditScreen), findsNothing);
      expect(
        find.descendant(
          of: find.byType(EntryDetailScreen),
          matching: find.text('Entry 1'),
        ),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Select an entry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification selection uses the same dirty-editor confirmation',
    (tester) async {
      await mount(tester);
      await open(tester, '0');
      await edit(tester);
      await tester.enterText(find.byType(TextFormField), 'Private draft');
      unawaited(router.openJournalEntry('1'));
      await tester.pumpAndSettle();
      expect(find.text('Keep editing'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Private draft'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('save review can be cancelled before switching notes', (
    tester,
  ) async {
    await mount(tester);
    await open(tester, '0');
    await edit(tester);
    await tester.enterText(find.byType(TextFormField), 'Changed words');
    await open(tester, '1');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to editing'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Changed words'), findsOneWidget);
    verifyNever(() => journal.update(any(), expected: any(named: 'expected')));
    await open(tester, '1');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditScreen), findsNothing);
    expect(
      find.descendant(
        of: find.byType(EntryDetailScreen),
        matching: find.text('Entry 1'),
      ),
      findsOneWidget,
    );
    verify(
      () => journal.update(any(), expected: any(named: 'expected')),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search query and feed session survive a folded note round trip',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Thought');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final feed = tester.state(find.byType(HomeScreen));
      await open(tester, '0');
      await resize(tester, 390);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(HomeScreen)), same(feed));
      expect(home.searchQuery, 'Thought');
      expect(find.widgetWithText(TextField, 'Thought'), findsOneWidget);
      await resize(tester, 1000);
      expect(home.searchQuery, 'Thought');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('feed scroll position survives selecting and folding a note', (
    tester,
  ) async {
    await mount(tester);
    final list = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(list, const Offset(0, -700));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(list);
    final offset = scroll.position.pixels;
    expect(offset, greaterThan(0));
    unawaited(router.openJournalEntry('0'));
    await tester.pumpAndSettle();
    await resize(tester, 390);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(list), same(scroll));
    expect(scroll.position.pixels, offset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture is not restarted when unfolding', (tester) async {
    await mount(tester, width: 390);
    await tester.tap(find.byType(RecordFab));
    await tester.pump(const Duration(milliseconds: 250));
    expect(home.isRecording, isTrue);
    await resize(tester, 1000);
    await resize(tester, 390);
    expect(home.isRecording, isTrue);
    verify(() => audio.start()).called(1);
  });

  testWidgets(
    'capture is centered on phones and at the window end in split layout',
    (tester) async {
      await mount(tester, width: 390);
      expect(
        tester.getRect(find.byType(FloatingActionButton)).center.dx,
        closeTo(195, 1),
      );
      await resize(tester, 1000);
      final button = tester.getRect(find.byType(FloatingActionButton));
      expect(button.right, closeTo(984, 1));
      expect(
        button.left,
        greaterThan(tester.getRect(find.byType(HomeScreen)).right),
      );
      expect(button.bottom, closeTo(784, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recording covers and blocks both panes, with Stop still usable after folding',
    (tester) async {
      await mount(tester);
      await open(tester, '0');
      final detail = tester.state(find.byType(EntryDetailScreen));
      final initialButton = tester.getRect(find.byType(FloatingActionButton));
      when(() => audio.stop()).thenAnswer((_) async => null);
      await tester.tap(find.byType(RecordFab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(home.isRecording, isTrue);
      expect(
        tester.getRect(find.byKey(const ValueKey('recording-barrier'))),
        const Rect.fromLTWH(0, 0, 1000, 800),
      );
      expect(tester.getSize(find.byType(SoundWaveform)).width, 1000);
      final stop = tester.getRect(find.byType(FloatingActionButton));
      expect(stop.right, closeTo(initialButton.right, .01));
      expect(stop.bottom, closeTo(initialButton.bottom, .01));
      await tester.tap(find.byTooltip('Edit'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(EntryEditScreen), findsNothing);
      expect(tester.state(find.byType(EntryDetailScreen)), same(detail));
      await resize(tester, 390);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(RecordFab), findsOneWidget);
      expect(
        tester.getRect(find.byType(FloatingActionButton)).center.dx,
        closeTo(195, 1),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('recording-barrier'))),
        const Rect.fromLTWH(0, 0, 390, 800),
      );
      verify(() => audio.start()).called(1);
      await tester.tap(find.byType(RecordFab));
      await tester.pumpAndSettle();
      expect(home.isRecording, isFalse);
      expect(find.byKey(const ValueKey('recording-barrier')), findsNothing);
      verify(() => audio.stop()).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('capture stays above the keyboard without resizing panes twice', (
    tester,
  ) async {
    await mount(tester);
    await open(tester, '0');
    await edit(tester);
    keyboard.value = const EdgeInsets.only(bottom: 300);
    await tester.pumpAndSettle();
    final button = tester.getRect(find.byType(FloatingActionButton));
    expect(button.right, closeTo(984, 1));
    expect(button.bottom, lessThanOrEqualTo(484));
    // The panel owns keyboard avoidance. Its outer frame remains full height.
    expect(tester.getSize(find.byType(EntryEditScreen)).height, 800);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'capture stays inside a usable region while the scrim spans the hinge',
    (tester) async {
      await mount(tester);
      features.value = const [
        DisplayFeature(
          bounds: Rect.fromLTWH(480, 0, 40, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ];
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(FloatingActionButton)).left,
        greaterThanOrEqualTo(536),
      );
      features.value = const [
        DisplayFeature(
          bounds: Rect.fromLTWH(0, 650, 1000, 0),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ];
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(FloatingActionButton)).bottom,
        lessThanOrEqualTo(634),
      );
      await tester.tap(find.byType(RecordFab));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getRect(find.byKey(const ValueKey('recording-barrier'))),
        const Rect.fromLTWH(0, 0, 1000, 800),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cold nested entry navigation still has a journal to return to', (
    tester,
  ) async {
    await mount(tester, width: 390, initialEntry: '0');
    expect(find.byType(EntryDetailScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(EntryDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cold nested entry navigation cannot bypass app lock', (
    tester,
  ) async {
    GetIt.I<AppStore>().isLocked = true;
    await mount(tester, initialEntry: '0');
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(EntryDetailScreen), findsNothing);
    verifyNever(() => journal.getById(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard fallback preserves the focused live editor', (
    tester,
  ) async {
    await mount(tester);
    await open(tester, '0');
    await edit(tester);
    await tester.enterText(find.byType(TextFormField), 'Still editing');
    final editor = tester.state(find.byType(EntryEditScreen));
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField),
        matching: find.byType(TextField),
      ),
    );
    expect(field.focusNode!.hasFocus, isTrue);
    keyboard.value = const EdgeInsets.only(bottom: 500);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.state(find.byType(EntryEditScreen)), same(editor));
    expect(field.focusNode!.hasFocus, isTrue);
    keyboard.value = EdgeInsets.zero;
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(editCreations, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'posture changes respect a hinge without replacing the open note',
    (tester) async {
      await mount(tester);
      await open(tester, '0');
      final detail = tester.state(find.byType(EntryDetailScreen));
      features.value = const [
        DisplayFeature(
          bounds: Rect.fromLTWH(480, 0, 40, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ];
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(HomeScreen)).right, 480);
      expect(tester.getRect(find.byType(EntryDetailScreen)).left, 520);
      expect(tester.state(find.byType(EntryDetailScreen)), same(detail));
      features.value = const [];
      await resize(tester, 390);
      expect(tester.state(find.byType(EntryDetailScreen)), same(detail));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text and short windows use a single readable pane', (
    tester,
  ) async {
    await mount(tester, width: 700, scale: 1.5);
    expect(find.text('Select an entry'), findsNothing);
    await open(tester, '0');
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(EntryDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
