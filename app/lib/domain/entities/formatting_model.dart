import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';

enum FormattingModelKind { light, balanced, quality }

/// Pinned, optional language-model weights for on-device note formatting.
class FormattingModel extends LocalAiModel {
  const FormattingModel({
    required super.id,
    required super.name,
    required super.fileName,
    required super.url,
    required super.bytes,
    required super.sha256,
    required this.kind,
    required this.quantization,
    this.requiresGemmaTerms = false,
  });

  final FormattingModelKind kind;
  final String quantization;
  final bool requiresGemmaTerms;
  String get license =>
      requiresGemmaTerms ? 'Gemma Terms of Use' : 'Apache-2.0';

  static const qwen3_0_6b = FormattingModel(
    id: 'qwen3-0.6b-q8_0',
    name: 'Qwen3 0.6B Q8',
    fileName: 'Qwen3-0.6B-Q8_0.gguf',
    url:
        'https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/23749fefcc72300e3a2ad315e1317431b06b590a/Qwen3-0.6B-Q8_0.gguf',
    bytes: 639446688,
    sha256: '9465e63a22add5354d9bb4b99e90117043c7124007664907259bd16d043bb031',
    kind: FormattingModelKind.light,
    quantization: 'Q8_0',
  );

  static const qwen3_1_7b = FormattingModel(
    id: 'qwen3-1.7b-q4_k_m',
    name: 'Qwen3 1.7B Q4_K_M',
    fileName: 'Qwen3-1.7B-Q4_K_M.gguf',
    url:
        'https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/d7f544eead698dbd1f15126ef60b45a1e1933222/Qwen3-1.7B-Q4_K_M.gguf',
    bytes: 1107409472,
    sha256: 'b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897',
    kind: FormattingModelKind.balanced,
    quantization: 'Q4_K_M',
  );

  static const qwen3_4bInstruct = FormattingModel(
    id: 'qwen3-4b-instruct-2507-q4_k_m',
    name: 'Qwen3 4B Instruct 2507 Q4_K_M',
    fileName: 'Qwen3-4B-Instruct-2507-Q4_K_M.gguf',
    url:
        'https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/a06e946bb6b655725eafa393f4a9745d460374c9/Qwen3-4B-Instruct-2507-Q4_K_M.gguf',
    bytes: 2497281120,
    sha256: '3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597',
    kind: FormattingModelKind.quality,
    quantization: 'Q4_K_M',
  );

  static const gemma3_4b = FormattingModel(
    id: 'gemma-3-4b-it-q4_k_m',
    name: 'Gemma 3 4B IT Q4_K_M',
    fileName: 'gemma-3-4b-it-Q4_K_M.gguf',
    url:
        'https://huggingface.co/unsloth/gemma-3-4b-it-GGUF/resolve/5a3566e716d80f709ed7b79817eaf7733d2a1fce/gemma-3-4b-it-Q4_K_M.gguf',
    bytes: 2489894016,
    sha256: '04a43a22e8d2003deda5acc262f68ec1005fa76c735a9962a8c77042a74a7d19',
    kind: FormattingModelKind.quality,
    quantization: 'Q4_K_M',
    requiresGemmaTerms: true,
  );

  static const catalog = [qwen3_0_6b, qwen3_1_7b, qwen3_4bInstruct, gemma3_4b];

  static FormattingModel? find(String id) {
    for (final model in catalog) {
      if (model.id == id) return model;
    }
    return null;
  }
}

enum FormattingRecommendationReason { unknown, economical, balanced }

class FormattingRecommendation {
  const FormattingRecommendation(this.model, this.reason);

  final FormattingModel model;
  final FormattingRecommendationReason reason;
}

/// Conservative device estimate, never a benchmark or a minimum requirement.
class FormattingRecommendationPolicy {
  static const balancedMemoryBytes = 6 * 1024 * 1024 * 1024;

  static FormattingRecommendation recommend(DeviceProfile profile) {
    final memory = profile.memoryBytes;
    if (memory == null ||
        memory <= 0 ||
        profile.processors == null ||
        profile.processors! <= 0) {
      return const FormattingRecommendation(
        FormattingModel.qwen3_0_6b,
        FormattingRecommendationReason.unknown,
      );
    }
    if (profile.lowMemory || !profile.is64Bit || memory < balancedMemoryBytes) {
      return const FormattingRecommendation(
        FormattingModel.qwen3_0_6b,
        FormattingRecommendationReason.economical,
      );
    }
    return const FormattingRecommendation(
      FormattingModel.qwen3_1_7b,
      FormattingRecommendationReason.balanced,
    );
  }
}
