import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/data/services/local_entry_draft_repository.dart';
import 'package:smartnotes/data/services/local_recording_metadata.dart';
import 'package:smartnotes/data/services/local_recording_playback.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_entry_draft_repository.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/services/i_recording_metadata.dart';
import 'package:smartnotes/domain/services/i_recording_playback.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_screen.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart';
import 'package:smartnotes/presentation/widgets/recording_player.dart';
import '../test/helpers/entry_experience_fakes.dart';
import '../test/helpers/local_services.dart';

class _Journal extends Mock implements IJournalEntryService {}

class _Processing extends Mock implements ProcessAudioNoteUseCase {}

/// Safe native smoke: generated silent audio, mock journal/model, isolated files.
/// Does not call main/configureDependencies or access the user's journal.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'local AAC playback, interruption, draft persistence and detail rendering',
    (tester) async {
      final directory = await (await getTemporaryDirectory()).createTemp(
        'entry-experience-',
      );
      final wav = File('${directory.path}/silent.wav');
      // Two seconds of mono PCM, generated here rather than recording the user.
      const bytes = 44100 * 2 * 2;
      final data = ByteData(44 + bytes);
      void ascii(int offset, String value) {
        for (var index = 0; index < value.length; index++) {
          data.setUint8(offset + index, value.codeUnitAt(index));
        }
      }

      ascii(0, 'RIFF');
      data.setUint32(4, 36 + bytes, Endian.little);
      ascii(8, 'WAVEfmt ');
      data.setUint32(16, 16, Endian.little);
      data.setUint16(20, 1, Endian.little);
      data.setUint16(22, 1, Endian.little);
      data.setUint32(24, 44100, Endian.little);
      data.setUint32(28, 88200, Endian.little);
      data.setUint16(32, 2, Endian.little);
      data.setUint16(34, 16, Endian.little);
      ascii(36, 'data');
      data.setUint32(40, bytes, Endian.little);
      await wav.writeAsBytes(data.buffer.asUint8List());
      final m4a = '${directory.path}/silent recording.m4a';
      final encoding = await FFmpegKit.executeWithArguments([
        '-y',
        '-i',
        wav.path,
        '-c:a',
        'aac',
        m4a,
      ]);
      expect(ReturnCode.isSuccess(await encoding.getReturnCode()), true);

      final playback = LocalRecordingPlayback();
      await playback.load(m4a);
      expect(playback.status, RecordingPlaybackStatus.ready);
      expect(playback.duration!.inMilliseconds, greaterThan(1500));
      await playback.play();
      await tester.pump(const Duration(milliseconds: 300));
      expect(playback.status, RecordingPlaybackStatus.playing);
      await playback.seek(const Duration(milliseconds: 900));
      expect(playback.position.inMilliseconds, greaterThanOrEqualTo(850));
      await playback.stop();
      await tester.pump(const Duration(milliseconds: 200));
      expect(playback.status, RecordingPlaybackStatus.paused);
      await playback.close();
      final missing = LocalRecordingPlayback();
      await missing.load('${directory.path}/missing.m4a');
      expect(missing.status, RecordingPlaybackStatus.missing);
      await missing.close();

      final entry = JournalEntry(
        id: 'isolated-preview',
        createdAt: DateTime(2026, 10, 19, 18, 42),
        updatedAt: DateTime(2026, 10, 19, 18, 42),
        status: EntryStatus.completed,
        title: 'A little room to breathe',
        audioPath: m4a,
        transcription:
            'I took the longer way home today. No headphones, no calls. '
            'Just the sound of the street and a little room to think.\n\n'
            'I keep treating every quiet moment as something I should fill. '
            'Today it felt good to leave one alone.',
      );
      final drafts = LocalEntryDraftRepository.inDirectory(
        Directory('${directory.path}/drafts'),
      );
      await drafts.write(
        EntryEditDraft(
          source: entry,
          title: entry.title!,
          subtitle: '',
          body: 'Recoverable correction',
          entryDate: entry.effectiveEntryDate,
        ),
      );
      expect(
        (await LocalEntryDraftRepository.inDirectory(
          Directory('${directory.path}/drafts'),
        ).read(entry.id))!.body,
        'Recoverable correction',
      );
      await drafts.remove(entry.id);

      final journal = _Journal();
      when(() => journal.watchById(entry.id)).thenAnswer(
        (_) => const Stream.empty(),
      );
      final processing = _Processing();
      when(() => journal.getById(entry.id)).thenAnswer((_) async => entry);
      when(
        () => processing.applyAiAction(entry, AiAction.organizedNote),
      ).thenAnswer(
        (_) async => entry.copyWith(
          title: 'Optional AI title',
          formattedNote:
              '## A quieter walk\n\n'
              '- Took the longer way home without headphones or calls.\n'
              '- Enjoyed leaving a quiet moment unfilled.',
        ),
      );
      final store = EntryDetailStore(
        journal,
        processing,
        MemoryFormattingModels(),
      );
      GetIt.I.registerFactory<EntryDetailStore>(() => store);
      GetIt.I.registerFactory<IRecordingPlayback>(
        () => LocalRecordingPlayback(),
      );
      final metadataDuration = await LocalRecordingMetadata().duration(m4a);
      expect(metadataDuration!.inMilliseconds, greaterThan(1500));
      GetIt.I.registerFactory<IRecordingMetadata>(
        () => FakeRecordingMetadata()..value = const Duration(seconds: 2),
      );
      addTearDown(() async {
        await GetIt.I.reset();
        await directory.delete(recursive: true);
      });
      final boundary = GlobalKey();
      Widget fixture(bool dark) => RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark : AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EntryDetailScreen(entryId: entry.id),
        ),
      );

      Future<void> snapshot(String name) async {
        await tester.pumpAndSettle();
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File(
          '${(await getTemporaryDirectory()).path}/smartnotes-$name.png',
        );
        await output.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        // Only fixture-image paths; never journal paths or content.
        debugPrint('ENTRY_FIXTURE_SCREENSHOT=${output.path}');
      }

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(fixture(false));
      await tester.pumpAndSettle();
      expect(find.text('A little room to breathe'), findsOneWidget);
      expect(find.text('Original · 0:02'), findsOneWidget);
      expect(find.byType(RecordingPlayer), findsNothing);
      await snapshot('entry-light');
      await tester.tap(find.text('Original · 0:02'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Play recording'), findsOneWidget);
      await snapshot('entry-player');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Original transcription'), findsOneWidget);
      await snapshot('entry-actions');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      expect(find.text('Optional AI title'), findsNothing);
      expect(find.text('Apply'), findsOneWidget);
      await snapshot('entry-ai-preview');
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(fixture(true));
      await tester.pumpAndSettle();
      await snapshot('entry-dark');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
