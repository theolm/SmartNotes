import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/data/services/local_recording_metadata.dart';

void main() {
  late Directory directory;
  late LocalRecordingMetadata metadata;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recording-metadata-');
    metadata = LocalRecordingMetadata();
  });

  tearDown(() => directory.delete(recursive: true));

  Uint8List box(String type, Uint8List payload) {
    final data = ByteData(8 + payload.length);
    data.setUint32(0, 8 + payload.length);
    for (var index = 0; index < 4; index++) {
      data.setUint8(4 + index, type.codeUnitAt(index));
    }
    final bytes = data.buffer.asUint8List();
    bytes.setRange(8, bytes.length, payload);
    return bytes;
  }

  Uint8List mvhd({
    required int version,
    required int timescale,
    required int duration,
  }) {
    final payloadLength = version == 1 ? 32 : 20;
    final data = ByteData(payloadLength);
    data.setUint8(0, version);
    if (version == 1) {
      data.setUint32(20, timescale);
      data.setUint64(24, duration);
    } else {
      data.setUint32(12, timescale);
      data.setUint32(16, duration);
    }
    return box('mvhd', data.buffer.asUint8List());
  }

  test('reads version 0 duration from the moov/mvhd atom', () async {
    final file = File('${directory.path}/recording.m4a')
      ..writeAsBytesSync(
        box('moov', mvhd(version: 0, timescale: 1000, duration: 12345)),
      );
    expect(
      await metadata.duration(file.path),
      const Duration(milliseconds: 12345),
    );
  });

  test('reads version 1 duration and caches the immutable recording', () async {
    final file = File('${directory.path}/recording-v1.m4a')
      ..writeAsBytesSync(
        box('moov', mvhd(version: 1, timescale: 1000, duration: 2500)),
      );
    expect(
      await metadata.duration(file.path),
      const Duration(seconds: 2, milliseconds: 500),
    );
    await file.delete();
    expect(
      await metadata.duration(file.path),
      const Duration(seconds: 2, milliseconds: 500),
    );
  });

  test('missing and malformed files return no duration', () async {
    expect(await metadata.duration('${directory.path}/missing.m4a'), isNull);
    final malformed = File('${directory.path}/broken.m4a')
      ..writeAsBytesSync([0, 0, 0, 4, 0x6d, 0x6f, 0x6f, 0x76]);
    expect(await metadata.duration(malformed.path), isNull);
  });
}
