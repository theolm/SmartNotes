import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Rejects only confirmed silence, not quiet speech or ambiguous recordings.
@lazySingleton
class RecordingSignalDetector {
  RecordingSignalDetector() : _execute = FFmpegKit.executeWithArguments;

  @visibleForTesting
  RecordingSignalDetector.withExecutor(this._execute);

  final Future<FFmpegSession> Function(List<String>) _execute;

  Future<bool> isSilent(String path) async {
    try {
      // Inspect the entire recording, including speech after a silent lead-in.
      final session = await _execute([
        '-nostdin',
        '-hide_banner',
        '-i',
        path,
        '-map',
        '0:a:0',
        '-af',
        'volumedetect',
        '-f',
        'null',
        '-',
      ]);
      if (!ReturnCode.isSuccess(await session.getReturnCode())) return false;
      final logs = await session.getAllLogsAsString() ?? '';
      final samples = RegExp(r'n_samples:\s*(\d+)').firstMatch(logs);
      final peak = RegExp(r'max_volume:\s*(-?[\d.]+) dB').firstMatch(logs);
      final count = int.tryParse(samples?.group(1) ?? '');
      final dbfs = double.tryParse(peak?.group(1) ?? '');
      // A peak threshold (not average volume) protects short, quiet utterances.
      return count != null &&
          count > 0 &&
          dbfs != null &&
          dbfs.isFinite &&
          dbfs < -60;
    } catch (_) {
      // Analysis failure is not evidence of silence. Preserve the recording.
      return false;
    }
  }
}
