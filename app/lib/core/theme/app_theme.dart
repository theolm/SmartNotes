import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_system_bars.dart';
import 'app_spacing.dart';

@immutable
final class AppTheme {
  const AppTheme._();

  static const Radius plateRadius = Radius.circular(12);

  static const String _uiFamily = 'Archivo';
  static const String _displayFamily = 'Archivo Black';

  static ThemeData get light => _base(
    brightness: Brightness.light,
    accent: AppColors.signalRed,
    paper: AppColors.paper,
    raised: AppColors.paperRaised,
    ink: AppColors.ink,
    inkSoft: AppColors.inkSoft,
  );

  static ThemeData get dark => _base(
    brightness: Brightness.dark,
    accent: AppColors.signalRedNight,
    paper: AppColors.nightPaper,
    raised: AppColors.nightRaised,
    ink: AppColors.nightInk,
    inkSoft: AppColors.nightInkSoft,
  );

  static ThemeData _base({
    required Brightness brightness,
    required Color accent,
    required Color paper,
    required Color raised,
    required Color ink,
    required Color inkSoft,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: inkSoft,
      onSecondary: paper,
      error: accent,
      onError: Colors.white,
      surface: paper,
      onSurface: ink,
      surfaceContainerHighest: raised,
      onSurfaceVariant: inkSoft,
      outline: ink,
      outlineVariant: Color.alphaBlend(ink.withValues(alpha: 0.16), paper),
    );
    final textTheme = _textTheme(ink: ink, inkSoft: inkSoft);
    const plateShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(plateRadius),
    );
    final plateBorder = BorderSide(color: ink);
    final inputBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.all(plateRadius),
      borderSide: plateBorder,
    );
    final errorInputBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.all(plateRadius),
      borderSide: BorderSide(color: accent),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: AppSystemBars.forBrightness(brightness),
      ),
      dividerTheme: DividerThemeData(color: ink, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: raised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(plateRadius),
          side: plateBorder,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        surfaceTintColor: raised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(plateRadius),
          side: plateBorder,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: raised,
        surfaceTintColor: raised,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: plateRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: paper,
          elevation: 0,
          shape: plateShape,
          textStyle: textTheme.labelLarge?.copyWith(color: paper),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: paper,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: plateShape,
          textStyle: textTheme.labelLarge?.copyWith(color: paper),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: plateBorder,
          shape: plateShape,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          shape: plateShape,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: paper,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: plateShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        labelStyle: textTheme.bodyMedium?.copyWith(color: inkSoft),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: ink),
        hintStyle: textTheme.bodyMedium?.copyWith(color: inkSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(plateRadius),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: errorInputBorder,
        focusedErrorBorder: errorInputBorder,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: paper),
        actionTextColor: paper,
        behavior: SnackBarBehavior.floating,
        shape: plateShape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: ink.withValues(alpha: 0.12),
      ),
    );
  }

  static TextTheme _textTheme({
    required Color ink,
    required Color inkSoft,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: _displayFamily,
        fontSize: 57,
        height: 1.1,
        letterSpacing: -0.5,
        color: ink,
      ),
      displayMedium: TextStyle(
        fontFamily: _displayFamily,
        fontSize: 45,
        height: 1.1,
        letterSpacing: -0.5,
        color: ink,
      ),
      displaySmall: TextStyle(
        fontFamily: _displayFamily,
        fontSize: 36,
        height: 1.1,
        letterSpacing: -0.5,
        color: ink,
      ),
      headlineLarge: TextStyle(
        fontFamily: _displayFamily,
        fontSize: 32,
        height: 1.1,
        letterSpacing: -0.5,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: _displayFamily,
        fontSize: 30,
        height: 1.1,
        letterSpacing: -0.5,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: _displayFamily,
        fontSize: 28,
        height: 1.1,
        letterSpacing: -0.5,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontFamily: _uiFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontFamily: _uiFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontFamily: _uiFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: _uiFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: _uiFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: ink,
      ),
      bodySmall: TextStyle(
        fontFamily: _uiFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: inkSoft,
      ),
      labelLarge: TextStyle(
        fontFamily: _uiFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontFamily: _uiFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: inkSoft,
      ),
      labelSmall: TextStyle(
        fontFamily: _uiFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: inkSoft,
      ),
    );
  }
}
