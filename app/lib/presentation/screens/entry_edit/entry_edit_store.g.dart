// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_edit_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$EntryEditStore on _EntryEditStore, Store {
  Computed<bool>? _$hasErrorComputed;

  @override
  bool get hasError => (_$hasErrorComputed ??= Computed<bool>(
    () => super.hasError,
    name: '_EntryEditStore.hasError',
  )).value;

  late final _$isCreatingAtom = Atom(
    name: '_EntryEditStore.isCreating',
    context: context,
  );

  @override
  bool get isCreating {
    _$isCreatingAtom.reportRead();
    return super.isCreating;
  }

  @override
  set isCreating(bool value) {
    _$isCreatingAtom.reportWrite(value, super.isCreating, () {
      super.isCreating = value;
    });
  }

  late final _$writeFailureAtom = Atom(
    name: '_EntryEditStore.writeFailure',
    context: context,
  );

  @override
  EntryWriteFailureKind? get writeFailure {
    _$writeFailureAtom.reportRead();
    return super.writeFailure;
  }

  @override
  set writeFailure(EntryWriteFailureKind? value) {
    _$writeFailureAtom.reportWrite(value, super.writeFailure, () {
      super.writeFailure = value;
    });
  }

  late final _$entryAtom = Atom(
    name: '_EntryEditStore.entry',
    context: context,
  );

  @override
  JournalEntry? get entry {
    _$entryAtom.reportRead();
    return super.entry;
  }

  @override
  set entry(JournalEntry? value) {
    _$entryAtom.reportWrite(value, super.entry, () {
      super.entry = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_EntryEditStore.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$isSavingAtom = Atom(
    name: '_EntryEditStore.isSaving',
    context: context,
  );

  @override
  bool get isSaving {
    _$isSavingAtom.reportRead();
    return super.isSaving;
  }

  @override
  set isSaving(bool value) {
    _$isSavingAtom.reportWrite(value, super.isSaving, () {
      super.isSaving = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_EntryEditStore.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$selectedEntryDateAtom = Atom(
    name: '_EntryEditStore.selectedEntryDate',
    context: context,
  );

  @override
  DateTime? get selectedEntryDate {
    _$selectedEntryDateAtom.reportRead();
    return super.selectedEntryDate;
  }

  @override
  set selectedEntryDate(DateTime? value) {
    _$selectedEntryDateAtom.reportWrite(value, super.selectedEntryDate, () {
      super.selectedEntryDate = value;
    });
  }

  late final _$latestEntryAsyncAction = AsyncAction(
    '_EntryEditStore.latestEntry',
    context: context,
  );

  @override
  Future<JournalEntry?> latestEntry() {
    return _$latestEntryAsyncAction.run(() => super.latestEntry());
  }

  late final _$loadEntryAsyncAction = AsyncAction(
    '_EntryEditStore.loadEntry',
    context: context,
  );

  @override
  Future<void> loadEntry(String id) {
    return _$loadEntryAsyncAction.run(() => super.loadEntry(id));
  }

  late final _$saveEntryAsyncAction = AsyncAction(
    '_EntryEditStore.saveEntry',
    context: context,
  );

  @override
  Future<JournalEntry?> saveEntry({
    required String title,
    required String subTitle,
    required String rawMarkdown,
  }) {
    return _$saveEntryAsyncAction.run(
      () => super.saveEntry(
        title: title,
        subTitle: subTitle,
        rawMarkdown: rawMarkdown,
      ),
    );
  }

  late final _$_EntryEditStoreActionController = ActionController(
    name: '_EntryEditStore',
    context: context,
  );

  @override
  void startCreation({String? id}) {
    final _$actionInfo = _$_EntryEditStoreActionController.startAction(
      name: '_EntryEditStore.startCreation',
    );
    try {
      return super.startCreation(id: id);
    } finally {
      _$_EntryEditStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void selectEntryDate(DateTime date) {
    final _$actionInfo = _$_EntryEditStoreActionController.startAction(
      name: '_EntryEditStore.selectEntryDate',
    );
    try {
      return super.selectEntryDate(date);
    } finally {
      _$_EntryEditStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isCreating: ${isCreating},
writeFailure: ${writeFailure},
entry: ${entry},
isLoading: ${isLoading},
isSaving: ${isSaving},
errorMessage: ${errorMessage},
selectedEntryDate: ${selectedEntryDate},
hasError: ${hasError}
    ''';
  }
}
