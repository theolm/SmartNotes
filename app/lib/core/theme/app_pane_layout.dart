import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// Geometry only: no device names, platform checks, routes, or feature state.
/// Minimums describe usable content, rather than a particular device category.
@immutable
class AppPaneLayout {
  const AppPaneLayout({
    required this.primary,
    required this.secondary,
    required this.single,
    required this.canSplit,
  });

  static const minListWidth = 280.0;
  static const minDetailWidth = 360.0;
  static const maxListWidth = 360.0;
  static const dividerWidth = 1.0;
  static const minPaneHeight = 320.0;
  static const readingWidth = 640.0;

  final Rect primary;
  final Rect secondary;
  final Rect single;
  final bool canSplit;

  factory AppPaneLayout.resolve({
    required Size size,
    required TextScaler textScaler,
    List<DisplayFeature> displayFeatures = const [],
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    TextDirection direction = TextDirection.ltr,
  }) {
    var usable = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final scale = math.max(1.0, textScaler.scale(16) / 16);
    final listMinimum = minListWidth * scale;
    final detailMinimum = minDetailWidth * scale;
    Rect? leftRegion;
    Rect? rightRegion;

    for (final feature in displayFeatures) {
      final separates =
          feature.type == DisplayFeatureType.hinge ||
          (feature.type == DisplayFeatureType.fold &&
              feature.state == DisplayFeatureState.postureHalfOpened);
      final intersects =
          feature.bounds.left <= usable.right &&
          feature.bounds.right >= usable.left &&
          feature.bounds.top <= usable.bottom &&
          feature.bounds.bottom >= usable.top;
      // A fold may be a zero-width/height line, so Rect.overlaps is not enough.
      if (!separates || !intersects) continue;
      final bounds = feature.bounds;
      if (bounds.height >= usable.height) {
        final left = Rect.fromLTRB(
          usable.left,
          usable.top,
          bounds.left,
          usable.bottom,
        );
        final right = Rect.fromLTRB(
          bounds.right,
          usable.top,
          usable.right,
          usable.bottom,
        );
        final list = direction == TextDirection.ltr ? left : right;
        final detail = direction == TextDirection.ltr ? right : left;
        if (list.width >= listMinimum && detail.width >= detailMinimum) {
          leftRegion = left;
          rightRegion = right;
        }
        usable = left.width >= right.width ? left : right;
      } else if (bounds.width >= usable.width) {
        // No special tabletop workflow: use the larger unobstructed region.
        final top = Rect.fromLTRB(
          usable.left,
          usable.top,
          usable.right,
          bounds.top,
        );
        final bottom = Rect.fromLTRB(
          usable.left,
          bounds.bottom,
          usable.right,
          usable.bottom,
        );
        usable = top.height >= bottom.height ? top : bottom;
      }
    }

    final availableHeight =
        usable.height - math.max(0.0, viewInsets.bottom - padding.bottom);
    final enoughHeight = availableHeight >= minPaneHeight;
    if (leftRegion != null && rightRegion != null && enoughHeight) {
      return AppPaneLayout(
        primary: direction == TextDirection.ltr ? leftRegion : rightRegion,
        secondary: direction == TextDirection.ltr ? rightRegion : leftRegion,
        single: usable,
        canSplit: true,
      );
    }
    final split =
        leftRegion == null &&
        rightRegion == null &&
        enoughHeight &&
        usable.width >= listMinimum + detailMinimum + dividerWidth;
    if (!split) {
      return AppPaneLayout(
        primary: usable,
        secondary: usable,
        single: usable,
        canSplit: false,
      );
    }
    final listWidth = (usable.width * .36).clamp(
      listMinimum,
      maxListWidth * scale,
    );
    final isLtr = direction == TextDirection.ltr;
    return AppPaneLayout(
      primary: Rect.fromLTWH(
        isLtr ? usable.left : usable.right - listWidth,
        usable.top,
        listWidth,
        usable.height,
      ),
      secondary: Rect.fromLTWH(
        isLtr ? usable.left + listWidth + dividerWidth : usable.left,
        usable.top,
        usable.width - listWidth - dividerWidth,
        usable.height,
      ),
      single: usable,
      canSplit: true,
    );
  }
}
