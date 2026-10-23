import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/data/services/local_entry_draft_repository.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_entry_draft_repository.dart';

void main() {
  late Directory directory;
  late LocalEntryDraftRepository drafts;
  final source = JournalEntry(
    id: '../entry/one',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    status: EntryStatus.completed,
    transcription: 'Original',
  );
  EntryEditDraft draft(String body) => EntryEditDraft(
    source: source,
    title: 'Title',
    subtitle: 'Subtitle',
    body: body,
    entryDate: DateTime(2025),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'smartnotes-edit-drafts-test-',
    );
    drafts = LocalEntryDraftRepository.inDirectory(directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'draft survives repository recreation without changing its source',
    () async {
      await drafts.write(draft('Corrected words'));
      final restored = await LocalEntryDraftRepository.inDirectory(
        directory,
      ).read(source.id);
      expect(restored!.source, source);
      expect(restored.body, 'Corrected words');
      expect(restored.entryDate, DateTime(2025));
      expect((await directory.list().toList()).length, 1);
    },
  );

  test('queued writes cannot resurrect a discarded draft', () async {
    final first = drafts.write(draft('First'));
    final second = drafts.write(draft('Second'));
    final discard = drafts.remove(source.id);
    await Future.wait([first, second, discard]);
    expect(await drafts.read(source.id), isNull);
    expect(await directory.list().toList(), isEmpty);
  });

  test(
    'intentionally empty drafts remain empty and corrupt files are not overwritten',
    () async {
      await drafts.write(draft(''));
      expect((await drafts.read(source.id))!.body, '');
      final file = (await directory.list().toList()).single as File;
      await file.writeAsString('not json');
      await expectLater(drafts.read(source.id), throwsFormatException);
      expect(await file.readAsString(), 'not json');
    },
  );
}
