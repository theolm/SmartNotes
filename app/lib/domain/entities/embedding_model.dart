import 'package:smartnotes/domain/entities/embedding_pipeline.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';

enum EmbeddingFamily { qwen, gemma, gemma2, e5 }

/// Pinned weights and the complete representation contract for one search model.
class EmbeddingModel extends LocalAiModel {
  const EmbeddingModel({
    required super.id,
    required super.name,
    required super.fileName,
    required super.url,
    required super.bytes,
    required super.sha256,
    required this.family,
    required this.architecture,
    required this.nativeDimensions,
    required this.dimensions,
    required this.contextTokens,
    required this.maxDistance,
    this.available = true,
  });

  final EmbeddingFamily family;
  final String architecture;
  final int nativeDimensions;
  final int dimensions;
  final int contextTokens;
  final double? maxDistance;
  final bool available;
  int get chunkTokens => 384;
  int get overlapTokens => 64;
  int get pooling => family == EmbeddingFamily.qwen ? 3 : 1;

  String get pipelineId => family == EmbeddingFamily.qwen
      ? EmbeddingPipeline.id
      : '$id:$sha256:llamadart-0.11.1:llamacpp-7fe450e1:'
            'pool$pooling:native$nativeDimensions:d$dimensions:l2:prefix-v1:'
            'current-original-dedup-v2:chunks384-overlap64-v1:passages-v1';

  String query(String text) => switch (family) {
    EmbeddingFamily.qwen => EmbeddingPipeline.query(text),
    EmbeddingFamily.gemma ||
    EmbeddingFamily.gemma2 => 'task: search result | query: $text',
    EmbeddingFamily.e5 => 'query: $text',
  };

  String document(String text) => switch (family) {
    EmbeddingFamily.qwen => text,
    EmbeddingFamily.gemma ||
    EmbeddingFamily.gemma2 => 'title: none | text: $text',
    EmbeddingFamily.e5 => 'passage: $text',
  };

  static const qwen = EmbeddingModel(
    id: 'qwen3-embedding-0.6b-q8_0',
    name: 'Qwen3 Embedding 0.6B Q8',
    fileName: 'Qwen3-Embedding-0.6B-Q8_0.gguf',
    url:
        'https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF/resolve/370f27d7550e0def9b39c1f16d3fbaa13aa67728/Qwen3-Embedding-0.6B-Q8_0.gguf',
    bytes: 639150592,
    sha256: '06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439',
    family: EmbeddingFamily.qwen,
    architecture: 'qwen3',
    nativeDimensions: 1024,
    dimensions: 512,
    contextTokens: 1024,
    maxDistance: EmbeddingPipeline.maxDistance,
  );

  static const gemma = EmbeddingModel(
    id: 'embeddinggemma-300m-q8_0',
    name: 'EmbeddingGemma 300M Q8',
    fileName: 'embeddinggemma-300M-Q8_0.gguf',
    url:
        'https://huggingface.co/ggml-org/embeddinggemma-300M-GGUF/resolve/0f741b5a6585bd53aeb15cd1372c56f2a0f65e12/embeddinggemma-300M-Q8_0.gguf',
    bytes: 333590944,
    sha256: 'b5ce9d77a3fc4b3b39ccb5643c36777911cc4eb46a66962eadfa3f5f60490d63',
    family: EmbeddingFamily.gemma,
    architecture: 'gemma-embedding',
    nativeDimensions: 768,
    dimensions: 512,
    contextTokens: 1024,
    maxDistance: 0.6093,
  );

  static const gemma2 = EmbeddingModel(
    id: 'embeddinggemma-2-q8_0',
    name: 'EmbeddingGemma 2 Q8',
    fileName: 'embeddinggemma-2-Q8_0.gguf',
    url:
        'https://huggingface.co/ggml-org/embeddinggemma-2-GGUF/resolve/58faf90940886df2d62be555c8765d00dac362c5/embeddinggemma-2-Q8_0.gguf',
    bytes: 309855456,
    sha256: '2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135',
    family: EmbeddingFamily.gemma2,
    architecture: 'gemma-embedding2',
    nativeDimensions: 768,
    dimensions: 512,
    contextTokens: 1024,
    maxDistance: null,
    available: false,
  );

  static const e5 = EmbeddingModel(
    id: 'multilingual-e5-small-q8_0',
    name: 'Multilingual E5 Small Q8',
    fileName: 'multilingual-e5-small-q8_0.gguf',
    url:
        'https://huggingface.co/cstr/multilingual-e5-small-GGUF/resolve/178420da727e544c2689e89b6648b205ad176eda/multilingual-e5-small-q8_0.gguf',
    bytes: 131624960,
    sha256: '0a34067a40f25d3149b36885faa62bee0e5284d0f9edc102acfc00e115d953e8',
    family: EmbeddingFamily.e5,
    architecture: 'bert',
    nativeDimensions: 384,
    dimensions: 384,
    contextTokens: 512,
    maxDistance: null,
    available: false,
  );

  static const catalog = [qwen, gemma, gemma2, e5];
  static EmbeddingModel? find(String id) {
    for (final model in catalog) {
      if (model.id == id) return model;
    }
    return null;
  }
}
