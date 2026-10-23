// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HomeStore on _HomeStore, Store {
  Computed<bool>? _$isSearchingComputed;

  @override
  bool get isSearching => (_$isSearchingComputed ??= Computed<bool>(
    () => super.isSearching,
    name: '_HomeStore.isSearching',
  )).value;
  Computed<bool>? _$hasMoreResultsComputed;

  @override
  bool get hasMoreResults => (_$hasMoreResultsComputed ??= Computed<bool>(
    () => super.hasMoreResults,
    name: '_HomeStore.hasMoreResults',
  )).value;
  Computed<List<JournalEntry>>? _$displayedEntriesComputed;

  @override
  List<JournalEntry> get displayedEntries =>
      (_$displayedEntriesComputed ??= Computed<List<JournalEntry>>(
        () => super.displayedEntries,
        name: '_HomeStore.displayedEntries',
      )).value;
  Computed<Map<DateTime, List<JournalEntry>>>? _$groupedEntriesComputed;

  @override
  Map<DateTime, List<JournalEntry>> get groupedEntries =>
      (_$groupedEntriesComputed ??= Computed<Map<DateTime, List<JournalEntry>>>(
        () => super.groupedEntries,
        name: '_HomeStore.groupedEntries',
      )).value;

  late final _$maintenanceProgressAtom = Atom(
    name: '_HomeStore.maintenanceProgress',
    context: context,
  );

  @override
  double? get maintenanceProgress {
    _$maintenanceProgressAtom.reportRead();
    return super.maintenanceProgress;
  }

  @override
  set maintenanceProgress(double? value) {
    _$maintenanceProgressAtom.reportWrite(value, super.maintenanceProgress, () {
      super.maintenanceProgress = value;
    });
  }

  late final _$indexIncompleteAtom = Atom(
    name: '_HomeStore.indexIncomplete',
    context: context,
  );

  @override
  bool get indexIncomplete {
    _$indexIncompleteAtom.reportRead();
    return super.indexIncomplete;
  }

  @override
  set indexIncomplete(bool value) {
    _$indexIncompleteAtom.reportWrite(value, super.indexIncomplete, () {
      super.indexIncomplete = value;
    });
  }

  late final _$entriesAtom = Atom(name: '_HomeStore.entries', context: context);

  @override
  ObservableList<JournalEntry> get entries {
    _$entriesAtom.reportRead();
    return super.entries;
  }

  @override
  set entries(ObservableList<JournalEntry> value) {
    _$entriesAtom.reportWrite(value, super.entries, () {
      super.entries = value;
    });
  }

  late final _$searchQueryAtom = Atom(
    name: '_HomeStore.searchQuery',
    context: context,
  );

  @override
  String get searchQuery {
    _$searchQueryAtom.reportRead();
    return super.searchQuery;
  }

  @override
  set searchQuery(String value) {
    _$searchQueryAtom.reportWrite(value, super.searchQuery, () {
      super.searchQuery = value;
    });
  }

  late final _$meaningRequestedAtom = Atom(
    name: '_HomeStore.meaningRequested',
    context: context,
  );

  @override
  bool get meaningRequested {
    _$meaningRequestedAtom.reportRead();
    return super.meaningRequested;
  }

  @override
  set meaningRequested(bool value) {
    _$meaningRequestedAtom.reportWrite(value, super.meaningRequested, () {
      super.meaningRequested = value;
    });
  }

  late final _$isSearchingWordsAtom = Atom(
    name: '_HomeStore.isSearchingWords',
    context: context,
  );

  @override
  bool get isSearchingWords {
    _$isSearchingWordsAtom.reportRead();
    return super.isSearchingWords;
  }

  @override
  set isSearchingWords(bool value) {
    _$isSearchingWordsAtom.reportWrite(value, super.isSearchingWords, () {
      super.isSearchingWords = value;
    });
  }

  late final _$isSearchingMeaningAtom = Atom(
    name: '_HomeStore.isSearchingMeaning',
    context: context,
  );

  @override
  bool get isSearchingMeaning {
    _$isSearchingMeaningAtom.reportRead();
    return super.isSearchingMeaning;
  }

  @override
  set isSearchingMeaning(bool value) {
    _$isSearchingMeaningAtom.reportWrite(value, super.isSearchingMeaning, () {
      super.isSearchingMeaning = value;
    });
  }

  late final _$isLoadingMoreAtom = Atom(
    name: '_HomeStore.isLoadingMore',
    context: context,
  );

  @override
  bool get isLoadingMore {
    _$isLoadingMoreAtom.reportRead();
    return super.isLoadingMore;
  }

  @override
  set isLoadingMore(bool value) {
    _$isLoadingMoreAtom.reportWrite(value, super.isLoadingMore, () {
      super.isLoadingMore = value;
    });
  }

  late final _$hasMoreWordsAtom = Atom(
    name: '_HomeStore.hasMoreWords',
    context: context,
  );

  @override
  bool get hasMoreWords {
    _$hasMoreWordsAtom.reportRead();
    return super.hasMoreWords;
  }

  @override
  set hasMoreWords(bool value) {
    _$hasMoreWordsAtom.reportWrite(value, super.hasMoreWords, () {
      super.hasMoreWords = value;
    });
  }

  late final _$hasMoreMeaningAtom = Atom(
    name: '_HomeStore.hasMoreMeaning',
    context: context,
  );

  @override
  bool get hasMoreMeaning {
    _$hasMoreMeaningAtom.reportRead();
    return super.hasMoreMeaning;
  }

  @override
  set hasMoreMeaning(bool value) {
    _$hasMoreMeaningAtom.reportWrite(value, super.hasMoreMeaning, () {
      super.hasMoreMeaning = value;
    });
  }

  late final _$searchNeedsRefreshAtom = Atom(
    name: '_HomeStore.searchNeedsRefresh',
    context: context,
  );

  @override
  bool get searchNeedsRefresh {
    _$searchNeedsRefreshAtom.reportRead();
    return super.searchNeedsRefresh;
  }

  @override
  set searchNeedsRefresh(bool value) {
    _$searchNeedsRefreshAtom.reportWrite(value, super.searchNeedsRefresh, () {
      super.searchNeedsRefresh = value;
    });
  }

  late final _$searchScrollRevisionAtom = Atom(
    name: '_HomeStore.searchScrollRevision',
    context: context,
  );

  @override
  int get searchScrollRevision {
    _$searchScrollRevisionAtom.reportRead();
    return super.searchScrollRevision;
  }

  @override
  set searchScrollRevision(int value) {
    _$searchScrollRevisionAtom.reportWrite(
      value,
      super.searchScrollRevision,
      () {
        super.searchScrollRevision = value;
      },
    );
  }

  late final _$meaningErrorAtom = Atom(
    name: '_HomeStore.meaningError',
    context: context,
  );

  @override
  String? get meaningError {
    _$meaningErrorAtom.reportRead();
    return super.meaningError;
  }

  @override
  set meaningError(String? value) {
    _$meaningErrorAtom.reportWrite(value, super.meaningError, () {
      super.meaningError = value;
    });
  }

  late final _$loadMoreErrorAtom = Atom(
    name: '_HomeStore.loadMoreError',
    context: context,
  );

  @override
  String? get loadMoreError {
    _$loadMoreErrorAtom.reportRead();
    return super.loadMoreError;
  }

  @override
  set loadMoreError(String? value) {
    _$loadMoreErrorAtom.reportWrite(value, super.loadMoreError, () {
      super.loadMoreError = value;
    });
  }

  late final _$searchResultsAtom = Atom(
    name: '_HomeStore.searchResults',
    context: context,
  );

  @override
  ObservableList<SearchResult>? get searchResults {
    _$searchResultsAtom.reportRead();
    return super.searchResults;
  }

  @override
  set searchResults(ObservableList<SearchResult>? value) {
    _$searchResultsAtom.reportWrite(value, super.searchResults, () {
      super.searchResults = value;
    });
  }

  late final _$searchErrorAtom = Atom(
    name: '_HomeStore.searchError',
    context: context,
  );

  @override
  String? get searchError {
    _$searchErrorAtom.reportRead();
    return super.searchError;
  }

  @override
  set searchError(String? value) {
    _$searchErrorAtom.reportWrite(value, super.searchError, () {
      super.searchError = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_HomeStore.isLoading',
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

  late final _$isRecordingAtom = Atom(
    name: '_HomeStore.isRecording',
    context: context,
  );

  @override
  bool get isRecording {
    _$isRecordingAtom.reportRead();
    return super.isRecording;
  }

  @override
  set isRecording(bool value) {
    _$isRecordingAtom.reportWrite(value, super.isRecording, () {
      super.isRecording = value;
    });
  }

  late final _$isProcessingAtom = Atom(
    name: '_HomeStore.isProcessing',
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

  late final _$recordStateAtom = Atom(
    name: '_HomeStore.recordState',
    context: context,
  );

  @override
  RecordState get recordState {
    _$recordStateAtom.reportRead();
    return super.recordState;
  }

  @override
  set recordState(RecordState value) {
    _$recordStateAtom.reportWrite(value, super.recordState, () {
      super.recordState = value;
    });
  }

  late final _$amplitudeAtom = Atom(
    name: '_HomeStore.amplitude',
    context: context,
  );

  @override
  double get amplitude {
    _$amplitudeAtom.reportRead();
    return super.amplitude;
  }

  @override
  set amplitude(double value) {
    _$amplitudeAtom.reportWrite(value, super.amplitude, () {
      super.amplitude = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_HomeStore.errorMessage',
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

  late final _$runSearchAsyncAction = AsyncAction(
    '_HomeStore.runSearch',
    context: context,
  );

  @override
  Future<void> runSearch() {
    return _$runSearchAsyncAction.run(() => super.runSearch());
  }

  late final _$loadMoreAsyncAction = AsyncAction(
    '_HomeStore.loadMore',
    context: context,
  );

  @override
  Future<void> loadMore() {
    return _$loadMoreAsyncAction.run(() => super.loadMore());
  }

  late final _$toggleRecordingAsyncAction = AsyncAction(
    '_HomeStore.toggleRecording',
    context: context,
  );

  @override
  Future<RecordingStartResult?> toggleRecording() {
    return _$toggleRecordingAsyncAction.run(() => super.toggleRecording());
  }

  late final _$startRecordingAsyncAction = AsyncAction(
    '_HomeStore.startRecording',
    context: context,
  );

  @override
  Future<RecordingStartResult> startRecording() {
    return _$startRecordingAsyncAction.run(() => super.startRecording());
  }

  late final _$stopRecordingAsyncAction = AsyncAction(
    '_HomeStore.stopRecording',
    context: context,
  );

  @override
  Future<void> stopRecording() {
    return _$stopRecordingAsyncAction.run(() => super.stopRecording());
  }

  late final _$_processEntryAsyncAction = AsyncAction(
    '_HomeStore._processEntry',
    context: context,
  );

  @override
  Future<void> _processEntry(JournalEntry entry) {
    return _$_processEntryAsyncAction.run(() => super._processEntry(entry));
  }

  late final _$retryProcessingAsyncAction = AsyncAction(
    '_HomeStore.retryProcessing',
    context: context,
  );

  @override
  Future<void> retryProcessing(JournalEntry entry) {
    return _$retryProcessingAsyncAction.run(() => super.retryProcessing(entry));
  }

  late final _$deleteEntryAsyncAction = AsyncAction(
    '_HomeStore.deleteEntry',
    context: context,
  );

  @override
  Future<bool> deleteEntry(JournalEntry entry) {
    return _$deleteEntryAsyncAction.run(() => super.deleteEntry(entry));
  }

  late final _$createDummyEntryAsyncAction = AsyncAction(
    '_HomeStore.createDummyEntry',
    context: context,
  );

  @override
  Future<void> createDummyEntry() {
    return _$createDummyEntryAsyncAction.run(() => super.createDummyEntry());
  }

  late final _$_HomeStoreActionController = ActionController(
    name: '_HomeStore',
    context: context,
  );

  @override
  void submitSearch(String query) {
    final _$actionInfo = _$_HomeStoreActionController.startAction(
      name: '_HomeStore.submitSearch',
    );
    try {
      return super.submitSearch(query);
    } finally {
      _$_HomeStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void useWordResults() {
    final _$actionInfo = _$_HomeStoreActionController.startAction(
      name: '_HomeStore.useWordResults',
    );
    try {
      return super.useWordResults();
    } finally {
      _$_HomeStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSearch() {
    final _$actionInfo = _$_HomeStoreActionController.startAction(
      name: '_HomeStore.clearSearch',
    );
    try {
      return super.clearSearch();
    } finally {
      _$_HomeStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
maintenanceProgress: ${maintenanceProgress},
indexIncomplete: ${indexIncomplete},
entries: ${entries},
searchQuery: ${searchQuery},
meaningRequested: ${meaningRequested},
isSearchingWords: ${isSearchingWords},
isSearchingMeaning: ${isSearchingMeaning},
isLoadingMore: ${isLoadingMore},
hasMoreWords: ${hasMoreWords},
hasMoreMeaning: ${hasMoreMeaning},
searchNeedsRefresh: ${searchNeedsRefresh},
searchScrollRevision: ${searchScrollRevision},
meaningError: ${meaningError},
loadMoreError: ${loadMoreError},
searchResults: ${searchResults},
searchError: ${searchError},
isLoading: ${isLoading},
isRecording: ${isRecording},
isProcessing: ${isProcessing},
recordState: ${recordState},
amplitude: ${amplitude},
errorMessage: ${errorMessage},
isSearching: ${isSearching},
hasMoreResults: ${hasMoreResults},
displayedEntries: ${displayedEntries},
groupedEntries: ${groupedEntries}
    ''';
  }
}
