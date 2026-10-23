import 'dart:async';
import 'package:smartnotes/application/journal_lifecycle.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' hide when;
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/domain/services/i_audio_recording_service.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/use_cases/process_audio_note.dart';
import '../helpers/local_services.dart';

class MockJournalEntryService extends Mock implements IJournalEntryService {}

class MockAudioRecordingService extends Mock
    implements IAudioRecordingService {}

class MockProcessAudioNoteUseCase extends Mock
    implements ProcessAudioNoteUseCase {}

void main() {
  late MockJournalEntryService mockJournalService;
  late MockAudioRecordingService mockAudioService;
  late MockProcessAudioNoteUseCase mockUseCase;
  late HomeStore store;
  late JournalLifecycle lifecycle;
  late StreamController<List<JournalEntry>> entriesController;

  setUpAll(() {
    registerFallbackValue(
      JournalEntry(
        id: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: EntryStatus.processing,
      ),
    );
  });

  setUp(() {
    entriesController = StreamController<List<JournalEntry>>.broadcast();
    mockJournalService = MockJournalEntryService();
    when(
      () => mockJournalService.watchSearchMaintenance(),
    ).thenAnswer((_) => const Stream.empty());
    mockAudioService = MockAudioRecordingService();
    mockUseCase = MockProcessAudioNoteUseCase();
    when(
      () => mockAudioService.onStateChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockAudioService.onAmplitudeChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockJournalService.watchAll(),
    ).thenAnswer((_) => entriesController.stream);
    final savedEntries = <String, JournalEntry>{};
    when(() => mockJournalService.update(any())).thenAnswer(
      (invocation) async {
        final entry = invocation.positionalArguments[0] as JournalEntry;
        savedEntries[entry.id] = entry;
        return entry;
      },
    );
    when(() => mockJournalService.getById(any())).thenAnswer(
      (invocation) async => savedEntries[invocation.positionalArguments[0]],
    );
    when(
      () => mockJournalService.update(any(), expected: any(named: 'expected')),
    ).thenAnswer(
      (invocation) async {
        final entry = invocation.positionalArguments[0] as JournalEntry;
        savedEntries[entry.id] = entry;
        return entry;
      },
    );
    final search = MemorySearch(() => store.entries.toList());
    lifecycle = JournalLifecycle(
      mockJournalService,
      mockUseCase,
      search,
      MemoryEmbeddingModels(),
    );
    store = HomeStore(
      mockJournalService,
      mockAudioService,
      lifecycle,
      search,
    );
  });

  tearDown(() async {
    store.dispose();
    await lifecycle.dispose();
    await entriesController.close();
  });

  group('HomeStore', () {
    test(
      'silent recording never creates an entry or starts transcription',
      () async {
        store.isRecording = true;
        when(() => mockAudioService.stop()).thenThrow(
          const AiFailure(AiFailureCode.noSpeech),
        );

        await store.toggleRecording();

        expect(store.isRecording, false);
        expect(store.isProcessing, false);
        expect(store.errorMessage, 'recordingNoSpeech');
        verifyNever(
          () => mockJournalService.create(audioPath: any(named: 'audioPath')),
        );
        verifyZeroInteractions(mockUseCase);
      },
    );
    test('missing key never prevents stopping an active recording', () async {
      store.isRecording = true;
      when(() => mockAudioService.stop()).thenAnswer((_) async => null);

      expect(await store.toggleRecording(), isNull);
      expect(store.isRecording, false);
      verify(() => mockAudioService.stop()).called(1);
      verifyNever(() => mockAudioService.hasPermission());
    });
    test(
      'local recording does not require an API key',
      () async {
        when(
          () => mockAudioService.hasPermission(),
        ).thenAnswer((_) async => true);
        when(() => mockAudioService.start()).thenAnswer((_) async {});

        expect(
          await store.toggleRecording(),
          RecordingStartResult.started,
        );
        expect(store.isRecording, true);
        expect(store.errorMessage, isNull);
        verify(() => mockAudioService.hasPermission()).called(1);
        verify(() => mockAudioService.start()).called(1);
        verifyNever(
          () => mockJournalService.create(audioPath: any(named: 'audioPath')),
        );
        verifyZeroInteractions(mockUseCase);
      },
    );
    test('subscribes to watchAll on creation', () {
      verify(() => mockJournalService.watchAll()).called(1);
    });

    test('populates entries and stops loading when stream emits', () async {
      final now = DateTime.now();
      final entries = [
        JournalEntry(
          id: '1',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.completed,
          title: 'First',
          formattedNote: 'Note one',
        ),
      ];

      entriesController.add(entries);
      await pumpEventQueue();

      expect(store.entries.length, 1);
      expect(store.entries.first.id, '1');
      expect(store.isLoading, false);
      expect(store.errorMessage, isNull);
    });

    test('updates entries reactively on subsequent stream events', () async {
      final now = DateTime.now();
      final first = [
        JournalEntry(
          id: '1',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.completed,
        ),
      ];
      final second = [
        ...first,
        JournalEntry(
          id: '2',
          createdAt: now.add(const Duration(seconds: 1)),
          updatedAt: now.add(const Duration(seconds: 1)),
          status: EntryStatus.completed,
        ),
      ];

      entriesController.add(first);
      await pumpEventQueue();
      expect(store.entries.length, 1);

      entriesController.add(second);
      await pumpEventQueue();
      expect(store.entries.length, 2);
    });

    test('deleteEntry deletes the entry and reports success', () async {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
      );
      when(() => mockJournalService.delete(entry.id)).thenAnswer((_) async {});

      final deleted = await store.deleteEntry(entry);

      expect(deleted, isTrue);
      expect(store.errorMessage, isNull);
      verify(() => mockJournalService.delete(entry.id)).called(1);
    });

    test('deleteEntry keeps the entry available when deletion fails', () async {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.completed,
      );
      store.entries = ObservableList.of([entry]);
      when(() => mockJournalService.delete(entry.id)).thenThrow(Exception());

      final deleted = await store.deleteEntry(entry);

      expect(deleted, isFalse);
      expect(store.entries, contains(entry));
      expect(store.errorMessage, 'Failed to delete entry');
    });

    test('sets errorMessage on stream error', () async {
      entriesController.addError(Exception('boom'));
      await pumpEventQueue();

      expect(store.isLoading, false);
      expect(store.errorMessage, isNotNull);
    });

    test('createDummyEntry creates and updates entries', () async {
      final now = DateTime.now();
      final created = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.processing,
        audioPath: '/dev/null/dummy.m4a',
      );
      final completed = created.copyWith(
        title: 'Sample entry',
        formattedNote: 'This is a sample note created for testing.',
        status: EntryStatus.completed,
      );

      when(
        () => mockJournalService.create(audioPath: any(named: 'audioPath')),
      ).thenAnswer((_) async => created);
      when(
        () => mockJournalService.update(completed),
      ).thenAnswer((_) async => completed);

      await store.createDummyEntry();

      verify(
        () => mockJournalService.create(audioPath: '/dev/null/dummy.m4a'),
      ).called(1);
      verify(() => mockJournalService.update(completed)).called(1);
    });

    test('startRecording sets isRecording to true on success', () async {
      when(
        () => mockAudioService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(() => mockAudioService.start()).thenAnswer((_) async => {});

      await store.startRecording();

      expect(store.isRecording, true);
      expect(store.errorMessage, isNull);
    });

    test('startRecording shows error when permission denied', () async {
      when(
        () => mockAudioService.hasPermission(),
      ).thenAnswer((_) async => false);

      await store.startRecording();

      expect(store.isRecording, false);
      expect(store.errorMessage, isNotNull);
    });

    test('toggleRecording starts recording when idle', () async {
      when(
        () => mockAudioService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(() => mockAudioService.start()).thenAnswer((_) async => {});

      await store.toggleRecording();

      expect(store.isRecording, true);
      verify(() => mockAudioService.start()).called(1);
    });

    test('toggleRecording stops recording when active', () async {
      const audioPath = '/audio/test.m4a';
      final now = DateTime.now();
      final created = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.processing,
        audioPath: audioPath,
      );

      when(
        () => mockAudioService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(() => mockAudioService.start()).thenAnswer((_) async => {});
      when(() => mockAudioService.stop()).thenAnswer((_) async => audioPath);
      when(
        () => mockJournalService.create(audioPath: audioPath),
      ).thenAnswer((_) async => created);

      await store.toggleRecording();
      expect(store.isRecording, true);

      await store.toggleRecording();
      expect(store.isRecording, false);
      verify(() => mockAudioService.stop()).called(1);
    });

    test('toggleRecording ignores rapid double-tap', () async {
      when(
        () => mockAudioService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(() => mockAudioService.start()).thenAnswer((_) async => {});

      // Fire two toggles concurrently; only one should start recording
      await Future.wait([
        store.toggleRecording(),
        store.toggleRecording(),
      ]);

      expect(store.isRecording, true);
      verify(() => mockAudioService.start()).called(1);
    });

    test(
      'startRecording exposes live amplitude from the service stream',
      () async {
        final amplitudeController = StreamController<double>();
        when(
          () => mockAudioService.onAmplitudeChanged,
        ).thenAnswer((_) => amplitudeController.stream);
        when(
          () => mockAudioService.hasPermission(),
        ).thenAnswer((_) async => true);
        when(() => mockAudioService.start()).thenAnswer((_) async => {});

        await store.startRecording();
        expect(store.amplitude, 0.0);

        amplitudeController.add(0.7);
        await pumpEventQueue();

        expect(store.amplitude, 0.7);

        await amplitudeController.close();
      },
    );

    test('stopRecording resets amplitude and stops listening', () async {
      const audioPath = '/audio/test.m4a';
      final now = DateTime.now();
      final created = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.processing,
        audioPath: audioPath,
      );
      final amplitudeController = StreamController<double>();

      when(
        () => mockAudioService.onAmplitudeChanged,
      ).thenAnswer((_) => amplitudeController.stream);
      when(
        () => mockAudioService.hasPermission(),
      ).thenAnswer((_) async => true);
      when(() => mockAudioService.start()).thenAnswer((_) async => {});
      when(() => mockAudioService.stop()).thenAnswer((_) async => audioPath);
      when(
        () => mockJournalService.create(audioPath: audioPath),
      ).thenAnswer((_) async => created);
      when(() => mockUseCase.process(created)).thenAnswer((_) async => created);

      await store.startRecording();
      amplitudeController.add(0.7);
      await pumpEventQueue();
      expect(store.amplitude, 0.7);

      await store.stopRecording();
      expect(store.amplitude, 0.0);

      amplitudeController.add(0.9);
      await pumpEventQueue();
      expect(store.amplitude, 0.0);

      await amplitudeController.close();
    });

    test('stopRecording is no-op when recording not started', () async {
      expect(store.isRecording, false);

      await store.stopRecording();

      expect(store.errorMessage, isNull);
      verifyNever(() => mockAudioService.stop());
      verifyNever(
        () => mockJournalService.create(audioPath: any(named: 'audioPath')),
      );
    });

    test('stopRecording processes audio via use case on success', () async {
      const audioPath = '/audio/test.m4a';
      final now = DateTime.now();
      final created = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.processing,
        audioPath: audioPath,
      );
      final completed = created.copyWith(
        title: 'Test Note',
        formattedNote: '# Test\n\nThis is a note.',
        transcription: 'This is a test note.',
        status: EntryStatus.completed,
      );

      when(() => mockAudioService.stop()).thenAnswer((_) async => audioPath);
      when(
        () => mockJournalService.create(audioPath: audioPath),
      ).thenAnswer((_) async => created);
      when(
        () => mockUseCase.process(created),
      ).thenAnswer((_) async => completed);

      await store.startRecording();
      store.isRecording = true;

      await store.stopRecording();
      await pumpEventQueue();

      expect(store.isRecording, false);
      verify(() => mockUseCase.process(created)).called(1);
    });

    test('stopRecording sets entry to error when use case fails', () async {
      const audioPath = '/audio/test.m4a';
      final now = DateTime.now();
      final created = JournalEntry(
        id: '1',
        createdAt: now,
        updatedAt: now,
        status: EntryStatus.processing,
        audioPath: audioPath,
      );
      final errored = created.copyWith(status: EntryStatus.error);

      when(() => mockAudioService.stop()).thenAnswer((_) async => audioPath);
      when(
        () => mockJournalService.create(audioPath: audioPath),
      ).thenAnswer((_) async => created);
      when(
        () => mockUseCase.process(created),
      ).thenThrow(Exception('processing failed'));
      when(
        () => mockJournalService.update(errored),
      ).thenAnswer((_) async => errored);

      await store.startRecording();
      store.isRecording = true;

      await store.stopRecording();

      expect(store.isRecording, false);
      await pumpEventQueue();
      verify(
        () => mockJournalService.update(
          errored,
          expected: any(named: 'expected'),
        ),
      ).called(1);
    });

    test(
      'displayedEntries uses search results for title, note, and transcription',
      () async {
        final now = DateTime.now();
        final entries = [
          JournalEntry(
            id: '1',
            createdAt: now,
            updatedAt: now,
            status: EntryStatus.completed,
            title: 'Café planning',
            formattedNote: 'We need to buy coffee.',
            transcription: 'buy coffee',
          ),
          JournalEntry(
            id: '2',
            createdAt: now,
            updatedAt: now,
            status: EntryStatus.completed,
            title: 'Gym',
            formattedNote: 'Leg day today.',
            transcription: 'workout legs',
          ),
          JournalEntry(
            id: '3',
            createdAt: now,
            updatedAt: now,
            status: EntryStatus.completed,
            title: 'Random',
            formattedNote: 'Nothing here.',
            transcription: 'random speech',
          ),
        ];
        store.entries = ObservableList.of(entries);

        store.submitSearch('cafe');
        await store.runSearch();
        expect(store.displayedEntries.length, 1);
        expect(store.displayedEntries.first.id, '1');

        store.submitSearch('legs');
        await store.runSearch();
        expect(store.displayedEntries.length, 1);
        expect(store.displayedEntries.first.id, '2');

        store.submitSearch('nothing');
        await store.runSearch();
        expect(store.displayedEntries.length, 1);
        expect(store.displayedEntries.first.id, '3');
      },
    );

    test('clearSearch resets displayedEntries to all entries', () async {
      final now = DateTime.now();
      final entries = [
        JournalEntry(
          id: '1',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.completed,
          title: 'First',
          formattedNote: 'Note one',
        ),
        JournalEntry(
          id: '2',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.completed,
          title: 'Second',
          formattedNote: 'Note two',
        ),
      ];
      store.entries = ObservableList.of(entries);
      store.submitSearch('one');
      await store.runSearch();
      expect(store.displayedEntries.length, 1);

      store.clearSearch();

      expect(store.searchQuery, '');
      expect(store.displayedEntries.length, 2);
    });

    test('entry snapshots render state without starting recovery', () async {
      final now = DateTime.now();
      entriesController.add([
        JournalEntry(
          id: 'pending',
          createdAt: now,
          updatedAt: now,
          status: EntryStatus.processing,
        ),
      ]);
      await pumpEventQueue();
      expect(store.entries.single.id, 'pending');
      verifyZeroInteractions(mockUseCase);
    });
  });
}
