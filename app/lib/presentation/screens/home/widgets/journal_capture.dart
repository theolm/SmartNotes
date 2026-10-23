import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/theme/app_spacing.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/screens/home/widgets/record_fab.dart';
import 'package:smartnotes/presentation/screens/home/widgets/recording_overlay.dart';
import 'package:smartnotes/presentation/screens/home/widgets/sound_waveform.dart';

/// A workspace-level capture surface, independent of either content pane.
class JournalCapture extends StatelessWidget {
  const JournalCapture({
    super.key,
    required this.store,
    required this.showAction,
    required this.child,
    this.alignEnd = false,
    this.controlRegion,
  });

  final HomeStore store;
  final bool showAction;
  final bool alignEnd;
  final Rect? controlRegion;
  final Widget child;

  @override
  Widget build(BuildContext context) => Observer.withBuiltChild(
    builder: (_, child) => RecordingOverlay(
      isActive: store.isRecording,
      waveform: Observer(
        builder: (_) => SoundWaveform(amplitude: store.amplitude),
      ),
      floatingActionButtonLocation: _CaptureFabLocation(
        alignEnd: alignEnd,
        region: controlRegion,
        keyboardBottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      floatingActionButton: RecordFab(
        // Never hide Stop when a resize hides the feed or search is active.
        isVisible: store.isRecording || showAction,
        isRecording: store.isRecording,
        onPressed: store.toggleRecording,
      ),
      child: child,
    ),
    child: child,
  );
}

/// Keep Material's keyboard/safe-area positioning, bounded to an unobstructed
/// display region so a centered compact control cannot land on a hinge.
class _CaptureFabLocation extends FloatingActionButtonLocation {
  const _CaptureFabLocation({
    required this.alignEnd,
    required this.region,
    required this.keyboardBottom,
  });

  final bool alignEnd;
  final Rect? region;
  final double keyboardBottom;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final base =
        (alignEnd
                ? FloatingActionButtonLocation.endFloat
                : FloatingActionButtonLocation.centerFloat)
            .getOffset(geometry);
    final bounds = region ?? (Offset.zero & geometry.scaffoldSize);
    final size = geometry.floatingActionButtonSize;
    const margin = AppSpacing.lg;
    final minX = bounds.left + margin;
    final maxX = math.max(minX, bounds.right - margin - size.width);
    final x = alignEnd
        ? geometry.textDirection == TextDirection.ltr
              ? maxX
              : minX
        : bounds.center.dx - size.width / 2;
    final availableBottom = math.min(
      bounds.bottom,
      geometry.scaffoldSize.height - keyboardBottom,
    );
    final maxY = math.max(
      bounds.top + margin,
      availableBottom - margin - size.height,
    );
    return Offset(x.clamp(minX, maxX).toDouble(), math.min(base.dy, maxY));
  }
}
