import 'journal_entry.dart';

enum SearchSource { title, note, original }

/// Evidence returned by retrieval, separate from the journal's current snapshot.
class SearchResult {
  const SearchResult({
    required this.entry,
    required this.excerpt,
    required this.sources,
    required this.score,
    this.byMeaning = false,
  });

  final JournalEntry entry;
  final String excerpt;
  final Set<SearchSource> sources;
  final double score;
  final bool byMeaning;

  /// FTS markers delimit matching words; they are rendered as spans, never HTML.
  static const matchStart = '\uE000';
  static const matchEnd = '\uE001';

  factory SearchResult.fromRow(Map<dynamic, dynamic> row) {
    final entry = JournalEntry.fromJson(
      Map<String, dynamic>.from(row['entry'] as Map),
    );
    final start = row['start'] as int?;
    final end = row['end'] as int?;
    int? column;
    var excerpt = (row['excerpt'] as String?) ?? '';
    if (row.containsKey('title_excerpt')) {
      // Prefer a contextual body passage to a title-only match.
      for (final (index, key) in [
        (2, 'note_excerpt'),
        (3, 'original_excerpt'),
        (1, 'title_excerpt'),
      ]) {
        final text = (row[key] as String?) ?? '';
        if (!text.contains(matchStart)) continue;
        column = index;
        excerpt = text;
        break;
      }
    }
    final sources = <SearchSource>{};
    if (column != null) {
      sources.add(switch (column) {
        1 => SearchSource.title,
        2 => SearchSource.note,
        _ =>
          entry.body.trim() == (entry.transcription?.trim() ?? '')
              ? SearchSource.note
              : SearchSource.original,
      });
    } else if (start != null && end != null) {
      var offset = 0;
      final body = entry.body.trim();
      final original = entry.transcription?.trim() ?? '';
      final fields = [
        (SearchSource.title, entry.title?.trim() ?? ''),
        (SearchSource.note, body),
        if (original != body) (SearchSource.original, original),
      ];
      for (final (source, text) in fields) {
        if (text.isEmpty) continue;
        if (start < offset + text.length && end > offset) sources.add(source);
        offset += text.length + 2;
      }
    }
    return SearchResult(
      entry: entry,
      excerpt: excerpt,
      sources: sources,
      score: (row['score'] as num).toDouble(),
      byMeaning: !row.containsKey('title_excerpt'),
    );
  }
}
