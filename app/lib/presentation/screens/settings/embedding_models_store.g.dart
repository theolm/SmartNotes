// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedding_models_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$EmbeddingModelsStore on _EmbeddingModelsStore, Store {
  Computed<bool>? _$changingComputed;

  @override
  bool get changing => (_$changingComputed ??= Computed<bool>(
    () => super.changing,
    name: '_EmbeddingModelsStore.changing',
  )).value;
  Computed<EmbeddingModel?>? _$activeModelComputed;

  @override
  EmbeddingModel? get activeModel =>
      (_$activeModelComputed ??= Computed<EmbeddingModel?>(
        () => super.activeModel,
        name: '_EmbeddingModelsStore.activeModel',
      )).value;
  Computed<ModelCheckState>? _$activeStateComputed;

  @override
  ModelCheckState get activeState =>
      (_$activeStateComputed ??= Computed<ModelCheckState>(
        () => super.activeState,
        name: '_EmbeddingModelsStore.activeState',
      )).value;

  late final _$activeIdAtom = Atom(
    name: '_EmbeddingModelsStore.activeId',
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

  late final _$selectionLoadedAtom = Atom(
    name: '_EmbeddingModelsStore.selectionLoaded',
    context: context,
  );

  @override
  bool get selectionLoaded {
    _$selectionLoadedAtom.reportRead();
    return super.selectionLoaded;
  }

  @override
  set selectionLoaded(bool value) {
    _$selectionLoadedAtom.reportWrite(value, super.selectionLoaded, () {
      super.selectionLoaded = value;
    });
  }

  late final _$loadingAtom = Atom(
    name: '_EmbeddingModelsStore.loading',
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

  late final _$activatingIdAtom = Atom(
    name: '_EmbeddingModelsStore.activatingId',
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

  late final _$removingIdAtom = Atom(
    name: '_EmbeddingModelsStore.removingId',
    context: context,
  );

  @override
  String? get removingId {
    _$removingIdAtom.reportRead();
    return super.removingId;
  }

  @override
  set removingId(String? value) {
    _$removingIdAtom.reportWrite(value, super.removingId, () {
      super.removingId = value;
    });
  }

  late final _$downloadingIdAtom = Atom(
    name: '_EmbeddingModelsStore.downloadingId',
    context: context,
  );

  @override
  String? get downloadingId {
    _$downloadingIdAtom.reportRead();
    return super.downloadingId;
  }

  @override
  set downloadingId(String? value) {
    _$downloadingIdAtom.reportWrite(value, super.downloadingId, () {
      super.downloadingId = value;
    });
  }

  late final _$failureAtom = Atom(
    name: '_EmbeddingModelsStore.failure',
    context: context,
  );

  @override
  EmbeddingCatalogFailure? get failure {
    _$failureAtom.reportRead();
    return super.failure;
  }

  @override
  set failure(EmbeddingCatalogFailure? value) {
    _$failureAtom.reportWrite(value, super.failure, () {
      super.failure = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    '_EmbeddingModelsStore.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$verifyAsyncAction = AsyncAction(
    '_EmbeddingModelsStore.verify',
    context: context,
  );

  @override
  Future<void> verify(String id) {
    return _$verifyAsyncAction.run(() => super.verify(id));
  }

  late final _$downloadAsyncAction = AsyncAction(
    '_EmbeddingModelsStore.download',
    context: context,
  );

  @override
  Future<void> download(String id) {
    return _$downloadAsyncAction.run(() => super.download(id));
  }

  late final _$activateAsyncAction = AsyncAction(
    '_EmbeddingModelsStore.activate',
    context: context,
  );

  @override
  Future<void> activate(String id) {
    return _$activateAsyncAction.run(() => super.activate(id));
  }

  late final _$removeAsyncAction = AsyncAction(
    '_EmbeddingModelsStore.remove',
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
selectionLoaded: ${selectionLoaded},
loading: ${loading},
activatingId: ${activatingId},
removingId: ${removingId},
downloadingId: ${downloadingId},
failure: ${failure},
changing: ${changing},
activeModel: ${activeModel},
activeState: ${activeState}
    ''';
  }
}
