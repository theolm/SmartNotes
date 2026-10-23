import 'package:smartnotes/domain/entities/local_ai_model.dart';

enum SpeechModelKind { base, smallEnglish, mediumEnglish, small, turbo, large }

/// Verified whisper.cpp weights with explicit language and loader capabilities.
class SpeechModel extends LocalAiModel {
  const SpeechModel({
    required super.id,
    required super.name,
    required super.fileName,
    required super.url,
    required super.bytes,
    required super.sha256,
    this.kind = SpeechModelKind.base,
    this.englishOnly = false,
    this.quantization = 'Q8_0',
  });

  final SpeechModelKind kind;
  final bool englishOnly;
  final String quantization;
  static const revision = '5359861c739e955e79d9a303bcbc70fb988958b1';
  static const _root =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/$revision';
  static const languageCodes = {
    'en',
    'zh',
    'de',
    'es',
    'ru',
    'ko',
    'fr',
    'ja',
    'pt',
    'tr',
    'pl',
    'ca',
    'nl',
    'ar',
    'sv',
    'it',
    'id',
    'hi',
    'fi',
    'vi',
    'he',
    'uk',
    'el',
    'ms',
    'cs',
    'ro',
    'da',
    'hu',
    'ta',
    'no',
    'th',
    'ur',
    'hr',
    'bg',
    'lt',
    'la',
    'mi',
    'ml',
    'cy',
    'sk',
    'te',
    'fa',
    'lv',
    'bn',
    'sr',
    'az',
    'sl',
    'kn',
    'et',
    'mk',
    'br',
    'eu',
    'is',
    'hy',
    'ne',
    'mn',
    'bs',
    'kk',
    'sq',
    'sw',
    'gl',
    'mr',
    'pa',
    'si',
    'km',
    'sn',
    'yo',
    'so',
    'af',
    'oc',
    'ka',
    'be',
    'tg',
    'sd',
    'gu',
    'am',
    'yi',
    'lo',
    'uz',
    'fo',
    'ht',
    'ps',
    'tk',
    'nn',
    'mt',
    'sa',
    'lb',
    'my',
    'bo',
    'tl',
    'mg',
    'as',
    'tt',
    'haw',
    'ln',
    'ha',
    'ba',
    'jw',
    'su',
  };

  bool supports(String? language) {
    if (language == null || language.isEmpty || language == 'auto') {
      return !englishOnly;
    }
    final code = language.toLowerCase().split(RegExp('[-_]')).first;
    return englishOnly
        ? code == 'en'
        : languageCodes.contains(code) ||
              (code == 'yue' &&
                  (kind == SpeechModelKind.turbo ||
                      kind == SpeechModelKind.large));
  }

  static SpeechModel? find(String id) {
    for (final model in catalog) {
      if (model.id == id) return model;
    }
    return null;
  }

  static const whisperBaseQ8 = SpeechModel(
    id: 'whisper-base-q8_0',
    name: 'Whisper base Q8',
    fileName: 'ggml-base-q8_0.bin',
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base-q8_0.bin',
    bytes: 81768585,
    sha256: 'c577b9a86e7e048a0b7eada054f4dd79a56bbfa911fbdacf900ac5b567cbb7d9',
  );

  static const smallEnglish = SpeechModel(
    id: 'whisper-small-en-q8_0',
    name: 'Whisper Small.en',
    kind: SpeechModelKind.smallEnglish,
    englishOnly: true,
    fileName: 'ggml-small.en-q8_0.bin',
    url: '$_root/ggml-small.en-q8_0.bin',
    bytes: 264477561,
    sha256: '67a179f608ea6114bd3fdb9060e762b588a3fb3bd00c4387971be4d177958067',
  );
  static const mediumEnglish = SpeechModel(
    id: 'whisper-medium-en-q5_0',
    name: 'Whisper Medium.en',
    kind: SpeechModelKind.mediumEnglish,
    englishOnly: true,
    quantization: 'Q5_0',
    fileName: 'ggml-medium.en-q5_0.bin',
    url: '$_root/ggml-medium.en-q5_0.bin',
    bytes: 539225533,
    sha256: '76733e26ad8fe1c7a5bf7531a9d41917b2adc0f20f2e4f5531688a8c6cd88eb0',
  );
  static const small = SpeechModel(
    id: 'whisper-small-q5_1',
    name: 'Whisper Small',
    kind: SpeechModelKind.small,
    quantization: 'Q5_1',
    fileName: 'ggml-small-q5_1.bin',
    url: '$_root/ggml-small-q5_1.bin',
    bytes: 190085487,
    sha256: 'ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb',
  );
  static const turbo = SpeechModel(
    id: 'whisper-large-v3-turbo-q5_0',
    name: 'Whisper Large-v3-turbo',
    kind: SpeechModelKind.turbo,
    quantization: 'Q5_0',
    fileName: 'ggml-large-v3-turbo-q5_0.bin',
    url: '$_root/ggml-large-v3-turbo-q5_0.bin',
    bytes: 574041195,
    sha256: '394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2',
  );
  static const large = SpeechModel(
    id: 'whisper-large-v3-q5_0',
    name: 'Whisper Large-v3',
    kind: SpeechModelKind.large,
    quantization: 'Q5_0',
    fileName: 'ggml-large-v3-q5_0.bin',
    url: '$_root/ggml-large-v3-q5_0.bin',
    bytes: 1081140203,
    sha256: 'd75795ecff3f83b5faa89d1900604ad8c780abd5739fae406de19f23ecd98ad1',
  );
  static const catalog = [
    whisperBaseQ8,
    smallEnglish,
    mediumEnglish,
    small,
    turbo,
    large,
  ];
}
