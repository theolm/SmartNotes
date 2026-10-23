abstract class ISettingsService {
  String? getSpeechModelId();
  Future<void> setSpeechConfiguration(String modelId, String? language);

  String? getFormattingModelId();
  Future<void> setFormattingModelId(String? modelId);
  String? getFormattingModelSignature();
  Future<void> setFormattingModelSignature(String? signature);
  String? getPendingAudioLanguage();
  Future<void> setPendingAudioLanguage(String? languageCode);
  bool getOnboardingCompleted();
  Future<void> setOnboardingCompleted();
  bool getProcessingNotificationPromptHandled();
  Future<void> setProcessingNotificationPromptHandled();

  String? getThemeMode();
  Future<void> setThemeMode(String mode);

  String? getAudioLanguage();
  Future<void> setAudioLanguage(String? languageCode);

  String getAppLocale();
  Future<void> setAppLocale(String locale);

  bool getLockAppEnabled();
  Future<void> setLockAppEnabled(bool enabled);
}
