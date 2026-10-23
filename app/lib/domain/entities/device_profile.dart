import 'package:smartnotes/domain/entities/speech_model.dart';

class DeviceProfile {
  const DeviceProfile({
    this.memoryBytes,
    this.lowMemory = false,
    this.is64Bit = false,
    this.processors,
    this.soc,
  });
  final int? memoryBytes;
  final bool lowMemory;
  final bool is64Bit;
  final int? processors;
  final String? soc;
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
    if (profile.lowMemory || !profile.is64Bit || memory < balancedMemoryBytes) {
      return SpeechRecommendation(
        fallback,
        RecommendationReason.economical,
      );
    }
    final powerful =
        memory >= powerfulMemoryBytes &&
        validatedSocProfiles.contains(profile.soc);
    final candidate = powerful
        ? (english ? SpeechModel.mediumEnglish : SpeechModel.turbo)
        : (english ? SpeechModel.smallEnglish : SpeechModel.small);
    if (!candidate.supports(language)) {
      return const SpeechRecommendation(
        SpeechModel.turbo,
        RecommendationReason.balanced,
      );
    }
    return SpeechRecommendation(
      candidate,
      powerful ? RecommendationReason.powerful : RecommendationReason.balanced,
    );
  }
}
