/// A stable page within a retrieval engine.
class SearchOptions {
  const SearchOptions({this.offset = 0, this.limit = 20})
    : assert(offset >= 0),
      assert(limit > 0);

  final int offset;
  final int limit;

  Map<String, Object?> toMap() => {
    'offset': offset,
    'limit': limit,
  };
}
