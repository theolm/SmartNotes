import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/core/theme/app_pane_layout.dart';

void main() {
  AppPaneLayout resolve(
    double width, {
    double height = 800,
    double scale = 1,
    List<DisplayFeature> features = const [],
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets keyboard = EdgeInsets.zero,
    TextDirection direction = TextDirection.ltr,
  }) => AppPaneLayout.resolve(
    size: Size(width, height),
    textScaler: TextScaler.linear(scale),
    displayFeatures: features,
    padding: padding,
    viewInsets: keyboard,
    direction: direction,
  );

  test('compact windows retain one pane', () {
    for (final width in [320.0, 390.0, 600.0, 640.0]) {
      expect(resolve(width).canSplit, isFalse);
    }
  });

  test('split starts only when both content minimums fit', () {
    final layout = resolve(641);
    expect(layout.canSplit, isTrue);
    expect(layout.primary.width, 280);
    expect(layout.secondary.width, 360);
  });

  test('wide windows bound the sidebar instead of stretching it', () {
    final layout = resolve(1600);
    expect(layout.primary.width, 360);
    expect(layout.secondary.right, 1600);
  });

  test('enlarged fonts fall back rather than squeeze both panes', () {
    expect(resolve(700, scale: 1.5).canSplit, isFalse);
    expect(resolve(1100, scale: 1.5).canSplit, isTrue);
    expect(resolve(1100, scale: 3).canSplit, isFalse);
  });

  test('short windows and keyboard-constrained height fall back', () {
    expect(resolve(1000, height: 300).canSplit, isFalse);
    expect(
      resolve(
        1000,
        height: 600,
        keyboard: const EdgeInsets.only(bottom: 300),
      ).canSplit,
      isFalse,
    );
  });

  test('RTL puts the journal on the leading side', () {
    final layout = resolve(1000, direction: TextDirection.rtl);
    expect(layout.primary.right, 1000);
    expect(layout.secondary.left, 0);
  });

  test('safe horizontal insets reduce usable space', () {
    final layout = resolve(
      700,
      padding: const EdgeInsets.symmetric(horizontal: 40),
    );
    expect(layout.canSplit, isFalse);
    expect(layout.single, const Rect.fromLTRB(40, 0, 660, 800));
  });

  test('hinge separates panes and expanded content stays unobstructed', () {
    final layout = resolve(
      1000,
      features: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(480, 0, 40, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ],
    );
    expect(layout.canSplit, isTrue);
    expect(layout.primary.right, 480);
    expect(layout.secondary.left, 520);
    expect(layout.single.width, 480);
  });

  test('zero-width half-open fold is a separator, flat crease is not', () {
    DisplayFeature fold(DisplayFeatureState state) => DisplayFeature(
      bounds: const Rect.fromLTWH(500, 0, 0, 800),
      type: DisplayFeatureType.fold,
      state: state,
    );
    expect(
      resolve(
        1000,
        features: [fold(DisplayFeatureState.postureHalfOpened)],
      ).primary.width,
      500,
    );
    expect(
      resolve(
        1000,
        features: [fold(DisplayFeatureState.postureFlat)],
      ).primary.width,
      360,
    );
  });

  test('insufficient hinge regions fall back to the larger region', () {
    final layout = resolve(
      700,
      features: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(250, 0, 20, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ],
    );
    expect(layout.canSplit, isFalse);
    expect(layout.single, const Rect.fromLTWH(270, 0, 430, 800));
  });

  test('horizontal fold avoids the crease without inventing tabletop UI', () {
    final layout = resolve(
      800,
      features: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(0, 350, 800, 0),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ],
    );
    expect(layout.single, const Rect.fromLTRB(0, 350, 800, 800));
  });
}
