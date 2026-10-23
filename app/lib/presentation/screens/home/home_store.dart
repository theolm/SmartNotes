import 'dart:async';
import 'package:smartnotes/domain/entities/search_index_status.dart';
import 'package:smartnotes/domain/entities/search_result.dart';
import 'package:smartnotes/domain/entities/search_options.dart';

import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:record/record.dart';

import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_audio_recording_service.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/services/i_entry_search_service.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/core/utils/log.dart' show logger;
import 'package:smartnotes/application/journal_lifecycle.dart';
import 'package:smartnotes/data/services/processing_feedback_service.dart';

part 'home_store.g.dart';

enum RecordingStartResult { started, failed }

@singleton
// ignore: library_private_types_in_public_api
class HomeStore = _HomeStore with _$HomeStore;

abstract class _HomeStore with Store {
  _HomeStore(
    this._journalEntryService,
    this._audioRecordingService,
    this._lifecycle,
    this._searchService, {
    ProcessingFeedbackService? processingFeedback,
  }) : processingFeedback =
           processingFeedback ?? ProcessingFeedbackService.unsupported() {
    _maintenanceSubscription = _journalEntryService
        .watchSearchMaintenance()
        .listen(
          (value) => runInAction(() => maintenanceProgress = value),
        );
    _entriesSubscription = _journalEntryService.watchAll().listen(
      _onEntriesUpdated,
      onError: _onEntriesError,
    );
  }

  final IJournalEntryService _journalEntryService;
  final IAudioRecordingService _audioRecordingService;
  final JournalLifecycle _lifecycle;
  final IEntrySearchService _searchService;
  final ProcessingFeedbackService processingFeedback;
  int _searchRevision = 0;
  Timer? _searchDebounce;
  static const searchPageSize = 20;
  Future<void>? _textRequest;
  bool _wordsComplete = false;
  bool _meaningComplete = false;
  int _wordOffset = 0;
  int _meaningOffset = 0;
  int _resultsRevision = -1;
  SearchIndexStatus? _lastIndexStatus;
  final _processingIds = <String>{};

  bool _isToggling = false;
  StreamSubscription<List<JournalEntry>>? _entriesSubscription;
  StreamSubscription<SearchIndexStatus>? _indexSubscription;
  StreamSubscription<double?>? _maintenanceSubscription;
  @observable
  double? maintenanceProgress;
  @observable
  bool indexIncomplete = false;
  StreamSubscription<double>? _amplitudeSubscription;

  @observable
  ObservableList<JournalEntry> entries = ObservableList<JournalEntry>();

  @observable
  String searchQuery = '';

  @observable
  bool meaningRequested = false;

  @observable
  bool isSearchingWords = false;

  @observable
  bool isSearchingMeaning = false;

  @observable
  bool isLoadingMore = false;

  @observable
  bool hasMoreWords = false;

  @observable
  bool hasMoreMeaning = false;

  @observable
  bool searchNeedsRefresh = false;

  @observable
  int searchScrollRevision = 0;

  @observable
  String? meaningError;

  @observable
  String? loadMoreError;

  @computed
  bool get isSearching => isSearchingWords || isSearchingMeaning;

  @computed
  bool get hasMoreResults => hasMoreWords || hasMoreMeaning;

  bool get showingPreviousResults =>
      searchResults != null && _resultsRevision != _searchRevision;

  @observable
  ObservableList<SearchResult>? searchResults;

  @observable
  String? searchError;

  @observable
  bool isLoading = true;

  @observable
  bool isRecording = false;

  @observable
  bool isProcessing = false;

  @observable
  RecordState recordState = RecordState.stop;

  @observable
  double amplitude = 0;

  @observable
  String? errorMessage;

  @computed
  List<JournalEntry> get displayedEntries {
    if (searchQuery.isEmpty) {
      return entries.toList()
        ..sort((a, b) => b.effectiveEntryDate.compareTo(a.effectiveEntryDate));
    }
    if (searchResults == null) return [];
    final current = {for (final entry in entries) entry.id: entry};
    // Keep retrieval rank while resolving edits and deletions from the journal.
    return [for (final result in searchResults!) ?current[result.entry.id]];
  }

