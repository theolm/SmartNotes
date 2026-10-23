import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/presentation/widgets/audio_language_options.dart';

void main() {
  DeviceProfile profile(int gb, {bool low = false, bool wide = true}) =>
      DeviceProfile(
        memoryBytes: gb * 1024 * 1024 * 1024,
        lowMemory: low,
        is64Bit: wide,
        processors: 8,
      );
  test('unknown hardware has a conservative multilingual fallback', () {
    for (final language in [null, 'auto', ...audioLanguageOptions.keys]) {
      final suggestion = SpeechRecommendationPolicy.recommend(
        const DeviceProfile(),
        language,
      );
      expect(suggestion.model, SpeechModel.whisperBaseQ8);
      expect(suggestion.model.supports(language), isTrue);
      expect(suggestion.reason, RecommendationReason.unknown);
    }
  });
  test(
    'memory boundary, low-memory flag, and 32-bit execution stay conservative',
    () {
      for (final device in [
        profile(4),
        profile(8, low: true),
        profile(8, wide: false),
      ]) {
        expect(
          SpeechRecommendationPolicy.recommend(device, 'en').model,
          SpeechModel.whisperBaseQ8,
        );
      }
      expect(
        SpeechRecommendationPolicy.recommend(profile(6), 'en-US').model,
        SpeechModel.smallEnglish,
      );
      expect(
        SpeechRecommendationPolicy.recommend(profile(6), 'pt-BR').model,
        SpeechModel.small,
      );
    },
  );
  test(
    'non-English and automatic language recommendations never return English-only weights',
    () {
      for (final memory in [4, 6, 8, 12, 24]) {
        for (final language in [
          null,
          'auto',
          ...audioLanguageOptions.keys.where((l) => l != 'en'),
        ]) {
          final model = SpeechRecommendationPolicy.recommend(
            profile(memory),
            language,
          ).model;
          expect(model.englishOnly, isFalse);
          expect(model.supports(language), isTrue);
        }
      }
    },
  );
  test('more RAM alone never qualifies an unmeasured high-end CPU', () {
    expect(
      SpeechRecommendationPolicy.recommend(profile(24), 'pt').model,
      SpeechModel.small,
    );
    expect(
      SpeechRecommendationPolicy.recommend(profile(24), 'en').model,
      SpeechModel.smallEnglish,
    );
  });
  test('unsupported language is rejected rather than falsely advertised', () {
    expect(
      () => SpeechRecommendationPolicy.recommend(profile(8), 'xx'),
      throwsArgumentError,
    );
  });
  test(
    'qualified SoC still needs memory headroom and language compatibility',
    () {
      const device = DeviceProfile(
        memoryBytes: 12 * 1024 * 1024 * 1024,
        is64Bit: true,
        processors: 8,
        soc: 'test-qualified',
      );
      for (final language in [null, 'pt', 'en']) {
        final result = SpeechRecommendationPolicy.recommend(
          device,
          language,
          validatedSocProfiles: {'test-qualified'},
        );
        expect(result.reason, RecommendationReason.powerful);
        expect(
          result.model,
          language == 'en' ? SpeechModel.mediumEnglish : SpeechModel.turbo,
        );
        expect(result.model.supports(language), isTrue);
      }
      expect(
        SpeechRecommendationPolicy.recommend(
          profile(8),
          'pt',
          validatedSocProfiles: {'test-qualified'},
        ).model,
        SpeechModel.small,
      );
    },
  );
  test(
    'Cantonese is recommended only when the actual checkpoint includes it',
    () {
      expect(
        SpeechRecommendationPolicy.recommend(
          const DeviceProfile(),
          'yue',
        ).model,
        SpeechModel.turbo,
      );
    },
  );
}
