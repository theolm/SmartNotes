import 'package:smartnotes/domain/entities/local_ai_model.dart';

/// Changing representation or passage-storage policy invalidates the derived index.
abstract final class EmbeddingPipeline {
  static const dimensions = 512;
  static const contextTokens = 1024;
  static const chunkTokens = 384;
  static const overlapTokens = 64;
  static const queryInstruction =
      'Given a personal journal search query, retrieve relevant journal passages';
  static const id =
      'qwen3-embedding-0.6b:q8_0:'
      '06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439:'
      'llamadart-0.11.1:llamacpp-7fe450e1:last:mrl512:l2:query-v1:current-original-dedup-v2:chunks384-overlap64-v1:passages-v1';

  /// Retrieval policy, not representation: a closer best chunk still matches.
  ///
  /// Recalibrated on CPU with pinned Q8 weights, training split only:
  /// max relevant 0.60309, min absent-topic 0.62776; rounded midpoint 0.6154.
  /// Evidence and holdout results: docs/embedding-calibration.md.
  static const maxDistance = 0.6154;
  static LocalAiModel get model => LocalAiModel.qwenEmbedding;
  static String query(String text) =>
      'Instruct: $queryInstruction\nQuery:$text';
}
