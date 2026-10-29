import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/domain/entities/speech_acceleration.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';

void main() {
  const available = SpeechAccelerationStatus(
    state: SpeechAccelerationState.available,
  );

  test('user preference always wins', () {
    final decision = SpeechBackendPolicy.decide(
      preferred: false,
      status: available,
      model: SpeechModel.turbo,
      audioDuration: const Duration(minutes: 5),
    );
    expect(decision.backend, SpeechBackend.cpu);
    expect(decision.reason, SpeechBackendReason.userDisabled);
  });

  test('unavailable devices fall back with the reported reason', () {
    const unsupported = SpeechAccelerationStatus(
      state: SpeechAccelerationState.unsupportedDevice,
      reason: SpeechBackendReason.unsupportedDevice,
    );
    final decision = SpeechBackendPolicy.decide(
      preferred: true,
      status: unsupported,
      model: SpeechModel.small,
      audioDuration: const Duration(seconds: 30),
    );
    expect(decision.backend, SpeechBackend.cpu);
    expect(decision.reason, SpeechBackendReason.unsupportedDevice);
  });

  test('Small and Turbo use the GPU at any duration', () {
    for (final model in [SpeechModel.small, SpeechModel.turbo]) {
      for (final duration in [
        const Duration(seconds: 5),
        const Duration(seconds: 11),
        const Duration(minutes: 3),
      ]) {
        final decision = SpeechBackendPolicy.decide(
          preferred: true,
          status: available,
          model: model,
          audioDuration: duration,
        );
        expect(decision.backend, SpeechBackend.gpu);
        expect(decision.reason, SpeechBackendReason.gpuReady);
      }
    }
  });

  test('Base stays on the CPU below the measured cutoff', () {
    final short = SpeechBackendPolicy.decide(
      preferred: true,
      status: available,
      model: SpeechModel.whisperBaseQ8,
      audioDuration: const Duration(seconds: 11),
    );
    expect(short.backend, SpeechBackend.cpu);
    expect(short.reason, SpeechBackendReason.durationBelowCutoff);

    final cutoff = SpeechBackendPolicy.decide(
      preferred: true,
      status: available,
      model: SpeechModel.whisperBaseQ8,
      audioDuration: SpeechBackendPolicy.baseGpuMinDuration,
    );
    expect(cutoff.backend, SpeechBackend.gpu);
  });

  test('unmeasured models stay on the CPU', () {
    for (final model in [
      SpeechModel.smallEnglish,
      SpeechModel.mediumEnglish,
      SpeechModel.large,
    ]) {
      final decision = SpeechBackendPolicy.decide(
        preferred: true,
        status: available,
        model: model,
        audioDuration: const Duration(minutes: 5),
      );
      expect(decision.backend, SpeechBackend.cpu);
      expect(decision.reason, SpeechBackendReason.modelNotQualified);
    }
  });
}
