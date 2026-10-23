import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Workaround for whisper_ggml 2.7.1's Apple file wrapper rejecting `auto`.
/// Uses the bundled whisper.cpp 1.9.1 public C API, not a second model/provider.
/// Remove this pre-pass when the binding accepts auto on all supported targets.
/// The detector's context is freed BEFORE file transcription loads its context.
Future<String> detectWhisperLanguage(String modelPath, String pcmPath) =>
    Isolate.run(() => _detect(modelPath, pcmPath));

Future<String> _detect(String modelPath, String pcmPath) async {
  // The adapter produces at most 30 seconds of mono 16 kHz float32 LE audio.
  final bytes = await File(pcmPath).readAsBytes();
  if (bytes.isEmpty || bytes.length % 4 != 0 || bytes.length > 30 * 16000 * 4) {
    throw const FormatException('Invalid language detection audio.');
  }
  final lib = DynamicLibrary.process();
  final init = lib
      .lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)
      >('whisper_init_from_file');
  final free = lib
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('whisper_free');
  final mel = lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Float>, Int32, Int32),
        int Function(Pointer<Void>, Pointer<Float>, int, int)
      >('whisper_pcm_to_mel');
  final detect = lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Int32, Int32, Pointer<Float>),
        int Function(Pointer<Void>, int, int, Pointer<Float>)
      >('whisper_lang_auto_detect');
  final language = lib
      .lookupFunction<
        Pointer<Utf8> Function(Int32),
        Pointer<Utf8> Function(int)
      >('whisper_lang_str');
  final path = modelPath.toNativeUtf8();
  final samples = malloc<Float>(bytes.length ~/ 4);
  Pointer<Void> context = nullptr;
  try {
    final data = ByteData.sublistView(bytes);
    final audio = samples.asTypedList(bytes.length ~/ 4);
    for (var i = 0; i < audio.length; i++) {
      audio[i] = data.getFloat32(i * 4, Endian.little);
    }
    context = init(path);
    if (context == nullptr) throw StateError('Could not load speech model.');
    final threads = math.min(4, Platform.numberOfProcessors);
    if (mel(context, samples, audio.length, threads) != 0) {
      throw StateError('Could not prepare language detection.');
    }
    final id = detect(context, 0, threads, nullptr);
    if (id < 0) throw StateError('Could not detect speech language.');
    final result = language(id);
    if (result == nullptr) {
      throw StateError('Unknown detected speech language.');
    }
    return result.toDartString();
  } finally {
    if (context != nullptr) free(context);
    malloc.free(samples);
    malloc.free(path);
  }
}
