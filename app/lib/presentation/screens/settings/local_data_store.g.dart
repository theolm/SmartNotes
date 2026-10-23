// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_data_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$LocalDataStore on _LocalDataStore, Store {
  late final _$indexStatusAtom = Atom(
    name: '_LocalDataStore.indexStatus',
    context: context,
  );

  @override
  SearchIndexStatus get indexStatus {
    _$indexStatusAtom.reportRead();
    return super.indexStatus;
  }

  @override
  set indexStatus(SearchIndexStatus value) {
    _$indexStatusAtom.reportWrite(value, super.indexStatus, () {
      super.indexStatus = value;
    });
  }

  late final _$modelReadyAtom = Atom(
    name: '_LocalDataStore.modelReady',
    context: context,
  );

  @override
  bool get modelReady {
    _$modelReadyAtom.reportRead();
    return super.modelReady;
  }

  @override
  set modelReady(bool value) {
    _$modelReadyAtom.reportWrite(value, super.modelReady, () {
      super.modelReady = value;
    });
  }

  late final _$modelCheckingAtom = Atom(
    name: '_LocalDataStore.modelChecking',
    context: context,
  );

  @override
  bool get modelChecking {
    _$modelCheckingAtom.reportRead();
    return super.modelChecking;
  }

  @override
  set modelChecking(bool value) {
    _$modelCheckingAtom.reportWrite(value, super.modelChecking, () {
      super.modelChecking = value;
    });
  }

  late final _$modelCheckFailedAtom = Atom(
    name: '_LocalDataStore.modelCheckFailed',
    context: context,
  );

  @override
  bool get modelCheckFailed {
    _$modelCheckFailedAtom.reportRead();
    return super.modelCheckFailed;
  }

  @override
  set modelCheckFailed(bool value) {
    _$modelCheckFailedAtom.reportWrite(value, super.modelCheckFailed, () {
      super.modelCheckFailed = value;
    });
  }

  late final _$isBusyAtom = Atom(
    name: '_LocalDataStore.isBusy',
    context: context,
  );

  @override
  bool get isBusy {
    _$isBusyAtom.reportRead();
    return super.isBusy;
  }

  @override
  set isBusy(bool value) {
    _$isBusyAtom.reportWrite(value, super.isBusy, () {
      super.isBusy = value;
    });
  }

  late final _$backupProgressAtom = Atom(
    name: '_LocalDataStore.backupProgress',
    context: context,
  );

  @override
  double? get backupProgress {
    _$backupProgressAtom.reportRead();
    return super.backupProgress;
  }

  @override
  set backupProgress(double? value) {
    _$backupProgressAtom.reportWrite(value, super.backupProgress, () {
      super.backupProgress = value;
    });
  }

  late final _$errorAtom = Atom(
    name: '_LocalDataStore.error',
    context: context,
  );

  @override
  LocalDataFailure? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(LocalDataFailure? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    '_LocalDataStore.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$indexNotesAsyncAction = AsyncAction(
    '_LocalDataStore.indexNotes',
    context: context,
  );

  @override
  Future<bool> indexNotes({bool rebuild = false}) {
    return _$indexNotesAsyncAction.run(
      () => super.indexNotes(rebuild: rebuild),
    );
  }

  late final _$exportJournalAsyncAction = AsyncAction(
    '_LocalDataStore.exportJournal',
    context: context,
  );

  @override
  Future<Uint8List?> exportJournal() {
    return _$exportJournalAsyncAction.run(() => super.exportJournal());
  }

  late final _$importJournalAsyncAction = AsyncAction(
    '_LocalDataStore.importJournal',
    context: context,
  );

  @override
  Future<int?> importJournal(Uint8List bytes) {
    return _$importJournalAsyncAction.run(() => super.importJournal(bytes));
  }

  late final _$_LocalDataStoreActionController = ActionController(
    name: '_LocalDataStore',
    context: context,
  );

  @override
  Future<void> retryRecordings() {
    final _$actionInfo = _$_LocalDataStoreActionController.startAction(
      name: '_LocalDataStore.retryRecordings',
    );
    try {
      return super.retryRecordings();
    } finally {
      _$_LocalDataStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
indexStatus: ${indexStatus},
modelReady: ${modelReady},
modelChecking: ${modelChecking},
modelCheckFailed: ${modelCheckFailed},
isBusy: ${isBusy},
backupProgress: ${backupProgress},
error: ${error}
    ''';
  }
}
