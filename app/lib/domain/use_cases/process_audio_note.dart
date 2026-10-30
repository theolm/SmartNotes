import 'package:injectable/injectable.dart';

import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/processed_audio.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/transcription_text.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/services/i_note_processing_service.dart';
import 'package:smartnotes/domain/services/i_formatting_feedback_service.dart';

@lazySingleton
class ProcessAudioNoteUseCase {
  ProcessAudioNoteUseCase(
    this._noteProcessingService,
    this._journalEntryService, {
    IFormattingFeedbackService? formattingFeedback,
    // Keep the injectable named parameter public and the dependency private.
    // ignore: prefer_initializing_formals
  }) : _formattingFeedback = formattingFeedback;

  final INoteProcessingService _noteProcessingService;
  final IJournalEntryService _journalEntryService;
  final IFormattingFeedbackService? _formattingFeedback;
  final _running = <String>{};

  Future<JournalEntry> _exclusive(
    String id,
    Future<JournalEntry> Function() work,
  ) async {
    if (!_running.add(id)) throw const AiFailure(AiFailureCode.busy);
    try {
      return await work();
    } finally {
      _running.remove(id);
    }
  }

  Future<JournalEntry> process(JournalEntry entry) =>
      _exclusive(entry.id, () => _process(entry));

  Future<JournalEntry> _process(JournalEntry entry) async {
    var current = entry;
    if (entry.status != EntryStatus.processing) {
      current = await _journalEntryService.update(
        entry.copyWith(status: EntryStatus.processing),
        expected: entry,
      );
    }
    if (current.transcription == null ||
        current.transcription!.trim().isEmpty) {
      final audioPath = current.audioPath;
      if (audioPath == null) throw Exception('No recording available');
      final text = requireSpeechTranscription(
        await _noteProcessingService.transcribe(audioPath),
      );
      // Preserve the original independently of all optional transformations.
      current = await _journalEntryService.update(
        current.copyWith(transcription: text),
        expected: current,
      );
    }
    // Metadata is best-effort; persist speech first and never rewrite the body.
    ({String title, String subTitle})? metadata;
    if (current.title == null || current.subTitle == null) {
      try {
        metadata = await _noteProcessingService.generateMetadata(
          current.transcription!,
        );
      } catch (_) {
        // An optional model failure must not turn a saved transcription into an error.
      }
    }
    return _journalEntryService.update(
      current.copyWith(
        status: EntryStatus.completed,
        title: current.title ?? metadata?.title,
        subTitle: current.subTitle ?? metadata?.subTitle,
      ),
      expected: current,
    );
  }

  /// Generates an unsaved preview. Only [acceptAiDraft] persists changes.
  Future<JournalEntry> applyAiAction(
    JournalEntry entry,
    AiAction action,
  ) => _exclusive(entry.id, () => _generateDraft(entry, action));

  /// Generates a preview only. Call [acceptAiDraft] to persist it.
  Future<JournalEntry> _generateDraft(
    JournalEntry entry,
    AiAction action,
  ) async {
    final source = entry.body;
    if (source.trim().isEmpty) {
      throw const AiFailure(AiFailureCode.noSpeech);
    }

    Future<ProcessedAudio> generate() =>
        _noteProcessingService.formatTranscription(
          action: action,
          transcription: source,
        );
    final processed =
        await (_formattingFeedback?.run(entry.id, generate) ?? generate());

    return entry.copyWith(
      title: processed.title,
      subTitle: processed.subTitle,
      formattedNote: processed.markdown,
      status: EntryStatus.completed,
    );
  }

  Future<JournalEntry> acceptAiDraft(
    JournalEntry source,
    JournalEntry draft, {
    bool replaceMetadata = false,
  }) => _exclusive(
    source.id,
    () => _journalEntryService.update(
      source.copyWith(
        formattedNote: draft.formattedNote,
        title: replaceMetadata ? draft.title : source.title,
        subTitle: replaceMetadata ? draft.subTitle : source.subTitle,
      ),
      expected: source,
    ),
  );

  Future<JournalEntry> restoreTranscription(JournalEntry entry) =>
      _exclusive(entry.id, () {
        if (entry.transcription?.trim().isNotEmpty != true) {
          throw const AiFailure(AiFailureCode.noSpeech);
        }
        return _journalEntryService.update(
          entry.copyWith(formattedNote: null),
          expected: entry,
        );
      });
}
