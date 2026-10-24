import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import 'package:smartnotes/core/utils/log.dart' show logger;
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/entry_write_failure.dart';
import 'package:smartnotes/domain/services/i_entry_draft_repository.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';

part 'entry_edit_store.g.dart';

@injectable
// ignore: library_private_types_in_public_api
class EntryEditStore = _EntryEditStore with _$EntryEditStore;

abstract class _EntryEditStore with Store {
  // Invoked through the public MobX alias's inherited constructor.
  // ignore: unused_element_parameter
  _EntryEditStore(this._journalEntryService, [this.drafts]);

  final IJournalEntryService _journalEntryService;
  final IEntryDraftRepository? drafts;

  @observable
  bool isCreating = false;

  String? creationId;

  Future<JournalEntry?> findCreatedEntry(String id) =>
      _journalEntryService.getById(id);

  @action
  void startCreation({String? id}) {
    isCreating = true;
    creationId = id ?? const Uuid().v4();
    entry = null;
    selectedEntryDate = DateTime.now();
    writeFailure = null;
    errorMessage = null;
  }

  @observable
  EntryWriteFailureKind? writeFailure;

  @action
  Future<JournalEntry?> latestEntry() async {
    try {
      final latest = await _journalEntryService.getById(entry!.id);
      if (latest == null) writeFailure = EntryWriteFailureKind.deleted;
      return latest;
    } catch (_) {
      writeFailure = EntryWriteFailureKind.unavailable;
      return null;
    }
  }

  @observable
  JournalEntry? entry;

  @observable
  bool isLoading = false;

  @observable
  bool isSaving = false;

  @observable
  String? errorMessage;

  @observable
  DateTime? selectedEntryDate;

  @computed
  bool get hasError => errorMessage != null;

  @action
  Future<void> loadEntry(String id) async {
    logger.d('loadEntry: id=$id');
    isLoading = true;
    errorMessage = null;
    writeFailure = null;

    try {
      final loaded = await _journalEntryService.getById(id);
      if (loaded == null) {
        logger.w('loadEntry: entry not found id=$id');
        errorMessage = 'Entry not found';
        entry = null;
      } else {
        logger.d('loadEntry: loaded id=$id');
        entry = loaded;
        selectedEntryDate = loaded.effectiveEntryDate;
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
  void selectEntryDate(DateTime date) {
    logger.d('selectEntryDate: $date');
    selectedEntryDate = date;
  }

  @action
  Future<JournalEntry?> saveEntry({
    required String title,
    required String subTitle,
    required String rawMarkdown,
  }) async {
    logger.d('saveEntry');
    final currentEntry = entry;
    if (isSaving || (currentEntry == null && !isCreating)) {
      logger.w('saveEntry: no entry loaded');
      return null;
    }

    isSaving = true;
    errorMessage = null;
    writeFailure = null;

    try {
      if (isCreating) {
        if (rawMarkdown.trim().isEmpty) {
          errorMessage = 'noteBodyRequired';
          return null;
        }
        final saved = await _journalEntryService.createTyped(
          id: creationId!,
          text: rawMarkdown,
          title: title,
          subTitle: subTitle,
        );
        entry = saved;
        selectedEntryDate = saved.effectiveEntryDate;
        isCreating = false;
        return saved;
      }
      if (currentEntry == null) return null;
      final updated = currentEntry.copyWith(
        title: title.isEmpty && currentEntry.title == null ? null : title,
        subTitle: subTitle.isEmpty && currentEntry.subTitle == null
            ? null
            : subTitle,
        formattedNote: rawMarkdown == currentEntry.body
            ? currentEntry.formattedNote
            : rawMarkdown,
        entryDate: selectedEntryDate == currentEntry.effectiveEntryDate
            ? currentEntry.entryDate
            : selectedEntryDate,
      );
      final saved = await _journalEntryService.update(
        updated,
        expected: currentEntry,
      );
      entry = saved;
      selectedEntryDate = saved.effectiveEntryDate;
      logger.d('saveEntry: entry updated id=${saved.id}');
      return saved;
    } catch (e) {
      writeFailure = e is EntryWriteFailure
          ? e.kind
          : EntryWriteFailureKind.unavailable;
      logger.e('saveEntry: write failed');
      errorMessage = 'Failed to save changes';
      return null;
    } finally {
      isSaving = false;
    }
  }
}
