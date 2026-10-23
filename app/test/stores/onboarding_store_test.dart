import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/datasources/local/shared_preferences_settings_service.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:smartnotes/data/services/unsupported_platform_model_downloader.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';
import 'package:smartnotes/domain/failures/model_download_cancelled.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/presentation/screens/onboarding/onboarding_store.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';
import 'package:smartnotes/presentation/screens/settings/speech_models_store.dart';
import '../helpers/local_services.dart';
import 'package:smartnotes/data/services/processing_feedback_service.dart';

class MockLocalAuth extends Mock implements ILocalAuthService {}

class _Platform extends UnsupportedPlatformModelDownloader {
  _Platform(this.transfer);
  final ModelTransfer transfer;
  @override
  Future<List<ModelTransfer>> status() async => [transfer];
}

class FailingModels extends MemoryEmbeddingModels {
  FailingModels({this.cancelled = false}) : super(ready: false);
  bool fail = true;
  final bool cancelled;
  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    if (fail) {
      if (cancelled) throw const ModelDownloadCancelled();
      throw StateError('Unavailable');
    }
    await super.download(modelId: modelId, onProgress: onProgress);
  }
}

class FakeProcessingFeedback extends ProcessingFeedbackService {
  FakeProcessingFeedback() : super.unsupported();
  int requests = 0;

  @override
  bool get supported => true;

  @override
  Future<bool> notificationsAllowed() async => false;

