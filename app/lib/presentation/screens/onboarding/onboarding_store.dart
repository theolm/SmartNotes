import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';
import 'package:mobx/mobx.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart';
import 'package:smartnotes/presentation/screens/settings/embedding_models_store.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';
import 'package:smartnotes/presentation/screens/settings/speech_models_store.dart';
import 'package:smartnotes/data/services/processing_feedback_service.dart';

part 'onboarding_store.g.dart';

enum OnboardingFailure { load, save, modelDownload }

enum OnboardingStep { welcome, language, speech, formatting, embedding }

@injectable
// ignore: library_private_types_in_public_api
class OnboardingStore = _OnboardingStore with _$OnboardingStore;

abstract class _OnboardingStore with Store {
  _OnboardingStore(
    this._settings,
    this._app,
    this._embeddingModels,
    this.speech,
    this.formatting, {
    ModelDownloadsStore? downloads,
    ProcessingFeedbackService? processingFeedback,
    // Passed through the public MobX alias by generated DI.
    // ignore: unused_element_parameter
    this.embeddings,
  }) : downloads = downloads ?? ModelDownloadsStore.unsupported(),
       _processingFeedback =
           processingFeedback ?? ProcessingFeedbackService.unsupported();
  final ModelDownloadsStore downloads;
  final EmbeddingModelsStore? embeddings;
  final SettingsStore _settings;
  final AppStore _app;
  final IEmbeddingModelService _embeddingModels;
  final SpeechModelsStore speech;
  final FormattingModelsStore formatting;
  final ProcessingFeedbackService _processingFeedback;
  bool get canBrowseJournal => _app.wasSetupCompleted;
  bool get shouldOfferNotificationPermission =>
      !_app.wasSetupCompleted &&
      _processingFeedback.supported &&
      !processingNotificationsAllowed &&
      !_settings.processingNotificationPromptHandled;

  Future<bool> requestProcessingNotifications() async {
    await _settings.markProcessingNotificationPromptHandled();
    processingNotificationsAllowed = await _processingFeedback
        .requestNotifications();
    return processingNotificationsAllowed;
  }

  Future<void> declineProcessingNotifications() =>
      _settings.markProcessingNotificationPromptHandled();
  void browseJournal() => _app.browseExistingJournal();
  @computed
  LocalAiModel get model =>
      EmbeddingModel.find(embeddings?.activeId ?? '') ?? _embeddingModels.model;
  @computed
  bool get selectedEmbeddingReady => embeddings == null
      ? embeddingModelReady
      : embeddings!.ready(embeddings!.activeId);
  @computed
  bool get modelReady => speech.activeReady;
  @computed
  bool get formattingReady => formatting.activeReady;
  @computed
  bool get currentModelReady => switch (step) {
    OnboardingStep.speech => modelReady,
    OnboardingStep.formatting => formattingReady,
    OnboardingStep.embedding => selectedEmbeddingReady,
    OnboardingStep.welcome || OnboardingStep.language => false,
  };
  @observable
  bool embeddingModelReady = false;
  @observable
  bool embeddingChecking = false;
  @observable
  bool embeddingDownloading = false;
  @observable
  ModelTransferState? embeddingTransferState;
  @computed
  bool get isDownloading =>
      embeddingDownloading || embeddings?.downloadingId != null;
  @observable
  int downloadedBytes = 0;
  @computed
  double get downloadProgress => downloadedBytes / model.bytes;
  @observable
  OnboardingStep step = OnboardingStep.welcome;
  @observable
  bool optionalFormattingEnabled = true;
  bool processingNotificationsAllowed = false;
  @observable
  bool working = true;
  @computed
  bool get isBusy =>
      working ||
      embeddingChecking ||
      speech.busy ||
      speech.loading ||
      formatting.busy ||
      formatting.downloading ||
      formatting.loading;
  @observable
  String? audioLanguage;
  @observable
  OnboardingFailure? error;
  @action
  Future<void> load() async {
    working = true;
    error = null;
    try {
      await _settings.load();
      processingNotificationsAllowed = await _processingFeedback
          .notificationsAllowed();
      audioLanguage = _settings.pendingAudioLanguage ?? _settings.audioLanguage;
      await speech.load(audioLanguage);
      if (speech.error != null) throw speech.error!;
      await formatting.load();
      await _checkEmbedding();
      if (embeddings != null) unawaited(embeddings!.load());
      optionalFormattingEnabled = !_app.wasSetupCompleted;
      if (_app.wasSetupCompleted) {
        step = !modelReady ? OnboardingStep.speech : OnboardingStep.embedding;
      }
    } catch (_) {
      error = OnboardingFailure.load;
    } finally {
      working = false;
    }
    await reconcileDownload();
  }

