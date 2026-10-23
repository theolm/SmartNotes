import 'package:smartnotes/domain/entities/search_result.dart';
import 'package:smartnotes/domain/entities/search_options.dart';
import 'package:smartnotes/domain/entities/search_index_status.dart';

abstract class IEntrySearchService {
  /// Invalidate queued text work when input, mode, or screen lifetime changes.
  void cancelTextSearch();

  /// Stable rank + ID ordering. Request an extra row to detect continuation.
  Future<List<SearchResult>> searchText(
    String query, {
    SearchOptions options = const SearchOptions(),
  });

  /// New semantic requests supersede earlier ones. Callers may also invalidate
  /// work while typing, changing search mode, or disposing their view.
  Future<List<SearchResult>> searchSemantic(
    String query, {
    bool Function()? isCancelled,
    SearchOptions options = const SearchOptions(),
  });
  Future<void> indexPending({bool retryFailures = false});
  Future<void> rebuild();
  Stream<SearchIndexStatus> watchIndexStatus();
}
