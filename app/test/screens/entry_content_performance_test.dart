import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/presentation/widgets/entry_content.dart';

void main() {
  testWidgets(
    'long Markdown paints loading first and retains rendered content on rebuild',
    (tester) async {
      final source = List.generate(
        100,
        (i) => '## Synthetic heading $i\n\n${'Generated prose. ' * 15}\n',
      ).join('\n');
      Widget app({bool dark = false}) => MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EntryContent(text: source, markdown: true),
          ),
        ),
      );
      await tester.pumpWidget(app());
      // The first mount never synchronously parses the long document.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      for (
        var i = 0;
        i < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final rendered = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .first;
      await tester.pumpWidget(app());
      expect(
        identical(
          tester.widgetList<SelectableText>(find.byType(SelectableText)).first,
          rendered,
        ),
        true,
      );
      await tester.pumpWidget(app(dark: true));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
