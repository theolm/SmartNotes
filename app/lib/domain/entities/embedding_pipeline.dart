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
  /// Calibrated with `integration_test/search_relevance_test.dart` on synthetic
  /// bilingual notes, using the real weights. Relevant matches landed between
  /// 0.27 and 0.60 cosine distance; ten clearly unrelated topics all started at
  /// 0.626. The cutoff sits inside that gap, favouring recall: a vague query
  /// keeps a weak-but-real entry rather than reporting nothing. Recalibrate
  /// with new evidence, and never tighten it without re-running the holdout.
  static const maxDistance = 0.61;
  static LocalAiModel get model => LocalAiModel.qwenEmbedding;
  static String query(String text) =>
      'Instruct: $queryInstruction\nQuery:$text';
}
