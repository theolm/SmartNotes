enum FormattingBackend { cpu, vulkan, metal }

enum FormattingWorkload { metadata, organization }

enum FormattingBackendReason {
  userDisabled,
  unqualified,
  memory,
  circuitOpen,
  qualified,
  fallback,
}

/// A release-qualified deployment, not a generic GPU capability claim.
class FormattingGpuProfile {
  const FormattingGpuProfile({
    required this.id,
    required this.hardware,
    required this.modelId,
    required this.workload,
    required this.backend,
    required this.minimumMemoryBytes,
    required this.minimumAvailableBytes,
    required this.gpuLayers,
  });

  final String id;
  final String hardware;
  final String modelId;
  final FormattingWorkload workload;
  final FormattingBackend backend;
  final int minimumMemoryBytes;
  final int minimumAvailableBytes;
  final int gpuLayers;
}

class FormattingBackendDecision {
  const FormattingBackendDecision.cpu(this.reason) : profile = null;
  const FormattingBackendDecision.gpu(FormattingGpuProfile this.profile)
    : reason = FormattingBackendReason.qualified;

  final FormattingGpuProfile? profile;
  final FormattingBackendReason reason;
  FormattingBackend get backend => profile?.backend ?? FormattingBackend.cpu;
  bool get usesGpu => backend != FormattingBackend.cpu;
}

class FormattingBackendPolicy {
  static const version = 1;
  static const runtime = 'llamadart-0.11.1-native-v0.5.0-2-policy-1';

  // Add only measured profiles documented in formatting-gpu-validation.md.
  static const qualifiedProfiles = <FormattingGpuProfile>[
    // Measured 2026-10-30 on Apple M5, macOS 26.5.2, Qwen3 1.7B Q4_K_M:
    // median 4.17 s vs 8.98 s CPU, 44 vs 23 generated tokens/s unthrottled.
    // Evidence and limits: docs/formatting-gpu-validation.md.
    FormattingGpuProfile(
      id: 'macos-m5-qwen3-1.7b-org-v1',
      hardware: 'macos:Apple M5',
      modelId: 'qwen3-1.7b-q4_k_m',
      workload: FormattingWorkload.organization,
      backend: FormattingBackend.metal,
      minimumMemoryBytes: 8 * 1024 * 1024 * 1024,
      // Measured peak RSS was 3.2 GiB on CPU and 2.1 GiB on Metal.
      minimumAvailableBytes: 4 * 1024 * 1024 * 1024,
      // ModelParams.maxGpuLayers, duplicated to keep domain pure.
      gpuLayers: 999,
    ),
  ];

  static FormattingBackendDecision decide({
    required bool preferred,
    required bool circuitOpen,
    required String hardware,
    required String modelId,
    required FormattingWorkload workload,
    required int? memoryBytes,
    required int? availableBytes,
    required bool lowMemory,
    List<FormattingGpuProfile> profiles = qualifiedProfiles,
  }) {
    if (!preferred) {
      return const FormattingBackendDecision.cpu(
        FormattingBackendReason.userDisabled,
      );
    }
    if (circuitOpen) {
      return const FormattingBackendDecision.cpu(
        FormattingBackendReason.circuitOpen,
      );
    }
    for (final profile in profiles) {
      if (profile.hardware != hardware ||
          profile.modelId != modelId ||
          profile.workload != workload ||
          profile.backend == FormattingBackend.cpu ||
          profile.gpuLayers <= 0) {
        continue;
      }
      if (lowMemory ||
          memoryBytes == null ||
          availableBytes == null ||
          memoryBytes < profile.minimumMemoryBytes ||
          availableBytes < profile.minimumAvailableBytes) {
        return const FormattingBackendDecision.cpu(
          FormattingBackendReason.memory,
        );
      }
      return FormattingBackendDecision.gpu(profile);
    }
    return const FormattingBackendDecision.cpu(
      FormattingBackendReason.unqualified,
    );
  }
}

/// Only confirmed, completed requests populate the last-result feedback.
class FormattingRunReport {
  const FormattingRunReport({
    required this.backend,
    required this.fellBack,
    required this.elapsed,
  });
  final FormattingBackend backend;
  final bool fellBack;
  final Duration elapsed;
}

class FormattingAccelerationStatus {
  const FormattingAccelerationStatus({
    this.preferred = false,
    this.circuitOpen = false,
    this.busy = false,
    this.lastRun,
  });
  final bool preferred;
  final bool circuitOpen;
  final bool busy;
  final FormattingRunReport? lastRun;
}
