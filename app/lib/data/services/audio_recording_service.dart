import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:smartnotes/domain/services/i_audio_recording_service.dart';
import 'package:smartnotes/core/utils/log.dart' show logger;

@Injectable(as: IAudioRecordingService)
class AudioRecordingService implements IAudioRecordingService {
  AudioRecordingService(this._record);

  final AudioRecorder _record;
  String? _currentPath;

  static const double _minDbfs = -60;
  static const Duration _amplitudeInterval = Duration(milliseconds: 50);

  @override
  Stream<RecordState> get onStateChanged => _record.onStateChanged();

  @override
  Stream<double> get onAmplitudeChanged => _record
      .onAmplitudeChanged(_amplitudeInterval)
      .map((amplitude) => _normalizeDbfs(amplitude.current));

  @override
  Future<bool> hasPermission() async {
    final permission = await _record.hasPermission();
    logger.d('hasPermission: $permission');
    return permission;
  }

  @override
  Future<void> start() async {
    logger.d('startRecording requested');
    final hasPermission = await _record.hasPermission();
    if (!hasPermission) {
      logger.e('startRecording failed: microphone permission denied');
      throw Exception('Microphone permission denied');
    }

    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${directory.path}/audio');
    await audioDir.create(recursive: true);

    _currentPath =
        '${audioDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        androidConfig: AndroidRecordConfig(
          useLegacy: kDebugMode,
        ),
      ),
      path: _currentPath!,
    );
    try {
      await WakelockPlus.enable();
      logger.d('startRecording: recorder started, wakelock enabled');
    } catch (e) {
      logger.w('startRecording: failed to enable wakelock: $e');
    }
  }

  @override
  Future<String?> stop() async {
    logger.d('stopRecording called');
    try {
      await WakelockPlus.disable();
    } catch (e) {
      logger.w('stopRecording: failed to disable wakelock: $e');
    }
    final path = await _record.stop();
    final recordedPath = path ?? _currentPath;
    _currentPath = null;

    if (recordedPath == null) {
      logger.w('stopRecording: returned path is null');
    }

    return recordedPath;
  }

  @override
  Future<void> dispose() async {
    await _record.dispose();
  }

  double _normalizeDbfs(double dbfs) {
    if (dbfs.isNaN || dbfs.isInfinite) return 0;
    return ((dbfs - _minDbfs) / -_minDbfs).clamp(0.0, 1.0).toDouble();
  }
}
