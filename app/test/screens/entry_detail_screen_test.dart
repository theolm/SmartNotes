import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_screen.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';

import '../helpers/nav_bar_inset.dart';
import '../helpers/local_services.dart';
import '../helpers/entry_experience_fakes.dart';
import 'package:smartnotes/domain/services/i_recording_metadata.dart';
import 'package:smartnotes/domain/services/i_recording_playback.dart';

class MockJournalEntryService extends Mock implements IJournalEntryService {}

class MockProcessAudioNoteUseCase extends Mock
    implements ProcessAudioNoteUseCase {}

class MockRouter extends Mock implements StackRouter {}

class _TestableEntryDetailScreen extends StatelessWidget {
  const _TestableEntryDetailScreen({
    required this.store,
    required this.entryId,
    this.router,
  });

  final EntryDetailStore store;
  final String entryId;
  final StackRouter? router;

  @override
  Widget build(BuildContext context) {
    final screen = withNavBarInset(EntryDetailScreen(entryId: entryId));
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: router == null
          ? screen
          : StackRouterScope(
              controller: router!,
              stateHash: 0,
              child: screen,
            ),
    );
  }
}

void main() {
  late MockJournalEntryService mockService;
  late MockProcessAudioNoteUseCase mockUseCase;
  late MemoryFormattingModels formatting;
  late EntryDetailStore store;

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
    mockService = MockJournalEntryService();
    when(() => mockService.watchById('1')).thenAnswer(
      (_) => const Stream.empty(),
    );
    mockUseCase = MockProcessAudioNoteUseCase();
    formatting = MemoryFormattingModels();
    store = EntryDetailStore(
      mockService,
      mockUseCase,
      formatting,
    );
    GetIt.I.registerFactory<EntryDetailStore>(() => store);
    GetIt.I.registerFactory<IRecordingPlayback>(() => FakeRecordingPlayback());
    GetIt.I.registerFactory<IRecordingMetadata>(() => FakeRecordingMetadata());
  });

  tearDown(() {
    GetIt.I.reset();
  });

  testWidgets('shows loading state initially', (tester) async {
    when(() => mockService.getById(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      _TestableEntryDetailScreen(store: store, entryId: '1'),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows markdown when entry is loaded', (tester) async {
    final entry = JournalEntry(
      id: '1',
      createdAt: DateTime(2026, 7, 1, 10, 30),
      updatedAt: DateTime(2026, 7, 1, 10, 30),
      status: EntryStatus.completed,
      title: 'Test Note',
      formattedNote: '# Hello\n\nWorld',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);

    await tester.pumpWidget(
      _TestableEntryDetailScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('July 1, 2026 10:30'), findsAtLeastNWidgets(1));
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
  });

  testWidgets(
    'untouched transcription is shown literally rather than as Markdown',
    (tester) async {
      final now = DateTime(2026);
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        transcription: '# Original *words*',
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      await tester.pumpWidget(
        _TestableEntryDetailScreen(store: store, entryId: '1'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownBody), findsNothing);
      expect(find.text('# Original *words*'), findsOneWidget);
    },
  );

  testWidgets('discarding a preview keeps the saved content unchanged', (
    tester,
  ) async {
    final now = DateTime(2026);
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      transcription: 'Original words',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);
    when(
      () => mockUseCase.applyAiAction(entry, AiAction.organizedNote),
    ).thenAnswer((_) async => entry.copyWith(formattedNote: 'Draft words'));
    await tester.pumpWidget(
      _TestableEntryDetailScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(store.entry, entry);
    expect(store.aiDraft, isNull);
    verifyNever(
      () => mockService.update(any(), expected: any(named: 'expected')),
    );
  });

  testWidgets(
    'note stays readable during generation and leaving ignores its result',
    (tester) async {
      final now = DateTime(2026);
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        transcription: 'Original words',
      );
      final response = Completer<JournalEntry>();
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      when(
        () => mockUseCase.applyAiAction(entry, AiAction.organizedNote),
      ).thenAnswer((_) => response.future);
      await tester.pumpWidget(
        _TestableEntryDetailScreen(store: store, entryId: '1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organize'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Original words'), findsOneWidget);
      expect(tester.widget<PopScope>(find.byType(PopScope).first).canPop, true);
      await tester.pumpWidget(const SizedBox());
      response.complete(entry.copyWith(formattedNote: 'Late draft'));
      await tester.pumpAndSettle();
      expect(store.aiDraft, isNull);
      expect(store.entry, entry);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wand opens the sheet before a slow model check completes', (
    tester,
  ) async {
    formatting.isReadyGate = Completer<bool>();
    final now = DateTime(2026);
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      transcription: 'Original words',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);
    await tester.pumpWidget(
      _TestableEntryDetailScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Preparing the offline model…'), findsOneWidget);
    expect(find.text('Organize'), findsNothing);
    expect(store.entry, entry);
    formatting.isReadyGate!.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Preparing the offline model…'), findsNothing);
    expect(find.text('Organize'), findsOneWidget);
  });

  testWidgets(
    'missing formatting model offers the settings path instead of changing the note',
    (tester) async {
      formatting.ready = false;
      final now = DateTime(2026);
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        transcription: 'Original words',
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      await tester.pumpWidget(
        _TestableEntryDetailScreen(store: store, entryId: '1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();
      expect(find.text('Formatting model needed'), findsOneWidget);
      expect(find.text('Go to settings'), findsOneWidget);
      expect(find.text('Organized note'), findsNothing);
      expect(store.entry, entry);
      verifyNever(
        () => mockUseCase.applyAiAction(
          any(),
          AiAction.organizedNote,
        ),
      );
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(store.entry!.status, EntryStatus.completed);
    },
  );

  testWidgets(
    'go to settings opens the formatting model screen without running an action',
    (tester) async {
      formatting.ready = false;
      final router = MockRouter();
      when(
        () => router.push<Object?>(const FormattingModelsRoute()),
      ).thenAnswer((_) async => null);
      final now = DateTime(2026);
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        transcription: 'Original words',
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      await tester.pumpWidget(
        _TestableEntryDetailScreen(
          store: store,
          entryId: '1',
          router: router,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to settings'));
      await tester.pumpAndSettle();
      verify(
        () => router.push<Object?>(const FormattingModelsRoute()),
      ).called(1);
      expect(find.text('Organized note'), findsNothing);
      verifyNever(
        () => mockUseCase.applyAiAction(any(), AiAction.organizedNote),
      );
    },
  );

  testWidgets(
    'a formatting model that disappears during an action shows the settings path',
    (tester) async {
      final now = DateTime(2026);
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        transcription: 'Original words',
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      when(
        () => mockUseCase.applyAiAction(entry, AiAction.organizedNote),
      ).thenAnswer((_) async {
        formatting.ready = false;
        throw const AiFailure(AiFailureCode.formattingModelMissing);
      });
      await tester.pumpWidget(
        _TestableEntryDetailScreen(store: store, entryId: '1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      expect(find.text('Formatting model needed'), findsOneWidget);
      expect(find.text('Go to settings'), findsOneWidget);
      expect(store.entry, entry);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('pads markdown clear of the navigation bar inset', (
    tester,
  ) async {
    final entry = JournalEntry(
      id: '1',
      createdAt: DateTime(2026, 7, 1, 10, 30),
      updatedAt: DateTime(2026, 7, 1, 10, 30),
      status: EntryStatus.completed,
      title: 'Test Note',
      formattedNote: '# Hello\n\nWorld',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);

    await tester.pumpWidget(
      _TestableEntryDetailScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();

    final padding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byType(MarkdownBody),
            matching: find.byType(Padding),
          )
          .first,
    );

    expect(
      padding.padding,
      const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + kNavBarInset,
      ),
    );
  });

  testWidgets('exposes direct edit and removes nonfunctional share', (
    tester,
  ) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      entryDate: now,
      status: EntryStatus.completed,
      title: 'Test',
      formattedNote: 'old',
    );

    when(() => mockService.getById('1')).thenAnswer((_) async => entry);

    await tester.pumpWidget(
      _TestableEntryDetailScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Reformat'), findsNothing);
  });

  testWidgets(
    'shows AI action menu for completed entries with a transcription',
    (
      tester,
    ) async {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        title: 'Test',
        formattedNote: '# Existing note',
        transcription: 'Original recording text',
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);

      await tester.pumpWidget(
        _TestableEntryDetailScreen(store: store, entryId: '1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();

      expect(find.text('Organize with AI'), findsOneWidget);
      expect(find.text('Organize'), findsOneWidget);
      expect(find.text('Journal style'), findsOneWidget);
      expect(find.text('Key points'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Clean up wording'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('Formal summary'), findsNothing);
      expect(find.text('Casual recap'), findsNothing);
      expect(find.text('Clean up wording'), findsOneWidget);
    },
  );

  testWidgets(
    'previews the selected action and applies only after confirmation',
    (
      tester,
    ) async {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        title: 'Before',
        formattedNote: '# Before',
        transcription: 'Original recording text',
      );
      final updated = entry.copyWith(
        title: 'Updated title',
        subTitle: 'Updated subtitle',
        formattedNote: '# Updated title\n\nUpdated note',
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      when(
        () => mockUseCase.applyAiAction(entry, AiAction.organizedNote),
      ).thenAnswer((_) async => updated);
      when(
        () => mockUseCase.acceptAiDraft(entry, updated, replaceMetadata: false),
      ).thenAnswer((_) async => updated);

      await tester.pumpWidget(
        _TestableEntryDetailScreen(store: store, entryId: '1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();

      expect(find.text('Updated title'), findsAtLeastNWidgets(1));
      expect(find.text('Updated note'), findsOneWidget);
      expect(store.entry, entry);
      expect(find.text('Preview AI changes'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(store.entry, updated);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.persist, false);
      expect(snackBar.duration, const Duration(seconds: 8));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      verify(
        () => mockUseCase.applyAiAction(entry, AiAction.organizedNote),
      ).called(1);
    },
  );

  testWidgets('keeps the note and shows retry dialog when an AI action fails', (
    tester,
  ) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      title: 'Before',
      formattedNote: '# Before\n\nExisting note',
      transcription: 'Original recording text',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);
    when(
      () => mockUseCase.applyAiAction(entry, AiAction.organizedNote),
    ).thenThrow(Exception('backend failed'));

    await tester.pumpWidget(
      _TestableEntryDetailScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organize'));
    await tester.pumpAndSettle();

    expect(find.text('Could not transform note'), findsOneWidget);
    expect(
      find.text(
        'AI processing could not complete. Please retry. Your saved content is unchanged.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Existing note'), findsOneWidget);
  });

  testWidgets(
    'AI actions can organize the current body without a transcription',
    (tester) async {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        formattedNote: '# Existing note',
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);

      await tester.pumpWidget(
        _TestableEntryDetailScreen(store: store, entryId: '1'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
    },
  );

  testWidgets('shows retry button for error entries with a recording', (
    tester,
  ) async {
    final now = DateTime.now();
    GetIt.I.unregister<IRecordingMetadata>();
    GetIt.I.registerFactory<IRecordingMetadata>(
      () => FakeRecordingMetadata()..available = true,
    );
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      entryDate: now,
      status: EntryStatus.error,
      audioPath: '/isolated/recording.m4a',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);

    await tester.pumpWidget(
      _TestableEntryDetailScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.replay), findsOneWidget);
  });

  testWidgets('preview supports compact dark layout with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026);
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      transcription: 'Original words',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);
    when(
      () => mockUseCase.applyAiAction(entry, AiAction.organizedNote),
    ).thenAnswer(
      (_) async => entry.copyWith(
        title: 'A personal journal entry',
        subTitle: 'Thoughts from today',
        formattedNote: '# Organized\n\nA new paragraph.',
      ),
    );
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
        home: const EntryDetailScreen(entryId: '1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organize'));
    await tester.pumpAndSettle();
    expect(find.text('Apply').hitTestable(), findsOneWidget);
    expect(find.text('Discard').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final typed in [false, true]) {
    testWidgets(
      'original restoration asks for confirmation before replacing edits (typed: $typed)',
      (tester) async {
        final now = DateTime(2026);
        final entry = JournalEntry(
          id: '1',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.completed,
          title: 'My title',
          transcription: 'Original words',
          formattedNote: 'Edited words',
          audioPath: typed ? null : '/isolated/recording.m4a',
        );
        when(() => mockService.getById('1')).thenAnswer((_) async => entry);
        when(
          () => mockUseCase.restoreTranscription(entry),
        ).thenAnswer((_) async => entry.copyWith(formattedNote: null));
        await tester.pumpWidget(
          _TestableEntryDetailScreen(store: store, entryId: '1'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(typed ? 'Original text' : 'Original transcription'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Original words'), findsOneWidget);
        final restoreLabel = typed
            ? 'Restore original text'
            : 'Restore original transcription';
        await tester.tap(find.text(restoreLabel));
        await tester.pumpAndSettle();
        verifyNever(() => mockUseCase.restoreTranscription(any()));
        await tester.tap(
          find.widgetWithText(FilledButton, restoreLabel),
        );
        await tester.pumpAndSettle();
        expect(store.entry!.body, 'Original words');
        expect(store.entry!.title, 'My title');
      },
    );
  }

  testWidgets('hides retry/reformat when processing', (tester) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      entryDate: now,
      status: EntryStatus.error,
      audioPath: '/audio/test.m4a',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);

    store.isProcessing = true;

    await tester.pumpWidget(
      _TestableEntryDetailScreen(store: store, entryId: '1'),
    );
    await tester.pump();

    expect(find.byIcon(Icons.replay), findsNothing);
  });
}
