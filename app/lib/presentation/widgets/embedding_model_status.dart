import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:smartnotes/presentation/screens/settings/embedding_models_store.dart';

/// Shared wording for the Settings destination and the selected-model panel.
String embeddingModelStatus(AppLocalizations l10n, EmbeddingModelsStore store) {
  if (!store.selectionLoaded) {
    return store.failure == EmbeddingCatalogFailure.load
        ? l10n.onboardingLoadFailed
        : l10n.embeddingModelCheckingSelection;
  }
  if (store.downloadingId == store.activeId) {
    final bytes = store.received[store.activeId] ?? 0;
    return bytes >= (store.activeModel?.bytes ?? 1)
        ? l10n.onboardingModelVerifying
        : l10n.embeddingModelDownloading;
  }
  return switch (store.activeState) {
    ModelCheckState.ready => l10n.embeddingModelReady,
    ModelCheckState.missing => l10n.embeddingModelDownloadNeeded,
    ModelCheckState.corrupt ||
    ModelCheckState.failed => l10n.embeddingModelRepairNeeded,
    ModelCheckState.unchecked ||
    ModelCheckState.checking => l10n.onboardingModelVerifying,
  };
}
