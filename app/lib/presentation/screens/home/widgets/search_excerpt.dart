import 'package:flutter/material.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/search_result.dart';

/// Shows retrieval evidence, without presenting a semantic guess as a literal hit.
class SearchExcerpt extends StatefulWidget {
  const SearchExcerpt({
    super.key,
    required this.result,
    required this.current,
    this.dateLabel,
  });
  final SearchResult result;
  final JournalEntry current;
  final String? dateLabel;

  @override
  State<SearchExcerpt> createState() => _SearchExcerptState();
}

class _SearchExcerptState extends State<SearchExcerpt> {
  bool _expanded = false;

  @override
  void didUpdateWidget(SearchExcerpt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final result = widget.result;
    final changed =
        result.entry.body != widget.current.body ||
        result.entry.transcription != widget.current.transcription ||
        result.entry.title != widget.current.title;
    if (changed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.searchEntryChanged, style: theme.textTheme.bodyMedium),
          if (widget.dateLabel != null)
            Text(widget.dateLabel!, style: theme.textTheme.bodySmall),
        ],
      );
    }
    final sources = result.sources
        .map(
          (source) => switch (source) {
            SearchSource.title => l10n.searchSourceTitle,
            SearchSource.note => l10n.searchSourceNote,
            SearchSource.original =>
              widget.current.audioPath == null
                  ? l10n.originalText
                  : l10n.searchSourceOriginal,
          },
        )
        .join(' · ');
    final label = result.byMeaning
        ? [
            l10n.searchRelatedByMeaning,
            if (sources.isNotEmpty) sources,
          ].join(' · ')
        : sources;
    final spans = <TextSpan>[];
    var highlighted = false;
    final tokens = RegExp(
      '${SearchResult.matchStart}|${SearchResult.matchEnd}|[^${SearchResult.matchStart}${SearchResult.matchEnd}]+',
    );
    for (final match in tokens.allMatches(
      result.byMeaning ? '' : result.excerpt,
    )) {
      final text = match[0]!;
      if (text == SearchResult.matchStart) {
        highlighted = true;
        continue;
      }
      if (text == SearchResult.matchEnd) {
        highlighted = false;
        continue;
      }
      spans.add(
        TextSpan(
          text: text,
          style: highlighted && !result.byMeaning
              ? TextStyle(
                  fontWeight: FontWeight.w700,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.10,
                  ),
                  color: theme.colorScheme.onSurface,
                )
              : null,
        ),
      );
    }
    if (result.byMeaning) spans.add(TextSpan(text: result.excerpt));
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(style: theme.textTheme.bodyLarge, children: spans),
          maxLines: 4,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final canExpand = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spans.isNotEmpty)
              Text.rich(
                TextSpan(children: spans),
                style: theme.textTheme.bodyLarge,
                maxLines: _expanded ? null : 4,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (widget.dateLabel != null)
                  Text(widget.dateLabel!, style: theme.textTheme.bodySmall),
                Text(
                  widget.dateLabel == null ? label : '· $label',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (canExpand)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded
                      ? l10n.searchCollapsePassage
                      : l10n.searchExpandPassage,
                ),
              ),
          ],
        );
      },
    );
  }
}
