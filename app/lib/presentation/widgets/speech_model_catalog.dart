import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/data/services/speech_model_service.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/presentation/screens/settings/speech_models_store.dart';
import 'package:smartnotes/presentation/widgets/audio_language_options.dart';
import 'package:smartnotes/presentation/widgets/local_model_size.dart';
import 'package:smartnotes/presentation/widgets/model_download_notice.dart';

String speechModelError(AppLocalizations l10n, Object error) {
  if (error is SpeechModelException) {
    return switch (error.problem) {
      SpeechModelProblem.storage => l10n.speechModelStorageError,
      SpeechModelProblem.inUse => l10n.speechModelInUseError,
      SpeechModelProblem.lastCompatible => l10n.speechModelLastError,
      _ => l10n.speechModelSelectError,
    };
  }
  return l10n.onboardingModelFailed;
}

class SpeechModelCatalog extends StatelessWidget {
  const SpeechModelCatalog({super.key, required this.store});
  final SpeechModelsStore store;

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
                RecommendationReason.unknown => l10n.speechModelEstimateUnknown,
                RecommendationReason.economical =>
                  l10n.speechModelEstimateEconomical,
                RecommendationReason.balanced =>
                  l10n.speechModelEstimateBalanced,
                RecommendationReason.powerful =>
                  l10n.speechModelEstimatePowerful,
              },
              style: text.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.speechModelEstimateDisclaimer, style: text.bodyMedium),
            if (store.activeUnavailable) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.speechModelActiveUnavailable,
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
                  speechModelError(l10n, store.error!),
                  style: text.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            for (final model in store.orderedCatalog)
              _ModelRow(store: store, model: model),
          ],
        );
      },
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.store, required this.model});
  final SpeechModelsStore store;
  final SpeechModel model;

  String _benefit(AppLocalizations l10n) => switch (model.kind) {
    SpeechModelKind.base => l10n.speechModelBaseBenefit,
    SpeechModelKind.smallEnglish => l10n.speechModelSmallEnglishBenefit,
    SpeechModelKind.mediumEnglish => l10n.speechModelMediumEnglishBenefit,
    SpeechModelKind.small => l10n.speechModelSmallBenefit,
    SpeechModelKind.turbo => l10n.speechModelTurboBenefit,
    SpeechModelKind.large => l10n.speechModelLargeBenefit,
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
        final compatible = model.supports(store.language);
        final state = store.states[model.id] ?? SpeechDownloadState.available;
        final activating = store.activatingId == model.id;
        final canActivate = installed && compatible && !active && !store.busy;
        final coverage = model.englishOnly
            ? l10n.speechModelEnglish
            : store.language == null
            ? l10n.speechModelAutomatic
            : l10n.speechModelMultilingual(
                audioLanguageOptions[store.language] ?? store.language!,
              );
        return Padding(
          key: ValueKey('model-row-${model.id}'),
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
                                              l10n.speechModelRecommended,
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
                                                l10n.speechModelActive,
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
                                    coverage,
                                    style: text.titleSmall,
                                  ),
                                ),
                                IconButton(
                                  tooltip: l10n.speechModelLanguages,
                                  onPressed: () =>
                                      _showLanguages(context, l10n),
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(_benefit(l10n), style: text.bodyMedium),
                            if (!compatible) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                l10n.speechModelIncompatible,
                                style: text.bodyMedium,
                              ),
                            ],
                            if ([
                              SpeechModelKind.mediumEnglish,
                              SpeechModelKind.turbo,
                              SpeechModelKind.large,
                            ].contains(model.kind)) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                l10n.speechModelHeavyWarning,
                                style: text.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _status(l10n, state, installed),
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

  String _status(
    AppLocalizations l10n,
    SpeechDownloadState state,
    bool installed,
  ) {
    return switch (state) {
      SpeechDownloadState.ready => l10n.speechModelInstalled,
      SpeechDownloadState.queued => l10n.speechModelQueued,
      SpeechDownloadState.downloading => l10n.onboardingModelProgress(
        (((store.received[model.id] ?? 0) / model.bytes) * 100).floor(),
      ),
      SpeechDownloadState.verifying => l10n.onboardingModelVerifying,
      SpeechDownloadState.checking => l10n.onboardingModelVerifying,
      SpeechDownloadState.failed => l10n.speechModelFailed,
      SpeechDownloadState.cancelled => l10n.speechModelCancelled,
      SpeechDownloadState.available =>
        (store.partial[model.id] ?? 0) > 0
            ? l10n.speechModelResume
            : l10n.speechModelAvailable,
    };
  }

  Widget _action(
    BuildContext context,
    AppLocalizations l10n,
    SpeechDownloadState state,
    bool installed,
    bool active,
    bool activating,
  ) {
    if (state == SpeechDownloadState.checking) {
      return const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(),
      );
    }
    if (activating) {
      return _pendingAction(
        context,
        key: ValueKey('activating-${model.id}'),
        tooltip: l10n.speechModelActivating,
        onPressed: null,
      );
    }
    if (state == SpeechDownloadState.queued ||
        state == SpeechDownloadState.downloading ||
        state == SpeechDownloadState.verifying) {
      return _pendingAction(
        context,
        key: ValueKey('cancel-${model.id}'),
        tooltip: l10n.cancel,
        onPressed: store.busy ? null : () => store.cancelDownload(model.id),
      );
    }
    if (installed) {
      return IconButton(
        key: ValueKey('delete-${model.id}'),
        tooltip: active ? l10n.speechModelActiveDeleteHint : l10n.delete,
        onPressed: active || store.busy
            ? null
            : () => _confirmDelete(context, l10n),
        icon: const Icon(Icons.delete_outline),
      );
    }
    final partial = (store.partial[model.id] ?? 0) > 0;
    return IconButton(
      key: ValueKey('download-${model.id}'),
      tooltip: state == SpeechDownloadState.failed
          ? l10n.speechModelRetry
          : partial
          ? l10n.speechModelResumeDownload
          : l10n.speechModelDownload,
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
        title: Text(l10n.speechModelRemoveTitle),
        content: Text(l10n.speechModelRemoveBody),
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

  void _showLanguages(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.speechModelLanguages),
        content: SingleChildScrollView(
          child: Text(
            model.englishOnly
                ? l10n.speechModelEnglish
                : '${l10n.speechModelAllLanguages}${model.kind == SpeechModelKind.turbo || model.kind == SpeechModelKind.large ? '\n\n${l10n.speechModelCantonese}' : ''}',
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
