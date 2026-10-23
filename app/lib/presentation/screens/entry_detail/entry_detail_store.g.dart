// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_detail_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$EntryDetailStore on _EntryDetailStore, Store {
  Computed<bool>? _$isBusyComputed;

  @override
  bool get isBusy => (_$isBusyComputed ??= Computed<bool>(
    () => super.isBusy,
    name: '_EntryDetailStore.isBusy',
  )).value;
  Computed<bool>? _$hasErrorComputed;

  @override
  bool get hasError => (_$hasErrorComputed ??= Computed<bool>(
    () => super.hasError,
    name: '_EntryDetailStore.hasError',
  )).value;

  late final _$entryAtom = Atom(
    name: '_EntryDetailStore.entry',
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
    name: '_EntryDetailStore.isLoading',
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
    name: '_EntryDetailStore.isSaving',
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

  late final _$isDeletingAtom = Atom(
    name: '_EntryDetailStore.isDeleting',
    context: context,
  );

  @override
  bool get isDeleting {
    _$isDeletingAtom.reportRead();
    return super.isDeleting;
  }

  @override
  set isDeleting(bool value) {
    _$isDeletingAtom.reportWrite(value, super.isDeleting, () {
      super.isDeleting = value;
    });
  }

  late final _$isProcessingAtom = Atom(
    name: '_EntryDetailStore.isProcessing',
    context: context,
  );

  @override
  bool get isProcessing {
    _$isProcessingAtom.reportRead();
    return super.isProcessing;
  }

  @override
  set isProcessing(bool value) {
    _$isProcessingAtom.reportWrite(value, super.isProcessing, () {
      super.isProcessing = value;
    });
  }

  late final _$isPerformingAiActionAtom = Atom(
    name: '_EntryDetailStore.isPerformingAiAction',
    context: context,
  );

  @override
  bool get isPerformingAiAction {
    _$isPerformingAiActionAtom.reportRead();
    return super.isPerformingAiAction;
  }

  @override
  set isPerformingAiAction(bool value) {
    _$isPerformingAiActionAtom.reportWrite(
      value,
      super.isPerformingAiAction,
      () {
        super.isPerformingAiAction = value;
      },
    );
  }

  late final _$errorMessageAtom = Atom(
    name: '_EntryDetailStore.errorMessage',
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

  late final _$aiDraftAtom = Atom(
    name: '_EntryDetailStore.aiDraft',
    context: context,
  );

  @override
  JournalEntry? get aiDraft {
    _$aiDraftAtom.reportRead();
    return super.aiDraft;
  }

  @override
  set aiDraft(JournalEntry? value) {
    _$aiDraftAtom.reportWrite(value, super.aiDraft, () {
      super.aiDraft = value;
    });
  }

  late final _$aiErrorMessageAtom = Atom(
    name: '_EntryDetailStore.aiErrorMessage',
    context: context,
  );

  @override
  String? get aiErrorMessage {
    _$aiErrorMessageAtom.reportRead();
    return super.aiErrorMessage;
  }

  @override
  set aiErrorMessage(String? value) {
    _$aiErrorMessageAtom.reportWrite(value, super.aiErrorMessage, () {
      super.aiErrorMessage = value;
    });
  }

  late final _$writeFailureAtom = Atom(
    name: '_EntryDetailStore.writeFailure',
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

  late final _$undoAiActionAsyncAction = AsyncAction(
    '_EntryDetailStore.undoAiAction',
    context: context,
  );

  @override
  Future<bool> undoAiAction() {
    return _$undoAiActionAsyncAction.run(() => super.undoAiAction());
  }

  late final _$deleteEntryAsyncAction = AsyncAction(
    '_EntryDetailStore.deleteEntry',
    context: context,
  );

  @override
  Future<void> deleteEntry() {
    return _$deleteEntryAsyncAction.run(() => super.deleteEntry());
  }

  late final _$loadEntryAsyncAction = AsyncAction(
    '_EntryDetailStore.loadEntry',
    context: context,
  );

  @override
  Future<void> loadEntry(String id) {
    return _$loadEntryAsyncAction.run(() => super.loadEntry(id));
  }

  late final _$applyAiActionAsyncAction = AsyncAction(
    '_EntryDetailStore.applyAiAction',
    context: context,
  );

  @override
  Future<bool> applyAiAction(AiAction action) {
    return _$applyAiActionAsyncAction.run(() => super.applyAiAction(action));
  }

  late final _$acceptAiDraftAsyncAction = AsyncAction(
    '_EntryDetailStore.acceptAiDraft',
    context: context,
  );

  @override
  Future<bool> acceptAiDraft({bool replaceMetadata = false}) {
    return _$acceptAiDraftAsyncAction.run(
      () => super.acceptAiDraft(replaceMetadata: replaceMetadata),
    );
  }

  late final _$restoreTranscriptionAsyncAction = AsyncAction(
    '_EntryDetailStore.restoreTranscription',
    context: context,
  );

  @override
  Future<bool> restoreTranscription({JournalEntry? source}) {
    return _$restoreTranscriptionAsyncAction.run(
      () => super.restoreTranscription(source: source),
    );
  }

  late final _$retryEntryAsyncAction = AsyncAction(
    '_EntryDetailStore.retryEntry',
    context: context,
  );

  @override
  Future<void> retryEntry() {
    return _$retryEntryAsyncAction.run(() => super.retryEntry());
  }

  late final _$_EntryDetailStoreActionController = ActionController(
    name: '_EntryDetailStore',
    context: context,
  );

  @override
  void discardAiDraft() {
    final _$actionInfo = _$_EntryDetailStoreActionController.startAction(
      name: '_EntryDetailStore.discardAiDraft',
    );
    try {
      return super.discardAiDraft();
    } finally {
      _$_EntryDetailStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  Future<bool> formattingReady() {
    final _$actionInfo = _$_EntryDetailStoreActionController.startAction(
      name: '_EntryDetailStore.formattingReady',
    );
    try {
      return super.formattingReady();
    } finally {
      _$_EntryDetailStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
entry: ${entry},
isLoading: ${isLoading},
isSaving: ${isSaving},
isDeleting: ${isDeleting},
isProcessing: ${isProcessing},
isPerformingAiAction: ${isPerformingAiAction},
errorMessage: ${errorMessage},
aiDraft: ${aiDraft},
aiErrorMessage: ${aiErrorMessage},
writeFailure: ${writeFailure},
isBusy: ${isBusy},
hasError: ${hasError}
    ''';
  }
}
