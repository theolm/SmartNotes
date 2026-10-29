import 'package:smartnotes/domain/entities/speech_acceleration.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';

/// Owns backend availability, the user preference, and crash-safe GPU state.
///
/// Implementations must never persist audio, transcripts, entry IDs, or model
/// paths. The GPU attempt marker is only a bounded crash-loop guard.
abstract class ISpeechAccelerationService {
  /// Resolves an interrupted GPU attempt before journal recovery starts.
  Future<void> initialize();

  /// Returns cached state unless [refresh] is true. Set [probe] to run the
  /// native capability check when it has not run in this session.
  Future<SpeechAccelerationStatus> status({
    bool refresh = false,
    bool probe = false,
  });

  Future<SpeechBackendDecision> decide({
    required SpeechModel model,
    required Duration audioDuration,
  });

  /// Writes the crash marker before native GPU work starts. Returns false when
  /// the marker cannot be persisted; callers must then stay on the CPU.
  Future<bool> beginGpuAttempt(SpeechModel model);

  /// Clears the marker after a handled success or failure.
  Future<void> completeGpuAttempt();

  /// Counts a recoverable GPU failure and opens the circuit when appropriate.
  Future<void> recordGpuFailure({
    required SpeechModel model,
    required String code,
  });

  /// Explicit user retry: clears the circuit and re-probes the device.
  Future<SpeechAccelerationStatus> resetCircuit();
}
