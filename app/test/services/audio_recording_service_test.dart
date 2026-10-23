import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:smartnotes/data/services/audio_recording_service.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

void main() {
  late MockAudioRecorder mockRecorder;
  late AudioRecordingService service;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _FakePathProvider();
    registerFallbackValue(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
    );
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockRecorder = MockAudioRecorder();
    service = AudioRecordingService(mockRecorder);
  });

  group('AudioRecordingService', () {
    test('hasPermission delegates to recorder', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);

      final result = await service.hasPermission();

      expect(result, true);
      verify(() => mockRecorder.hasPermission()).called(1);
    });

    test('start throws when permission denied', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);

      expect(service.start(), throwsException);
    });

    test('stop returns path and clears internal state', () async {
      const path = '/path/to/audio.m4a';
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(
        () => mockRecorder.start(
          any(),
          path: any(named: 'path'),
        ),
      ).thenAnswer((_) async => {});
      when(() => mockRecorder.stop()).thenAnswer((_) async => path);

      await service.start();
      final result = await service.stop();

      expect(result, path);
    });

    group('onAmplitudeChanged', () {
      test('normalizes dBFS to the 0.0–1.0 range', () {
        when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
          (_) => Stream.fromIterable([
            Amplitude(current: 0, max: 0),
            Amplitude(current: -30, max: -30),
            Amplitude(current: -60, max: -60),
          ]),
        );

        expect(
          service.onAmplitudeChanged,
          emitsInOrder([1.0, 0.5, 0.0, emitsDone]),
        );
      });

      test('clamps values outside the -60..0 dBFS range', () {
        when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
          (_) => Stream.fromIterable([
            Amplitude(current: 5, max: 5),
            Amplitude(current: -90, max: -90),
          ]),
        );

        expect(
          service.onAmplitudeChanged,
          emitsInOrder([1.0, 0.0, emitsDone]),
        );
      });

      test('maps infinite amplitude to 0.0', () {
        when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
          (_) => Stream.fromIterable([
            Amplitude(
              current: double.negativeInfinity,
              max: double.negativeInfinity,
            ),
          ]),
        );

        expect(service.onAmplitudeChanged, emitsInOrder([0.0, emitsDone]));
      });
    });
  });
}
