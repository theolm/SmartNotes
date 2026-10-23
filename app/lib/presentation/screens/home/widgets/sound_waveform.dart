import 'dart:math' as math;

import 'package:flutter/material.dart';

class SoundWaveform extends StatefulWidget {
  const SoundWaveform({super.key, required this.amplitude});

  final double amplitude;

  @override
  State<SoundWaveform> createState() => _SoundWaveformState();
}

class _SoundWaveformState extends State<SoundWaveform>
    with SingleTickerProviderStateMixin {
  static const int _capacity = 90;
  static const double _easeFactor = 0.35;

  final List<double> _samples = [0];
  double _eased = 0;
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker =
        AnimationController(
            vsync: this,
            duration: const Duration(seconds: 1),
          )
          ..addListener(_onTick)
          ..repeat();
  }

  void _onTick() {
    _eased += (widget.amplitude - _eased) * _easeFactor;
    _samples.add(_eased);
    if (_samples.length > _capacity) {
      _samples.removeAt(0);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.45;

    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        return CustomPaint(
          size: Size(double.infinity, height),
          painter: SoundWaveformPainter(
            samples: List.unmodifiable(_samples),
            phase: _ticker.value * 2 * math.pi,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        );
      },
    );
  }
}

class SoundWaveformPainter extends CustomPainter {
  SoundWaveformPainter({
    required this.samples,
    required this.phase,
    required this.color,
  });

  final List<double> samples;
  final double phase;
  final Color color;

  static const double _barWidth = 4;
  static const double _barGap = 3;
  static const double _minBarHeight = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = (size.width / (_barWidth + _barGap)).floor();
    if (barCount <= 0) return;

    final visible = samples.length < barCount ? samples.length : barCount;
    final startIndex = samples.length - visible;
    final stripWidth = visible * (_barWidth + _barGap) - _barGap;
    final originX = (size.width - stripWidth) / 2;

    final paint = Paint();

    for (var i = 0; i < visible; i++) {
      final sample = samples[startIndex + i];
      final base = 0.04 + 0.03 * math.sin(phase + i * 0.35);
      final factor = (base + sample * (1 - base)).clamp(0.0, 1.0).toDouble();
      final barHeight = math.max(_minBarHeight, size.height * factor);

      final x = originX + i * (_barWidth + _barGap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, _barWidth, barHeight),
        const Radius.circular(_barWidth / 2),
      );

      final recency = (i + 1) / visible;
      final alpha = (0.10 + 0.25 * factor) * (0.4 + 0.6 * recency);
      paint.color = color.withValues(alpha: alpha);
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(SoundWaveformPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.phase != phase;
}
