// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'formatting_models_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FormattingModelsStore on _FormattingModelsStore, Store {
  Computed<FormattingRecommendation>? _$recommendationComputed;

  @override
  FormattingRecommendation get recommendation =>
      (_$recommendationComputed ??= Computed<FormattingRecommendation>(
        () => super.recommendation,
        name: '_FormattingModelsStore.recommendation',
      )).value;
  Computed<bool>? _$activeReadyComputed;

  @override
  bool get activeReady => (_$activeReadyComputed ??= Computed<bool>(
    () => super.activeReady,
    name: '_FormattingModelsStore.activeReady',
  )).value;
  Computed<List<FormattingModel>>? _$orderedCatalogComputed;

  @override
  List<FormattingModel> get orderedCatalog =>
      (_$orderedCatalogComputed ??= Computed<List<FormattingModel>>(
        () => super.orderedCatalog,
        name: '_FormattingModelsStore.orderedCatalog',
      )).value;
  Computed<bool>? _$activeUnavailableComputed;

  @override
  bool get activeUnavailable => (_$activeUnavailableComputed ??= Computed<bool>(
    () => super.activeUnavailable,
    name: '_FormattingModelsStore.activeUnavailable',
  )).value;
  Computed<int>? _$installedCountComputed;

  @override
  int get installedCount => (_$installedCountComputed ??= Computed<int>(
    () => super.installedCount,
    name: '_FormattingModelsStore.installedCount',
  )).value;
  Computed<int>? _$installedBytesComputed;

  @override
  int get installedBytes => (_$installedBytesComputed ??= Computed<int>(
    () => super.installedBytes,
    name: '_FormattingModelsStore.installedBytes',
  )).value;

  late final _$activeIdAtom = Atom(
    name: '_FormattingModelsStore.activeId',
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
    name: '_FormattingModelsStore.profile',
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
    name: '_FormattingModelsStore.loading',
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
    name: '_FormattingModelsStore.busy',
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
    name: '_FormattingModelsStore.downloading',
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
    name: '_FormattingModelsStore.activatingId',
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
    name: '_FormattingModelsStore.error',
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
    '_FormattingModelsStore.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$refreshAsyncAction = AsyncAction(
    '_FormattingModelsStore.refresh',
    context: context,
  );

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$activateAsyncAction = AsyncAction(
    '_FormattingModelsStore.activate',
    context: context,
  );

  @override
  Future<bool> activate(String id) {
    return _$activateAsyncAction.run(() => super.activate(id));
  }

  late final _$removeAsyncAction = AsyncAction(
    '_FormattingModelsStore.remove',
    context: context,
  );

  @override
  Future<void> remove(String id) {
    return _$removeAsyncAction.run(() => super.remove(id));
  }

  @override
  String toString() {
    return '''
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
