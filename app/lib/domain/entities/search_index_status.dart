class SearchIndexStatus {
  const SearchIndexStatus({
    this.indexed = 0,
    this.pending = 0,
    this.failed = 0,
    this.generation = 0,
  });
  final int indexed;
  final int pending;
  final int failed;
  final int generation;
  bool get isIncomplete => pending > 0 || failed > 0;
}
