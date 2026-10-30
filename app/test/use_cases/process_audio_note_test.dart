import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/processed_audio.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/services/i_note_processing_service.dart';
import 'package:smartnotes/domain/services/i_formatting_feedback_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';

class MockProcessing extends Mock implements INoteProcessingService {}

class MockJournal extends Mock implements IJournalEntryService {}

class RecordingFormattingFeedback implements IFormattingFeedbackService {
  String? entryId;
  bool running = false;

  @override
  Future<T> run<T>(String entryId, Future<T> Function() operation) async {
    this.entryId = entryId;
    running = true;
    try {
      return await operation();
    } finally {
      running = false;
    }
  }
}

void main() {
  final now = DateTime(2026, 10, 8);
  final entry = JournalEntry(
    id: '1',
    createdAt: now,
    updatedAt: now,
    status: EntryStatus.processing,
    audioPath: '/audio/original.m4a',
  );
  late MockProcessing processing;
  late MockJournal journal;
  late ProcessAudioNoteUseCase useCase;
  setUpAll(() => registerFallbackValue(entry));
  setUp(() {
    processing = MockProcessing();
    journal = MockJournal();
    useCase = ProcessAudioNoteUseCase(processing, journal);
    when(
      () => processing.generateMetadata(any()),
    ).thenAnswer((_) async => null);
    when(
      () => journal.update(any(), expected: any(named: 'expected')),
    ).thenAnswer((i) async => i.positionalArguments.first as JournalEntry);
    when(
      () => processing.transcribe(any()),
    ).thenAnswer((_) async => 'Original speech');
    when(
      () => processing.formatTranscription(
        action: AiAction.organizedNote,
        transcription: any(named: 'transcription'),
      ),
    ).thenAnswer(
      (_) async => const ProcessedAudio(
        title: 'Title',
        subTitle: 'Summary',
        markdown: 'Note',
        transcription: 'Original speech',
      ),
    );
  });
  test(
    'transcribes original audio and completes without formatting',
    () async {
      final result = await useCase.process(entry);
      expect(result.status, EntryStatus.completed);
      final saved = verify(
        () => journal.update(captureAny(), expected: any(named: 'expected')),
      ).captured.cast<JournalEntry>();
      expect(saved, hasLength(2));
      expect(saved.first.transcription, 'Original speech');
      expect(saved.first.status, EntryStatus.processing);
      expect(saved.last.formattedNote, isNull);
      expect(result.body, 'Original speech');
      expect(result.title, isNull);
      verifyNever(
        () => processing.formatTranscription(
          action: AiAction.organizedNote,
          transcription: any(named: 'transcription'),
        ),
      );
      verify(() => processing.transcribe('/audio/original.m4a')).called(1);
    },
  );
  test('retry reuses the persisted local transcription', () async {
    await useCase.process(entry.copyWith(transcription: 'Original speech'));
    verifyNever(() => processing.transcribe(any()));
  });
  for (final text in [
    '',
    '  ',
    '[BLANK_AUDIO]',
    '[blank_audio] [SILENCE]',
    '[NO_SPEECH]',
  ]) {
    test('does not persist non-speech transcript: $text', () async {
      when(() => processing.transcribe(any())).thenAnswer((_) async => text);
      await expectLater(
        useCase.process(entry),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.code,
            'code',
            AiFailureCode.noSpeech,
          ),
        ),
      );
      verifyNever(
        () => journal.update(any(), expected: any(named: 'expected')),
      );
      verifyNever(() => processing.generateMetadata(any()));
    });
  }
  test('keeps actual words alongside non-speech markers', () async {
    when(() => processing.transcribe(any())).thenAnswer(
      (_) async => '[BLANK_AUDIO] A quiet sentence. [BLANK_AUDIO]',
    );
    final result = await useCase.process(entry);
    expect(result.transcription, 'A quiet sentence.');
    expect(result.status, EntryStatus.completed);
  });
  test(
    'saves transcription before generating metadata without rewriting it',
    () async {
      when(() => processing.generateMetadata('Original speech')).thenAnswer((
        _,
      ) async {
        verify(
          () => journal.update(
            entry.copyWith(transcription: 'Original speech'),
            expected: entry,
          ),
        ).called(1);
        return (title: 'Title', subTitle: 'Subtitle', languageCode: 'pt');
      });
      final result = await useCase.process(entry);
      expect(result.title, 'Title');
      expect(result.subTitle, 'Subtitle');
      expect(result.languageCode, 'pt');
      expect(result.body, 'Original speech');
      expect(result.formattedNote, isNull);
      expect(result.status, EntryStatus.completed);
      final saved = verify(
        () => journal.update(captureAny(), expected: any(named: 'expected')),
      ).captured.cast<JournalEntry>();
      expect(saved.last.languageCode, 'pt');
      expect(saved.last.status, EntryStatus.completed);
    },
  );
  test('metadata failure still completes the transcribed note', () async {
    when(() => processing.generateMetadata(any())).thenThrow(
      const AiFailure(AiFailureCode.unavailable),
    );
    final result = await useCase.process(entry);
    expect(result.status, EntryStatus.completed);
    expect(result.transcription, 'Original speech');
    expect(result.title, isNull);
    expect(result.languageCode, isNull);
  });
  test(
    'retry preserves existing metadata including explicitly empty fields',
    () async {
      final source = entry.copyWith(
        transcription: 'Original speech',
        title: 'My title',
        subTitle: '',
      );
      final result = await useCase.process(source);
      expect(result.title, 'My title');
      expect(result.subTitle, '');
      verifyNever(() => processing.generateMetadata(any()));
    },
  );
  test('fills only missing metadata on retry', () async {
    when(() => processing.generateMetadata(any())).thenAnswer(
      (_) async =>
          (title: 'Generated', subTitle: 'Subtitle', languageCode: 'en'),
    );
    final result = await useCase.process(
      entry.copyWith(
        transcription: 'Original speech',
        title: 'My title',
      ),
    );
    expect(result.title, 'My title');
    expect(result.subTitle, 'Subtitle');
    expect(result.languageCode, 'en');
    verifyNever(() => processing.transcribe(any()));
  });
  test('never replaces an existing detected language', () async {
    when(() => processing.generateMetadata(any())).thenAnswer(
      (_) async =>
          (title: 'Generated', subTitle: 'Subtitle', languageCode: 'pt'),
    );
    final result = await useCase.process(
      entry.copyWith(transcription: 'Original speech', languageCode: 'es'),
    );
    expect(result.languageCode, 'es');
    expect(result.title, 'Generated');
  });
  test('empty stored language is replaced by detected language', () async {
    when(() => processing.generateMetadata(any())).thenAnswer(
      (_) async =>
          (title: 'Generated', subTitle: 'Subtitle', languageCode: 'pt'),
    );
    final result = await useCase.process(
      entry.copyWith(transcription: 'Original speech', languageCode: ''),
    );
    expect(result.languageCode, 'pt');
  });
  test('missing language detection keeps the note complete', () async {
    when(() => processing.generateMetadata(any())).thenAnswer(
      (_) async =>
          (title: 'Generated', subTitle: 'Subtitle', languageCode: null),
    );
    final result = await useCase.process(
      entry.copyWith(transcription: 'Original speech'),
    );
    expect(result.status, EntryStatus.completed);
    expect(result.title, 'Generated');
    expect(result.languageCode, isNull);
  });
  test('unavailable formatting does not affect successful capture', () async {
    when(
      () => processing.formatTranscription(
        action: AiAction.organizedNote,
        transcription: any(named: 'transcription'),
      ),
    ).thenThrow(Exception('Unavailable'));
    final result = await useCase.process(entry);
    expect(result.transcription, 'Original speech');
    expect(result.status, EntryStatus.completed);
  });
  test('failed transcription never persists empty content', () async {
    when(
      () => processing.transcribe(any()),
    ).thenThrow(Exception('Unavailable'));
    await expectLater(useCase.process(entry), throwsException);
    verifyNever(() => journal.update(any(), expected: any(named: 'expected')));
  });
  test(
    'empty speech is rejected before persisting a successful note',
    () async {
      when(() => processing.transcribe(any())).thenAnswer((_) async => '  ');
      await expectLater(useCase.process(entry), throwsA(isA<AiFailure>()));
      verifyNever(
        () => journal.update(any(), expected: any(named: 'expected')),
      );
    },
  );
  test('rejects AI action without a transcription', () async {
    await expectLater(
      useCase.applyAiAction(entry, AiAction.keyPoints),
      throwsException,
    );
    verifyZeroInteractions(processing);
  });

  test(
    'AI preview runs inside formatting feedback without saving the draft',
    () async {
      final feedback = RecordingFormattingFeedback();
      final tracked = ProcessAudioNoteUseCase(
        processing,
        journal,
        formattingFeedback: feedback,
      );
      when(
        () => processing.formatTranscription(
          action: AiAction.organizedNote,
          transcription: 'Source',
        ),
      ).thenAnswer((_) async {
        expect(feedback.running, true);
        return const ProcessedAudio(
          title: 'Title',
          subTitle: 'Subtitle',
          markdown: 'Preview',
          transcription: 'Source',
        );
      });
      final draft = await tracked.applyAiAction(
        entry.copyWith(transcription: 'Source'),
        AiAction.organizedNote,
      );
      expect(feedback.entryId, entry.id);
      expect(feedback.running, false);
      expect(draft.body, 'Preview');
      expect(draft.transcription, 'Source');
      verifyZeroInteractions(journal);
    },
  );

  test(
    'AI failure ends formatting feedback without changing saved content',
    () async {
      final feedback = RecordingFormattingFeedback();
      final tracked = ProcessAudioNoteUseCase(
        processing,
        journal,
        formattingFeedback: feedback,
      );
      const failure = AiFailure(AiFailureCode.invalidNote);
      when(
        () => processing.formatTranscription(
          action: AiAction.organizedNote,
          transcription: 'Source',
        ),
      ).thenThrow(failure);
      await expectLater(
        tracked.applyAiAction(
          entry.copyWith(transcription: 'Source'),
          AiAction.organizedNote,
        ),
        throwsA(same(failure)),
      );
      expect(feedback.entryId, entry.id);
      expect(feedback.running, false);
      verifyZeroInteractions(journal);
    },
  );
  test('preserves entry date when applying an action', () async {
    final dated = entry.copyWith(
      transcription: 'Original speech',
      entryDate: DateTime(2020, 2, 3),
    );
    final result = await useCase.applyAiAction(dated, AiAction.organizedNote);
    expect(result.entryDate, dated.entryDate);
    verifyZeroInteractions(journal);
  });

  test(
    'AI previews use edited text and retain the original without writes',
    () async {
      final edited = entry.copyWith(
        transcription: 'Original speech',
        formattedNote: 'Corrected text',
      );
      final draft = await useCase.applyAiAction(edited, AiAction.organizedNote);
      expect(draft.transcription, 'Original speech');
      verify(
        () => processing.formatTranscription(
          action: AiAction.organizedNote,
          transcription: 'Corrected text',
        ),
      ).called(1);
      verifyZeroInteractions(journal);
      final saved = await useCase.acceptAiDraft(edited, draft);
      expect(saved.formattedNote, 'Note');
      expect(saved.title, isNull);
      expect(saved.transcription, 'Original speech');
      verify(() => journal.update(any(), expected: edited)).called(1);
    },
  );

  test('metadata replacement is explicitly selected', () async {
    final source = entry.copyWith(
      title: 'My title',
      transcription: 'Original speech',
    );
    final draft = await useCase.applyAiAction(source, AiAction.organizedNote);
    final saved = await useCase.acceptAiDraft(
      source,
      draft,
      replaceMetadata: true,
    );
    expect(saved.title, 'Title');
    expect(saved.subTitle, 'Summary');
  });

  test(
    'preset previews share the unchanged source until explicitly accepted',
    () async {
      final source = entry.copyWith(transcription: 'Original speech');
      for (final action in AiAction.values) {
        when(
          () => processing.formatTranscription(
            action: action,
            transcription: 'Original speech',
          ),
        ).thenAnswer(
          (_) async => ProcessedAudio(
            title: 'Title',
            subTitle: 'Subtitle',
            markdown: 'Draft for ${action.name}',
            transcription: 'Original speech',
          ),
        );
        final draft = await useCase.applyAiAction(source, action);
        expect(draft.formattedNote, 'Draft for ${action.name}');
        expect(draft.transcription, source.transcription);
        verify(
          () => processing.formatTranscription(
            action: action,
            transcription: 'Original speech',
          ),
        ).called(1);
      }
      expect(source.body, 'Original speech');
      verifyZeroInteractions(journal);
    },
  );

  test(
    'chained accepted presets use the current body and retain the original',
    () async {
      final source = entry.copyWith(transcription: 'Original speech');
      when(
        () => processing.formatTranscription(
          action: AiAction.keyPoints,
          transcription: source.body,
        ),
      ).thenAnswer(
        (_) async => const ProcessedAudio(
          title: 'Title',
          subTitle: 'Subtitle',
          markdown: '- Original speech',
          transcription: 'Original speech',
        ),
      );
      final bullets = await useCase.applyAiAction(source, AiAction.keyPoints);
      verifyZeroInteractions(journal);
      final accepted = await useCase.acceptAiDraft(source, bullets);
      when(
        () => processing.formatTranscription(
          action: AiAction.journalEntry,
          transcription: '- Original speech',
        ),
      ).thenAnswer(
        (_) async => const ProcessedAudio(
          title: 'Title',
          subTitle: 'Subtitle',
          markdown: 'Original speech.',
          transcription: '- Original speech',
        ),
      );
      final prose = await useCase.applyAiAction(
        accepted,
        AiAction.journalEntry,
      );
      expect(prose.body, 'Original speech.');
      expect(prose.transcription, 'Original speech');
      expect(prose.audioPath, source.audioPath);
      expect(prose.createdAt, source.createdAt);
      verify(() => journal.update(any(), expected: source)).called(1);
      verify(
        () => processing.formatTranscription(
          action: AiAction.journalEntry,
          transcription: '- Original speech',
        ),
      ).called(1);
      verifyNoMoreInteractions(journal);
      verifyNever(() => processing.transcribe(any()));
    },
  );

  test(
    'restore clears only the current body and checks the source snapshot',
    () async {
      final source = entry.copyWith(
        transcription: 'Original speech',
        formattedNote: 'Changed',
        title: 'My title',
      );
      final restored = await useCase.restoreTranscription(source);
      expect(restored.formattedNote, isNull);
      expect(restored.body, 'Original speech');
      expect(restored.audioPath, entry.audioPath);
      expect(restored.title, 'My title');
      verify(() => journal.update(any(), expected: source)).called(1);
    },
  );

  test(
    'intentionally empty edited text does not fall back to original',
    () async {
      final empty = entry.copyWith(
        transcription: 'Original speech',
        formattedNote: '',
      );
      expect(empty.body, '');
      await expectLater(
        useCase.applyAiAction(empty, AiAction.organizedNote),
        throwsA(isA<AiFailure>()),
      );
      verifyZeroInteractions(processing);
    },
  );

  test(
    'concurrent processing of the same note transcribes only once',
    () async {
      final response = Completer<String>();
      when(
        () => processing.transcribe(any()),
      ).thenAnswer((_) => response.future);
      final first = useCase.process(entry);
      await pumpEventQueue();
      await expectLater(useCase.process(entry), throwsA(isA<AiFailure>()));
      response.complete('Original speech');
      await first;
      verify(() => processing.transcribe(any())).called(1);
    },
  );

  test(
    'retry completes an older error entry without formatting or retranscribing',
    () async {
      final failed = entry.copyWith(
        status: EntryStatus.error,
        transcription: 'Original speech',
      );
      await useCase.process(failed);
      final saved = verify(
        () => journal.update(captureAny(), expected: any(named: 'expected')),
      ).captured.cast<JournalEntry>();
      expect(saved.first.status, EntryStatus.processing);
      expect(saved.first.transcription, 'Original speech');
      verifyNever(() => processing.transcribe(any()));
    },
  );
}
