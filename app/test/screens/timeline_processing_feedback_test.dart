import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/processing_feedback.dart';
import 'package:smartnotes/presentation/screens/home/widgets/timeline_item.dart';

void main() {
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

  testWidgets('uses subtitle before the note body in the timeline preview', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 20, 9, 30);
    final entry = JournalEntry(
      id: 'entry-subtitle',
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
      transcription: 'The body should not be shown here.',
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
    expect(find.text('Plans for tomorrow.'), findsOneWidget);
    expect(find.text('The body should not be shown here.'), findsNothing);
  });
}
