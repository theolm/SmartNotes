import 'package:smartnotes/domain/entities/speech_acceleration.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_speech_acceleration_service.dart';

/// Safe default for tests and compositions without the optional GPU runtime.
class CpuOnlySpeechAccelerationService implements ISpeechAccelerationService {
  const CpuOnlySpeechAccelerationService();

  @override
  Future<void> initialize() async {}

  @override
  Future<SpeechAccelerationStatus> status({
    bool refresh = false,
    bool probe = false,
  }) async => const SpeechAccelerationStatus(
    state: SpeechAccelerationState.unsupportedDevice,
    reason: SpeechBackendReason.unsupportedDevice,
  );

  @override
  Future<SpeechBackendDecision> decide({
    required SpeechModel model,
    required Duration audioDuration,
  }) async => const SpeechBackendDecision(
    SpeechBackend.cpu,
    SpeechBackendReason.unsupportedDevice,
  );

  @override
  Future<bool> beginGpuAttempt(SpeechModel model) async => false;

  @override
  Future<void> completeGpuAttempt() async {}

  @override
  Future<void> recordGpuFailure({
    required SpeechModel model,
    required String code,
  }) async {}

  @override
  Future<SpeechAccelerationStatus> resetCircuit() => status();
}
