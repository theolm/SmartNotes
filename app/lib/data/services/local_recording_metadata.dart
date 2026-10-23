import 'dart:io';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:smartnotes/domain/services/i_recording_metadata.dart';

/// Reads the MP4 `mvhd` atom without creating an audio player or touching the
/// audio session. AAC recordings are written as M4A/MP4 by the recorder.
@LazySingleton(as: IRecordingMetadata)
class LocalRecordingMetadata implements IRecordingMetadata {
  final _cache = <String, Duration?>{};

  @override
  Future<bool> exists(String path) async {
    try {
      return await File(path).exists();
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<Duration?> duration(String path) async {
    if (_cache.containsKey(path)) return _cache[path];
    final value = await _read(path);
    _cache[path] = value;
    return value;
  }

  Future<Duration?> _read(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final input = await file.open();
    try {
      return await _findMoov(input, 0, await input.length());
    } on FileSystemException {
      return null;
    } finally {
      await input.close();
    }
  }

  Future<Duration?> _findMoov(
    RandomAccessFile input,
    int start,
    int end,
  ) async {
    var offset = start;
    while (offset + 8 <= end) {
      final box = await _readBox(input, offset, end);
      if (box == null) return null;
      if (box.type == 'moov') {
        return _findMvhd(input, box.contentStart, box.end);
      }
      offset = box.end;
    }
    return null;
  }

  Future<Duration?> _findMvhd(
    RandomAccessFile input,
    int start,
    int end,
  ) async {
    var offset = start;
    while (offset + 8 <= end) {
      final box = await _readBox(input, offset, end);
      if (box == null) return null;
      if (box.type == 'mvhd') {
        final payload = await _readAt(
          input,
          box.contentStart,
          box.end - box.contentStart,
        );
        return _parseMvhd(payload);
      }
      offset = box.end;
    }
    return null;
  }

  Duration? _parseMvhd(Uint8List payload) {
    if (payload.isEmpty) return null;
    final version = payload[0];
    if (version != 0 && version != 1) return null;
    if (version == 1 ? payload.length < 32 : payload.length < 20) {
      return null;
    }
    final data = ByteData.sublistView(payload);
    final timescale = version == 1 ? data.getUint32(20) : data.getUint32(12);
    final duration = version == 1 ? data.getUint64(24) : data.getUint32(16);
    if (timescale == 0 || duration == 0) return null;
    if (version != 1 && duration == 0xFFFFFFFF) return null;
    final microseconds = (duration * 1000000 / timescale).round();
    return microseconds > 0 ? Duration(microseconds: microseconds) : null;
  }

  Future<_Box?> _readBox(
    RandomAccessFile input,
    int offset,
    int end,
  ) async {
    final header = await _readAt(input, offset, 8);
    if (header.length < 8) return null;
    final data = ByteData.sublistView(header);
    var size = data.getUint32(0);
    final type = String.fromCharCodes(header.sublist(4, 8));
    var contentStart = offset + 8;
    if (size == 1) {
      final large = await _readAt(input, contentStart, 8);
      if (large.length < 8) return null;
      size = ByteData.sublistView(large).getUint64(0);
      contentStart += 8;
    } else if (size == 0) {
      size = end - offset;
    }
    final boxEnd = offset + size;
    if (size < contentStart - offset || boxEnd > end) return null;
    return _Box(type, contentStart, boxEnd);
  }

  Future<Uint8List> _readAt(
    RandomAccessFile input,
    int offset,
    int length,
  ) async {
    await input.setPosition(offset);
    return input.read(length);
  }
}

class _Box {
  const _Box(this.type, this.contentStart, this.end);
  final String type;
  final int contentStart;
  final int end;
}
