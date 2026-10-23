import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/core/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    test(
      'theme preserves accessible contrast and 48 dp action targets (${theme.brightness})',
      () {
        double contrast(Color foreground, Color background) {
          final a = foreground.computeLuminance();
          final b = background.computeLuminance();
          return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
        }

        expect(
          contrast(theme.colorScheme.onSurface, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(
            theme.colorScheme.onSurfaceVariant,
            theme.colorScheme.surfaceContainerHighest,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(theme.colorScheme.primary, theme.colorScheme.surface),
          greaterThanOrEqualTo(3),
        );
        for (final style in [
          theme.filledButtonTheme.style!,
          theme.outlinedButtonTheme.style!,
          theme.textButtonTheme.style!,
        ]) {
          expect(
            style.minimumSize!.resolve({})!.height,
            greaterThanOrEqualTo(48),
          );
        }
        expect(theme.textTheme.titleMedium!.fontFamily, 'Archivo');
        expect(theme.textTheme.headlineLarge!.fontFamily, 'Archivo Black');
      },
    );
  }
  group('AppTheme system bars', () {
    test('light theme uses transparent bars with dark icons', () {
      final style = AppTheme.light.appBarTheme.systemOverlayStyle;

      expect(style, isNotNull);
      expect(style!.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarDividerColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    });

    test('dark theme uses transparent bars with light icons', () {
      final style = AppTheme.dark.appBarTheme.systemOverlayStyle;

      expect(style, isNotNull);
      expect(style!.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarDividerColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    });
  });
}
