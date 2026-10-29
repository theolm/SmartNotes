/// Stage timings only: safe to serialize without audio paths or journal text.
/// Durations use a monotonic clock. The plugin request includes its own audio
/// conversion, model loading, native inference, and model disposal; do not label
/// this boundary as pure inference or compare it directly with encoder timings.
class TranscriptionMeasurement {
  const TranscriptionMeasurement({
    required this.queueWait,
    required this.modelVerification,
    required this.audioConversion,
    required this.languageDetection,
    required this.whisperRequest,
    required this.cleanup,
    required this.total,
    this.backend = 'cpu',
    this.fallback = false,
    this.gpuFailureCode,
  });

  final Duration queueWait;
  final Duration modelVerification;
  final Duration audioConversion;
  final Duration languageDetection;
  final Duration whisperRequest;
  final Duration cleanup;
  final Duration total;

  /// Backend that produced the accepted transcript: `cpu` or `vulkan`.
  final String backend;

  /// Whether a GPU attempt failed and the request was retried on the CPU.
  final bool fallback;

  /// Stable native failure code when [fallback] is true.
  final String? gpuFailureCode;

  Map<String, Object> toJson() => {
    'schema_version': 1,
    'backend': backend,
    'fallback': fallback,
    'gpu_failure_code': ?gpuFailureCode,
    'queue_wait_us': queueWait.inMicroseconds,
    'model_verification_us': modelVerification.inMicroseconds,
    'audio_conversion_us': audioConversion.inMicroseconds,
    'language_detection_us': languageDetection.inMicroseconds,
    'whisper_request_us': whisperRequest.inMicroseconds,
    'cleanup_us': cleanup.inMicroseconds,
    'total_us': total.inMicroseconds,
    'whisper_request_scope':
        'plugin conversion, model loading, inference, and native disposal',
  };
}

/// The original transcript is intentionally excluded from timing serialization.
class MeasuredTranscription {
  const MeasuredTranscription(this.text, this.measurement);

  final String text;
  final TranscriptionMeasurement measurement;
}
