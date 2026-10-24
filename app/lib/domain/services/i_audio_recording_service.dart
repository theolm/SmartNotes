import 'package:record/record.dart';

abstract class IAudioRecordingService {
  Stream<RecordState> get onStateChanged;
  Stream<double> get onAmplitudeChanged;
  Future<bool> hasPermission();
  Future<void> start();

  /// Stops capture. Throws AiFailure(noSpeech) for confirmed silence, before
  /// handing the recording to journal persistence or transcription.
  Future<String?> stop();
  Future<void> dispose();
}
