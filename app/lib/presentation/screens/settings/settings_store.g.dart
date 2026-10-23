// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SettingsStore on _SettingsStore, Store {
  late final _$themeModeAtom = Atom(
    name: '_SettingsStore.themeMode',
    context: context,
  );

  @override
  ThemeMode get themeMode {
    _$themeModeAtom.reportRead();
    return super.themeMode;
  }

  @override
  set themeMode(ThemeMode value) {
    _$themeModeAtom.reportWrite(value, super.themeMode, () {
      super.themeMode = value;
    });
  }

  late final _$audioLanguageAtom = Atom(
    name: '_SettingsStore.audioLanguage',
    context: context,
  );

  @override
  String? get audioLanguage {
    _$audioLanguageAtom.reportRead();
    return super.audioLanguage;
  }

  @override
  set audioLanguage(String? value) {
    _$audioLanguageAtom.reportWrite(value, super.audioLanguage, () {
      super.audioLanguage = value;
    });
  }

  late final _$appLocaleAtom = Atom(
    name: '_SettingsStore.appLocale',
    context: context,
  );

  @override
  String get appLocale {
    _$appLocaleAtom.reportRead();
    return super.appLocale;
  }

  @override
  set appLocale(String value) {
    _$appLocaleAtom.reportWrite(value, super.appLocale, () {
      super.appLocale = value;
    });
  }

  late final _$lockAppEnabledAtom = Atom(
    name: '_SettingsStore.lockAppEnabled',
    context: context,
  );

  @override
  bool get lockAppEnabled {
    _$lockAppEnabledAtom.reportRead();
    return super.lockAppEnabled;
  }

  @override
  set lockAppEnabled(bool value) {
    _$lockAppEnabledAtom.reportWrite(value, super.lockAppEnabled, () {
      super.lockAppEnabled = value;
    });
  }

  late final _$lockAppAvailableAtom = Atom(
    name: '_SettingsStore.lockAppAvailable',
    context: context,
  );

  @override
  bool get lockAppAvailable {
    _$lockAppAvailableAtom.reportRead();
    return super.lockAppAvailable;
  }

  @override
  set lockAppAvailable(bool value) {
    _$lockAppAvailableAtom.reportWrite(value, super.lockAppAvailable, () {
      super.lockAppAvailable = value;
    });
  }

  late final _$isUpdatingLockAppAtom = Atom(
    name: '_SettingsStore.isUpdatingLockApp',
    context: context,
  );

  @override
  bool get isUpdatingLockApp {
    _$isUpdatingLockAppAtom.reportRead();
    return super.isUpdatingLockApp;
  }

  @override
  set isUpdatingLockApp(bool value) {
    _$isUpdatingLockAppAtom.reportWrite(value, super.isUpdatingLockApp, () {
      super.isUpdatingLockApp = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    '_SettingsStore.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$setThemeModeAsyncAction = AsyncAction(
    '_SettingsStore.setThemeMode',
    context: context,
  );

  @override
  Future<void> setThemeMode(ThemeMode mode) {
    return _$setThemeModeAsyncAction.run(() => super.setThemeMode(mode));
  }

  late final _$setAudioLanguageAsyncAction = AsyncAction(
    '_SettingsStore.setAudioLanguage',
    context: context,
  );

  @override
  Future<void> setAudioLanguage(String? code) {
    return _$setAudioLanguageAsyncAction.run(
      () => super.setAudioLanguage(code),
    );
  }

  late final _$setAppLocaleAsyncAction = AsyncAction(
    '_SettingsStore.setAppLocale',
    context: context,
  );

  @override
  Future<void> setAppLocale(String locale) {
    return _$setAppLocaleAsyncAction.run(() => super.setAppLocale(locale));
  }

  late final _$setLockAppEnabledAsyncAction = AsyncAction(
    '_SettingsStore.setLockAppEnabled',
    context: context,
  );

  @override
  Future<bool> setLockAppEnabled(bool enabled, {required String reason}) {
    return _$setLockAppEnabledAsyncAction.run(
      () => super.setLockAppEnabled(enabled, reason: reason),
    );
  }

  @override
  String toString() {
    return '''
themeMode: ${themeMode},
audioLanguage: ${audioLanguage},
appLocale: ${appLocale},
lockAppEnabled: ${lockAppEnabled},
lockAppAvailable: ${lockAppAvailable},
isUpdatingLockApp: ${isUpdatingLockApp}
    ''';
  }
}
