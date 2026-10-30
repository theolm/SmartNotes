import 'package:smartnotes/domain/entities/formatting_acceleration.dart';

abstract class IFormattingAccelerationService {
  Future<void> initialize();
  Future<void> dispose();
  FormattingAccelerationStatus get status;
  Stream<FormattingAccelerationStatus> get changes;
  Future<void> setPreferred(bool preferred);
  Future<void> resetCircuit();
  Future<FormattingBackendDecision> decide(
    String modelId,
    FormattingWorkload workload,
  );

  /// Called inside the inference lease, before constructing any GPU session.
  Future<bool> begin(String modelId, FormattingBackendDecision decision);
  Future<bool> canRetryOnCpu(FormattingBackendDecision decision);

  /// Only call after successful native disposal. Otherwise leave the marker.
  Future<void> finish(String modelId, {required bool backendFailed});
  void cleanupFailed();
  void report(FormattingRunReport report);
}
