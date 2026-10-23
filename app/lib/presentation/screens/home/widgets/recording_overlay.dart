import 'package:flutter/material.dart';

import 'package:smartnotes/presentation/screens/home/widgets/sound_waveform.dart';

class RecordingOverlay extends StatelessWidget {
  const RecordingOverlay({
    super.key,
    required this.isActive,
    required this.child,
    this.amplitude = 0,
    this.floatingActionButton,
    this.waveform,
    this.floatingActionButtonLocation =
        FloatingActionButtonLocation.centerFloat,
  });

  final bool isActive;
  final Widget child;
  final double amplitude;
  final Widget? floatingActionButton;
  final Widget? waveform;
  final FloatingActionButtonLocation floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Content panes already consume their own local keyboard insets.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          ExcludeFocus(
            excluding: isActive,
            child: ExcludeSemantics(
              excluding: isActive,
              child: IgnorePointer(ignoring: isActive, child: child),
            ),
          ),
          if (isActive) ...[
            Positioned.fill(
              child: ModalBarrier(
                key: const ValueKey('recording-barrier'),
                dismissible: false,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: waveform ?? SoundWaveform(amplitude: amplitude),
              ),
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: floatingActionButtonLocation,
      // RecordFab owns the reduced-motion-aware transition. Do not also move
      // its anchor when the Stop label changes width or panes are rearranged.
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: floatingActionButton,
    );
  }
}
