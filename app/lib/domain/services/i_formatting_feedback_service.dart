/// Tracks an optional formatting preview without changing its persistence rules.
abstract class IFormattingFeedbackService {
  Future<T> run<T>(String entryId, Future<T> Function() operation);
}
