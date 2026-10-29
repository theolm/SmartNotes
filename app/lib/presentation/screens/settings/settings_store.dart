import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import 'package:smartnotes/domain/entities/speech_acceleration.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_speech_acceleration_service.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';

part 'settings_store.g.dart';

@singleton
// ignore: library_private_types_in_public_api
class SettingsStore = _SettingsStore with _$SettingsStore;

abstract class _SettingsStore with Store {
  _SettingsStore(
    this._settingsService,
    this._localAuthService,
    ISpeechModelService speechModels, {
    ISpeechAccelerationService? acceleration,
  }) : _speechModels = speechModels,
       // ignore: prefer_initializing_formals
       _acceleration = acceleration;
  // ignore: unused_element
  _SettingsStore.forTesting(this._settingsService, this._localAuthService)
    : _speechModels = null,
      _acceleration = null;

  final ISpeechModelService? _speechModels;
  final ISpeechAccelerationService? _acceleration;

  final ISettingsService _settingsService;
  final ILocalAuthService _localAuthService;

  @observable
  ThemeMode themeMode = ThemeMode.system;

  @observable
  String? audioLanguage;

  @observable
  String appLocale = 'en';

  @observable
  bool lockAppEnabled = false;

  @observable
  bool lockAppAvailable = false;

  @observable
  bool isUpdatingLockApp = false;

  @observable
  bool gpuPreferred = true;

  @observable
  SpeechAccelerationStatus gpuStatus = const SpeechAccelerationStatus(
    state: SpeechAccelerationState.checking,
  );

  @observable
  bool isUpdatingGpu = false;

  @action
  Future<void> load() async {
    final savedTheme = _settingsService.getThemeMode();
    if (savedTheme != null) {
      themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == savedTheme,
        orElse: () => ThemeMode.system,
      );
    }
    audioLanguage = _settingsService.getAudioLanguage();
    appLocale = _settingsService.getAppLocale();
    lockAppEnabled = _settingsService.getLockAppEnabled();
    lockAppAvailable = await _localAuthService.isAvailable();
    gpuPreferred = _settingsService.getSpeechGpuPreferred();
    final acceleration = _acceleration;
    if (acceleration != null) {
      await acceleration.initialize();
      gpuStatus = await acceleration.status();
    }
  }

  @action
  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _settingsService.setThemeMode(mode.name);
  }

  String? get pendingAudioLanguage =>
      _settingsService.getPendingAudioLanguage();

  Future<void> setPendingAudioLanguage(String? code) =>
      _settingsService.setPendingAudioLanguage(code);

  bool get processingNotificationPromptHandled =>
      _settingsService.getProcessingNotificationPromptHandled();

  Future<void> markProcessingNotificationPromptHandled() =>
      _settingsService.setProcessingNotificationPromptHandled();

  @action
  Future<void> setAudioLanguage(String? code) async {
    if (_speechModels != null) {
      await _speechModels.activate(_speechModels.activeModelId, language: code);
    } else {
      await _settingsService.setAudioLanguage(code);
    }
    audioLanguage = code;
  }

  @action
  Future<void> setAppLocale(String locale) async {
    appLocale = locale;
    await _settingsService.setAppLocale(locale);
  }

  @action
  Future<void> refreshGpuStatus({bool probe = false, bool refresh = false}) async {
    final acceleration = _acceleration;
    if (acceleration == null) return;
    gpuStatus = await acceleration.status(probe: probe, refresh: refresh);
  }

  @action
  Future<void> setGpuPreferred(bool preferred) async {
    if (isUpdatingGpu) return;
    isUpdatingGpu = true;
    try {
      await _settingsService.setSpeechGpuPreferred(preferred);
      gpuPreferred = preferred;
      final acceleration = _acceleration;
      if (acceleration == null) return;
      if (preferred) {
        final current = await acceleration.status();
        gpuStatus = current.state == SpeechAccelerationState.circuitOpen
            ? await acceleration.resetCircuit()
            : await acceleration.status(refresh: true, probe: true);
      } else {
        gpuStatus = await acceleration.status(refresh: true);
      }
    } finally {
      isUpdatingGpu = false;
    }
  }

  /// Explicit retry after a GPU failure or an interrupted attempt.
  @action
  Future<void> retryGpu() async {
    if (isUpdatingGpu) return;
    isUpdatingGpu = true;
    try {
      await _settingsService.setSpeechGpuPreferred(true);
      gpuPreferred = true;
      final acceleration = _acceleration;
      if (acceleration != null) {
        gpuStatus = await acceleration.resetCircuit();
      }
    } finally {
      isUpdatingGpu = false;
    }
  }

  /// Enables or disables the app lock.
  ///
  /// Enabling requires a successful local authentication prompt first, so a
  /// user can never lock the app on a device they cannot unlock later.
  /// Returns whether the setting was actually applied.
  @action
  Future<bool> setLockAppEnabled(bool enabled, {required String reason}) async {
    if (isUpdatingLockApp) return lockAppEnabled == enabled;
    isUpdatingLockApp = true;
    try {
      if (enabled) {
        final result = await _localAuthService.authenticate(reason: reason);
        if (result != LocalAuthResult.success) {
          return false;
        }
      }
      lockAppEnabled = enabled;
      await _settingsService.setLockAppEnabled(enabled);
      return true;
    } finally {
      isUpdatingLockApp = false;
    }
  }
}
