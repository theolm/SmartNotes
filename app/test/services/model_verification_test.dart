import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/data/services/model_verification.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';

void main() {
  late Directory root;
  late File file;
  late Map<String, String> records;
  late ModelVerificationStore store;
  late int hashes;
  final bytes = [1, 2, 3, 4];
  final digest = sha256.convert(bytes).toString();
  LocalAiModel model({String id = 'fixture', String? hash}) => LocalAiModel(
    id: id,
    name: 'Fixture',
    fileName: '$id.bin',
    url: 'https://example.com/model',
    bytes: bytes.length,
    sha256: hash ?? digest,
  );
  ModelVerification verifier({
    LocalAiModel? artifact,
    ModelVerificationStore? persistence,
    Future<String> Function(File)? hash,
    String? Function()? legacy,
  }) => ModelVerification(
    model: artifact ?? model(),
    folder: 'fixtures',
    store: persistence ?? store,
    legacySignature: legacy,
    hash:
        hash ??
        (_) async {
          hashes++;
          return digest;
        },
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('verification-fixture-');
    file = File('${root.path}/fixtures/fixture.bin');
    await file.parent.create();
    await file.writeAsBytes(bytes);
    records = {};
    hashes = 0;
    store = ModelVerificationStore.forTesting(
      read: (key) => records[key],
      write: (key, value) async {
        if (value == null) {
          records.remove(key);
        } else {
          records[key] = value;
        }
      },
    );
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'cold stat-only probe reuses persisted full verification, zero hashes',
    () async {
      expect(await verifier().cached(file), false);
      expect(hashes, 0);
      expect(await verifier().verify(file), true);
      expect(hashes, 1);
      expect(await verifier().cached(file), true);
      expect(await verifier().verify(file), true);
      expect(hashes, 1);
    },
  );

  for (final field in [
    'size',
    'modified',
    'modelId',
    'digest',
    'version',
    'fileName',
    'folder',
  ]) {
    test('$field mismatch requires full verification', () async {
      expect(await verifier().verify(file), true);
      final key = records.keys.single;
      final record = jsonDecode(records[key]!) as Map<String, dynamic>;
      record[field] =
          field == 'size' || field == 'modified' || field == 'version'
          ? -1
          : 'changed';
      records[key] = jsonEncode(record);
      expect(await verifier().cached(file), false);
      expect(hashes, 1);
      expect(await verifier().verify(file), true);
      expect(hashes, 2);
    });
  }

  test(
    'actual mtime change invalidates the in-process and persisted cache',
    () async {
      final check = verifier();
      await check.verify(file);
      await file.setLastModified(
        DateTime.now().add(const Duration(seconds: 5)),
      );
      expect(await check.verify(file), true);
      expect(hashes, 2);
    },
  );

  test('catalog digest change rejects a formerly valid artifact', () async {
    await verifier().verify(file);
    final check = verifier(artifact: model(hash: 'changed'));
    expect(await check.verify(file), false);
    expect(check.state, ModelCheckState.corrupt);
    expect(records, isEmpty);
  });

  test(
    'missing/truncated files invalidate records without reading contents',
    () async {
      await verifier().verify(file);
      await file.writeAsBytes([1]);
      final check = verifier();
      expect(await check.verify(file), false);
      expect(check.state, ModelCheckState.corrupt);
      await file.delete();
      expect(await check.verify(file), false);
      expect(check.state, ModelCheckState.missing);
      expect(hashes, 1);
      expect(records, isEmpty);
    },
  );

  test(
    'corrupt and unreadable content have distinct recoverable outcomes',
    () async {
      final corrupt = verifier(hash: (_) async => 'wrong');
      expect(await corrupt.verify(file), false);
      expect(corrupt.state, ModelCheckState.corrupt);
      final error = verifier(
        hash: (_) async => throw const FileSystemException(),
      );
      expect(await error.verify(file), false);
      expect(error.state, ModelCheckState.failed);
      expect(records, isEmpty);
    },
  );

  test(
    'explicit invalidation fences an in-flight verification result',
    () async {
      final started = Completer<void>();
      final gate = Completer<String>();
      final check = verifier(
        hash: (_) {
          started.complete();
          return gate.future;
        },
      );
      final job = check.verify(file);
      await started.future;
      await check.invalidate();
      gate.complete(digest);
      expect(await job, false);
      expect(records, isEmpty);
    },
  );

  test('malformed cache is a safe miss', () async {
    records[store.key('fixtures', model().id)] = 'not JSON';
    expect(await verifier().verify(file), true);
    expect(hashes, 1);
  });

  test(
    'preferences failure retains successful verification in memory',
    () async {
      final failing = ModelVerificationStore.forTesting(
        read: (_) => throw StateError('Read failed'),
        write: (_, _) async => throw StateError('Write failed'),
      );
      final check = verifier(persistence: failing);
      expect(await check.verify(file), true);
      expect(await check.verify(file), true);
      expect(hashes, 1);
      expect(await verifier(persistence: failing).verify(file), true);
      expect(hashes, 2);
    },
  );

  test(
    'concurrent same-artifact requests join a single verification',
    () async {
      final gate = Completer<String>();
      final check = verifier(
        hash: (_) {
          hashes++;
          return gate.future;
        },
      );
      final jobs = List.generate(8, (_) => check.verify(file));
      await pumpEventQueue();
      expect(hashes, 1);
      gate.complete(digest);
      expect(await Future.wait(jobs), everyElement(true));
    },
  );

  test('concurrent different-model writes retain both records', () async {
    final other = File('${file.parent.path}/other.bin');
    await other.writeAsBytes(bytes);
    expect(
      await Future.wait([
        verifier().verify(file),
        verifier(artifact: model(id: 'other')).verify(other),
      ]),
      [true, true],
    );
    expect(records, hasLength(2));
    expect(await verifier().cached(file), true);
    expect(await verifier(artifact: model(id: 'other')).cached(other), true);
  });

  test(
    'deletion or mutation during hashing never publishes verification',
    () async {
      final gate = Completer<String>();
      final started = Completer<void>();
      final check = verifier(
        hash: (_) {
          started.complete();
          return gate.future;
        },
      );
      final job = check.verify(file);
      await started.future;
      await file.delete();
      gate.complete(digest);
      expect(await job, false);
      expect(records, isEmpty);
    },
  );

  test(
    'matching legacy formatting signature migrates without a hash',
    () async {
      final stat = await file.stat();
      final legacy = jsonEncode({
        'modelId': model().id,
        'size': stat.size,
        'modified': stat.modified.millisecondsSinceEpoch,
        'digest': digest,
      });
      expect(await verifier(legacy: () => legacy).cached(file), true);
      expect(hashes, 0);
      expect(jsonDecode(records.values.single)['version'], 1);
      expect(await verifier().cached(file), true);
    },
  );

  test(
    'download seeds final artifact and cold activation needs no second hash',
    () async {
      await file.delete();
      final client = MockClient((_) async => http.Response.bytes(bytes, 200));
      addTearDown(client.close);
      LocalModelDownload installation() => LocalModelDownload(
        client,
        model: model(),
        directory: () async => root,
        folder: 'fixtures',
        verificationStore: store,
        hash: (_) async {
          hashes++;
          return digest;
        },
      );
      await installation().download(onProgress: (_, _) {});
      expect(hashes, 1);
      expect(await installation().cachedReady(), true);
      expect(await installation().requireModelPath(), file.path);
      expect(hashes, 1);
    },
  );

  testWidgets('production hash gate waits for the first rendered frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final production = ModelVerificationStore(
      await SharedPreferences.getInstance(),
    );
    final check = verifier(persistence: production);
    late Future<bool> job;
    await tester.runAsync(() async {
      job = check.verify(file);
      await pumpEventQueue();
    });
    expect(hashes, 0);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => production.allowVerification(),
    );
    await tester.pumpWidget(const MaterialApp(home: Text('Readable journal')));
    expect(find.text('Readable journal'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await job, true);
    });
    expect(hashes, 1);
  });
}
