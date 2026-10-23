import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import 'package:smartnotes/core/utils/log.dart' show logger;
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/entry_write_failure.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/services/i_formatting_model_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';

part 'entry_detail_store.g.dart';

@injectable
// ignore: library_private_types_in_public_api
class EntryDetailStore = _EntryDetailStore with _$EntryDetailStore;

abstract class _EntryDetailStore with Store {
  _EntryDetailStore(
    this._journalEntryService,
    this._processAudioNoteUseCase,
    this._formattingModels,
  );

  final IJournalEntryService _journalEntryService;
  final ProcessAudioNoteUseCase _processAudioNoteUseCase;
  final IFormattingModelService _formattingModels;
  StreamSubscription<JournalEntry?>? _entrySubscription;
  bool _deletedHere = false;

  /// Reflect background transcription/imports without changing an AI draft's source.
  void watchEntry(String id) {
    _entrySubscription?.cancel();
    _entrySubscription = _journalEntryService
        .watchById(id)
        .listen(
          (latest) {
            if (isDeleting || _deletedHere) return;
            if (latest == null) {
              entry = null;
              errorMessage = 'Entry not found';
            } else {
              entry = latest;
              errorMessage = null;
            }
          },
          onError: (Object _) {
            // A transient observation failure must not blank an already readable note.
          },
        );
  }

  void dispose() {
    _entrySubscription?.cancel();
    _undoSource = null;
    _undoApplied = null;
    discardAiDraft();
  }

  @observable
  JournalEntry? entry;

  @observable
  bool isLoading = false;

  @observable
  bool isSaving = false;

  @observable
  bool isDeleting = false;

  @observable
  bool isProcessing = false;

  @observable
  bool isPerformingAiAction = false;

  @observable
  String? errorMessage;

  @observable
  JournalEntry? aiDraft;

  @observable
  String? aiErrorMessage;

  @observable
  EntryWriteFailureKind? writeFailure;

  JournalEntry? _undoSource;
  JournalEntry? _undoApplied;
  JournalEntry? get draftSource => _draftSource;

  EntryWriteFailureKind _writeKind(Object error) => error is EntryWriteFailure
      ? error.kind
      : error is AiFailure && error.code == AiFailureCode.busy
      ? EntryWriteFailureKind.busy
      : EntryWriteFailureKind.unavailable;

  Future<JournalEntry?> savedForComparison() async {
    try {
      final id = _draftSource?.id ?? entry?.id;
      if (id == null) return null;
      final latest = await _journalEntryService.getById(id);
      if (latest == null) writeFailure = EntryWriteFailureKind.deleted;
      return latest;
    } catch (_) {
      writeFailure = EntryWriteFailureKind.unavailable;
      return null;
    }
  }

  @action
  Future<bool> undoAiAction() async {
    final source = _undoSource;
    final applied = _undoApplied;
    if (source == null || applied == null || isSaving || isBusy || isDeleting) {
      return false;
    }
    isSaving = true;
    writeFailure = null;
    try {
      entry = await _journalEntryService.update(
        applied.copyWith(
          formattedNote: source.formattedNote,
          title: source.title,
          subTitle: source.subTitle,
        ),
        expected: applied,
      );
      _undoSource = null;
      _undoApplied = null;
      return true;
    } catch (error) {
      writeFailure = _writeKind(error);
      return false;
    } finally {
      isSaving = false;
    }
  }

  JournalEntry? _draftSource;
  int _draftRequest = 0;

  @action
  void discardAiDraft() {
    _draftRequest++;
    aiDraft = null;
    _draftSource = null;
    aiErrorMessage = null;
    writeFailure = null;
    isPerformingAiAction = false;
  }

  @computed
  bool get isBusy => isProcessing || isPerformingAiAction;

  @computed
  bool get hasError => errorMessage != null;

  @action
  Future<void> deleteEntry() async {
    logger.d('deleteEntry');
    final currentEntry = entry;
    if (currentEntry == null || isDeleting || isSaving || isBusy) {
      logger.w('deleteEntry: no entry loaded');
      return;
    }

    isDeleting = true;
    errorMessage = null;

    try {
      await _journalEntryService.delete(currentEntry.id);
      _deletedHere = true;
      logger.d('deleteEntry: entry deleted id=${currentEntry.id}');
      entry = null;
    } catch (e) {
      logger.e('deleteEntry: failed');
      errorMessage = 'Failed to delete entry';
    } finally {
      isDeleting = false;
    }
  }