  SearchResult? searchResultFor(JournalEntry entry) {
    for (final result in searchResults ?? <SearchResult>[]) {
      if (result.entry.id == entry.id) return result;
    }
    return null;
  }

  @computed
  Map<DateTime, List<JournalEntry>> get groupedEntries {
    final groups = <DateTime, List<JournalEntry>>{};
    for (final entry in displayedEntries) {
      final day = DateTime(
        entry.effectiveEntryDate.year,
        entry.effectiveEntryDate.month,
        entry.effectiveEntryDate.day,
      );
      groups.putIfAbsent(day, () => []).add(entry);
    }
    return groups;
  }

  void _onEntriesUpdated(List<JournalEntry> updated) {
    entries = ObservableList.of(updated);
    isLoading = false;
    errorMessage = null;
    if (searchQuery.isNotEmpty) {
      if (searchResults != null) {
        // Keep the reader's pages and scroll position after edits or imports.
        // Refresh explicitly before using offsets against a different journal.
        _searchService.cancelTextSearch();
        _searchDebounce?.cancel();
        _searchRevision++;
        _textRequest = null;
        isSearchingWords = false;
        isSearchingMeaning = false;
        isLoadingMore = false;
        searchNeedsRefresh = true;
      } else {
        final includeMeaning = meaningRequested;
        submitSearch(searchQuery);
        if (includeMeaning) unawaited(runSearch());
      }
    }
  }

  void _onEntriesError(Object error, StackTrace stackTrace) {
    logger.e('Journal observation failed', stackTrace: stackTrace);
    errorMessage = 'Failed to load entries';
    isLoading = false;
  }

  void listenToRecordingState() {
    _audioRecordingService.onStateChanged.listen((state) {
      recordState = state;
    });
  }

