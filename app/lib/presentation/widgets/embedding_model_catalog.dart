import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:smartnotes/presentation/screens/settings/embedding_models_store.dart';
import 'package:smartnotes/presentation/widgets/local_model_size.dart';
import 'package:smartnotes/presentation/widgets/model_download_notice.dart';
import 'package:smartnotes/presentation/widgets/model_catalog_tile.dart';
import 'package:smartnotes/presentation/widgets/embedding_model_status.dart';

/// Catalog policy stays here; all model families share the row presentation.
class EmbeddingModelCatalog extends StatefulWidget {
  const EmbeddingModelCatalog({super.key, required this.store});
  final EmbeddingModelsStore store;
  @override
  State<EmbeddingModelCatalog> createState() => _EmbeddingModelCatalogState();
}

class _EmbeddingModelCatalogState extends State<EmbeddingModelCatalog>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.store.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.store.load());
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(AppLocalizations.of(dialog)!.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(AppLocalizations.of(dialog)!.embeddingModelConfirm),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _download(EmbeddingModel model) async {
    if (model.family == EmbeddingFamily.gemma) {
      final l10n = AppLocalizations.of(context)!;
      final terms = await rootBundle.loadString(
        'assets/licenses/gemma-NOTICE.txt',
      );
      if (!mounted ||
          !await _confirm(
            l10n.embeddingModelTermsTitle,
            '${l10n.embeddingModelTermsMessage}\n\n$terms',
          )) {
        return;
      }
    }
    await widget.store.download(model.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.embeddingCatalogHelp,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Observer(
          builder: (_) => Semantics(
            liveRegion: true,
            child: Text(embeddingModelStatus(l10n, store)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ModelDownloadNotice(store: store.downloads),
        Observer(
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (store.loading || store.changing) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (store.activatingId != null) ...[
                Text(l10n.embeddingModelSwitching),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.embeddingModelSwitchingFromActive),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (store.failure != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    switch (store.failure!) {
                      EmbeddingCatalogFailure.activation =>
                        l10n.embeddingModelActivationFailed,
                      EmbeddingCatalogFailure.removal =>
                        l10n.embeddingModelRemovalFailed,
                      EmbeddingCatalogFailure.load => l10n.onboardingLoadFailed,
                      _ => l10n.onboardingModelFailed,
                    },
                    style: TextStyle(
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
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
        for (final model in store.catalog.where((m) => m.available))
          _row(model),
        if (store.catalog.any((m) => !m.available))
          ExpansionTile(
            key: const ValueKey('unavailable-embedding-models'),
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.embeddingModelsUnavailable),
            children: [
              for (final model in store.catalog.where((m) => !m.available))
                _row(model),
            ],
          ),
      ],
    );
  }

  Widget _row(EmbeddingModel model) {
    final store = widget.store;
    final l10n = AppLocalizations.of(context)!;
    return Observer(
      builder: (_) {
        final active = store.selectionLoaded && store.activeId == model.id;
        final ready = store.ready(model.id);
        final checking = store.states[model.id] == ModelCheckState.checking;
        final downloading = store.downloadingId == model.id;
        final pending =
            store.activatingId == model.id || store.removingId == model.id;
        final partial = (store.partial[model.id] ?? 0) > 0;
        final failed = store.failedDownloads.contains(model.id);
        final unavailable = model.family == EmbeddingFamily.e5
            ? l10n.embeddingModelE5Unavailable
            : l10n.embeddingModelUnsupported;
        final bytes = store.received[model.id] ?? 0;
        final status = !model.available
            ? unavailable
            : pending
            ? l10n.embeddingModelSwitching
            : checking
            ? l10n.onboardingModelVerifying
            : downloading
            ? bytes >= model.bytes
                  ? l10n.onboardingModelVerifying
                  : l10n.onboardingModelProgress(
                      ((bytes / model.bytes) * 100).floor(),
                    )
            : ready
            ? l10n.formattingModelInstalled
            : failed
            ? l10n.onboardingModelFailed
            : partial
            ? l10n.embeddingModelResume
            : l10n.formattingModelAvailable;
        final canDelete = ready;
        return ModelCatalogTile(
          key: ValueKey('embedding-model-${model.id}'),
          name: model.name,
          metadata:
              '${localModelSize(context, model.bytes)} · ${l10n.embeddingModelDimensions(model.dimensions)}',
          active: active,
          activeLabel: l10n.formattingModelActive,
          detailsTitle: l10n.searchSettingsTitle,
          description: l10n.embeddingModelSelectionHelp,
          status: status,
          onTap:
              ready &&
                  !active &&
                  model.available &&
                  !checking &&
                  !store.changing &&
                  !store.loading
              ? () async {
                  if (await _confirm(
                    l10n.embeddingModelSwitchTitle(model.name),
                    l10n.embeddingModelSwitchConfirmation,
                  )) {
                    await store.activate(model.id);
                  }
                }
              : null,
          detailsTooltip: l10n.formattingModelInfo,
          onDetails: () => _showDetails(model),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ModelCatalogActionButton(
                buttonKey: ValueKey(
                  'embedding-${downloading
                      ? 'cancel'
                      : canDelete
                      ? 'delete'
                      : 'download'}-${model.id}',
                ),
                action: downloading || pending
                    ? ModelCatalogAction.pending
                    : checking
                    ? ModelCatalogAction.checking
                    : canDelete
                    ? ModelCatalogAction.delete
                    : !model.available
                    ? ModelCatalogAction.unavailable
                    : ModelCatalogAction.download,
                tooltip: downloading
                    ? l10n.cancel
                    : pending
                    ? l10n.embeddingModelSwitching
                    : checking
                    ? l10n.onboardingModelVerifying
                    : canDelete
                    ? active
                          ? l10n.formattingModelActiveDeleteHint
                          : l10n.delete
                    : !model.available
                    ? unavailable
                    : failed
                    ? l10n.retry
                    : partial
                    ? l10n.embeddingModelResume
                    : l10n.embeddingModelDownload,
                onPressed: downloading
                    ? store.cancelDownload
                    : pending || checking || store.changing || store.loading
                    ? null
                    : canDelete
                    ? active
                          ? null
                          : () async {
                              if (await _confirm(
                                l10n.delete,
                                l10n.embeddingModelDeleteConfirmation,
                              )) {
                                await store.remove(model.id);
                              }
                            }
                    : !model.available || store.downloadingId != null
                    ? null
                    : () => _download(model),
              ),
              if (partial && !ready && !active && !downloading && !checking)
                ModelCatalogActionButton(
                  buttonKey: ValueKey('embedding-delete-${model.id}'),
                  action: ModelCatalogAction.delete,
                  tooltip: l10n.delete,
                  onPressed: store.changing || store.loading
                      ? null
                      : () async {
                          if (await _confirm(
                            l10n.delete,
                            l10n.embeddingModelDeleteConfirmation,
                          )) {
                            await store.remove(model.id);
                          }
                        },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showDetails(EmbeddingModel model) {
    final store = widget.store;
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(model.name),
        content: SingleChildScrollView(
          child: Text(
            '${l10n.embeddingModelDimensions(model.dimensions)}\n\n${l10n.embeddingModelSelectionHelp}\n\n${l10n.embeddingModelSwitchConfirmation}',
          ),
        ),
        actions: [
          Observer(
            builder: (_) => TextButton(
              onPressed:
                  model.available &&
                      store.ready(model.id) &&
                      !store.changing &&
                      store.downloadingId != model.id
                  ? () {
                      Navigator.pop(dialog);
                      unawaited(store.verify(model.id));
                    }
                  : null,
              child: Text(l10n.embeddingModelVerify),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
