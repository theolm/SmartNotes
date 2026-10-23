import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';

/// Per-artifact records, independent of journal storage. Separate preference
/// keys prevent concurrent model installations from overwriting one another.
@lazySingleton
class ModelVerificationStore {
  ModelVerificationStore(SharedPreferences preferences)
    : read = preferences.getString,
      _firstFrame = Completer<void>(),
      write = ((key, value) async {
        if (value == null) {
          await preferences.remove(key);
        } else {
          await preferences.setString(key, value);
        }
      });

  ModelVerificationStore.forTesting({required this.read, required this.write})
    : _firstFrame = null;

  final Completer<void>? _firstFrame;
  void allowVerification() {
    if (_firstFrame != null && !_firstFrame.isCompleted) _firstFrame.complete();
  }

  Future<void> get afterFirstFrame => _firstFrame?.future ?? Future.value();

  final String? Function(String key) read;
  final Future<void> Function(String key, String? value) write;

  String key(String folder, String id) => 'modelVerification.v1.$folder.$id';
}

/// Owns verification, cache invalidation and single-flight checks. A cache probe
/// never opens artifact contents. Full hashes are globally serialized.
class ModelVerification {
  ModelVerification({
    required this.model,
    required this.folder,
    this.store,
    this.legacySignature,
    Future<String> Function(File)? hash,
  }) : _hash = hash ?? _sha256;

  final LocalAiModel model;
  final String folder;
  final ModelVerificationStore? store;
  final String? Function()? legacySignature;
  final Future<String> Function(File) _hash;
  Map<String, dynamic>? _memory;
  Future<bool>? _checking;
  int _generation = 0;
  ModelCheckState state = ModelCheckState.unchecked;
  int fullHashCount = 0;
  int cacheHitCount = 0;
  static Future<void> _tail = Future.value();

  static Future<String> _sha256(File file) {
    final path = file.path;
    return Isolate.run(
      () async => (await sha256.bind(File(path).openRead()).first).toString(),
    );
  }

  static Future<T> _serialized<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Map<String, dynamic>? _decode(String? raw) {
    try {
      final value = raw == null ? null : jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  bool _matches(Map<String, dynamic>? record, FileStat stat) =>
      record != null &&
      record['version'] == 1 &&
      record['fileName'] == model.fileName &&
      record['folder'] == folder &&
      record['modelId'] == model.id &&
      record['size'] == stat.size &&
      record['modified'] == stat.modified.millisecondsSinceEpoch &&
      record['digest'] == model.sha256 &&
      stat.type == FileSystemEntityType.file &&
      stat.size == model.bytes;

  Map<String, dynamic> _record(FileStat stat) => {
    'version': 1,
    'fileName': model.fileName,
    'folder': folder,
    'modelId': model.id,
    'size': stat.size,
    'modified': stat.modified.millisecondsSinceEpoch,
    'digest': model.sha256,
    'verifiedAt': DateTime.now().millisecondsSinceEpoch,
  };

  Future<void> _persist(Map<String, dynamic>? record) async {
    try {
      await store?.write(
        store!.key(folder, model.id),
        record == null ? null : jsonEncode(record),
      );
    } catch (_) {
      // Persistence is an optimization, never an integrity requirement.
    }
  }

  Future<void> invalidate() async {
    _generation++;
    await _forget();
  }

  Future<void> _forget() async {
    _memory = null;
    state = ModelCheckState.unchecked;
    await _persist(null);
  }

  Future<bool> cached(File file) async {
    final stat = await file.stat();
    Map<String, dynamic>? record = _memory;
    try {
      record ??= _decode(store?.read(store!.key(folder, model.id)));
    } catch (_) {
      // Unavailable preferences require verification, not a startup failure.
    }
    if (_matches(record, stat)) {
      cacheHitCount++;
      _memory = record;
      state = ModelCheckState.ready;
      return true;
    }
    // ADR-023's legacy formatting record has no version or artifact fields.
    Map<String, dynamic>? legacy;
    try {
      legacy = _decode(legacySignature?.call());
    } catch (_) {}
    if (legacy != null &&
        _matches(
          {
            ...legacy,
            'version': 1,
            'fileName': model.fileName,
            'folder': folder,
          },
          stat,
        )) {
      await remember(stat);
      return true;
    }
    await _forget();
    state = stat.type != FileSystemEntityType.file
        ? ModelCheckState.missing
        : stat.size != model.bytes
        ? ModelCheckState.corrupt
        : _checking != null
        ? ModelCheckState.checking
        : ModelCheckState.unchecked;
    return false;
  }

  Future<void> remember(FileStat stat) async {
    _memory = _record(stat);
    state = ModelCheckState.ready;
    await _persist(_memory);
  }

  Future<bool> verify(File file) =>
      _checking ??= _verify(file).whenComplete(() => _checking = null);

  Future<bool> _verify(File file) async {
    try {
      if (await cached(file)) return true;
      if (state == ModelCheckState.missing ||
          state == ModelCheckState.corrupt) {
        return false;
      }
      state = ModelCheckState.checking;
      final generation = _generation;
      await store?.afterFirstFrame;
      return await _serialized(() async {
        final before = await file.stat();
        if (before.type != FileSystemEntityType.file ||
            before.size != model.bytes) {
          state = ModelCheckState.missing;
          return false;
        }
        fullHashCount++;
        final digest = await _hash(file);
        final after = await file.stat();
        if (generation != _generation ||
            digest != model.sha256 ||
            before.modified != after.modified ||
            before.changed != after.changed ||
            before.size != after.size ||
            after.type != FileSystemEntityType.file) {
          await invalidate();
          state = ModelCheckState.corrupt;
          return false;
        }
        await remember(after);
        return true;
      });
    } catch (_) {
      await invalidate();
      state = ModelCheckState.failed;
      return false;
    }
  }

  /// Download validation does not certify a .part under the final artifact key.
  Future<bool> validatePartial(File file) async {
    await store?.afterFirstFrame;
    return _serialized(() async {
      final before = await file.stat();
      if (before.type != FileSystemEntityType.file ||
          before.size != model.bytes) {
        return false;
      }
      fullHashCount++;
      final digest = await _hash(file);
      final after = await file.stat();
      return digest == model.sha256 &&
          before.size == after.size &&
          before.modified == after.modified &&
          before.changed == after.changed;
    });
  }
}
