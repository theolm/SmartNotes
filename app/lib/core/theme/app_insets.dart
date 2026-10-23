import 'package:flutter/material.dart';

import 'app_spacing.dart';

@immutable
final class AppInsets {
  const AppInsets._();

  static double bottomSystemPadding(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom;
  }

  static EdgeInsets scrollContentPadding(
    BuildContext context, {
    double extra = AppSpacing.lg,
  }) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom + extra;
    return EdgeInsets.only(bottom: bottom);
  }

  static EdgeInsets withBottomSystemPadding(
    BuildContext context,
    EdgeInsets base,
  ) {
    return base.copyWith(
      bottom: base.bottom + MediaQuery.viewPaddingOf(context).bottom,
    );
  }
}
