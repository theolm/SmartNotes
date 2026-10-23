import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import '../helpers/local_services.dart';

class MockJournalEntryService extends Mock implements IJournalEntryService {}

class MockProcessAudioNoteUseCase extends Mock
    implements ProcessAudioNoteUseCase {}

class FakeJournalEntry extends Fake implements JournalEntry {}

void main() {
  late MockJournalEntryService mockService;
  late MockProcessAudioNoteUseCase mockUseCase;
  late EntryDetailStore store;

  setUpAll(() {
    registerFallbackValue(FakeJournalEntry());
  });

  setUp(() {
    mockService = MockJournalEntryService();
    mockUseCase = MockProcessAudioNoteUseCase();
    store = EntryDetailStore(
      mockService,
      mockUseCase,
      MemoryFormattingModels(),
    );
  });

  group('EntryDetailStore', () {
    test('loadEntry sets entry when found', () async {
      final entry = JournalEntry(
        id: '1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: EntryStatus.completed,
        title: 'Test',
        formattedNote: '# Note',
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);

      await store.loadEntry('1');

      expect(store.isLoading, false);
      expect(store.entry, entry);
      expect(store.errorMessage, isNull);
    });

    test('loadEntry sets error when not found', () async {
      when(() => mockService.getById('1')).thenAnswer((_) async => null);

      await store.loadEntry('1');

      expect(store.isLoading, false);
      expect(store.entry, isNull);
      expect(store.errorMessage, isNotNull);
    });

    test('loadEntry sets error on failure', () async {
      when(() => mockService.getById('1')).thenThrow(Exception('boom'));

      await store.loadEntry('1');

      expect(store.isLoading, false);
      expect(store.entry, isNull);
      expect(store.errorMessage, isNotNull);
    });

    test('deleteEntry removes entry and audio file', () async {
      final entry = JournalEntry(
        id: '1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: EntryStatus.completed,
      );
      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      await store.loadEntry('1');
      when(() => mockService.delete('1')).thenAnswer((_) async {});

      await store.deleteEntry();

      expect(store.entry, isNull);
      expect(store.isDeleting, false);
      verify(() => mockService.delete('1')).called(1);
    });

    test('retryEntry calls process on use case', () async {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.error,
        audioPath: '/audio/test.m4a',
      );
      final completed = entry.copyWith(
        title: 'Retried',
        formattedNote: '# Retried note',
        transcription: 'transcription',
        status: EntryStatus.completed,
      );

      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      await store.loadEntry('1');

      when(() => mockUseCase.process(entry)).thenAnswer((_) async => completed);

      await store.retryEntry();

      expect(store.isProcessing, false);
      expect(store.entry?.status, EntryStatus.completed);
      expect(store.entry?.title, 'Retried');
      expect(store.errorMessage, isNull);
      verify(() => mockUseCase.process(entry)).called(1);
    });

    test('retryEntry sets error when use case fails', () async {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.error,
        audioPath: '/audio/test.m4a',
      );

      when(() => mockService.getById('1')).thenAnswer((_) async => entry);
      await store.loadEntry('1');

      when(() => mockUseCase.process(entry)).thenThrow(Exception('fail'));
      when(() => mockService.update(any())).thenAnswer(
        (_) async => entry.copyWith(status: EntryStatus.error),
      );

      await store.retryEntry();

      expect(store.isProcessing, false);
      expect(store.errorMessage, isNotNull);
      expect(store.entry?.status, EntryStatus.error);
      verifyNever(() => mockService.update(any()));
    });

    test(
      'applyAiAction creates a draft and only acceptance updates the entry',
      () async {
        final now = DateTime.now();
        final entry = JournalEntry(
          id: '1',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.completed,
          transcription: 'raw note',
        );
        final updated = entry.copyWith(
          title: 'Key points',
          subTitle: 'Summary',
          formattedNote: '# Key points',
        );
        store.entry = entry;
        when(
          () => mockUseCase.applyAiAction(entry, AiAction.keyPoints),
        ).thenAnswer((_) async => updated);

        final succeeded = await store.applyAiAction(AiAction.keyPoints);

        expect(succeeded, isTrue);
        expect(store.entry, entry);
        expect(store.aiDraft, updated);
        expect(store.isPerformingAiAction, isFalse);
        when(
          () =>
              mockUseCase.acceptAiDraft(entry, updated, replaceMetadata: false),
        ).thenAnswer((_) async => updated);
        expect(await store.acceptAiDraft(), true);
        expect(store.entry, updated);
        expect(store.aiDraft, isNull);
      },
    );

    test('applyAiAction preserves the current entry on failure', () async {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
        title: 'Existing title',
        formattedNote: '# Existing note',
        transcription: 'raw note',
      );
      store.entry = entry;
      when(
        () => mockUseCase.applyAiAction(entry, AiAction.formalSummary),
      ).thenThrow(Exception('fail'));

      final succeeded = await store.applyAiAction(AiAction.formalSummary);

      expect(succeeded, isFalse);
      expect(store.entry, entry);
      expect(store.isPerformingAiAction, isFalse);
    });

    test(
      'discarding an in-flight generation ignores its late result',
      () async {
        final now = DateTime(2026);
        final source = JournalEntry(
          id: '1',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.completed,
          transcription: 'Original',
        );
        store.entry = source;
        final response = Completer<JournalEntry>();
        when(
          () => mockUseCase.applyAiAction(source, AiAction.organizedNote),
        ).thenAnswer((_) => response.future);
        final running = store.applyAiAction(AiAction.organizedNote);
        expect(store.isPerformingAiAction, true);
        expect(await store.applyAiAction(AiAction.organizedNote), false);
        store.discardAiDraft();
        response.complete(source.copyWith(formattedNote: 'Late response'));
        expect(await running, false);
        expect(store.aiDraft, isNull);
        expect(store.entry, source);
        verify(
          () => mockUseCase.applyAiAction(source, AiAction.organizedNote),
        ).called(1);
        verifyZeroInteractions(mockService);
      },
    );

    test(
      'discarding a preview never saves and failed acceptance retains the note',
      () async {
        final now = DateTime(2026);
        final source = JournalEntry(
          id: '1',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.completed,
          transcription: 'Original',
        );
        final draft = source.copyWith(formattedNote: 'Draft');
        store.entry = source;
        when(
          () => mockUseCase.applyAiAction(source, AiAction.organizedNote),
        ).thenAnswer((_) async => draft);
        await store.applyAiAction(AiAction.organizedNote);
        store.discardAiDraft();
        expect(await store.acceptAiDraft(), false);
        verifyNever(
          () => mockUseCase.acceptAiDraft(
            any(),
            any(),
            replaceMetadata: any(named: 'replaceMetadata'),
          ),
        );
        await store.applyAiAction(AiAction.organizedNote);
        when(
          () =>
              mockUseCase.acceptAiDraft(source, draft, replaceMetadata: false),
        ).thenThrow(StateError('Changed'));
        expect(await store.acceptAiDraft(), false);
        expect(store.entry, source);
        expect(store.entry!.status, EntryStatus.completed);
        expect(store.aiErrorMessage, 'unavailable');
        expect(store.isSaving, false);
      },
    );
  });
}
