import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartnotes/domain/services/i_settings_service.dart';

@Injectable(as: ISettingsService)
class SharedPreferencesSettingsService implements ISettingsService {
  SharedPreferencesSettingsService(this._prefs);

  final SharedPreferences _prefs;

  Map<String, dynamic>? get _speechConfiguration {
    final raw = _prefs.getString('speechConfiguration');
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic> &&
          value['modelId'] is String &&
          (value['language'] == null || value['language'] is String)) {
        return value;
      }
    } on FormatException {
      // Invalid persisted configuration requires explicit repair.
    }
    return {'modelId': 'invalid'};
  }

  @override
  String? getSpeechModelId() => _speechConfiguration?['modelId'] as String?;

  @override
  Future<void> setSpeechConfiguration(String modelId, String? language) async {
    if (!await _prefs.setString(
      'speechConfiguration',
      jsonEncode({'modelId': modelId, 'language': language}),
    )) {
      throw StateError('Could not persist transcription configuration.');
    }
  }

  static const _formattingModelKey = 'formattingModelId';

  @override
  String? getFormattingModelId() => _prefs.getString(_formattingModelKey);

  @override
  Future<void> setFormattingModelId(String? modelId) async {
    final saved = modelId == null || modelId.isEmpty
        ? await _prefs.remove(_formattingModelKey)
        : await _prefs.setString(_formattingModelKey, modelId);
    if (!saved) {
      throw StateError('Could not persist formatting model selection.');
    }
  }

  static const _formattingSignatureKey = 'formattingModelSignature';

  @override
  String? getFormattingModelSignature() =>
      _prefs.getString(_formattingSignatureKey);

  @override
  Future<void> setFormattingModelSignature(String? signature) async {
    final saved = signature == null
        ? await _prefs.remove(_formattingSignatureKey)
        : await _prefs.setString(_formattingSignatureKey, signature);
    if (!saved) {
      throw StateError('Could not persist formatting model verification.');
    }
  }

  @override
  String? getPendingAudioLanguage() => _prefs.getString('pendingAudioLanguage');

  @override
  Future<void> setPendingAudioLanguage(String? languageCode) async {
    if (languageCode == null) {
      await _prefs.remove('pendingAudioLanguage');
    } else {
      await _prefs.setString('pendingAudioLanguage', languageCode);
    }
  }

  @override
  bool getOnboardingCompleted() =>
      _prefs.getBool('onboardingCompleted') ?? false;

  @override
  Future<void> setOnboardingCompleted() async {
    if (!await _prefs.setBool('onboardingCompleted', true)) {
      throw StateError('Could not persist onboarding completion.');
    }
  }

  @override
  bool getProcessingNotificationPromptHandled() =>
      _prefs.getBool('processingNotificationPromptHandled') ?? false;

  @override
  Future<void> setProcessingNotificationPromptHandled() async {
    if (!await _prefs.setBool('processingNotificationPromptHandled', true)) {
      throw StateError('Could not persist notification prompt state.');
    }
  }

  static const _themeModeKey = 'themeMode';
  static const _audioLanguageKey = 'audioLanguage';
  static const _appLocaleKey = 'appLocale';
  static const _lockAppKey = 'lockAppEnabled';

  @override
  String? getThemeMode() => _prefs.getString(_themeModeKey);

  @override
  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_themeModeKey, mode);
  }

  @override
  String? getAudioLanguage() => _speechConfiguration != null
      ? _speechConfiguration!['language'] as String?
      : _prefs.getString(_audioLanguageKey);

  @override
  Future<void> setAudioLanguage(String? languageCode) async {
    final id = getSpeechModelId();
    if (id != null) {
      await setSpeechConfiguration(id, languageCode);
      return;
    }
    if (languageCode == null) {
      await _prefs.remove(_audioLanguageKey);
    } else {
      await _prefs.setString(_audioLanguageKey, languageCode);
    }
  }

  @override
  String getAppLocale() => _prefs.getString(_appLocaleKey) ?? 'en';

  @override
  Future<void> setAppLocale(String locale) async {
    await _prefs.setString(_appLocaleKey, locale);
  }

  @override
  bool getLockAppEnabled() => _prefs.getBool(_lockAppKey) ?? false;

  @override
  Future<void> setLockAppEnabled(bool enabled) async {
    await _prefs.setBool(_lockAppKey, enabled);
  }
}
