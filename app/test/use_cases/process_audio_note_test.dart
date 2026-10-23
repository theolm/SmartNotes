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
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';

class MockProcessing extends Mock implements INoteProcessingService {}

class MockJournal extends Mock implements IJournalEntryService {}

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
        return (title: 'Title', subTitle: 'Subtitle');
      });
      final result = await useCase.process(entry);
      expect(result.title, 'Title');
      expect(result.subTitle, 'Subtitle');
      expect(result.body, 'Original speech');
      expect(result.formattedNote, isNull);
      expect(result.status, EntryStatus.completed);
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
      (_) async => (title: 'Generated', subTitle: 'Subtitle'),
    );
    final result = await useCase.process(
      entry.copyWith(
        transcription: 'Original speech',
        title: 'My title',
      ),
    );
    expect(result.title, 'My title');
    expect(result.subTitle, 'Subtitle');
    verifyNever(() => processing.transcribe(any()));
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
