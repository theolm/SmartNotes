import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';

import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';

part 'app_store.g.dart';

@singleton
// ignore: library_private_types_in_public_api
class AppStore = _AppStore with _$AppStore;

abstract class _AppStore with Store {
  _AppStore(
    this._localAuthService,
    this._settingsService,
    this._models,
    this._embeddingModels,
  );

  final ILocalAuthService _localAuthService;
  final ISettingsService _settingsService;
  final ISpeechModelService _models;
  final IEmbeddingModelService _embeddingModels;
  bool get wasSetupCompleted => _settingsService.getOnboardingCompleted();
  final modelChecks = ObservableMap<String, ModelCheckState>();
  Future<void>? _modelChecks;

  /// Called only after rendering; model errors never affect journal routing.
  Future<void> checkModels() =>
      _modelChecks ??= _checkModels().whenComplete(() => _modelChecks = null);

  Future<void> _checkModels() async {
    if (!hasCompletedOnboarding) return;
    Future<void> check(
      String name,
      Future<ModelCheckState> Function() work,
    ) async {
      runInAction(() => modelChecks[name] = ModelCheckState.checking);
      try {
        final result = await work();
        runInAction(() => modelChecks[name] = result);
      } catch (_) {
        runInAction(() => modelChecks[name] = ModelCheckState.failed);
      }
    }

    await Future.wait([
      check('speech', () => _models.readiness(verify: true)),
      check('embedding', () => _embeddingModels.readiness(verify: true)),
    ]);
  }

  @observable
  bool browsingExistingJournal = false;
  @action
  void browseExistingJournal() {
    if (wasSetupCompleted) {
      browsingExistingJournal = true;
    }
  }

  @observable
  bool isInitialized = false;

  @observable
  bool hasCompletedOnboarding = false;

  @action
  Future<void> completeOnboarding() async {
    await _models.requireModelPath();
    await _embeddingModels.requireModelPath();
    await _settingsService.setOnboardingCompleted();
    hasCompletedOnboarding = true;
  }

  @observable
  bool isLocked = false;

  @observable
  String? lockErrorMessage;

  @computed
  bool get isUnlocked => isInitialized && !isLocked;

  @action
  Future<void> initialize() async {
    // Completed setup is independent of replaceable AI weights. Never read a
    // model here: this runs before runApp and initializes the route guard.
    try {
      isLocked = _settingsService.getLockAppEnabled();
      hasCompletedOnboarding = _settingsService.getOnboardingCompleted();
      lockErrorMessage = null;
    } catch (_) {
      isLocked = true;
      lockErrorMessage = 'Could not read local settings. Unlock to continue.';
    }
    isInitialized = true;
  }

  @action
  Future<bool> unlock({required String reason}) async {
    lockErrorMessage = null;
    final result = await _localAuthService.authenticate(reason: reason);
    if (result == LocalAuthResult.success) {
      isLocked = false;
      return true;
    }
    isLocked = true;
    lockErrorMessage = switch (result) {
      LocalAuthResult.cancelled => 'Authentication cancelled',
      LocalAuthResult.unavailable =>
        'No biometrics or device credentials are available on this device',
      LocalAuthResult.failed => 'Could not unlock. Try again.',
      LocalAuthResult.success => null,
    };
    return false;
  }
}
