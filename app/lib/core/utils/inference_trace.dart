import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Opt-in local diagnostics. Never pass source text, paths, or provider errors.
class InferenceTrace {
  static const enabled = bool.fromEnvironment('INFERENCE_TRACE');
  static int _sequence = 0;

  static void event(String stage, [Map<String, Object?> fields = const {}]) {
    if (!enabled) return;
    try {
      debugPrintSynchronously(
        'INFERENCE_TRACE ${jsonEncode({
          'time': DateTime.now().toUtc().toIso8601String(),
          'pid': pid,
          'stage': stage,
          'rssBytes': ProcessInfo.currentRss,
          'maxRssBytes': ProcessInfo.maxRss,
          ...fields,
        })}',
      );
    } catch (_) {
      // Diagnostics must not affect processing or disposal.
    }
  }

  static Future<T> run<T>(String stage, Future<T> Function() work) async {
    if (!enabled) return work();
    final id = ++_sequence;
    final clock = Stopwatch()..start();
    void emit(String state, [String? errorType]) => event('$stage.$state', {
      'span': id,
      'elapsedMs': clock.elapsedMilliseconds,
      'errorType': ?errorType,
    });
    emit('begin');
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => emit('tick'),
    );
    try {
      final result = await work();
      emit('success');
      return result;
    } catch (error) {
      emit('error', error.runtimeType.toString());
      rethrow;
    } finally {
      timer.cancel();
      emit('end');
    }
  }
}
