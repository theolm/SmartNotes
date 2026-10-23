import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/data/services/formatting_model_service.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart';
import 'package:smartnotes/presentation/widgets/local_model_size.dart';
import 'package:smartnotes/presentation/widgets/model_download_notice.dart';

String formattingModelError(AppLocalizations l10n, Object error) {
  if (error is FormattingModelException) {
    return switch (error.problem) {
      FormattingModelProblem.storage => l10n.formattingModelStorageError,
      FormattingModelProblem.inUse => l10n.formattingModelInUseError,
      _ => l10n.formattingModelSelectError,
    };
  }
  return l10n.onboardingModelFailed;
}

class FormattingModelCatalog extends StatelessWidget {
  const FormattingModelCatalog({super.key, required this.store});

  final FormattingModelsStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Observer(
      builder: (_) {
        if (store.loading) return const LinearProgressIndicator();
        final recommendation = store.recommendation;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModelDownloadNotice(store: store.downloads),
            Text(
              switch (recommendation.reason) {
                FormattingRecommendationReason.unknown =>
                  l10n.formattingModelEstimateUnknown,
                FormattingRecommendationReason.economical =>
                  l10n.formattingModelEstimateEconomical,
                FormattingRecommendationReason.balanced =>
                  l10n.formattingModelEstimateBalanced,
              },
              style: text.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.formattingModelEstimateDisclaimer,
              style: text.bodyMedium,
            ),
            if (store.activeUnavailable) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.formattingModelActiveUnavailable,
                  style: text.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            if (store.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  formattingModelError(l10n, store.error!),
                  style: text.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: store.load,
                  child: Text(l10n.retry),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            for (final model in store.orderedCatalog)
              _FormattingModelRow(store: store, model: model),
          ],
        );
      },
    );
  }
}

class _FormattingModelRow extends StatelessWidget {
  const _FormattingModelRow({required this.store, required this.model});

  final FormattingModelsStore store;
  final FormattingModel model;

  String _capability(AppLocalizations l10n) => switch (model.kind) {
    FormattingModelKind.light => l10n.formattingModelCapabilityLight,
    FormattingModelKind.balanced => l10n.formattingModelCapabilityBalanced,
  };

  String _memory(AppLocalizations l10n) => switch (model.kind) {
    FormattingModelKind.light => l10n.formattingModelMemoryLight,
    FormattingModelKind.balanced => l10n.formattingModelMemoryBalanced,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Observer(
      builder: (_) {
        final installed = store.ready(model.id);
        final active = store.activeReady && store.activeId == model.id;
        final state =
            store.states[model.id] ?? FormattingDownloadState.available;
        final activating = store.activatingId == model.id;
        final canActivate = installed && !active && !store.busy;
        return Padding(
          key: ValueKey('formatting-model-row-${model.id}'),
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? colors.primary : colors.outlineVariant,
                width: active ? 2 : 1,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(11),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: canActivate ? () => store.activate(model.id) : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child:
                                  active ||
                                      model.id == store.recommendation.model.id
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.xs,
                                      ),
                                      child: Wrap(
                                        spacing: AppSpacing.md,
                                        runSpacing: AppSpacing.xs,
                                        children: [
                                          if (model.id ==
                                              store.recommendation.model.id)
                                            Text(
                                              l10n.formattingModelRecommended,
                                              style: text.labelMedium?.copyWith(
                                                color: colors.primary,
                                              ),
                                            ),
                                          if (active)
                                            TweenAnimationBuilder<double>(
                                              tween: Tween(
                                                begin: 0,
                                                end: 1,
                                              ),
                                              duration: const Duration(
                                                milliseconds: 160,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              builder:
                                                  (context, value, child) =>
                                                      Opacity(
                                                        opacity: value,
                                                        child: child,
                                                      ),
                                              child: Text(
                                                l10n.formattingModelActive,
                                                style: text.labelMedium
                                                    ?.copyWith(
                                                      color: colors.primary,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            Text(model.name, style: text.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${localModelSize(context, model.bytes)} · ${model.quantization}',
                              style: text.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _capability(l10n),
                                    style: text.titleSmall,
                                  ),
                                ),
                                IconButton(
                                  tooltip: l10n.formattingModelInfo,
                                  onPressed: () => _showDetails(context, l10n),
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(_memory(l10n), style: text.bodyMedium),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _status(l10n, state),
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _action(
                        context,
                        l10n,
                        state,
                        installed,
                        active,
                        activating,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _status(AppLocalizations l10n, FormattingDownloadState state) {
    return switch (state) {
      FormattingDownloadState.ready => l10n.formattingModelInstalled,
      FormattingDownloadState.queued => l10n.formattingModelQueued,
      FormattingDownloadState.downloading => l10n.onboardingModelProgress(
        (((store.received[model.id] ?? 0) / model.bytes) * 100).floor(),
      ),
      FormattingDownloadState.verifying => l10n.onboardingModelVerifying,
      FormattingDownloadState.checking => l10n.onboardingModelVerifying,
      FormattingDownloadState.failed => l10n.formattingModelFailed,
      FormattingDownloadState.cancelled => l10n.formattingModelCancelled,
      FormattingDownloadState.available =>
        (store.partial[model.id] ?? 0) > 0
            ? l10n.formattingModelResume
            : l10n.formattingModelAvailable,
    };
  }

  Widget _action(
    BuildContext context,
    AppLocalizations l10n,
    FormattingDownloadState state,
    bool installed,
    bool active,
    bool activating,
  ) {
    if (state == FormattingDownloadState.checking) {
      return const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(),
      );
    }
    if (activating) {
      return _pendingAction(
        context,
        key: ValueKey('formatting-activating-${model.id}'),
        tooltip: l10n.formattingModelActivating,
        onPressed: null,
      );
    }
    if (state == FormattingDownloadState.queued ||
        state == FormattingDownloadState.downloading ||
        state == FormattingDownloadState.verifying) {
      return _pendingAction(
        context,
        key: ValueKey('formatting-cancel-${model.id}'),
        tooltip: l10n.cancel,
        onPressed: store.busy ? null : () => store.cancelDownload(model.id),
      );
    }
    if (installed) {
      return IconButton(
        key: ValueKey('formatting-delete-${model.id}'),
        tooltip: active ? l10n.formattingModelActiveDeleteHint : l10n.delete,
        onPressed: active || store.busy
            ? null
            : () => _confirmDelete(context, l10n),
        icon: const Icon(Icons.delete_outline),
      );
    }
    final partial = (store.partial[model.id] ?? 0) > 0;
    return IconButton(
      key: ValueKey('formatting-download-${model.id}'),
      tooltip: state == FormattingDownloadState.failed
          ? l10n.formattingModelRetry
          : partial
          ? l10n.formattingModelResumeDownload
          : l10n.formattingModelDownload,
      onPressed: store.busy ? null : () => store.downloadOne(model.id),
      icon: const Icon(Icons.download_outlined),
    );
  }

  Widget _pendingAction(
    BuildContext context, {
    Key? key,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.formattingModelRemoveTitle),
        content: Text(l10n.formattingModelRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.remove(model.id);
  }

  void _showDetails(BuildContext context, AppLocalizations l10n) {
    final text = Theme.of(context).textTheme;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(model.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.formattingModelCapabilities,
                style: text.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(_capability(l10n)),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.formattingModelLanguages,
                style: text.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.formattingModelAllLanguages),
              const SizedBox(height: AppSpacing.md),
              Text(_memory(l10n)),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.formattingModelNoteLimit),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${l10n.formattingModelLicense}: Apache-2.0 · ${localModelSize(context, model.bytes)} · ${model.quantization}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
