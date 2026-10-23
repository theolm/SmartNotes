/// A version-pinned, independently verified native inference artifact.
class LocalAiModel {
  const LocalAiModel({
    required this.id,
    required this.name,
    required this.fileName,
    required this.url,
    required this.bytes,
    required this.sha256,
  });
  final String id;
  final String name;
  final String fileName;
  final String url;
  final int bytes;
  final String sha256;

  static const qwenEmbedding = LocalAiModel(
    id: 'qwen3-embedding-0.6b-q8_0',
    name: 'Qwen3 Embedding 0.6B Q8',
    fileName: 'Qwen3-Embedding-0.6B-Q8_0.gguf',
    url:
        'https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF/resolve/370f27d7550e0def9b39c1f16d3fbaa13aa67728/Qwen3-Embedding-0.6B-Q8_0.gguf',
    bytes: 639150592,
    sha256: '06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439',
  );
}