  void _listenToAmplitude() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _audioRecordingService.onAmplitudeChanged.listen(
      (value) => amplitude = value,
    );
  }

  void _cancelAmplitudeListener() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    amplitude = 0;
  }

  @action
  void submitSearch(String query) {
    searchScrollRevision++;
    _searchService.cancelTextSearch();
    _searchDebounce?.cancel();
    _textRequest = null;
    _wordsComplete = false;
    _meaningComplete = false;
    _wordOffset = 0;
    _meaningOffset = 0;
    searchQuery = query.trim();
    // Keep the last results readable while a text search refreshes.
    if (searchQuery.isEmpty) searchResults = null;
    searchError = null;
    meaningError = null;
    loadMoreError = null;
    meaningRequested = false;
    isSearchingMeaning = false;
    isLoadingMore = false;
    hasMoreWords = false;
    hasMoreMeaning = false;
    searchNeedsRefresh = false;
    _searchRevision++;
    isSearchingWords = searchQuery.isNotEmpty;
    if (searchQuery.isNotEmpty) {
      final revision = _searchRevision;
      _searchDebounce = Timer(const Duration(milliseconds: 250), () {
        unawaited(_ensureWords(revision));
      });
    }
  }

  void _watchIndex() {
    _indexSubscription ??= _searchService.watchIndexStatus().listen(
      (status) {
        runInAction(() {
          indexIncomplete = status.isIncomplete;
          final previous = _lastIndexStatus;
          _lastIndexStatus = status;
          if (previous != null &&
              meaningRequested &&
              (_meaningComplete || isLoadingMore) &&
              (previous.generation != status.generation ||
                  previous.indexed != status.indexed ||
                  previous.pending != status.pending ||
                  previous.failed != status.failed)) {
            // Offset pages cannot continue safely across a changing index.
            searchNeedsRefresh = true;
            _searchRevision++;
            _textRequest = null;
            isSearchingWords = false;
            isSearchingMeaning = false;
            isLoadingMore = false;
          }
        });
      },
      onError: (Object _) {
        runInAction(() => indexIncomplete = true);
      },
    );
  }

  SearchOptions _page(int offset) => SearchOptions(
    offset: offset,
    limit: searchPageSize + 1,
  );

  String _failure(Object error) => error is AiFailure
      ? error.code.name
      : 'Local search could not finish. Please try again.';

  Future<void> _ensureWords(int revision) {
    if (_wordsComplete || revision != _searchRevision) return Future.value();
    runInAction(() => isSearchingWords = true);
    return _textRequest ??= _fetchWords(revision);
  }

  Future<void> _fetchWords(int revision) async {
    try {
      final results = await _searchService.searchText(
        searchQuery,
        options: _page(0),
      );
      if (revision != _searchRevision) return;
      runInAction(() {
        searchResults = ObservableList.of(results.take(searchPageSize));
        _resultsRevision = revision;
        _wordOffset = searchResults!.length;
        hasMoreWords = results.length > searchPageSize;
        _wordsComplete = true;
        searchError = null;
      });
    } catch (error) {
      if (revision == _searchRevision) {
        runInAction(() => searchError = _failure(error));
      }
    } finally {
      if (revision == _searchRevision) {
        runInAction(() {
          isSearchingWords = false;
          _textRequest = null;
        });
      }
    }
  }

  void _append(Iterable<SearchResult> results) {
    if (_resultsRevision != _searchRevision) searchResults = null;
    _resultsRevision = _searchRevision;
    final combined = {
      for (final result in searchResults ?? <SearchResult>[])
        result.entry.id: result,
    };
    for (final result in results) {
      final previous = combined[result.entry.id];
      // Literal evidence wins, but replacing it never moves a result already read.
      if (previous == null || (previous.byMeaning && !result.byMeaning)) {
        combined[result.entry.id] = result;
      }
    }
    searchResults = ObservableList.of(combined.values);
  }

  @action
  Future<void> runSearch() async {
    _searchDebounce?.cancel();
    final query = searchQuery;
    if (query.isEmpty || isSearchingMeaning || isLoadingMore) return;
    if (searchNeedsRefresh || searchError != null) {
      submitSearch(query);
      _searchDebounce?.cancel();
    }
    final revision = _searchRevision;
    meaningRequested = true;
    isSearchingMeaning = true;
    meaningError = null;
    _watchIndex();
    await _ensureWords(revision);
    if (revision != _searchRevision) return;
    try {
      if (_meaningComplete) return;
      final results = await _searchService.searchSemantic(
        query,
        options: _page(0),
        isCancelled: () => revision != _searchRevision,
      );
      if (revision == _searchRevision) {
        _append(results.take(searchPageSize));
        _meaningOffset = results.take(searchPageSize).length;
        hasMoreMeaning = results.length > searchPageSize;
        _meaningComplete = true;
      }
    } catch (error) {
      if (revision == _searchRevision) {
        meaningError = _failure(error);
      }
    } finally {
      if (revision == _searchRevision) {
        isSearchingMeaning = false;
      }
    }
  }

  @action
  Future<void> loadMore() async {
    if (isSearching || isLoadingMore || !hasMoreResults || searchNeedsRefresh) {
      return;
    }
    final revision = _searchRevision;
    isLoadingMore = true;
    loadMoreError = null;
    final initialCount = searchResults?.length ?? 0;
    try {
      do {
        if (hasMoreWords) {
          final page = await _searchService.searchText(
            searchQuery,
            options: _page(_wordOffset),
          );
          if (revision != _searchRevision) return;
          _append(page.take(searchPageSize));
          _wordOffset += page.take(searchPageSize).length;
          hasMoreWords = page.length > searchPageSize;
        }
        if (hasMoreMeaning) {
          final page = await _searchService.searchSemantic(
            searchQuery,
            options: _page(_meaningOffset),
            isCancelled: () => revision != _searchRevision,
          );
          if (revision != _searchRevision) return;
          _append(page.take(searchPageSize));
          _meaningOffset += page.take(searchPageSize).length;
          hasMoreMeaning = page.length > searchPageSize;
        }
        // Do not strand the reader on an extra page containing only duplicates.
      } while (hasMoreResults && (searchResults?.length ?? 0) == initialCount);
    } catch (error) {
      if (revision == _searchRevision) loadMoreError = _failure(error);
    } finally {
      if (revision == _searchRevision) isLoadingMore = false;
    }
  }

  @action
  void useWordResults() {
    submitSearch(searchQuery);
  }

  @action
  void clearSearch() {
    submitSearch('');
  }

  @action
  Future<RecordingStartResult?> toggleRecording() async {
    if (_isToggling) return null;
    _isToggling = true;
    try {
      if (isRecording) {
        await stopRecording();
        return null;
      } else {
        return await startRecording();
      }
    } finally {
      _isToggling = false;
    }
  }

  @action
  Future<RecordingStartResult> startRecording() async {
    logger.d('startRecording');
    errorMessage = null;
    try {
      final hasPermission = await _audioRecordingService.hasPermission();
      if (!hasPermission) {
        logger.e('startRecording: permission denied');
        errorMessage = 'Microphone permission denied';
        return RecordingStartResult.failed;
      }

      await _audioRecordingService.start();
      isRecording = true;
      _listenToAmplitude();
      logger.d('startRecording: recording started');
      return RecordingStartResult.started;
    } catch (e) {
      logger.e('startRecording: error — $e');
      errorMessage = 'Failed to start recording';
      isRecording = false;
      return RecordingStartResult.failed;
    }
  }

  @action
  Future<void> stopRecording() async {
    logger.d('stopRecording');
    if (!isRecording) {
      logger.d('stopRecording: no-op, recording was not active');
      return;
    }
    errorMessage = null;
    try {
      final audioPath = await _audioRecordingService.stop();
      isRecording = false;

      if (audioPath == null) {
        logger.e('stopRecording: no audio path returned');
        errorMessage = 'No audio recorded';
        return;
      }

      logger.d('stopRecording: creating entry');
      final entry = await _journalEntryService.create(audioPath: audioPath);
      logger.d('stopRecording: entry created id=${entry.id}');

      _processEntry(entry);
    } catch (e) {
      logger.e('stopRecording: error — $e');
      errorMessage = e is AiFailure && e.code == AiFailureCode.noSpeech
          ? 'recordingNoSpeech'
          : 'Failed to stop recording';
      isRecording = false;
    } finally {
      _cancelAmplitudeListener();
    }
  }

  @action
  Future<void> _processEntry(JournalEntry entry) async {
    if (!_processingIds.add(entry.id)) return;
    isProcessing = true;
    errorMessage = null;

    try {
      await _lifecycle.processEntry(entry);
    } catch (e) {
      logger.e('_processEntry: error — $e');
      errorMessage = e is AiFailure ? e.code.name : 'AI processing failed';
    } finally {
      _processingIds.remove(entry.id);
      isProcessing = _processingIds.isNotEmpty;
    }
  }

  @action
  Future<void> retryProcessing(JournalEntry entry) async {
    logger.d('retryProcessing: entryId=${entry.id}');
    await _processEntry(entry);
  }

  @action
  Future<bool> deleteEntry(JournalEntry entry) async {
    logger.d('deleteEntry: entryId=${entry.id}');
    errorMessage = null;

    try {
      await _journalEntryService.delete(entry.id);
      logger.d('deleteEntry: entry deleted id=${entry.id}');
      return true;
    } catch (e) {
      logger.e('deleteEntry: error — $e');
      errorMessage = 'Failed to delete entry';
      return false;
    }
  }

  @action
  Future<void> createDummyEntry() async {
    errorMessage = null;
    try {
      final entry = await _journalEntryService.create(
        audioPath: '/dev/null/dummy.m4a',
      );
      final updated = entry.copyWith(
        title: 'Sample entry',
        formattedNote: 'This is a sample note created for testing.',
        status: EntryStatus.completed,
      );
      await _journalEntryService.update(updated);
    } catch (e) {
      errorMessage = 'Failed to create entry';
    }
  }

  void dispose() {
    _searchService.cancelTextSearch();
    _searchDebounce?.cancel();
    _searchRevision++;
    _indexSubscription?.cancel();
    _maintenanceSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _entriesSubscription?.cancel();
    _entriesSubscription = null;
  }
}
