import 'package:smartnotes/domain/entities/speech_model.dart';

/// Backend used for speech transcription. GPU means the optional Android
/// Vulkan runtime, never a remote service.
enum SpeechBackend { cpu, gpu }

/// Device-level availability of the optional GPU runtime.
enum SpeechAccelerationState {
  checking,
  available,
  unsupportedDevice,
  capabilityFailed,
  circuitOpen,
  disabledByUser,
}

/// Why a backend was or was not selected. Codes are stable and safe to log.
enum SpeechBackendReason {
  gpuReady,
  userDisabled,
  unsupportedDevice,
  capabilityFailed,
  circuitOpen,
  modelNotQualified,
  durationBelowCutoff,
}

class SpeechAccelerationStatus {
  const SpeechAccelerationStatus({
    required this.state,
    this.reason,
    this.deviceName,
    this.runtime,
    this.failureCode,
  });

  final SpeechAccelerationState state;
  final SpeechBackendReason? reason;
  final String? deviceName;
  final String? runtime;
  final String? failureCode;

  bool get canUseGpu => state == SpeechAccelerationState.available;
}

class SpeechBackendDecision {
  const SpeechBackendDecision(this.backend, this.reason);

  final SpeechBackend backend;
  final SpeechBackendReason reason;

  bool get usesGpu => backend == SpeechBackend.gpu;
}

/// Pure selection policy. Measurement and device probing stay outside so the
/// rules can be unit-tested without Flutter, native code, or real hardware.
class SpeechBackendPolicy {
  /// Base Q8 is slower on the GPU for short captures. Measured on the S24:
  /// 5 s was 24.5% slower, 15 s was 12.9% faster, 30 s 40.6%, 45 s 47.3%.
  /// 20 s keeps a safety margin above the crossover without discarding most
  /// of the long-recording gain.
  static const baseGpuMinDuration = Duration(seconds: 20);

  static const gpuQualifiedKinds = {
    SpeechModelKind.small,
    SpeechModelKind.turbo,
  };

  static SpeechBackendDecision decide({
    required bool preferred,
    required SpeechAccelerationStatus status,
    required SpeechModel model,
    required Duration audioDuration,
  }) {
    if (!preferred) {
      return const SpeechBackendDecision(
        SpeechBackend.cpu,
        SpeechBackendReason.userDisabled,
      );
    }
    if (!status.canUseGpu) {
      return SpeechBackendDecision(
        SpeechBackend.cpu,
        status.reason ?? SpeechBackendReason.unsupportedDevice,
      );
    }
    if (gpuQualifiedKinds.contains(model.kind)) {
      return const SpeechBackendDecision(
        SpeechBackend.gpu,
        SpeechBackendReason.gpuReady,
      );
    }
    if (model.kind == SpeechModelKind.base) {
      if (audioDuration >= baseGpuMinDuration) {
        return const SpeechBackendDecision(
          SpeechBackend.gpu,
          SpeechBackendReason.gpuReady,
        );
      }
      return const SpeechBackendDecision(
        SpeechBackend.cpu,
        SpeechBackendReason.durationBelowCutoff,
      );
    }
    return const SpeechBackendDecision(
      SpeechBackend.cpu,
      SpeechBackendReason.modelNotQualified,
    );
  }
}
