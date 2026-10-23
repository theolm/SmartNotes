abstract class IEmbeddingService {
  /// Checks cancellation before loading and between native operations. An active
  /// forward pass always finishes and its session is disposed before returning.
  Future<List<double>> embedQuery(String text, {bool Function()? isCancelled});

  /// Tokenizes and indexes the entire source. Cancellation discards all vectors.
  /// [onPassage] reports each embedded chunk, in vector order, with its UTF-16
  /// offset in the unmodified source. Keep it only if the entire call succeeds.
  Future<List<List<double>>> embedDocument(
    String text, {
    bool Function()? isCancelled,
    void Function(String text, int start)? onPassage,
  });
}
