import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/formatting_acceleration_service.dart';
import 'package:smartnotes/data/services/formatting_inference_runner.dart';
import 'package:smartnotes/data/services/gpu_circuit_store.dart';
import 'package:smartnotes/data/services/local_formatting_session.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/formatting_acceleration.dart';
import 'package:smartnotes/domain/services/i_formatting_acceleration_service.dart';

const profile = FormattingGpuProfile(
  id: 'fixture',
  hardware: 'android:firmware-1',
  modelId: 'model',
  workload: FormattingWorkload.organization,
  backend: FormattingBackend.vulkan,
  minimumMemoryBytes: 8000,
  minimumAvailableBytes: 3000,
  gpuLayers: 20,
);
const gpu = FormattingBackendDecision.gpu(profile);

class _Device extends DeviceProfileService {
  DeviceProfile profile = const DeviceProfile(
    hardwareIdentity: 'android:firmware-1',
    memoryBytes: 8000,
    availableMemoryBytes: 4000,
  );
  @override
  Future<DeviceProfile> read() async => profile;
}

class _Acceleration extends Mock implements IFormattingAccelerationService {}

class _Session implements LocalFormattingSession {
  Object? loadError;
  Object? disposeError;
  Completer<void>? disposal;
  int disposals = 0;
  bool loaded = false;
  @override
  Future<void> load(String path) async {
    loaded = true;
    if (loadError case final error?) throw error;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await disposal?.future;
    if (disposeError case final error?) throw error;
  }

