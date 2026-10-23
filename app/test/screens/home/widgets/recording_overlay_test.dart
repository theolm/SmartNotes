import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/presentation/screens/home/widgets/recording_overlay.dart';
import 'package:smartnotes/presentation/screens/home/widgets/sound_waveform.dart';

Widget buildSubject({required bool isActive, double amplitude = 0}) {
  return MaterialApp(
    home: RecordingOverlay(
      isActive: isActive,
      amplitude: amplitude,
      child: const Scaffold(body: Text('content')),
    ),
  );
}

SoundWaveformPainter _waveformPainter(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(SoundWaveform),
      matching: find.byType(CustomPaint),
    ),
  );
  return customPaint.painter! as SoundWaveformPainter;
}

void main() {
  group('RecordingOverlay', () {
    testWidgets('shows no waveform when inactive', (tester) async {
      await tester.pumpWidget(buildSubject(isActive: false));

      expect(find.byType(SoundWaveform), findsNothing);
    });

    testWidgets('shows waveform anchored to the bottom when active', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isActive: true));

      final waveform = find.byType(SoundWaveform);
      expect(waveform, findsOneWidget);

      final overlayBottom = tester
          .getBottomLeft(find.byType(RecordingOverlay))
          .dy;
      expect(tester.getBottomLeft(waveform).dy, overlayBottom);

      await tester.pumpWidget(buildSubject(isActive: false));
    });

    testWidgets('waveform bars stay low in silence', (tester) async {
      await tester.pumpWidget(buildSubject(isActive: true, amplitude: 0));

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }

      final painter = _waveformPainter(tester);
      expect(painter.samples.last, lessThan(0.2));

      await tester.pumpWidget(buildSubject(isActive: false));
    });

    testWidgets('waveform bars rise with loud input', (tester) async {
      await tester.pumpWidget(buildSubject(isActive: true, amplitude: 1));

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }

      final painter = _waveformPainter(tester);
      expect(painter.samples.last, greaterThan(0.5));

      await tester.pumpWidget(buildSubject(isActive: false));
    });
  });
}
