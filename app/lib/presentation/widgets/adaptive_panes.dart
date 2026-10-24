import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smartnotes/core/theme/app_pane_layout.dart';

/// Both children keep the same element ancestry across every layout change.
/// In particular, the nested Navigator and editor controllers are never moved
/// between a Row, a route, and an overlay when the window is resized.
class AdaptivePanes extends StatelessWidget {
  const AdaptivePanes({
    super.key,
    required this.layout,
    required this.showSecondary,
    required this.expanded,
    required this.primary,
    required this.secondary,
  });

  final AppPaneLayout layout;
  final bool showSecondary;
  final bool expanded;
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    final split = layout.canSplit && !expanded;
    final left = layout.primary.left < layout.secondary.left
        ? layout.primary
        : layout.secondary;
    final right = layout.primary.left < layout.secondary.left
        ? layout.secondary
        : layout.primary;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          _pane(
            rect: split ? layout.primary : layout.single,
            visible: split || !showSecondary,
            child: primary,
          ),
          _pane(
            rect: split ? layout.secondary : layout.single,
            visible: split || showSecondary,
            child: secondary,
          ),
          if (split &&
              (right.left - left.right).abs() <= AppPaneLayout.dividerWidth)
            Positioned(
              left: left.right,
              top: left.top,
              height: left.height,
              width: AppPaneLayout.dividerWidth,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pane({
    required Rect rect,
    required bool visible,
    required Widget child,
  }) => Positioned.fromRect(
    rect: rect,
    child: Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: ExcludeFocus(
          excluding: !visible,
          child: Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              EdgeInsets localInsets(EdgeInsets insets) => EdgeInsets.fromLTRB(
                math.max(0, insets.left - rect.left),
                math.max(0, insets.top - rect.top),
                math.max(0, insets.right - (media.size.width - rect.right)),
                math.max(0, insets.bottom - (media.size.height - rect.bottom)),
              );
              return MediaQuery(
                data: media.copyWith(
                  size: rect.size,
                  padding: localInsets(media.padding),
                  viewPadding: localInsets(media.viewPadding),
                  viewInsets: localInsets(media.viewInsets),
                  // Separating features were already handled by the parent.
                  displayFeatures: const [],
                ),
                child: child,
              );
            },
          ),
        ),
      ),
    ),
  );
}
