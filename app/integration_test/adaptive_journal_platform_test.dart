import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartnotes/application/journal_lifecycle.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/data/datasources/local/sqlite_journal_entry_service.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_audio_recording_service.dart';
import 'package:smartnotes/domain/services/i_file_storage_service.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_screen.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/screens/home/widgets/timeline_item.dart';

import '../test/helpers/local_services.dart';

class _Files extends Mock implements IFileStorageService {}

class _Audio extends Mock implements IAudioRecordingService {}

class _Process extends Mock implements ProcessAudioNoteUseCase {}

class _Settings extends Mock implements ISettingsService {}

class _Auth extends Mock implements ILocalAuthService {}

/// Runs the real SQLite FFI worker and actual nested journal navigation.
/// Does not initialize the app's DI, open the user's journal, or load models.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'repeated sidebar selections use the native SQLite worker safely',
    (tester) async {
      final directory = await (await getTemporaryDirectory()).createTemp(
        'adaptive-journal-',
      );
      final database = LocalDatabase();
      await database.open(path: '${directory.path}/journal.sqlite');
      final files = _Files();
      when(
        () => files.getAudioDirectoryPath(),
      ).thenAnswer((_) async => directory.path);
      final journal = SqliteJournalEntryService(database, files);
      final entries = List.generate(
        3,
        (index) => JournalEntry(
          id: 'native-entry-$index',
          title: 'Sample entry $index',
          transcription: 'Isolated sample thought $index.',
          createdAt: DateTime(2026, 10, 23, 12 - index),
          updatedAt: DateTime(2026, 10, 23),
          status: EntryStatus.completed,
        ),
      );
      for (final entry in entries) {
        await database.insertEntry(entry);
      }

      final process = _Process();
      final search = MemorySearch(() => entries);
      final home = HomeStore(
        journal,
        _Audio(),
        JournalLifecycle(journal, process, search, MemoryEmbeddingModels()),
        search,
      );
      final app =
          AppStore(
              _Auth(),
              _Settings(),
              MemorySpeechModels(),
              MemoryEmbeddingModels(),
            )
            ..isInitialized = true
            ..hasCompletedOnboarding = true;
      final router = AppRouter();
      GetIt.I.registerSingleton<AppStore>(app);
      GetIt.I.registerSingleton<HomeStore>(home);
      GetIt.I.registerFactory<EntryDetailStore>(
        () => EntryDetailStore(journal, process, MemoryFormattingModels()),
      );
      addTearDown(() async {
        home.dispose();
        router.dispose();
        await database.close();
        await GetIt.I.reset();
        // This directory was created by this test and contains sample data only.
        await directory.delete(recursive: true);
      });
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router.config(),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 20; attempt++) {
        final index = attempt % entries.length;
        // Real asynchronous isolate messages require real frames on a device.
        for (
          var frame = 0;
          frame < 50 && find.byType(TimelineItem).evaluate().isEmpty;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        if (attempt == 0) {
          await tester.tap(
            find.descendant(
              of: find.byType(TimelineItem),
              matching: find.text('Sample entry $index'),
            ),
          );
        } else {
          unawaited(router.openJournalEntry(entries[index].id));
        }
        await tester.pumpAndSettle();
        for (
          var frame = 0;
          frame < 50 &&
              find
                  .descendant(
                    of: find.byType(EntryDetailScreen),
                    matching: find.text('Sample entry $index'),
                  )
                  .evaluate()
                  .isEmpty;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(
          find.descendant(
            of: find.byType(EntryDetailScreen),
            matching: find.text('Sample entry $index'),
          ),
          findsOneWidget,
        );
        expect(await database.entry(entries[index].id), entries[index]);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
