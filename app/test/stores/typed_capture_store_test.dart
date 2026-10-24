import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_store.dart';

class _Journal extends Mock implements IJournalEntryService {}

void main() {
  late _Journal journal;
  late EntryEditStore store;
  final saved = JournalEntry(
    id: 'reserved',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    status: EntryStatus.completed,
    transcription: 'Original words',
  );

  setUpAll(() => registerFallbackValue(saved));
  setUp(() {
    journal = _Journal();
    store = EntryEditStore(journal)..startCreation(id: 'reserved');
  });

  Future<JournalEntry?> save([String body = 'Original words']) =>
      store.saveEntry(
        title: '',
        subTitle: '',
        rawMarkdown: body,
      );

  void stubCreate(Future<JournalEntry> Function() action) {
    when(
      () => journal.createTyped(
        id: 'reserved',
        text: 'Original words',
        title: '',
        subTitle: '',
      ),
    ).thenAnswer((_) => action());
  }

  test(
    'starting a capture does not create an entry and blank text cannot save',
    () async {
      expect(store.entry, isNull);
      expect(store.isCreating, isTrue);
      expect(await save(' \n '), isNull);
      expect(store.errorMessage, 'noteBodyRequired');
      expect(store.isSaving, isFalse);
      verifyZeroInteractions(journal);
    },
  );

  test('concurrent Save calls create only one entry', () async {
    final pending = Completer<JournalEntry>();
    stubCreate(() => pending.future);
    final first = save();
    expect(store.isSaving, isTrue);
    expect(await save(), isNull);
    pending.complete(saved);
    expect(await first, saved);
    expect(store.entry, saved);
    expect(store.isCreating, isFalse);
    verify(
      () => journal.createTyped(
        id: 'reserved',
        text: 'Original words',
        title: '',
        subTitle: '',
      ),
    ).called(1);
  });

  test(
    'failed creation retains the capture ID for an explicit retry',
    () async {
      stubCreate(() async => throw StateError('Unavailable'));
      expect(await save(), isNull);
      expect(store.entry, isNull);
      expect(store.isCreating, isTrue);
      expect(store.creationId, 'reserved');
      expect(store.isSaving, isFalse);
      expect(store.writeFailure, isNotNull);
      stubCreate(() async => saved);
      expect(await save(), saved);
      expect(store.writeFailure, isNull);
    },
  );

  test(
    'later edits preserve the first saved text and use checked updates',
    () async {
      stubCreate(() async => saved);
      await save();
      when(() => journal.update(any(), expected: saved)).thenAnswer(
        (call) async => call.positionalArguments.first as JournalEntry,
      );
      final edited = await save('Edited words');
      expect(edited!.body, 'Edited words');
      expect(edited.transcription, 'Original words');
      expect(edited.audioPath, isNull);
      verify(() => journal.update(any(), expected: saved)).called(1);
      verify(
        () => journal.createTyped(
          id: 'reserved',
          text: 'Original words',
          title: '',
          subTitle: '',
        ),
      ).called(1);
    },
  );
}
