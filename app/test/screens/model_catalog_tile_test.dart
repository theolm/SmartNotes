import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/presentation/widgets/model_catalog_tile.dart';
import 'package:smartnotes/presentation/widgets/model_settings_page.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'shared rows support compact large text and independent actions ${theme.brightness}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = 0;
        var details = 0;
        var downloads = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: ModelSettingsPage(
              title: 'Models',
              children: [
                ModelCatalogTile(
                  name: 'A local model',
                  metadata: '300 MB · Q8',
                  active: true,
                  activeLabel: 'Active',
                  recommendedLabel: 'Recommended',
                  detailsTitle: 'Supported languages',
                  description: 'Local processing with no server.',
                  status: 'Installed',
                  onTap: () => selected++,
                  detailsTooltip: 'Information',
                  onDetails: () => details++,
                  trailing: ModelCatalogActionButton(
                    action: ModelCatalogAction.download,
                    tooltip: 'Download',
                    onPressed: () => downloads++,
                  ),
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Download'));
        await tester.tap(find.byTooltip('Information'));
        expect(downloads, 1);
        expect(details, 1);
        expect(selected, 0);
        await tester.tap(find.text('A local model'));
        expect(selected, 1);
        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(ModelCatalogTile),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.selected, isTrue);
      },
    );
  }
}