  @override
  Future<bool> requestNotifications() async {
    requests++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesSettingsService settings;
  late SettingsStore preferences;
  late AppStore app;
  late MemorySpeechModels speech;
  late MemoryFormattingModels formatting;
  late MemoryEmbeddingModels embeddings;
  late OnboardingStore store;
  Future<void> load() async {
    store = OnboardingStore(
      preferences,
      app,
      embeddings,
      SpeechModelsStore(speech, MemoryDeviceProfile()),
      FormattingModelsStore(formatting, MemoryDeviceProfile()),
    );
    await store.load();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SharedPreferencesSettingsService(
      await SharedPreferences.getInstance(),
    );
    final auth = MockLocalAuth();
    when(() => auth.isAvailable()).thenAnswer((_) async => false);
    preferences = SettingsStore.forTesting(settings, auth);
    speech = MemorySpeechModels(settings: settings);
    formatting = MemoryFormattingModels();
    embeddings = MemoryEmbeddingModels();
    app = AppStore(auth, settings, speech, embeddings);
    await app.initialize();
    await load();
  });
  test('first run has five bounded steps, no credentials', () {
    store.back();
    expect(store.step, OnboardingStep.welcome);
    for (var i = 0; i < 8; i++) {
      store.next();
    }
    expect(store.step, OnboardingStep.embedding);
    expect(store.model, embeddings.model);
    store.back();
    expect(store.step, OnboardingStep.formatting);
    store.back();
    expect(store.step, OnboardingStep.speech);
  });
  test(
    'notification rationale is offered once and denial is accepted',
    () async {
      final feedback = FakeProcessingFeedback();
      store = OnboardingStore(
        preferences,
        app,
        embeddings,
        SpeechModelsStore(speech, MemoryDeviceProfile()),
        FormattingModelsStore(formatting, MemoryDeviceProfile()),
        processingFeedback: feedback,
      );
      await store.load();
      expect(store.shouldOfferNotificationPermission, true);
      expect(await store.requestProcessingNotifications(), false);
      expect(feedback.requests, 1);
      expect(store.shouldOfferNotificationPermission, false);
    },
  );
  for (final state in [
    ModelTransferState.failed,
    ModelTransferState.cancelled,
  ]) {
    test('restores persisted embedding ${state.name} after restart', () async {
      embeddings.ready = false;
      final downloads = ModelDownloadsStore(
        _Platform(
          ModelTransfer(
            id: embeddings.model.id,
            state: state,
            received: 20,
            total: embeddings.model.bytes,
          ),
        ),
      );
      addTearDown(downloads.dispose);
      store = OnboardingStore(
        preferences,
        app,
        embeddings,
        SpeechModelsStore(speech, MemoryDeviceProfile()),
        FormattingModelsStore(formatting, MemoryDeviceProfile()),
        downloads: downloads,
      );
      await store.load();
      expect(store.embeddingModelReady, false);
      expect(store.embeddingTransferState, state);
      expect(
        store.error,
        state == ModelTransferState.failed
            ? OnboardingFailure.modelDownload
            : isNull,
      );
    });
  }
  test('only speech and embeddings are mandatory', () async {
    speech.ready = embeddings.ready = false;
    await load();
    store.next();
    store.next();
    expect(store.step, OnboardingStep.speech);
    expect(await store.finish(), false);
    expect(store.step, OnboardingStep.speech);
    expect(settings.getOnboardingCompleted(), false);
    await store.speech.downloadOne(SpeechModel.whisperBaseQ8.id);
    expect(store.modelReady, true);
    store.next();
    expect(store.step, OnboardingStep.formatting);
    expect(await store.finish(), false);
    expect(store.step, OnboardingStep.embedding);
    await store.downloadModel();
    expect(store.currentModelReady, true);
    expect(await store.finish(), true);
  });
  test(
    'optional formatting model can be activated without blocking setup',
    () async {
      speech.ready = embeddings.ready = false;
      formatting.ready = false;
      await load();
      store.next();
      store.next();
      expect(store.step, OnboardingStep.speech);
      await store.speech.downloadOne(SpeechModel.whisperBaseQ8.id);
      store.next();
      expect(store.step, OnboardingStep.formatting);
      expect(store.formattingReady, false);
      await store.formatting.downloadOne(FormattingModel.qwen3_0_6b.id);
      expect(store.formattingReady, true);
      expect(store.step, OnboardingStep.formatting);
      store.next();
      expect(store.step, OnboardingStep.embedding);
      await store.downloadModel();
      expect(await store.finish(), true);
    },
  );
  test('repair mode skips the optional formatting step', () async {
    await app.completeOnboarding();
    await load();
    expect(store.step, OnboardingStep.embedding);
    expect(store.optionalFormattingEnabled, false);
    store.back();
    expect(store.step, OnboardingStep.speech);
    store.next();
    expect(store.step, OnboardingStep.embedding);
  });
  test('repair starts with missing speech before embeddings', () async {
    await app.completeOnboarding();
    speech.ready = embeddings.ready = false;
    await app.initialize();
    await load();
    expect(store.step, OnboardingStep.speech);
    expect(store.currentModelReady, false);
    store.next();
    expect(store.step, OnboardingStep.speech);
    await store.speech.downloadOne(SpeechModel.whisperBaseQ8.id);
    expect(store.currentModelReady, true);
    store.next();
    expect(store.step, OnboardingStep.embedding);
    expect(store.currentModelReady, false);
    await store.downloadModel();
    expect(store.currentModelReady, true);
    expect(await store.finish(), true);
  });
  test(
    'advancing past the last step preserves download failure state',
    () async {
      embeddings = FailingModels();
      await load();
      await store.finish();
      await store.downloadModel();
      expect(store.step, OnboardingStep.embedding);
      expect(store.error, OnboardingFailure.modelDownload);
      store.next();
      expect(store.step, OnboardingStep.embedding);
      expect(store.error, OnboardingFailure.modelDownload);
    },
  );
  for (final state in [
    FormattingDownloadState.downloading,
    FormattingDownloadState.verifying,
  ]) {
    test(
      'formatting $state blocks onboarding navigation and completion',
      () async {
        store.next();
        store.next();
        store.next();
        expect(store.step, OnboardingStep.formatting);
        store.formatting.downloading = true;
        store.formatting.states[FormattingModel.qwen3_0_6b.id] = state;
        expect(store.isBusy, true);
        store.next();
        expect(store.step, OnboardingStep.formatting);
        store.back();
        expect(store.step, OnboardingStep.formatting);
        expect(await store.finish(), false);
        expect(settings.getOnboardingCompleted(), false);
        store.formatting.downloading = false;
        store.next();
        expect(store.step, OnboardingStep.embedding);
        expect(await store.finish(), true);
      },
    );
  }
  test('language and completion survive restart without credentials', () async {
    await store.selectLanguage('pt');
    expect(await store.finish(), true);
    expect(settings.getAudioLanguage(), 'pt');
    await app.initialize();
    expect(app.hasCompletedOnboarding, true);
  });
  test(
    'a pending onboarding language survives reload before completion',
    () async {
      await store.selectLanguage('pt');
      await load();
      expect(store.audioLanguage, 'pt');
      expect(settings.getAudioLanguage(), isNull);
    },
  );
  test(
    'existing user downloads only missing embeddings and can browse notes',
    () async {
      await app.completeOnboarding();
      embeddings.ready = false;
      await app.initialize();
      await load();
      expect(store.step, OnboardingStep.embedding);
      expect(store.canBrowseJournal, true);
      expect(app.hasCompletedOnboarding, true);
      store.browseJournal();
      expect(app.browsingExistingJournal, true);
      await store.downloadModel();
      expect(await store.finish(), true);
    },
  );
  test('download failure supports retry and never completes setup', () async {
    final failing = FailingModels();
    embeddings = failing;
    await load();
    await store.finish();
    await store.downloadModel();
    expect(store.error, OnboardingFailure.modelDownload);
    expect(store.isBusy, false);
    expect(settings.getOnboardingCompleted(), false);
    failing.fail = false;
    await store.downloadModel();
    expect(store.embeddingModelReady, true);
    expect(store.error, isNull);
  });
  test('cancelled download leaves setup resumable without error', () async {
    embeddings = FailingModels(cancelled: true);
    await load();
    await store.finish();
    await store.downloadModel();
    expect(store.error, isNull);
    expect(store.embeddingModelReady, false);
    expect(await store.finish(), false);
  });
}
