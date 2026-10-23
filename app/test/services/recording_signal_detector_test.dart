import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/data/services/recording_signal_detector.dart';

class _Session extends Mock implements FFmpegSession {}

void main() {
  late _Session session;
  late RecordingSignalDetector detector;
  late List<String> arguments;

  setUp(() {
    session = _Session();
    when(() => session.getReturnCode()).thenAnswer((_) async => ReturnCode(0));
    detector = RecordingSignalDetector.withExecutor((args) async {
      arguments = args;
      return session;
    });
  });

  for (final peak in [-91.0, -70.0, -60.1]) {
    test('rejects confirmed silence at $peak dBFS', () async {
      when(() => session.getAllLogsAsString()).thenAnswer(
        (_) async => 'n_samples: 44100\nmax_volume: $peak dB',
      );
      expect(await detector.isSilent('/recordings/with spaces.m4a'), true);
      expect(arguments, contains('/recordings/with spaces.m4a'));
      expect(arguments, isNot(contains('-t')));
    });
  }

  for (final peak in [-60.0, -59.0, -45.0, -10.0]) {
    test('retains quiet or brief signals at $peak dBFS', () async {
      when(() => session.getAllLogsAsString()).thenAnswer(
        (_) async => 'n_samples: 4410000\nmax_volume: $peak dB',
      );
      expect(await detector.isSilent('recording.m4a'), false);
    });
  }

  for (final logs in [
    '',
    'n_samples: 0\nmax_volume: -91.0 dB',
    'max_volume: -91.0 dB',
    'n_samples: 44100',
    'n_samples: 44100\nmax_volume: -inf dB',
  ]) {
    test('retains audio when analysis is inconclusive: $logs', () async {
      when(() => session.getAllLogsAsString()).thenAnswer((_) async => logs);
      expect(await detector.isSilent('recording.m4a'), false);
    });
  }

  test('failed decoding is not treated as silence', () async {
    when(() => session.getReturnCode()).thenAnswer((_) async => ReturnCode(1));
    expect(await detector.isSilent('recording.m4a'), false);
  });

  test('platform failure preserves the recording', () async {
    detector = RecordingSignalDetector.withExecutor((_) async {
      throw Exception('Unavailable');
    });
    expect(await detector.isSilent('recording.m4a'), false);
  });
}
