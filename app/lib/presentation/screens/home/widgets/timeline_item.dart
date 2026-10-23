import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/processing_feedback.dart';
import 'package:smartnotes/domain/entities/search_result.dart';
import 'search_excerpt.dart';

class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.entry,
    this.onRetry,
    this.onDelete,
    this.feedback,
    this.showDate = false,
    this.searchResult,
  });

  final JournalEntry entry;
  final VoidCallback? onRetry;
  final Future<void> Function()? onDelete;
  final ProcessingFeedback? feedback;
  final bool showDate;
  final SearchResult? searchResult;

  String get _preview {
    final text = entry.body;
    // Layout only needs a few lines, not a multi-megabyte recording transcript.
    if (text.length <= 600) return text;
    var end = 600;
    if (text.codeUnitAt(end - 1) >= 0xD800 &&
        text.codeUnitAt(end - 1) <= 0xDBFF) {
      end--;
    }
    return '${text.substring(0, end)}…';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final time = (showDate ? DateFormat.yMMMd().add_Hm() : DateFormat.Hm())
        .format(entry.effectiveEntryDate);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    final isError = entry.status == EntryStatus.error;
    final isProcessing = entry.status == EntryStatus.processing;
    final activeFeedback = feedback?.entryId == entry.id ? feedback : null;
    final title = isError
        ? l10n.processingFailed
        : (entry.title?.trim().isNotEmpty == true ? entry.title! : null);

    return Slidable(
      key: ValueKey(entry.id),
      endActionPane: onDelete == null
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => onDelete!(),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  icon: Icons.delete_outline,
                  label: l10n.delete,
                ),
              ],
            ),
      child: InkWell(
        onTap: isProcessing
            ? null
            : isError
            ? () => _showErrorBottomSheet(
                context,
                onRetry: onRetry,
              )
            : () => context.pushRoute(EntryDetailRoute(entryId: entry.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Curves.easeOutCubic,
                  child: searchResult != null
                      ? SearchExcerpt(
                          result: searchResult!,
                          current: entry,
                          dateLabel: time,
                        )
                      : !isProcessing && !isError && entry.body.isNotEmpty
                      ? Text(
                          _preview,
                          key: const ValueKey('preview'),
                          style: Theme.of(context).textTheme.bodyLarge,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        )
                      : const SizedBox.shrink(key: ValueKey('pending')),
                ),
                if (searchResult == null ||
                    isError ||
                    isProcessing ||
                    activeFeedback != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (searchResult == null)
                        Text(
                          time,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      AnimatedSwitcher(
                        duration: duration,
                        child: isError
                            ? _ErrorIndicator(onRetry: onRetry, l10n: l10n)
                            : isProcessing || activeFeedback != null
                            ? _ProcessingPill(
                                l10n: l10n,
                                feedback: activeFeedback,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorIndicator extends StatelessWidget {
  const _ErrorIndicator({this.onRetry, required this.l10n});

  final VoidCallback? onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          l10n.error,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(
          Icons.replay,
          size: 18,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}

void _showErrorBottomSheet(
  BuildContext context, {
  VoidCallback? onRetry,
}) {
  final l10n = AppLocalizations.of(context)!;

  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(ctx).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.processingFailed,
              style: Theme.of(ctx).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onRetry?.call();
                },
                child: Text(l10n.retry),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProcessingPill extends StatelessWidget {
  const _ProcessingPill({required this.l10n, this.feedback});

  final AppLocalizations l10n;
  final ProcessingFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final label = switch (feedback?.phase) {
      ProcessingPhase.preparingTranscription =>
        l10n.processingPreparingTranscription,
      ProcessingPhase.transcribing => l10n.processingTranscribingAudio,
      ProcessingPhase.preparingSearch =>
        '${l10n.processingNoteReadyTitle} · ${l10n.processingPreparingSearch}',
      ProcessingPhase.finalizing => l10n.processingFinalizing,
      null => l10n.processing,
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
