import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';

part 'settings_store.g.dart';

@singleton
// ignore: library_private_types_in_public_api
class SettingsStore = _SettingsStore with _$SettingsStore;

abstract class _SettingsStore with Store {
  _SettingsStore(
    this._settingsService,
    this._localAuthService,
    ISpeechModelService speechModels,
  ) : _speechModels = speechModels;
  // ignore: unused_element
  _SettingsStore.forTesting(this._settingsService, this._localAuthService)
    : _speechModels = null;

  final ISpeechModelService? _speechModels;

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
