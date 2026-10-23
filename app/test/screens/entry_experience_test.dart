import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/entry_write_failure.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/services/i_recording_metadata.dart';
import 'package:smartnotes/domain/services/i_recording_playback.dart';
import 'package:smartnotes/domain/services/i_entry_draft_repository.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_screen.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart';
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_screen.dart';
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_store.dart';
import 'package:smartnotes/presentation/widgets/entry_content.dart';
import 'package:smartnotes/presentation/widgets/recording_player.dart';
import '../helpers/entry_experience_fakes.dart';
import '../helpers/local_services.dart';

class MockJournal extends Mock implements IJournalEntryService {}

class MockProcessing extends Mock implements ProcessAudioNoteUseCase {}

Widget app(Widget child, {bool dark = false, double scale = 1}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

void main() {
  late MockJournal journal;
  late MockProcessing processing;
  late MemoryEntryDrafts drafts;
  late EntryEditStore editor;
  late EntryDetailStore detail;
  late FakeRecordingPlayback player;
  late FakeRecordingMetadata metadata;
  final source = JournalEntry(
    id: 'entry',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    status: EntryStatus.completed,
    transcription: 'Original words',
    audioPath: '/isolated/recording.m4a',
  );

  setUpAll(() => registerFallbackValue(source));
  setUp(() {
    journal = MockJournal();
    when(() => journal.watchById('entry')).thenAnswer(
      (_) => const Stream.empty(),
    );
    processing = MockProcessing();
    drafts = MemoryEntryDrafts();
    editor = EntryEditStore(journal, drafts);
    detail = EntryDetailStore(journal, processing, MemoryFormattingModels());
    player = FakeRecordingPlayback();
    metadata = FakeRecordingMetadata();
    GetIt.I.registerFactory<EntryEditStore>(() => editor);
    GetIt.I.registerFactory<EntryDetailStore>(() => detail);
    GetIt.I.registerFactory<IRecordingPlayback>(() => player);
    GetIt.I.registerFactory<IRecordingMetadata>(() => metadata);
    when(() => journal.getById('entry')).thenAnswer((_) async => source);
  });
  tearDown(() async => GetIt.I.reset());

  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const EntryEditScreen(entryId: 'entry'),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editor is body first and dirty Back can keep, save, or discard',
    (tester) async {
      await openEditor(tester);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Correction');
      await tester.pump(const Duration(milliseconds: 500));
      expect(drafts.values['entry']!.body, 'Correction');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Save your changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Correction'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(drafts.values, isEmpty);
      verifyNever(
        () => journal.update(any(), expected: any(named: 'expected')),
      );
    },
  );

  testWidgets(
    'draft resume is explicit and preserves a stale expected source',
    (tester) async {
      drafts.values['entry'] = EntryEditDraft(
        source: source,
        title: '',
        subtitle: '',
        body: 'Unfinished correction',
        entryDate: source.effectiveEntryDate,
      );
      final latest = source.copyWith(
        formattedNote: 'Newer entry',
        updatedAt: DateTime(2026, 2),
      );
      when(() => journal.getById('entry')).thenAnswer((_) async => latest);
      await openEditor(tester);
      expect(find.text('Resume your edits?'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Resume edits'));
      await tester.pumpAndSettle();
      expect(editor.entry, source);
      expect(editor.writeFailure, EntryWriteFailureKind.changed);
      expect(find.text('Unfinished correction'), findsOneWidget);
      expect(find.text('Copy edits'), findsOneWidget);
      expect(find.text('Compare saved entry'), findsOneWidget);
    },
  );

  testWidgets('unreadable recovery draft blocks overwriting it', (
    tester,
  ) async {
    drafts.fail = true;
    await openEditor(tester);
    expect(
      find.textContaining('Could not load your editing draft'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('background flushes edits and successful save clears the draft', (
    tester,
  ) async {
    when(() => journal.update(any(), expected: source)).thenAnswer(
      (invocation) async =>
          (invocation.positionalArguments.first as JournalEntry).copyWith(
            updatedAt: DateTime(2026, 2),
          ),
    );
    await openEditor(tester);
    await tester.enterText(find.byType(TextFormField), 'My words');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(drafts.values['entry']!.body, 'My words');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(drafts.values, isEmpty);
    expect(find.text('Open'), findsOneWidget);
    expect(editor.entry!.transcription, source.transcription);
    expect(editor.entry!.audioPath, source.audioPath);
  });

  testWidgets('Back on draft recovery keeps the persisted draft', (
    tester,
  ) async {
    drafts.values['entry'] = EntryEditDraft(
      source: source,
      title: '',
      subtitle: '',
      body: 'Keep this draft',
      entryDate: source.effectiveEntryDate,
    );
    await openEditor(tester);
    expect(find.text('Resume your edits?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(drafts.values['entry']!.body, 'Keep this draft');
  });

  testWidgets(
    'AI acceptance cannot be dismissed mid-save and Undo is explicit',
    (tester) async {
      final proposal = source.copyWith(formattedNote: 'AI proposal');
      final save = Completer<JournalEntry>();
      when(
        () => processing.applyAiAction(source, AiAction.organizedNote),
      ).thenAnswer((_) async => proposal);
      when(
        () =>
            processing.acceptAiDraft(source, proposal, replaceMetadata: false),
      ).thenAnswer((_) => save.future);
      when(
        () => journal.update(any(), expected: proposal),
      ).thenAnswer((_) async => source);
      await tester.pumpWidget(app(const EntryDetailScreen(entryId: 'entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Preview AI changes'), findsOneWidget);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.enableDrag, false);
      expect(sheet.showDragHandle, false);
      expect(detail.isSaving, true);
      save.complete(proposal);
      await tester.pumpAndSettle();
      expect(find.text('Changes applied'), findsOneWidget);
      expect(detail.entry, proposal);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(detail.entry, source);
      expect(find.text('Previous note restored'), findsOneWidget);
    },
  );

  testWidgets(
    'reading flow has no embedded player and playback opens on demand',
    (tester) async {
      await tester.pumpWidget(app(const EntryDetailScreen(entryId: 'entry')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SliverAppBar>(find.byType(SliverAppBar)).title,
        isNull,
      );
      expect(find.text('Entry'), findsNothing);
      expect(find.byType(RecordingPlayer), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(
        find.ancestor(
          of: find.byType(EntryContent),
          matching: find.byType(Card),
        ),
        findsNothing,
      );
      expect(find.text('Original · 1:34'), findsOneWidget);
      expect(find.text('Original transcription'), findsNothing);
      final listen = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      final states = <WidgetState>{};
      expect(
        listen.style!.side!.resolve(states)!.color,
        AppTheme.light.colorScheme.outline,
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      expect(icon.color, AppTheme.light.colorScheme.primary);
      expect(
        (listen.style!.shape!.resolve(states) as RoundedRectangleBorder)
            .borderRadius,
        const BorderRadius.all(AppTheme.plateRadius),
      );

      await tester.tap(find.text('Original · 1:34'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(RecordingPlayer), findsOneWidget);
      expect(find.text('Original recording'), findsOneWidget);
      expect(find.byTooltip('Play recording'), findsOneWidget);
      expect(player.playCalls, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RecordingPlayer), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Original transcription'), findsOneWidget);
      await tester.tap(find.text('Original transcription'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Original words'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets('original transcription is omitted when unavailable', (
    tester,
  ) async {
    when(() => journal.getById('entry')).thenAnswer(
      (_) async =>
          source.copyWith(transcription: null, formattedNote: 'Saved note'),
    );
    await tester.pumpWidget(app(const EntryDetailScreen(entryId: 'entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Original transcription'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets(
    'header action and player sheet support both themes and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          app(const EntryDetailScreen(entryId: 'entry'), dark: dark, scale: 2),
        );
        await tester.pumpAndSettle();
        expect(find.text('Original · 1:34'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Original · 1:34'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byType(RecordingPlayer), findsOneWidget);
        expect(find.byTooltip('Play recording'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Original transcription'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('pending save blocks duplicate actions and Back', (tester) async {
    final result = Completer<JournalEntry>();
    when(
      () => journal.update(any(), expected: source),
    ).thenAnswer((_) => result.future);
    await openEditor(tester);
    await tester.enterText(find.byType(TextFormField), 'Correction');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    expect(
      tester
          .widget<PopScope>(
            find.byWidgetPredicate((widget) => widget is PopScope).last,
          )
          .canPop,
      false,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Processing'))
          .onPressed,
      isNull,
    );
    result.complete(source.copyWith(formattedNote: 'Correction'));
    await tester.pumpAndSettle();
    verify(() => journal.update(any(), expected: source)).called(1);
  });

  testWidgets(
    'literal transcription and preview share bounded readable typography',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const EntryDetailScreen(entryId: 'entry')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(EntryContent)).width,
        lessThanOrEqualTo(640),
      );
      expect(find.byType(MarkdownBody), findsNothing);
      expect(find.byTooltip('Edit'), findsOneWidget);
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: EntryContent(text: '# Heading\n\nBody', markdown: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(
        markdown.styleSheet!.h1!.fontSize,
        AppTheme.light.textTheme.titleLarge!.fontSize,
      );
    },
  );

  testWidgets('empty edited note never reveals original as current content', (
    tester,
  ) async {
    when(
      () => journal.getById('entry'),
    ).thenAnswer((_) async => source.copyWith(formattedNote: ''));
    await tester.pumpWidget(app(const EntryDetailScreen(entryId: 'entry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('This note is empty'), findsOneWidget);
    expect(find.text('Original words'), findsNothing);
    expect(find.text('Original transcription'), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Original transcription'), findsOneWidget);
    expect(find.byIcon(Icons.auto_fix_high), findsNothing);
  });

  testWidgets(
    'player never autoplays, seeks, stops on background, and closes',
    (tester) async {
      await tester.pumpWidget(
        app(const Scaffold(body: RecordingPlayer(path: '/isolated/file.m4a'))),
      );
      await tester.pumpAndSettle();
      expect(player.playCalls, 0);
      await tester.tap(find.byTooltip('Play recording'));
      await tester.pump();
      expect(player.playCalls, 1);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChangeEnd!(28000);
      await tester.pump();
      expect(player.position, const Duration(seconds: 28));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(player.stopCalls, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(player.playCalls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(player.closed, true);
    },
  );

  testWidgets(
    'missing recording preserves failed-entry text without futile retry',
    (tester) async {
      player.missing = true;
      when(
        () => journal.getById('entry'),
      ).thenAnswer((_) async => source.copyWith(status: EntryStatus.error));
      await tester.pumpWidget(app(const EntryDetailScreen(entryId: 'entry')));
      await tester.pumpAndSettle();
      expect(find.text('Original words'), findsOneWidget);
      expect(find.byIcon(Icons.replay), findsNothing);
      await tester.tap(find.text('Original · 1:34'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Original recording is unavailable'),
        findsOneWidget,
      );
      expect(find.byTooltip('Play recording'), findsNothing);
    },
  );

  testWidgets('playback error is contained in the sheet and retry recovers', (
    tester,
  ) async {
    player.failuresRemaining = 1;
    await tester.pumpWidget(app(const EntryDetailScreen(entryId: 'entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Original · 1:34'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not play this recording'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Play recording'), findsOneWidget);
    expect(find.byTooltip('Pause recording'), findsNothing);
    expect(player.playCalls, 0);
  });

  testWidgets('overflow menu is disabled during a busy operation', (
    tester,
  ) async {
    await tester.pumpWidget(app(const EntryDetailScreen(entryId: 'entry')));
    await tester.pumpAndSettle();
    detail.isSaving = true;
    await tester.pump();
    final menu = tester.widget<PopupMenuButton<dynamic>>(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton<dynamic>),
    );
    expect(menu.enabled, false);
  });

  testWidgets(
    'preview compares exact source and hides optional proposed metadata',
    (tester) async {
      final proposal = source.copyWith(
        title: 'Proposed metadata title',
        subTitle: 'Proposed subtitle',
        formattedNote: '# Organized words',
      );
      when(
        () => processing.applyAiAction(source, AiAction.organizedNote),
      ).thenAnswer((_) async => proposal);
      await tester.pumpWidget(app(const EntryDetailScreen(entryId: 'entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      expect(find.text('Proposed metadata title'), findsNothing);
      expect(find.text('Organized words'), findsOneWidget);
      await tester.tap(find.text('Saved entry'));
      await tester.pumpAndSettle();
      expect(find.text('Organized words'), findsNothing);
      expect(find.text('Original words'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(find.text('Proposed metadata title'), findsOneWidget);
      expect(detail.entry, source);
    },
  );

  testWidgets('entry date picker stays responsive throughout its transition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        const EntryEditScreen(entryId: 'entry'),
        scale: 323.99996076311385 / 360,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entry date'));
    // Android's non-linear font scaling produced this exact fractional page
    // width in the failing app. Inspect every frame, not just the settled UI.
    for (var frame = 0; frame < 400; frame++) {
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull, reason: 'Transition frame $frame');
    }
    expect(find.byType(DatePickerDialog), findsOneWidget);
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.firstDate, DateTime(1900));
    expect(picker.lastDate, DateTime(2200));
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(CalendarDatePicker)),
      ).scale(14),
      closeTo(14 * 323.99996076311385 / 360, 0.000001),
    );
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to calendar'));
    for (var frame = 0; frame < 400; frame++) {
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull, reason: 'Return frame $frame');
    }
    await tester.tap(find.text('2'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Save note'), findsOneWidget);
    expect(editor.selectedEntryDate?.day, 2);
  });

  testWidgets('compact dark reading and editing support 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(const EntryDetailScreen(entryId: 'entry'), dark: true, scale: 2),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      app(const EntryEditScreen(entryId: 'entry'), dark: true, scale: 2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    expect(tester.takeException(), isNull);
  });
}
