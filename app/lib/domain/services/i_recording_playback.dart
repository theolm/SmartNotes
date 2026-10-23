import 'package:flutter/foundation.dart';

enum RecordingPlaybackStatus {
  idle,
  preparing,
  ready,
  playing,
  paused,
  ended,
  missing,
  error,
}

/// One screen owns one local-file player. No background playback or auto-resume.
abstract class IRecordingPlayback extends ChangeNotifier {
  RecordingPlaybackStatus get status;
  Duration get position;
  Duration? get duration;
  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> close();
}
