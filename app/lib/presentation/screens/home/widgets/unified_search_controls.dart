import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/presentation/ai_error_message.dart';
import '../home_store.dart';

class UnifiedSearchControls extends StatelessWidget {
  const UnifiedSearchControls({
    super.key,
    required this.store,
    required this.onEdit,
    required this.onSearch,
  });
  final HomeStore store;
  final VoidCallback onEdit;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final failure = store.searchError ?? store.meaningError;
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (store.searchQuery.isEmpty)
              Text(
                l10n.searchUnifiedHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              if (store.showingPreviousResults)
                Text(
                  l10n.searchPreviousResults,
                  style: theme.textTheme.bodySmall,
                ),
              if (store.isSearchingWords || store.isSearchingMeaning)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    store.isSearchingWords
                        ? l10n.searchFindingWords
                        : l10n.searchFindingMeaning,
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                Wrap(
                  spacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (store.searchResults != null)
                      Text(
                        l10n.searchResultCount(store.displayedEntries.length),
                        style: theme.textTheme.bodySmall,
                      ),
                    if (!store.meaningRequested)
                      TextButton(
                        onPressed: onSearch,
                        child: Text(l10n.searchFindRelated),
                      ),
                  ],
                ),
              if (store.meaningRequested && store.indexIncomplete)
                Text(l10n.indexIncomplete, style: theme.textTheme.bodySmall),
              if (store.searchNeedsRefresh)
                TextButton(
                  onPressed: onSearch,
                  child: Text(l10n.searchRefresh),
                ),
              if (failure != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(aiErrorMessage(l10n, failure)),
                ),
                if (store.meaningError != null)
                  Text(
                    l10n.searchWordsStillAvailable,
                    style: theme.textTheme.bodySmall,
                  ),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    TextButton(
                      onPressed: store.isSearching ? null : onSearch,
                      child: Text(l10n.retry),
                    ),
                    TextButton(
                      onPressed: onEdit,
                      child: Text(l10n.searchEditQuery),
                    ),
                    if (store.meaningError != null)
                      TextButton(
                        onPressed: store.useWordResults,
                        child: Text(l10n.searchKeepWords),
                      ),
                    if (failure == AiFailureCode.modelMissing.name ||
                        failure == AiFailureCode.invalidEmbedding.name)
                      TextButton(
                        onPressed: () =>
                            context.pushRoute(const EmbeddingModelsRoute()),
                        child: Text(l10n.embeddingModelManage),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}

class UnifiedSearchFooter extends StatelessWidget {
  const UnifiedSearchFooter({
    super.key,
    required this.store,
    required this.onEdit,
  });
  final HomeStore store;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final l10n = AppLocalizations.of(context)!;
      if (store.isSearching || store.searchQuery.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            if (store.displayedEntries.isEmpty &&
                store.searchError == null &&
                store.meaningError == null) ...[
              Text(
                l10n.noSearchResults,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.searchWordsEmptyHint, textAlign: TextAlign.center),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: onEdit,
                    child: Text(l10n.searchEditQuery),
                  ),
                ],
              ),
            ],
            if (store.loadMoreError != null)
              Semantics(
                liveRegion: true,
                child: Text(aiErrorMessage(l10n, store.loadMoreError!)),
              ),
            if (store.hasMoreResults && !store.searchNeedsRefresh)
              OutlinedButton(
                onPressed: store.isLoadingMore ? null : store.loadMore,
                child: Text(
                  store.isLoadingMore
                      ? l10n.searchLoadingMore
                      : store.loadMoreError != null
                      ? l10n.retry
                      : l10n.searchLoadMore,
                ),
              )
            else if (store.searchQuery.isNotEmpty &&
                store.displayedEntries.isNotEmpty &&
                !store.searchNeedsRefresh)
              Text(
                store.meaningRequested && store.meaningError == null
                    ? l10n.searchEndResults
                    : l10n.searchEndWordResults,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      );
    },
  );
}
