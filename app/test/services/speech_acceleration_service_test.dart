import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/gpu_circuit_store.dart';
import 'package:smartnotes/data/services/speech_acceleration_service.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/speech_acceleration.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

class _Settings extends Mock implements ISettingsService {}

class _ProfileService extends DeviceProfileService {
  _ProfileService(this.profile);
  final DeviceProfile profile;
  @override
  Future<DeviceProfile> read() async => profile;
}

const _arm64Vulkan = DeviceProfile(
  memoryBytes: 8 * 1024 * 1024 * 1024,
  is64Bit: true,
  processors: 8,
  sdkInt: 34,
  supportedAbis: ['arm64-v8a'],
  hasVulkan11: true,
);

WhisperCapabilities _caps({bool available = true}) => WhisperCapabilities(
  backend: 'vulkan',
  vulkanCompiled: true,
  vulkanAvailable: available,
  deviceCount: available ? 1 : 0,
  deviceName: 'Test GPU',
  runtime: 'runtime-1',
);

void main() {
  late _Settings settings;
  late Directory directory;
  late GpuCircuitStore circuit;

  setUp(() async {
    settings = _Settings();
    when(() => settings.getSpeechGpuPreferred()).thenReturn(true);
    directory = await Directory.systemTemp.createTemp('gpu-acceleration-test-');
    circuit = GpuCircuitStore.at(File('${directory.path}/circuit.json'));
  });

  tearDown(() async => directory.delete(recursive: true));

  SpeechAccelerationService service({
    DeviceProfile profile = _arm64Vulkan,
    bool isAndroid = true,
    Future<WhisperCapabilities> Function()? probe,
  }) => SpeechAccelerationService.forTesting(
    settings,
    _ProfileService(profile),
    circuit,
    isAndroid: isAndroid,
    probe: probe ?? () async => _caps(),
  );

  test('the user preference disables the GPU before any device work', () async {
    when(() => settings.getSpeechGpuPreferred()).thenReturn(false);
    final acceleration = service(probe: () async => fail('must not probe'));
    final status = await acceleration.status(probe: true);
    expect(status.state, SpeechAccelerationState.disabledByUser);
    final decision = await acceleration.decide(
      model: SpeechModel.turbo,
      audioDuration: const Duration(minutes: 2),
    );
    expect(decision.backend, SpeechBackend.cpu);
    expect(decision.reason, SpeechBackendReason.userDisabled);
  });

  test('non-Android, 32-bit and pre-Vulkan 1.1 devices stay on the CPU', () async {
    final cases = [
      (profile: _arm64Vulkan, android: false),
      (
        profile: const DeviceProfile(
          is64Bit: true,
          processors: 8,
          supportedAbis: ['armeabi-v7a'],
          hasVulkan11: true,
        ),
        android: true,
      ),
      (
        profile: const DeviceProfile(
          is64Bit: true,
          processors: 8,
          supportedAbis: ['arm64-v8a'],
          hasVulkan11: false,
        ),
        android: true,
      ),
    ];
    for (final item in cases) {
      final acceleration = service(
        profile: item.profile,
        isAndroid: item.android,
        probe: () async => fail('must not probe'),
      );
      final status = await acceleration.status(probe: true);
      expect(status.state, SpeechAccelerationState.unsupportedDevice);
    }
  });

  test('eligible devices report checking until a probe is requested', () async {
    var probes = 0;
    final acceleration = service(
      probe: () async {
        probes += 1;
        return _caps();
      },
    );
    expect((await acceleration.status()).state, SpeechAccelerationState.checking);
    expect(probes, 0);
    final available = await acceleration.status(probe: true);
    expect(available.state, SpeechAccelerationState.available);
    expect(available.deviceName, 'Test GPU');
    expect(probes, 1);
    // Cached capability is reused.
    await acceleration.status(probe: true);
    expect(probes, 1);
  });

  test('probe failures and missing Vulkan devices fall back safely', () async {
    final throwing = service(probe: () async => throw StateError('no driver'));
    expect(
      (await throwing.status(probe: true)).state,
      SpeechAccelerationState.capabilityFailed,
    );
    final unavailable = service(probe: () async => _caps(available: false));
    expect(
      (await unavailable.status(probe: true)).state,
      SpeechAccelerationState.capabilityFailed,
    );
  });

  test('selects GPU only for the measured model and duration policy', () async {
    final acceleration = service();
    final turbo = await acceleration.decide(
      model: SpeechModel.turbo,
      audioDuration: const Duration(seconds: 8),
    );
    expect(turbo.backend, SpeechBackend.gpu);

    final baseShort = await acceleration.decide(
      model: SpeechModel.whisperBaseQ8,
      audioDuration: const Duration(seconds: 11),
    );
    expect(baseShort.backend, SpeechBackend.cpu);
    expect(baseShort.reason, SpeechBackendReason.durationBelowCutoff);

    final baseLong = await acceleration.decide(
      model: SpeechModel.whisperBaseQ8,
      audioDuration: const Duration(minutes: 2),
    );
    expect(baseLong.backend, SpeechBackend.gpu);

    final large = await acceleration.decide(
      model: SpeechModel.large,
      audioDuration: const Duration(minutes: 5),
    );
    expect(large.backend, SpeechBackend.cpu);
  });

  test('two recoverable failures open the circuit and reset re-probes', () async {
    var probes = 0;
    final acceleration = service(
      probe: () async {
        probes += 1;
        return _caps();
      },
    );
    expect((await acceleration.status(probe: true)).canUseGpu, isTrue);
    await acceleration.beginGpuAttempt(SpeechModel.turbo);
    await acceleration.recordGpuFailure(
      model: SpeechModel.turbo,
      code: 'vulkan_init_failed',
    );
    await acceleration.completeGpuAttempt();
    expect((await acceleration.status()).canUseGpu, isTrue);

    await acceleration.beginGpuAttempt(SpeechModel.turbo);
    await acceleration.recordGpuFailure(
      model: SpeechModel.turbo,
      code: 'vulkan_inference_failed',
    );
    await acceleration.completeGpuAttempt();
    final open = await acceleration.status();
    expect(open.state, SpeechAccelerationState.circuitOpen);
    expect(open.failureCode, 'vulkan_inference_failed');

    final decision = await acceleration.decide(
      model: SpeechModel.turbo,
      audioDuration: const Duration(minutes: 1),
    );
    expect(decision.backend, SpeechBackend.cpu);
    expect(decision.reason, SpeechBackendReason.circuitOpen);

    final reset = await acceleration.resetCircuit();
    expect(reset.state, SpeechAccelerationState.available);
    expect(probes, 2);
  });

  test('an interrupted attempt is resolved before the first decision', () async {
    File('${directory.path}/circuit.json').writeAsStringSync(
      '{"schema_version":1,"pending":{"model":"whisper-turbo"},'
      '"failures":0,"open":false,"runtime":"runtime-1"}',
    );
    final acceleration = service();
    await acceleration.initialize();
    final status = await acceleration.status();
    expect(status.state, SpeechAccelerationState.circuitOpen);
    expect(status.failureCode, 'interrupted');
  });

  test('probe persists a crash marker before native work and shares concurrent probes', () async {
    final done = Completer<WhisperCapabilities>();
    final entered = Completer<void>();
    var probes = 0;
    final acceleration = service(probe: () {
      probes++;
      final raw = jsonDecode(File('${directory.path}/circuit.json').readAsStringSync());
      expect(raw['pending']['model'], 'capability_probe');
      entered.complete();
      return done.future;
    });
    final first = acceleration.status(probe: true);
    await entered.future;
    final second = acceleration.status(probe: true, refresh: true);
    done.complete(_caps());
    expect((await first).canUseGpu, isTrue);
    expect((await second).canUseGpu, isTrue);
    expect(probes, 1);
    expect((await circuit.read()).open, isFalse);
  });

  test('interrupted probe disables GPU on restart without probing again', () async {
    await circuit.begin(model: 'capability_probe');
    final acceleration = service(probe: () async => fail('must not probe'));
    expect((await acceleration.status(probe: true)).state,
        SpeechAccelerationState.circuitOpen);
  });

  test('unreadable circuit keeps decisions on CPU, including explicit CPU preference', () async {
    // A directory in place of the file reliably causes an I/O failure, even
    // when tests run with privileges that bypass file mode bits.
    Directory('${directory.path}/circuit.json').createSync();
    final acceleration = service(probe: () async => fail('must not probe'));
    await acceleration.initialize();
    expect((await acceleration.status()).failureCode, 'storage_unavailable');
    expect((await acceleration.decide(model: SpeechModel.turbo,
        audioDuration: const Duration(minutes: 2))).backend, SpeechBackend.cpu);
    when(() => settings.getSpeechGpuPreferred()).thenReturn(false);
    expect((await acceleration.status()).state, SpeechAccelerationState.disabledByUser);
  });

  test('unwritable probe marker never enters native code', () async {
    final acceleration = service(probe: () async => fail('must not probe'));
    await acceleration.initialize();
    Directory('${directory.path}/circuit.json').createSync();
    expect((await acceleration.status(probe: true)).state,
        SpeechAccelerationState.circuitOpen);
  });
}
