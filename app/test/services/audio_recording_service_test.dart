import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:smartnotes/data/services/audio_recording_service.dart';
import 'package:smartnotes/data/services/recording_signal_detector.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

class MockSignalDetector extends Mock implements RecordingSignalDetector {}

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late MockAudioRecorder mockRecorder;
  late AudioRecordingService service;
  late MockSignalDetector detector;
  late Directory directory;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'recording-service-test-',
    );
    PathProviderPlatform.instance = _FakePathProvider(directory.path);
    mockRecorder = MockAudioRecorder();
    detector = MockSignalDetector();
    when(() => detector.isSilent(any())).thenAnswer((_) async => false);
    service = AudioRecordingService(mockRecorder, detector);
  });

  tearDown(() => directory.delete(recursive: true));

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

    test('silent capture is discarded and reports no speech', () async {
      late File recording;
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(
        () => mockRecorder.start(any(), path: any(named: 'path')),
      ).thenAnswer(
        (call) async {
          recording = File(call.namedArguments[#path] as String);
          await recording.writeAsBytes([0]);
        },
      );
      when(() => mockRecorder.stop()).thenAnswer((_) async => null);
      when(() => detector.isSilent(any())).thenAnswer((_) async => true);

      await service.start();
      await expectLater(
        service.stop(),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.code,
            'code',
            AiFailureCode.noSpeech,
          ),
        ),
      );
      expect(await recording.exists(), false);
      // The owned path has been cleared, even when validation rejects capture.
      expect(await service.stop(), isNull);
    });

    test('silent result never deletes an unrelated recorder path', () async {
      final unrelated = File('${directory.path}/unrelated.m4a');
      await unrelated.writeAsBytes([0]);
      when(() => mockRecorder.stop()).thenAnswer((_) async => unrelated.path);
      when(() => detector.isSilent(any())).thenAnswer((_) async => true);

      await expectLater(service.stop(), throwsA(isA<AiFailure>()));
      expect(await unrelated.exists(), true);
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
