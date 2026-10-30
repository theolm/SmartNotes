import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/processing_feedback.dart';
import 'package:smartnotes/presentation/screens/home/widgets/timeline_item.dart';

void main() {
  for (final phase in [
    ProcessingPhase.preparingFormatting,
    ProcessingPhase.formatting,
  ]) {
    testWidgets('shows ${phase.name} on a completed, readable note', (
      tester,
    ) async {
      final now = DateTime(2026, 10, 29);
      final entry = JournalEntry(
        id: 'formatting',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        transcription: 'Saved words remain readable.',
      );
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TimelineItem(
              entry: entry,
              feedback: ProcessingFeedback(
                entryId: entry.id,
                phase: phase,
                modelName: 'Qwen3 1.7B Q4_K_M',
              ),
              onOpen: () => opened = true,
            ),
          ),
        ),
      );
      expect(
        find.text(
          phase == ProcessingPhase.formatting
              ? 'Formatting note…'
              : 'Preparing AI formatting…',
        ),
        findsOneWidget,
      );
      expect(find.text('Saved words remain readable.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Saved words remain readable.'));
      expect(opened, true);
    });
  }

  testWidgets('shows that the note is ready while search is prepared', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 20, 9, 30);
    final entry = JournalEntry(
      id: 'entry-1',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      transcription: 'Saved words remain readable.',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TimelineItem(
            entry: entry,
            feedback: const ProcessingFeedback(
              entryId: 'entry-1',
              phase: ProcessingPhase.preparingSearch,
              modelName: 'Qwen3 Embedding 0.6B Q8',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Note ready · Preparing for search…'), findsOneWidget);
    expect(find.text('Saved words remain readable.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders formatted note Markdown in the timeline preview', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 20, 9, 30);
    final entry = JournalEntry(
      id: 'entry-markdown',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      formattedNote: '**Important**\n\n- Keep the Markdown readable.',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TimelineItem(entry: entry)),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Important\n\n• Keep the Markdown readable.',
      ),
      findsOneWidget,
    );
    expect(find.text('**Important**'), findsNothing);
  });

  testWidgets(
    'uses the note body instead of subtitle in the timeline preview',
    (
      tester,
    ) async {
      final now = DateTime(2026, 10, 20, 9, 30);
      final entry = JournalEntry(
        id: 'entry-subtitle',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        transcription: 'The current note body.',
        title: 'Conversation',
        subTitle: 'Plans for tomorrow.',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TimelineItem(entry: entry)),
        ),
      );

      expect(find.text('Conversation'), findsOneWidget);
      expect(find.text('Plans for tomorrow.'), findsNothing);
      expect(find.text('The current note body.'), findsOneWidget);
    },
  );
}
