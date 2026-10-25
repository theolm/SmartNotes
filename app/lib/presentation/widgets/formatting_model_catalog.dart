import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/data/services/formatting_model_service.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart';
import 'package:smartnotes/presentation/widgets/local_model_size.dart';
import 'package:smartnotes/presentation/widgets/model_download_notice.dart';
import 'package:smartnotes/presentation/widgets/model_catalog_tile.dart';

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
            Text(switch (recommendation.reason) {
              FormattingRecommendationReason.unknown =>
                l10n.formattingModelEstimateUnknown,
              FormattingRecommendationReason.economical =>
                l10n.formattingModelEstimateEconomical,
              FormattingRecommendationReason.balanced =>
                l10n.formattingModelEstimateBalanced,
            }, style: text.bodyLarge),
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
    FormattingModelKind.quality => l10n.formattingModelCapabilityQuality,
  };
  String _memory(AppLocalizations l10n) => switch (model.kind) {
    FormattingModelKind.light => l10n.formattingModelMemoryLight,
    FormattingModelKind.balanced => l10n.formattingModelMemoryBalanced,
    FormattingModelKind.quality => l10n.formattingModelMemoryQuality,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Observer(
      builder: (_) {
        final installed = store.ready(model.id);
        final active = store.activeReady && store.activeId == model.id;
        final state =
            store.states[model.id] ?? FormattingDownloadState.available;
        return ModelCatalogTile(
          key: ValueKey('formatting-model-row-${model.id}'),
          name: model.name,
          metadata:
              '${localModelSize(context, model.bytes)} · ${model.quantization}',
          active: active,
          activeLabel: l10n.formattingModelActive,
          recommendedLabel: model.id == store.recommendation.model.id
              ? l10n.formattingModelRecommended
              : null,
          onTap: installed && !active && !store.busy
              ? () => store.activate(model.id)
              : null,
          detailsTitle: _capability(l10n),
          description: _memory(l10n),
          status: _status(l10n, state),
          detailsTooltip: l10n.formattingModelInfo,
          onDetails: () => _showDetails(context, l10n),
          trailing: _action(
            context,
            l10n,
            state,
            installed,
            active,
            store.activatingId == model.id,
          ),
        );
      },
    );
  }

  String _status(AppLocalizations l10n, FormattingDownloadState state) =>
      switch (state) {
        FormattingDownloadState.ready => l10n.formattingModelInstalled,
        FormattingDownloadState.queued => l10n.formattingModelQueued,
        FormattingDownloadState.downloading => l10n.onboardingModelProgress(
          (((store.received[model.id] ?? 0) / model.bytes) * 100).floor(),
        ),
        FormattingDownloadState.verifying ||
        FormattingDownloadState.checking => l10n.onboardingModelVerifying,
        FormattingDownloadState.failed => l10n.formattingModelFailed,
        FormattingDownloadState.cancelled => l10n.formattingModelCancelled,
        FormattingDownloadState.available =>
          (store.partial[model.id] ?? 0) > 0
              ? l10n.formattingModelResume
              : l10n.formattingModelAvailable,
      };

  Widget _action(
    BuildContext context,
    AppLocalizations l10n,
    FormattingDownloadState state,
    bool installed,
    bool active,
    bool activating,
  ) {
    if (state == FormattingDownloadState.checking) {
      return ModelCatalogActionButton(
        action: ModelCatalogAction.checking,
        tooltip: l10n.onboardingModelVerifying,
      );
    }
    if (activating) {
      return ModelCatalogActionButton(
        buttonKey: ValueKey('formatting-activating-${model.id}'),
        action: ModelCatalogAction.pending,
        tooltip: l10n.formattingModelActivating,
      );
    }
    if (state == FormattingDownloadState.queued ||
        state == FormattingDownloadState.downloading ||
        state == FormattingDownloadState.verifying) {
      return ModelCatalogActionButton(
        buttonKey: ValueKey('formatting-cancel-${model.id}'),
        action: ModelCatalogAction.pending,
        tooltip: l10n.cancel,
        onPressed: store.busy ? null : () => store.cancelDownload(model.id),
      );
    }
    if (installed) {
      return ModelCatalogActionButton(
        buttonKey: ValueKey('formatting-delete-${model.id}'),
        action: ModelCatalogAction.delete,
        tooltip: active ? l10n.formattingModelActiveDeleteHint : l10n.delete,
        onPressed: active || store.busy
            ? null
            : () => _confirmDelete(context, l10n),
      );
    }
    return ModelCatalogActionButton(
      buttonKey: ValueKey('formatting-download-${model.id}'),
      action: ModelCatalogAction.download,
      tooltip: state == FormattingDownloadState.failed
          ? l10n.formattingModelRetry
          : (store.partial[model.id] ?? 0) > 0
          ? l10n.formattingModelResumeDownload
          : l10n.formattingModelDownload,
      onPressed: store.busy ? null : () => _download(context, l10n),
    );
  }

  Future<void> _download(BuildContext context, AppLocalizations l10n) async {
    if (model.requiresGemmaTerms) {
      final terms = await rootBundle.loadString(
        'assets/licenses/gemma-NOTICE.txt',
      );
      if (!context.mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(l10n.formattingModelTermsTitle),
          content: Text('${l10n.formattingModelTermsMessage}\n\n$terms'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l10n.formattingModelAcceptTerms),
            ),
          ],
        ),
      );
      if (accepted != true || !context.mounted) return;
    }
    await store.downloadOne(model.id);
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
              Text(l10n.formattingModelCapabilities, style: text.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(_capability(l10n)),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.formattingModelLanguages, style: text.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.formattingModelAllLanguages),
              const SizedBox(height: AppSpacing.md),
              Text(_memory(l10n)),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.formattingModelNoteLimit),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${l10n.formattingModelLicense}: ${model.license} · ${localModelSize(context, model.bytes)} · ${model.quantization}',
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