  Future<void> reconcileDownload() async {
    if (embeddingDownloading || working) return;
    try {
      await speech.refresh();
      await formatting.refresh();
      final transfers = await downloads.refresh();
      final transfer = transfers
          .where((item) => item.id == model.id)
          .firstOrNull;
      embeddingTransferState = transfer?.state;
      if (transfer != null && transfer.state.isActive) {
        step = OnboardingStep.embedding;
        downloadedBytes = transfer.received;
        unawaited(downloadModel());
      } else {
        await _checkEmbedding();
        if (!embeddingModelReady && transfer != null && modelReady) {
          step = OnboardingStep.embedding;
        }
        if (!embeddingModelReady &&
            transfer?.state == ModelTransferState.failed) {
          error = OnboardingFailure.modelDownload;
        }
      }
    } catch (_) {
      error = OnboardingFailure.load;
    }
  }

  Future<void> _checkEmbedding() async {
    embeddingChecking = true;
    try {
      embeddingModelReady = await _embeddingModels.isReady();
    } finally {
      embeddingChecking = false;
    }
  }

  @action
  void next() {
    if (isBusy ||
        step == OnboardingStep.embedding ||
        (step == OnboardingStep.speech && !modelReady)) {
      return;
    }
    step = switch (step) {
      OnboardingStep.welcome => OnboardingStep.language,
      OnboardingStep.language => OnboardingStep.speech,
      OnboardingStep.speech =>
        optionalFormattingEnabled
            ? OnboardingStep.formatting
            : OnboardingStep.embedding,
      OnboardingStep.formatting ||
      OnboardingStep.embedding => OnboardingStep.embedding,
    };
    downloadedBytes = 0;
    error = null;
  }

  @action
  void back() {
    if (!isBusy && step != OnboardingStep.welcome) {
      step = switch (step) {
        OnboardingStep.welcome ||
        OnboardingStep.language => OnboardingStep.welcome,
        OnboardingStep.speech => OnboardingStep.language,
        OnboardingStep.formatting => OnboardingStep.speech,
        OnboardingStep.embedding =>
          optionalFormattingEnabled
              ? OnboardingStep.formatting
              : OnboardingStep.speech,
      };
      downloadedBytes = 0;
      error = null;
    }
  }

  @action
  Future<void> selectLanguage(String? language) async {
    if (isBusy) return;
    audioLanguage = language;
    speech.setLanguage(language);
    await _settings.setPendingAudioLanguage(language);
  }

  @action
  Future<void> downloadModel() async {
    if (isBusy || step != OnboardingStep.embedding) return;
    error = null;
    working = embeddingDownloading = true;
    embeddingTransferState = ModelTransferState.downloading;
    try {
      if (embeddings != null) {
        await embeddings!.download(model.id);
      } else {
        await _embeddingModels.download(
          onProgress: (received, _) =>
              runInAction(() => downloadedBytes = received),
        );
      }
      embeddingModelReady = await _embeddingModels.isReady();
      embeddingTransferState = embeddingModelReady
          ? ModelTransferState.completed
          : ModelTransferState.failed;
      if (!embeddingModelReady) error = OnboardingFailure.modelDownload;
    } on ModelDownloadCancelled {
      embeddingTransferState = ModelTransferState.cancelled;
      // Preserve resumable partial files.
    } catch (_) {
      error = OnboardingFailure.modelDownload;
      embeddingTransferState = ModelTransferState.failed;
    } finally {
      working = embeddingDownloading = false;
    }
  }

  void cancelDownload() => _embeddingModels.cancelDownload();

  @action
  Future<bool> finish() async {
    if (isBusy || error == OnboardingFailure.load) return false;
    if (!modelReady || !selectedEmbeddingReady) {
      step = !modelReady ? OnboardingStep.speech : OnboardingStep.embedding;
      error = OnboardingFailure.modelDownload;
      return false;
    }
    if (!await speech.activate(speech.activeId)) {
      error = OnboardingFailure.modelDownload;
      return false;
    }
    working = true;
    error = null;
    try {
      await _settings.load();
      await _app.completeOnboarding();
      await _settings.setPendingAudioLanguage(null);
      return true;
    } catch (_) {
      error = OnboardingFailure.save;
      return false;
    } finally {
      working = false;
    }
  }
}