  @action
  Future<void> loadEntry(String id) async {
    logger.d('loadEntry: id=$id');
    isLoading = true;
    errorMessage = null;
    _undoSource = null;
    _undoApplied = null;
    _deletedHere = false;

    try {
      final loaded = await _journalEntryService.getById(id);
      if (loaded == null) {
        logger.w('loadEntry: entry not found id=$id');
        errorMessage = 'Entry not found';
        entry = null;
      } else {
        logger.d('loadEntry: loaded id=$id');
        entry = loaded;
      }
    } catch (e) {
      logger.e('loadEntry: failed');
      errorMessage = 'Failed to load entry';
      entry = null;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> formattingReady() => _formattingModels.isReady();

  @action
  Future<bool> applyAiAction(AiAction action) async {
    logger.d('applyAiAction: action=${action.name}');
    final currentEntry = entry;
    if (currentEntry == null || isBusy || isSaving || isDeleting) {
      logger.w('applyAiAction: no entry loaded');
      return false;
    }

    discardAiDraft();
    final request = _draftRequest;
    isPerformingAiAction = true;

    try {
      final draft = await _processAudioNoteUseCase.applyAiAction(
        currentEntry,
        action,
      );
      if (request != _draftRequest) return false;
      _draftSource = currentEntry;
      aiDraft = draft;
      return true;
    } catch (e) {
      logger.e('applyAiAction: failed');
      if (request == _draftRequest) {
        aiErrorMessage = e is AiFailure
            ? e.code.name
            : AiFailureCode.unavailable.name;
      }
      return false;
    } finally {
      if (request == _draftRequest) isPerformingAiAction = false;
    }
  }

  @action
  Future<bool> acceptAiDraft({bool replaceMetadata = false}) async {
    final source = _draftSource;
    final draft = aiDraft;
    if (source == null || draft == null || isSaving || isBusy || isDeleting) {
      return false;
    }
    isSaving = true;
    aiErrorMessage = null;
    writeFailure = null;
    try {
      entry = await _processAudioNoteUseCase.acceptAiDraft(
        source,
        draft,
        replaceMetadata: replaceMetadata,
      );
      _undoSource = source;
      _undoApplied = entry;
      discardAiDraft();
      return true;
    } catch (error) {
      writeFailure = _writeKind(error);
      aiErrorMessage = writeFailure!.name;
      return false;
    } finally {
      isSaving = false;
    }
  }

  @action
  Future<bool> restoreTranscription({JournalEntry? source}) async {
    final current = source ?? entry;
    if (current == null || isBusy || isSaving || isDeleting) return false;
    isSaving = true;
    aiErrorMessage = null;
    try {
      entry = await _processAudioNoteUseCase.restoreTranscription(current);
      discardAiDraft();
      return true;
    } catch (error) {
      writeFailure = _writeKind(error);
      aiErrorMessage = writeFailure!.name;
      return false;
    } finally {
      isSaving = false;
    }
  }

  @action
  Future<void> retryEntry() async {
    logger.d('retryEntry');
    final currentEntry = entry;
    if (currentEntry == null || isBusy || isSaving || isDeleting) {
      logger.w('retryEntry: no entry loaded');
      return;
    }

    isProcessing = true;
    errorMessage = null;

    try {
      final updated = await _processAudioNoteUseCase.process(currentEntry);
      entry = updated;
    } catch (e) {
      logger.e('retryEntry: failed');
      errorMessage = e is AiFailure
          ? e.code.name
          : AiFailureCode.unavailable.name;
      try {
        final latest = await _journalEntryService.getById(currentEntry.id);
        entry = latest ?? currentEntry;
        if (latest != null &&
            latest.status == EntryStatus.processing &&
            !(e is AiFailure && e.code == AiFailureCode.busy)) {
          entry = await _journalEntryService.update(
            latest.copyWith(status: EntryStatus.error),
            expected: latest,
          );
        }
      } catch (_) {
        /* Keep the persisted state intact if storage is unavailable. */
      }
    } finally {
      isProcessing = false;
    }
  }
}
