import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/presentation/screens/home/widgets/journal_timeline.dart';

void main() {
  testWidgets(
    'search pages and a note round trip preserve scroll; a new query resets it',
    (tester) async {
      final now = DateTime(2026);
      final entries = List.generate(
        50,
        (i) => JournalEntry(
          id: '$i',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.completed,
        ),
      );
      Widget app(int count, int identity) => MaterialApp(
        home: Scaffold(
          body: JournalTimeline(
            entries: entries.take(count).toList(),
            isSearching: true,
            showDayHeaders: false,
            scrollIdentity: identity,
            header: const Text('Search controls'),
            footer: const Text('Load more'),
            itemBuilder: (entry) => Builder(
              builder: (context) => SizedBox(
                height: 100,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('Opened note')),
                    ),
                  ),
                  child: Text('Note ${entry.id}'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(30, 1));
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      final offset = tester
          .widget<ListView>(find.byType(ListView))
          .controller!
          .offset;
      await tester.tap(find.text('Note 5'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Opened note'))).pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        offset,
      );
      await tester.pumpWidget(app(50, 1));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        offset,
      );
      await tester.pumpWidget(app(50, 2));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        0,
      );
    },
  );
  testWidgets('incoming entries wait while reading, then appear at the top', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 21, 12);
    JournalEntry entry(String id) => JournalEntry(
      id: id,
      createdAt: now,
      updatedAt: now,
      status: EntryStatus.completed,
    );
    final entries = List.generate(30, (index) => entry('$index'));
    Widget app(List<JournalEntry> values) => MaterialApp(
      home: Scaffold(
        body: JournalTimeline(
          entries: values,
          itemBuilder: (entry) => SizedBox(
            height: 100,
            child: Text('Note ${entry.id}'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(entries));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('Note 5'));
    await tester.pumpWidget(app([entry('new'), ...entries]));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Note 5')), before);
    expect(find.text('Note new'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('Note new'), findsOneWidget);
    expect(tester.getSize(find.byType(ListView)).width, lessThanOrEqualTo(640));
  });
}
