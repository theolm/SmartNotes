import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/entry_write_failure.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart';
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_store.dart';
import '../helpers/local_services.dart';

class MockJournal extends Mock implements IJournalEntryService {}

class MockProcessing extends Mock implements ProcessAudioNoteUseCase {}

void main() {
  final source = JournalEntry(
    id: 'one',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    status: EntryStatus.completed,
    title: 'My title',
    subTitle: 'My subtitle',
    transcription: 'Original recording text',
    formattedNote: '',
    audioPath: '/isolated/original.m4a',
  );
  final proposed = source.copyWith(
    title: 'AI title',
    subTitle: 'AI subtitle',
    formattedNote: 'AI body',
  );
  final applied = proposed.copyWith(updatedAt: DateTime(2026, 2));
  late MockJournal journal;
  late MockProcessing processing;
  late EntryDetailStore store;

  setUpAll(() {
    registerFallbackValue(source);
    registerFallbackValue(AiAction.organizedNote);
  });
  setUp(() async {
    journal = MockJournal();
    processing = MockProcessing();
    store = EntryDetailStore(journal, processing, MemoryFormattingModels());
    when(() => journal.getById('one')).thenAnswer((_) async => source);
    when(
      () => processing.applyAiAction(source, AiAction.organizedNote),
    ).thenAnswer((_) async => proposed);
    when(
      () => processing.acceptAiDraft(source, proposed, replaceMetadata: true),
    ).thenAnswer((_) async => applied);
    await store.loadEntry('one');
  });

  test(
    'Undo restores exact editable fields including intentionally empty content',
    () async {
      await store.applyAiAction(AiAction.organizedNote);
      expect(await store.acceptAiDraft(replaceMetadata: true), true);
      when(() => journal.update(any(), expected: applied)).thenAnswer(
        (i) async => (i.positionalArguments.first as JournalEntry).copyWith(
          updatedAt: DateTime(2026, 3),
        ),
      );
      expect(await store.undoAiAction(), true);
      expect(store.entry!.formattedNote, '');
      expect(store.entry!.title, source.title);
      expect(store.entry!.subTitle, source.subTitle);
      expect(store.entry!.audioPath, source.audioPath);
      expect(store.entry!.transcription, source.transcription);
      expect(store.entry!.createdAt, source.createdAt);
      expect(store.entry!.updatedAt, DateTime(2026, 3));
      expect(await store.undoAiAction(), false);
      verify(() => journal.update(any(), expected: applied)).called(1);
    },
  );

  for (final kind in [
    EntryWriteFailureKind.changed,
    EntryWriteFailureKind.deleted,
  ]) {
    test(
      'Undo rejects ${kind.name} entry without losing the accepted snapshot',
      () async {
        await store.applyAiAction(AiAction.organizedNote);
        await store.acceptAiDraft(replaceMetadata: true);
        when(
          () => journal.update(any(), expected: applied),
        ).thenThrow(EntryWriteFailure(kind));
        expect(await store.undoAiAction(), false);
        expect(store.entry, applied);
        expect(store.writeFailure, kind);
      },
    );
  }

  for (final kind in EntryWriteFailureKind.values) {
    test(
      'AI save classifies ${kind.name} and retains proposal/source for recovery',
      () async {
        await store.applyAiAction(AiAction.organizedNote);
        when(
          () => processing.acceptAiDraft(
            source,
            proposed,
            replaceMetadata: false,
          ),
        ).thenThrow(EntryWriteFailure(kind));
        expect(await store.acceptAiDraft(), false);
        expect(store.writeFailure, kind);
        expect(store.aiDraft, proposed);
        expect(store.draftSource, source);
        expect(store.entry, source);
      },
    );
    test(
      'manual save classifies ${kind.name} without replacing its source',
      () async {
        final editor = EntryEditStore(journal);
        await editor.loadEntry('one');
        when(
          () => journal.update(any(), expected: source),
        ).thenThrow(EntryWriteFailure(kind));
        expect(
          await editor.saveEntry(
            title: '',
            subTitle: '',
            rawMarkdown: 'Correction',
          ),
          isNull,
        );
        expect(editor.writeFailure, kind);
        expect(editor.entry, source);
      },
    );
  }

  test(
    'storage error is not a conflict and busy inference has a distinct outcome',
    () async {
      await store.applyAiAction(AiAction.organizedNote);
      when(
        () =>
            processing.acceptAiDraft(source, proposed, replaceMetadata: false),
      ).thenThrow(Exception('Storage failure'));
      await store.acceptAiDraft();
      expect(store.writeFailure, EntryWriteFailureKind.unavailable);
      when(
        () =>
            processing.acceptAiDraft(source, proposed, replaceMetadata: false),
      ).thenThrow(const AiFailure(AiFailureCode.busy));
      await store.acceptAiDraft();
      expect(store.writeFailure, EntryWriteFailureKind.busy);
    },
  );

  test('deletion and other operations are gated consistently', () async {
    store.isDeleting = true;
    expect(await store.applyAiAction(AiAction.organizedNote), false);
    expect(await store.restoreTranscription(), false);
    await store.deleteEntry();
    await store.retryEntry();
    verifyNever(() => journal.delete(any()));
    verifyNever(() => processing.process(any()));
    verifyNever(() => processing.applyAiAction(any(), any()));
  });

  test('detail observation subscribes only to its entry', () {
    when(
      () => journal.watchById(source.id),
    ).thenAnswer((_) => const Stream.empty());
    store.watchEntry(source.id);
    verify(() => journal.watchById(source.id)).called(1);
    verifyNever(() => journal.watchAll());
    store.dispose();
  });

  test(
    'background snapshots update reading but retain the exact generation source',
    () async {
      final changes = StreamController<JournalEntry?>();
      when(
        () => journal.watchById(source.id),
      ).thenAnswer((_) => changes.stream);
      store.watchEntry(source.id);
      await store.applyAiAction(AiAction.organizedNote);
      final latest = source.copyWith(formattedNote: 'Updated elsewhere');
      changes.add(latest);
      await Future<void>.delayed(Duration.zero);
      expect(store.entry, latest);
      expect(store.draftSource, source);
      changes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(store.entry, isNull);
      expect(store.aiDraft, proposed);
      store.dispose();
      await changes.close();
    },
  );

  test(
    'metadata-only save preserves literal, untouched transcription',
    () async {
      final original = source.copyWith(formattedNote: null);
      when(() => journal.getById('one')).thenAnswer((_) async => original);
      when(
        () => journal.update(any(), expected: original),
      ).thenAnswer((i) async => i.positionalArguments.first as JournalEntry);
      final editor = EntryEditStore(journal);
      await editor.loadEntry('one');
      final saved = await editor.saveEntry(
        title: 'New title',
        subTitle: original.subTitle!,
        rawMarkdown: original.body,
      );
      expect(saved!.formattedNote, isNull);
      expect(saved.body, original.transcription);
      expect(saved.title, 'New title');
    },
  );

  test(
    'restoration uses the original transcription snapshot actually shown',
    () async {
      final newer = source.copyWith(
        transcription: 'Imported original',
        formattedNote: 'Imported text',
      );
      store.entry = newer;
      when(
        () => processing.restoreTranscription(source),
      ).thenThrow(EntryWriteFailure(EntryWriteFailureKind.changed));
      expect(await store.restoreTranscription(source: source), false);
      expect(store.entry, newer);
      expect(store.writeFailure, EntryWriteFailureKind.changed);
      verifyNever(() => processing.restoreTranscription(newer));
    },
  );
}
