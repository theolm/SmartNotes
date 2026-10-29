import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/data/services/transcription_measurement.dart';

void main() {
  test('serializes microsecond stages without transcript or paths', () {
    const measurement = TranscriptionMeasurement(
      queueWait: Duration(microseconds: 1),
      modelVerification: Duration(microseconds: 2),
      audioConversion: Duration(microseconds: 3),
      languageDetection: Duration(microseconds: 4),
      whisperRequest: Duration(microseconds: 5),
      cleanup: Duration(microseconds: 6),
      total: Duration(microseconds: 25),
    );
    const result = MeasuredTranscription('Private original text', measurement);
    final json = result.measurement.toJson();
    expect(json['schema_version'], 1);
    expect(json['backend'], 'cpu');
    expect(json['fallback'], isFalse);
    expect(json.containsKey('gpu_failure_code'), isFalse);
    expect(json['queue_wait_us'], 1);
    expect(json['model_verification_us'], 2);
    expect(json['audio_conversion_us'], 3);
    expect(json['language_detection_us'], 4);
    expect(json['whisper_request_us'], 5);
    expect(json['cleanup_us'], 6);
    expect(json['total_us'], 25);
    expect(json['whisper_request_scope'], contains('plugin conversion'));
    expect(jsonEncode(json), isNot(contains(result.text)));
    expect(json.keys, isNot(contains('audioPath')));
    expect(json.keys, isNot(contains('modelPath')));
  });

  test('reports the backend that produced the transcript and fallback code', () {
    const measurement = TranscriptionMeasurement(
      queueWait: Duration.zero,
      modelVerification: Duration.zero,
      audioConversion: Duration.zero,
      languageDetection: Duration.zero,
      whisperRequest: Duration.zero,
      cleanup: Duration.zero,
      total: Duration.zero,
      backend: 'cpu',
      fallback: true,
      gpuFailureCode: 'vulkan_init_failed',
    );
    final json = measurement.toJson();
    expect(json['backend'], 'cpu');
    expect(json['fallback'], isTrue);
    expect(json['gpu_failure_code'], 'vulkan_init_failed');
  });
}
