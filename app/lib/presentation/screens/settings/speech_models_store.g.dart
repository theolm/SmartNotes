// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_models_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SpeechModelsStore on _SpeechModelsStore, Store {
  Computed<SpeechRecommendation>? _$recommendationComputed;

  @override
  SpeechRecommendation get recommendation =>
      (_$recommendationComputed ??= Computed<SpeechRecommendation>(
        () => super.recommendation,
        name: '_SpeechModelsStore.recommendation',
      )).value;
  Computed<bool>? _$activeReadyComputed;

  @override
  bool get activeReady => (_$activeReadyComputed ??= Computed<bool>(
    () => super.activeReady,
    name: '_SpeechModelsStore.activeReady',
  )).value;
  Computed<List<SpeechModel>>? _$orderedCatalogComputed;

  @override
  List<SpeechModel> get orderedCatalog =>
      (_$orderedCatalogComputed ??= Computed<List<SpeechModel>>(
        () => super.orderedCatalog,
        name: '_SpeechModelsStore.orderedCatalog',
      )).value;
  Computed<bool>? _$activeUnavailableComputed;

  @override
  bool get activeUnavailable => (_$activeUnavailableComputed ??= Computed<bool>(
    () => super.activeUnavailable,
    name: '_SpeechModelsStore.activeUnavailable',
  )).value;
  Computed<int>? _$installedCountComputed;

  @override
  int get installedCount => (_$installedCountComputed ??= Computed<int>(
    () => super.installedCount,
    name: '_SpeechModelsStore.installedCount',
  )).value;
  Computed<int>? _$installedBytesComputed;

  @override
  int get installedBytes => (_$installedBytesComputed ??= Computed<int>(
    () => super.installedBytes,
    name: '_SpeechModelsStore.installedBytes',
  )).value;

  late final _$languageAtom = Atom(
    name: '_SpeechModelsStore.language',
    context: context,
  );

  @override
  String? get language {
    _$languageAtom.reportRead();
    return super.language;
  }

  @override
  set language(String? value) {
    _$languageAtom.reportWrite(value, super.language, () {
      super.language = value;
    });
  }

  late final _$activeIdAtom = Atom(
    name: '_SpeechModelsStore.activeId',
    context: context,
  );

  @override
  String get activeId {
    _$activeIdAtom.reportRead();
    return super.activeId;
  }

  @override
  set activeId(String value) {
    _$activeIdAtom.reportWrite(value, super.activeId, () {
      super.activeId = value;
    });
  }

  late final _$profileAtom = Atom(
    name: '_SpeechModelsStore.profile',
    context: context,
  );

  @override
  DeviceProfile get profile {
    _$profileAtom.reportRead();
    return super.profile;
  }

  @override
  set profile(DeviceProfile value) {
    _$profileAtom.reportWrite(value, super.profile, () {
      super.profile = value;
    });
  }

  late final _$loadingAtom = Atom(
    name: '_SpeechModelsStore.loading',
    context: context,
  );

  @override
  bool get loading {
    _$loadingAtom.reportRead();
    return super.loading;
  }

  @override
  set loading(bool value) {
    _$loadingAtom.reportWrite(value, super.loading, () {
      super.loading = value;
    });
  }

  late final _$busyAtom = Atom(
    name: '_SpeechModelsStore.busy',
    context: context,
  );

  @override
  bool get busy {
    _$busyAtom.reportRead();
    return super.busy;
  }

  @override
  set busy(bool value) {
    _$busyAtom.reportWrite(value, super.busy, () {
      super.busy = value;
    });
  }

  late final _$downloadingAtom = Atom(
    name: '_SpeechModelsStore.downloading',
    context: context,
  );

  @override
  bool get downloading {
    _$downloadingAtom.reportRead();
    return super.downloading;
  }

  @override
  set downloading(bool value) {
    _$downloadingAtom.reportWrite(value, super.downloading, () {
      super.downloading = value;
    });
  }

  late final _$activatingIdAtom = Atom(
    name: '_SpeechModelsStore.activatingId',
    context: context,
  );

  @override
  String? get activatingId {
    _$activatingIdAtom.reportRead();
    return super.activatingId;
  }

  @override
  set activatingId(String? value) {
    _$activatingIdAtom.reportWrite(value, super.activatingId, () {
      super.activatingId = value;
    });
  }

  late final _$errorAtom = Atom(
    name: '_SpeechModelsStore.error',
    context: context,
  );

  @override
  Object? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(Object? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    '_SpeechModelsStore.load',
    context: context,
  );

  @override
  Future<void> load(String? audioLanguage) {
    return _$loadAsyncAction.run(() => super.load(audioLanguage));
  }

  late final _$refreshAsyncAction = AsyncAction(
    '_SpeechModelsStore.refresh',
    context: context,
  );

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$activateAsyncAction = AsyncAction(
    '_SpeechModelsStore.activate',
    context: context,
  );

  @override
  Future<bool> activate(String id) {
    return _$activateAsyncAction.run(() => super.activate(id));
  }

  late final _$removeAsyncAction = AsyncAction(
    '_SpeechModelsStore.remove',
    context: context,
  );

  @override
  Future<void> remove(String id) {
    return _$removeAsyncAction.run(() => super.remove(id));
  }

  late final _$_SpeechModelsStoreActionController = ActionController(
    name: '_SpeechModelsStore',
    context: context,
  );

  @override
  void setLanguage(String? value) {
    final _$actionInfo = _$_SpeechModelsStoreActionController.startAction(
      name: '_SpeechModelsStore.setLanguage',
    );
    try {
      return super.setLanguage(value);
    } finally {
      _$_SpeechModelsStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
language: ${language},
activeId: ${activeId},
profile: ${profile},
loading: ${loading},
busy: ${busy},
downloading: ${downloading},
activatingId: ${activatingId},
error: ${error},
recommendation: ${recommendation},
activeReady: ${activeReady},
orderedCatalog: ${orderedCatalog},
activeUnavailable: ${activeUnavailable},
installedCount: ${installedCount},
installedBytes: ${installedBytes}
    ''';
  }
}