  @override
  Future<int> countPrompt(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  ) async => 100;
  @override
  Future<LlamaCompletion> generate(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  ) async =>
      const LlamaCompletion(text: '{}', finishReason: LlamaFinishReason.stop);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(gpu);
    registerFallbackValue(FormattingWorkload.organization);
    registerFallbackValue(
      const FormattingRunReport(
        backend: FormattingBackend.cpu,
        fellBack: false,
        elapsed: Duration.zero,
      ),
    );
  });

  group('qualification policy', () {
    FormattingBackendDecision decide({
      bool preferred = true,
      bool open = false,
      String hardware = 'android:firmware-1',
      String model = 'model',
      FormattingWorkload workload = FormattingWorkload.organization,
      int? available = 4000,
      bool lowMemory = false,
    }) => FormattingBackendPolicy.decide(
      preferred: preferred,
      circuitOpen: open,
      hardware: hardware,
      modelId: model,
      workload: workload,
      memoryBytes: 8000,
      availableBytes: available,
      lowMemory: lowMemory,
      profiles: [profile],
    );

    test('exact deployment and workload required', () {
      expect(decide().backend, FormattingBackend.vulkan);
      expect(decide(hardware: 'android:firmware-2').usesGpu, false);
      expect(decide(model: 'another-model').usesGpu, false);
      expect(decide(workload: FormattingWorkload.metadata).usesGpu, false);
    });
    test('preference and circuit override qualification', () {
      expect(
        decide(preferred: false).reason,
        FormattingBackendReason.userDisabled,
      );
      expect(decide(open: true).reason, FormattingBackendReason.circuitOpen);
    });
    test('unknown or insufficient current memory keeps CPU', () {
      for (final bytes in [null, 0, 2999]) {
        expect(decide(available: bytes).reason, FormattingBackendReason.memory);
      }
      expect(decide(lowMemory: true).usesGpu, false);
    });
    test(
      'native parameters preserve explicit CPU and Vulkan mitigation',
      () async {
        final cpu = LlamaFormattingSession();
        final vulkan = LlamaFormattingSession(decision: gpu);
        expect(cpu.modelParams.device, ComputeDevice.cpu);
        expect(cpu.modelParams.gpuLayers, 0);
        expect(cpu.modelParams.numberOfThreads, 4);
        expect(vulkan.modelParams.device, ComputeDevice.gpu);
        expect(vulkan.modelParams.preferredBackend, GpuBackend.vulkan);
        expect(vulkan.modelParams.gpuLayers, 20);
        expect(vulkan.modelParams.microBatchSize, 0);
        expect(vulkan.modelParams.contextSize, 4096);
        await cpu.dispose();
        await vulkan.dispose();
      },
    );
  });

  group('session lifetime and fallback', () {
    late _Acceleration acceleration;
    late LocalInferenceQueue queue;
    late _Session first;
    late _Session second;
    late FormattingInferenceRunner runner;
    late List<FormattingBackendDecision> attempts;
    setUp(() {
      acceleration = _Acceleration();
      queue = LocalInferenceQueue();
      first = _Session();
      second = _Session();
      attempts = [];
      when(
        () => acceleration.decide(any(), any()),
      ).thenAnswer((_) async => gpu);
      when(
        () => acceleration.begin(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => acceleration.finish(
          any(),
          backendFailed: any(named: 'backendFailed'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => acceleration.canRetryOnCpu(any()),
      ).thenAnswer((_) async => true);
      runner = FormattingInferenceRunner.forTesting(acceleration, queue, (
        decision,
      ) {
        attempts.add(decision);
        return attempts.length == 1 ? first : second;
      });
    });
    Future<String> run({
      Future<String> Function(LocalFormattingSession)? generate,
    }) => queue.run(
      () => runner.run(
        path: 'fixture',
        modelId: 'model',
        workload: FormattingWorkload.organization,
        generate: generate ?? (_) async => 'accepted',
      ),
    );

    test('successful GPU reports only after disposal', () async {
      first.disposal = Completer();
      final job = run();
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => acceleration.report(any()));
      verifyNever(
        () => acceleration.finish(
          any(),
          backendFailed: any(named: 'backendFailed'),
        ),
      );
      first.disposal!.complete();
      expect(await job, 'accepted');
      expect(first.disposals, 1);
      final report =
          verify(() => acceleration.report(captureAny())).captured.single
              as FormattingRunReport;
      expect(report.backend, FormattingBackend.vulkan);
      expect(report.fellBack, false);
    });
    test(
      'single fresh CPU retry waits for GPU disposal and owns queue',
      () async {
        first.loadError = const FormattingGpuUnavailable();
        first.disposal = Completer();
        final job = run();
        var nextRan = false;
        final next = queue.run(() async => nextRan = true);
        await Future<void>.delayed(Duration.zero);
        expect(attempts.length, 1);
        expect(nextRan, false);
        first.disposal!.complete();
        expect(await job, 'accepted');
        await next;
        expect(attempts.map((d) => d.backend), [
          FormattingBackend.vulkan,
          FormattingBackend.cpu,
        ]);
        expect(first.disposals, 1);
        expect(second.disposals, 1);
        final report =
            verify(() => acceleration.report(captureAny())).captured.single
                as FormattingRunReport;
        expect(report.fellBack, true);
        expect(report.backend, FormattingBackend.cpu);
      },
    );
    test('unknown native load failure is not retried', () async {
      first.loadError = StateError('ambiguous runtime error');
      await expectLater(run(), throwsA(isA<FormattingLoadFailure>()));
      expect(attempts.length, 1);
      expect(first.disposals, 1);
    });
    test(
      'CPU failure after GPU failure never starts a third session',
      () async {
        first.loadError = const FormattingGpuUnavailable();
        second.loadError = StateError('CPU failed');
        await expectLater(run(), throwsA(isA<FormattingLoadFailure>()));
        expect(attempts.length, 2);
        verifyNever(() => acceleration.report(any()));
      },
    );
    test('invalid output and cancellation are not backend failures', () async {
      for (final code in [
        AiFailureCode.invalidNote,
        AiFailureCode.noteTooLong,
        AiFailureCode.incompleteNote,
      ]) {
        await expectLater(
          run(generate: (_) async => throw AiFailure(code)),
          throwsA(isA<AiFailure>()),
        );
      }
      expect(attempts.length, 3);
      verifyNever(() => acceleration.canRetryOnCpu(any()));
      verifyNever(() => acceleration.report(any()));
    });
    test(
      'failed disposal retains marker and blocks every queued native job',
      () async {
        first.loadError = const FormattingGpuUnavailable();
        first.disposeError = StateError('native resource not released');
        await expectLater(run(), throwsA(isA<AiFailure>()));
        await expectLater(
          queue.run(() async => 'must not run'),
          throwsA(isA<AiFailure>()),
        );
        expect(first.disposals, 1);
        expect(attempts.length, 1);
        verify(() => acceleration.cleanupFailed()).called(1);
        verifyNever(
          () => acceleration.finish(
            any(),
            backendFailed: any(named: 'backendFailed'),
          ),
        );
      },
    );
    test(
      'successful generation with failed cleanup is not accepted or retried',
      () async {
        first.disposeError = StateError('cleanup failed');
        await expectLater(run(), throwsA(isA<AiFailure>()));
        expect(first.disposals, 1);
        verifyNever(() => acceleration.report(any()));
      },
    );
    test('memory pressure prevents CPU retry allocation', () async {
      first.loadError = const FormattingGpuUnavailable();
      when(
        () => acceleration.canRetryOnCpu(any()),
      ).thenAnswer((_) async => false);
      await expectLater(run(), throwsA(isA<FormattingLoadFailure>()));
      expect(attempts.length, 1);
    });
    test('unwritable marker selects CPU before constructing GPU', () async {
      when(
        () => acceleration.begin(any(), any()),
      ).thenAnswer((_) async => false);
      expect(await run(), 'accepted');
      expect(attempts.single.backend, FormattingBackend.cpu);
      verifyNever(
        () => acceleration.finish(
          any(),
          backendFailed: any(named: 'backendFailed'),
        ),
      );
    });
  });

  group('independent persisted preference and crash circuit', () {
    late Directory temp;
    late File marker;
    late SharedPreferences preferences;
    late _Device device;
    late FormattingAccelerationService service;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('formatting-circuit-test');
      marker = File('${temp.path}/formatting.json');
      SharedPreferences.setMockInitialValues({'speechGpuPreferred': true});
      preferences = await SharedPreferences.getInstance();
      device = _Device();
      service = FormattingAccelerationService.forTesting(
        preferences,
        device,
        GpuCircuitStore.at(marker),
        profiles: [profile],
      );
    });
    tearDown(() async {
      await service.dispose();
      await temp.delete(recursive: true);
    });
    test('off by default and speech preference stays independent', () async {
      expect(service.status.preferred, false);
      await service.setPreferred(true);
      expect(
        (await service.decide(
          'model',
          FormattingWorkload.organization,
        )).usesGpu,
        true,
      );
      await service.setPreferred(false);
      expect(preferences.getBool('speechGpuPreferred'), true);
    });
    test('interrupted marker disables GPU before next attempt', () async {
      await GpuCircuitStore.at(
        marker,
      ).begin(model: 'model', runtime: 'fixture');
      await service.setPreferred(true);
      await service.initialize();
      expect(service.status.circuitOpen, true);
      expect(await service.begin('model', gpu), false);
      await service.resetCircuit();
      expect(await service.begin('model', gpu), true);
      await service.finish('model', backendFailed: false);
      expect((await GpuCircuitStore.at(marker).read()).open, false);
    });
    test('settings refresh and reset cannot clear an active marker', () async {
      await service.setPreferred(true);
      expect(await service.begin('model', gpu), true);
      await service.initialize();
      await service.resetCircuit();
      expect(service.status.busy, true);
      expect(marker.readAsStringSync(), contains('pending'));
      expect(await service.begin('model', gpu), false);
      await service.finish('model', backendFailed: false);
      expect(service.status.busy, false);
    });
    test('two recoverable failures open circuit', () async {
      await service.setPreferred(true);
      for (var i = 0; i < 2; i++) {
        expect(await service.begin('model', gpu), true);
        await service.finish('model', backendFailed: true);
      }
      expect(service.status.circuitOpen, true);
      expect(await service.begin('model', gpu), false);
    });
    test('corrupt marker and storage failure keep CPU', () async {
      marker.writeAsStringSync('{broken');
      await service.setPreferred(true);
      expect(
        (await service.decide('model', FormattingWorkload.organization)).reason,
        FormattingBackendReason.circuitOpen,
      );
    });
    test('cleanup failure cannot be reset in the same process', () async {
      await service.setPreferred(true);
      await service.begin('model', gpu);
      service.cleanupFailed();
      await service.resetCircuit();
      expect(service.status.circuitOpen, true);
      expect(service.status.busy, true);
      expect((await GpuCircuitStore.at(marker).read()).open, true);
    });
  });
}
