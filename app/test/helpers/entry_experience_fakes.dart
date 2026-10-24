import 'package:smartnotes/domain/services/i_entry_draft_repository.dart';
import 'package:smartnotes/domain/services/i_recording_metadata.dart';
import 'package:smartnotes/domain/services/i_recording_playback.dart';

class MemoryEntryDrafts implements IEntryDraftRepository {
  final values = <String, EntryEditDraft>{};
  bool fail = false;
  @override
  Future<EntryEditDraft?> read(String id) async {
    if (fail) throw Exception('Unavailable');
    return values[id];
  }

  @override
  Future<void> write(EntryEditDraft draft) async {
    if (fail) throw Exception('Unavailable');
    values[draft.id] = draft;
  }

  @override
  Future<void> remove(String id) async {
    if (fail) throw Exception('Unavailable');
    values.remove(id);
  }
}

class FakeRecordingMetadata implements IRecordingMetadata {
  bool available = false;
  @override
  Future<bool> exists(String path) async => available;
  Duration? value = const Duration(minutes: 1, seconds: 34);
  @override
  Future<Duration?> duration(String path) async => value;
}

class FakeRecordingPlayback extends IRecordingPlayback {
  @override
  RecordingPlaybackStatus status = RecordingPlaybackStatus.idle;
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration = const Duration(seconds: 94);
  bool missing = false;
  bool failLoad = false;
  int failuresRemaining = 0;
  int playCalls = 0;
  int stopCalls = 0;
  bool closed = false;

  void emit(RecordingPlaybackStatus value) {
    status = value;
    notifyListeners();
  }

  @override
  Future<void> load(String path) async {
    closed = false;
    final failure = failLoad || failuresRemaining > 0;
    if (failuresRemaining > 0) failuresRemaining--;
    emit(
      missing
          ? RecordingPlaybackStatus.missing
          : failure
          ? RecordingPlaybackStatus.error
          : RecordingPlaybackStatus.ready,
    );
  }

  @override
  Future<void> play() async {
    playCalls++;
    emit(RecordingPlaybackStatus.playing);
  }

  @override
  Future<void> pause() async => emit(RecordingPlaybackStatus.paused);
  @override
  Future<void> seek(Duration value) async {
    position = value;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    emit(RecordingPlaybackStatus.paused);
  }

  @override
  Future<void> close() async {
    // Reusable test double: each player sheet opens a fresh lifecycle.
    closed = true;
  }
}
