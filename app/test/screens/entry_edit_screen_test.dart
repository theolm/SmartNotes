import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_screen.dart';
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_store.dart';

import '../helpers/nav_bar_inset.dart';

class MockJournalEntryService extends Mock implements IJournalEntryService {}

class _TestableEntryEditScreen extends StatelessWidget {
  const _TestableEntryEditScreen({required this.store, required this.entryId});

  final EntryEditStore store;
  final String entryId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewPadding: const EdgeInsets.only(bottom: kNavBarInset),
          ),
          child: EntryEditScreen(entryId: entryId),
        ),
      ),
    );
  }
}

void main() {
  late MockJournalEntryService mockService;
  late EntryEditStore store;

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
    store = EntryEditStore(mockService);
    GetIt.I.registerFactory<EntryEditStore>(() => store);
  });

  tearDown(() {
    GetIt.I.reset();
  });

  testWidgets('shows loading state initially', (tester) async {
    when(() => mockService.getById(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      _TestableEntryEditScreen(store: store, entryId: '1'),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows form fields when entry is loaded', (tester) async {
    final entry = JournalEntry(
      id: '1',
      createdAt: DateTime(2026, 7, 1, 10, 30),
      updatedAt: DateTime(2026, 7, 1, 10, 30),
      entryDate: DateTime(2026, 7, 1, 10, 30),
      status: EntryStatus.completed,
      title: 'Test Note',
      subTitle: 'Subtitle text',
      formattedNote: '# Hello\n\nWorld',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);

    await tester.pumpWidget(
      _TestableEntryEditScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Supports Markdown'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Test Note'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Subtitle text'), findsOneWidget);
    expect(find.text('July 1, 2026 10:30'), findsOneWidget);
  });

  for (final width in [390.0, 900.0]) {
    testWidgets('metadata review retains edits after dismissal at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entry = JournalEntry(
        id: '1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        status: EntryStatus.completed,
        title: 'Old title',
        transcription: 'Original words',
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      await tester.pumpWidget(
        _TestableEntryEditScreen(store: store, entryId: '1'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Edited words');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        width < 600 ? find.byType(BottomSheet) : find.byType(Dialog),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Old title'),
        'New title',
      );
      await tester.tap(find.text('Back to editing'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Edited words'),
        findsOneWidget,
      );
      verifyNever(
        () => mockService.update(any(), expected: any(named: 'expected')),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'New title'), findsOneWidget);
      await tester.tap(find.text('Back to editing'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('formatting help explains Markdown without changing the note', (
    tester,
  ) async {
    final entry = JournalEntry(
      id: '1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      status: EntryStatus.completed,
      transcription: 'Original words',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);
    await tester.pumpWidget(
      _TestableEntryEditScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Formatting help'));
    await tester.pumpAndSettle();
    expect(find.textContaining('**Bold**'), findsOneWidget);
    await tester.tap(find.text('Back to editing'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'Original words'),
      findsOneWidget,
    );
  });

  testWidgets('Markdown help is a quiet footer inside the focused editor', (
    tester,
  ) async {
    final entry = JournalEntry(
      id: '1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      status: EntryStatus.completed,
      transcription: 'Original words',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);
    await tester.pumpWidget(
      _TestableEntryEditScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('note-editor'));
    final help = find.byTooltip('Formatting help');
    final hint = find.text('Supports Markdown');
    expect(find.descendant(of: editor, matching: help), findsOneWidget);
    expect(find.descendant(of: editor, matching: hint), findsOneWidget);
    expect(
      tester.getTopLeft(hint).dy,
      greaterThan(tester.getBottomLeft(find.byType(EditableText)).dy),
    );
    final helpButton = find.ancestor(of: help, matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(helpButton).iconSize, 18);
    expect(tester.getSize(helpButton).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(helpButton).height, greaterThanOrEqualTo(48));
    final theme = Theme.of(tester.element(editor));
    final hintStyle = tester.widget<Text>(hint).style!;
    expect(hintStyle.fontSize, theme.textTheme.bodySmall!.fontSize);
    expect(hintStyle.color, theme.colorScheme.onSurfaceVariant);
    expect(tester.widget<InputDecorator>(editor).isFocused, isFalse);
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(tester.widget<InputDecorator>(editor).isFocused, isTrue);
  });

  testWidgets('transcript-only entry initializes the note editor', (
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
    await tester.pumpWidget(
      _TestableEntryEditScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'Original words'),
      findsOneWidget,
    );
  });

  testWidgets('pads the edit form clear of the navigation bar inset', (
    tester,
  ) async {
    final entry = JournalEntry(
      id: '1',
      createdAt: DateTime(2026, 7, 1, 10, 30),
      updatedAt: DateTime(2026, 7, 1, 10, 30),
      status: EntryStatus.completed,
      title: 'Test Note',
      formattedNote: '# Hello',
    );
    when(() => mockService.getById('1')).thenAnswer((_) async => entry);

    await tester.pumpWidget(
      _TestableEntryEditScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );

    expect(
      scrollView.padding,
      const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + kNavBarInset,
      ),
    );
  });

  testWidgets('saves updated title, subtitle, date and note', (tester) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: '1',
      createdAt: now,
      updatedAt: now,
      entryDate: now,
      status: EntryStatus.completed,
      title: 'Old title',
      subTitle: 'Old subtitle',
      formattedNote: 'old note',
    );
    final newDate = DateTime(2025, 5, 10, 9, 0);

    when(() => mockService.getById('1')).thenAnswer((_) async => entry);
    when(() => mockService.update(any(), expected: entry)).thenAnswer(
      (invocation) {
        final updated = invocation.positionalArguments.first as JournalEntry;
        return Future.value(updated);
      },
    );

    await tester.pumpWidget(
      _TestableEntryEditScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'old note'),
      'new note',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextFormField, 'Old title'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Old title'),
      'New title',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Old subtitle'),
      'New subtitle',
    );
    store.selectEntryDate(newDate);
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => mockService.update(captureAny(), expected: entry),
            ).captured.single
            as JournalEntry;
    expect(captured.title, 'New title');
    expect(captured.subTitle, 'New subtitle');
    expect(captured.formattedNote, 'new note');
    expect(captured.entryDate, newDate);
  });

  testWidgets('failed snapshot save keeps unsaved edits visible', (
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
      () => mockService.update(any(), expected: entry),
    ).thenThrow(StateError('Changed'));
    await tester.pumpWidget(
      _TestableEntryEditScreen(store: store, entryId: '1'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Original words'),
      'My unsaved edits',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'My unsaved edits'),
      findsOneWidget,
    );
    expect(find.textContaining('Your draft is still here'), findsOneWidget);
    expect(store.entry!.transcription, 'Original words');
  });
}
