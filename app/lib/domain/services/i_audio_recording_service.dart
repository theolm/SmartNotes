import 'package:record/record.dart';

abstract class IAudioRecordingService {
  Stream<RecordState> get onStateChanged;
  Stream<double> get onAmplitudeChanged;
  Future<bool> hasPermission();
  Future<void> start();
  Future<String?> stop();
  Future<void> dispose();
}
