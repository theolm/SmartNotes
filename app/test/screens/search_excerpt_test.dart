import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/search_result.dart';
import 'package:smartnotes/presentation/screens/home/widgets/search_excerpt.dart';

void main() {
  final date = DateTime(2026);
  final entry = JournalEntry(
    id: 'entry',
    createdAt: date,
    updatedAt: date,
    status: EntryStatus.completed,
    formattedNote: 'Current words',
    transcription: 'Original memory',
  );

  Widget app(
    SearchResult result, {
    JournalEntry? current,
    VoidCallback? onTap,
  }) => MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: InkWell(
          onTap: onTap,
          child: SearchExcerpt(result: result, current: current ?? entry),
        ),
      ),
    ),
  );

  testWidgets(
    'text highlights are styled spans with a visible original-source label',
    (tester) async {
      await tester.pumpWidget(
        app(
          SearchResult(
            entry: entry,
            excerpt:
                'Remember ${SearchResult.matchStart}Júlia${SearchResult.matchEnd} at the café.',
            sources: {SearchSource.original},
            score: -1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Original transcription'), findsOneWidget);
      expect(
        find.text('Remember Júlia at the café.', findRichText: true),
        findsOneWidget,
      );
      final text = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      );
      final spans = (text.textSpan as TextSpan).children!.cast<TextSpan>();
      expect(
        spans.singleWhere((s) => s.text == 'Júlia').style!.fontWeight,
        FontWeight.w700,
      );
      expect(
        find.textContaining(SearchResult.matchStart, findRichText: true),
        findsNothing,
      );
    },
  );

  testWidgets(
    'semantic evidence expands without opening the entry and survives large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var opened = 0;
      await tester.pumpWidget(
        app(
          SearchResult(
            entry: entry,
            excerpt: 'A related passage. ' * 60,
            sources: {SearchSource.original},
            score: 0.3,
            byMeaning: true,
          ),
          onTap: () => opened++,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Related by meaning · Original transcription'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Show matching passage'));
      await tester.tap(find.text('Show matching passage'));
      await tester.pumpAndSettle();
      expect(opened, 0);
      final text = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      );
      expect(text.maxLines, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an edited entry never presents stale evidence as current text', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SearchResult(
          entry: entry,
          excerpt: 'Old private words',
          sources: {SearchSource.note},
          score: 0.2,
          byMeaning: true,
        ),
        current: entry.copyWith(formattedNote: 'Revised words'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old private words', findRichText: true), findsNothing);
    expect(find.textContaining('This entry has changed.'), findsOneWidget);
  });
}
