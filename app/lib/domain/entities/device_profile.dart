import 'package:smartnotes/domain/entities/speech_model.dart';

class DeviceProfile {
  const DeviceProfile({
    this.memoryBytes,
    this.lowMemory = false,
    this.is64Bit = false,
    this.processors,
    this.soc,
    this.sdkInt,
    this.supportedAbis = const [],
    this.hasVulkan11 = false,
    this.availableMemoryBytes,
    this.hardwareIdentity = '',
    this.runtimeIdentity = '',
    this.memoryPressure = false,
  });
  final int? memoryBytes;
  final bool lowMemory;
  final bool is64Bit;
  final int? processors;
  final String? soc;
  final int? sdkInt;
  final List<String> supportedAbis;
  final bool hasVulkan11;
  final int? availableMemoryBytes;

  /// Stable hardware identity used for profile qualification. Never a serial.
  final String hardwareIdentity;

  /// OS build, driver generation and runtime identity for crash safety.
  final String runtimeIdentity;

  /// Transient OS memory pressure, separate from the device's low-RAM class.
  final bool memoryPressure;

  bool get supportsArm64 => supportedAbis.contains('arm64-v8a');
}

enum RecommendationReason { unknown, economical, balanced, powerful }

class SpeechRecommendation {
  const SpeechRecommendation(this.model, this.reason);
  final SpeechModel model;
  final RecommendationReason reason;
}

/// Policy v1: conservative estimates, not minimum device requirements.
/// High-end qualification stays empty until measured CPU profiles are approved.
class SpeechRecommendationPolicy {
  static const balancedMemoryBytes = 6 * 1024 * 1024 * 1024;
  static const powerfulMemoryBytes = 12 * 1024 * 1024 * 1024;
  static const qualifiedSocProfiles = <String>{};

  static SpeechRecommendation recommend(
    DeviceProfile profile,
    String? language, {
    Set<String> validatedSocProfiles = qualifiedSocProfiles,
  }) {
    if (!SpeechModel.turbo.supports(language)) {
      throw ArgumentError.value(
        language,
        'language',
        'Unsupported transcription language',
      );
    }
    final fallback = SpeechModel.whisperBaseQ8.supports(language)
        ? SpeechModel.whisperBaseQ8
        : SpeechModel.turbo;
    final memory = profile.memoryBytes;
    if (memory == null ||
        memory <= 0 ||
        profile.processors == null ||
        profile.processors! <= 0) {
      return SpeechRecommendation(
        fallback,
        RecommendationReason.unknown,
      );
    }
    final english =
        language != null &&
        RegExp(r'^en(?:[-_]|$)', caseSensitive: false).hasMatch(language);
    if (!profile.is64Bit || profile.lowMemory || memory < balancedMemoryBytes) {
      return SpeechRecommendation(
        fallback,
        RecommendationReason.economical,
      );
    }
    final socQualified =
        profile.soc != null && validatedSocProfiles.contains(profile.soc);
    if (socQualified && memory >= powerfulMemoryBytes) {
      return SpeechRecommendation(
        english ? SpeechModel.mediumEnglish : SpeechModel.turbo,
        RecommendationReason.powerful,
      );
    }
    return SpeechRecommendation(
      english
          ? SpeechModel.smallEnglish
          : SpeechModel.small.supports(language)
          ? SpeechModel.small
          : SpeechModel.turbo,
      RecommendationReason.balanced,
    );
  }
}
