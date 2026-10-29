import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

/// Crash-safe GPU state. The pending marker is written synchronously before
/// native Vulkan work so a driver crash leaves evidence on the next launch.
/// It intentionally contains no audio, transcript, entry, or file paths.
@lazySingleton
class GpuCircuitStore {
  GpuCircuitStore() : _fileOverride = null;

  @visibleForTesting
  GpuCircuitStore.at(File file) : _fileOverride = file;

  static const _fileName = 'speech-gpu-circuit.json';
  static const _failureLimit = 2;

  final File? _fileOverride;
  File? _resolved;
  GpuCircuitState _state = const GpuCircuitState();

  Future<File> _file() async {
    final override = _fileOverride;
    if (override != null) return override;
    final cached = _resolved;
    if (cached != null) return cached;
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return _resolved = File('${directory.path}/$_fileName');
  }

  /// Reads and resolves an interrupted attempt. Call before journal recovery.
  Future<GpuCircuitState> read() async {
    final file = await _file();
    final type = FileSystemEntity.typeSync(file.path);
    if (type == FileSystemEntityType.notFound) {
      _state = const GpuCircuitState();
      return _state;
    }
    if (type != FileSystemEntityType.file) {
      throw const FileSystemException('GPU state is not a regular file');
    }
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Unexpected GPU state');
      }
      if ((raw['runtime'] != null && raw['runtime'] is! String) ||
          (raw['reason'] != null && raw['reason'] is! String)) {
        throw const FormatException('Invalid GPU state fields');
      }
      final pending = raw['pending'];
      if (pending is Map<String, dynamic>) {
        // The process did not reach the end of a GPU attempt. Disabling the
        // backend now prevents a crash loop; recovery runs on the CPU.
        _state = GpuCircuitState(
          open: true,
          failures: _failureLimit,
          reason: 'interrupted',
          runtime: raw['runtime'] as String?,
        );
        _writeSync();
        return _state;
      }
      _state = GpuCircuitState(
        open: raw['open'] == true,
        failures: raw['failures'] is num
            ? (raw['failures'] as num).toInt()
            : 0,
        reason: raw['reason'] as String?,
        runtime: raw['runtime'] as String?,
      );
      return _state;
    } on FormatException {
      // Corrupt diagnostic state must not block transcription. Treat it as an
      // interrupted attempt rather than silently trusting the GPU again.
      _state = const GpuCircuitState(
        open: true,
        failures: _failureLimit,
        reason: 'corrupt_state',
      );
      _writeSync();
      return _state;
    }
  }

  Future<void> begin({required String model, String? runtime}) async {
    final file = await _file();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = file.existsSync()
        ? _decodeOrNull(file.readAsStringSync())
        : null;
    final data = <String, dynamic>{
      'schema_version': 1,
      'pending': {
        'model': model,
        'runtime': runtime,
        'started_at': now,
      },
      'failures': existing?['failures'] ?? _state.failures,
      'open': existing?['open'] == true || _state.open,
      'reason': existing?['reason'] ?? _state.reason,
      'runtime': runtime ?? existing?['runtime'] ?? _state.runtime,
      'updated_at': now,
    };
    _writeSync(data);
  }

  Future<void> complete({String? runtime}) async {
    final file = await _file();
    if (!file.existsSync()) return;
    final existing = _decodeOrNull(file.readAsStringSync());
    if (existing == null) return;
    final data = <String, dynamic>{
      ...existing,
      'pending': null,
      'runtime': runtime ?? existing['runtime'],
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    _writeSync(data);
  }

  Future<void> recordFailure({
    required String model,
    required String code,
    String? runtime,
  }) async {
    final file = await _file();
    final existing = file.existsSync()
        ? _decodeOrNull(file.readAsStringSync())
        : null;
    final previous = existing?['failures'] is num
        ? (existing!['failures'] as num).toInt()
        : _state.failures;
    final failures = previous + 1;
    _state = GpuCircuitState(
      open: failures >= _failureLimit,
      failures: failures,
      reason: code,
      runtime: runtime ?? _state.runtime,
    );
    final data = <String, dynamic>{
      'schema_version': 1,
      'pending': null,
      'failures': failures,
      'open': _state.open,
      'reason': code,
      'runtime': _state.runtime,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    _writeSync(data);
  }

  Future<void> reset() async {
    _state = const GpuCircuitState();
    final file = await _file();
    if (file.existsSync()) file.deleteSync();
  }

  Map<String, dynamic>? _decodeOrNull(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }

  void _writeSync([Map<String, dynamic>? data]) {
    final file = _fileOverride ?? _resolved;
    if (file == null) {
      throw StateError('GPU state file has not been resolved');
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode(data ?? _state.toJson()),
      flush: true,
    );
  }
}

class GpuCircuitState {
  const GpuCircuitState({
    this.open = false,
    this.failures = 0,
    this.reason,
    this.runtime,
  });

  final bool open;
  final int failures;
  final String? reason;
  final String? runtime;

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'pending': null,
    'failures': failures,
    'open': open,
    'reason': reason,
    'runtime': runtime,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  };
}
