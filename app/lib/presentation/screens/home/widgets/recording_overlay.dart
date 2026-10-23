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
  });

  final bool isActive;
  final Widget child;
  final double amplitude;
  final Widget? floatingActionButton;
  final Widget? waveform;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          child,
          if (isActive) ...[
            Positioned.fill(
              child: Container(
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: floatingActionButton,
    );
  }
}
