import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';

void main() {
  final now = DateTime.utc(2026, 10, 30);
  JournalEntry entry({String? languageCode}) => JournalEntry(
    id: '1',
    createdAt: now,
    updatedAt: now,
    status: EntryStatus.completed,
    transcription: 'Original speech',
    languageCode: languageCode,
  );

  test('detected language survives a JSON round trip', () {
    final restored = JournalEntry.fromJson(entry(languageCode: 'pt').toJson());
    expect(restored.languageCode, 'pt');
    expect(restored.body, 'Original speech');
  });

  test('legacy JSON without a language remains readable', () {
    final restored = JournalEntry.fromJson(
      entry().toJson()..remove('languageCode'),
    );
    expect(restored.languageCode, isNull);
    expect(restored.body, 'Original speech');
  });
}
