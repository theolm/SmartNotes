import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/data/services/gpu_circuit_store.dart';

void main() {
  late Directory directory;
  late File file;
  late GpuCircuitStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('gpu-circuit-test-');
    file = File('${directory.path}/circuit.json');
    store = GpuCircuitStore.at(file);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('an unfinished GPU attempt opens the circuit on the next read', () async {
    file.writeAsStringSync(
      jsonEncode({
        'schema_version': 1,
        'pending': {'model': 'whisper-small-q5_1', 'started_at': 1},
        'failures': 0,
        'open': false,
        'runtime': 'runtime-1',
      }),
    );
    final state = await store.read();
    expect(state.open, isTrue);
    expect(state.reason, 'interrupted');
    expect(state.runtime, 'runtime-1');
    final persisted = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(persisted['pending'], isNull);
    expect(persisted['open'], isTrue);
  });

  test('a completed attempt clears the marker without opening the circuit', () async {
    await store.begin(model: 'whisper-small-q5_1', runtime: 'runtime-1');
    await store.complete(runtime: 'runtime-1');
    final state = await store.read();
    expect(state.open, isFalse);
    expect(state.failures, 0);
  });

  test('two recoverable failures open the circuit', () async {
    await store.begin(model: 'whisper-small-q5_1');
    await store.recordFailure(model: 'whisper-small-q5_1', code: 'vulkan_init_failed');
    expect((await store.read()).open, isFalse);

    await store.begin(model: 'whisper-small-q5_1');
    await store.recordFailure(
      model: 'whisper-small-q5_1',
      code: 'vulkan_inference_failed',
    );
    final state = await store.read();
    expect(state.open, isTrue);
    expect(state.failures, 2);
    expect(state.reason, 'vulkan_inference_failed');
  });

  test('reset removes the marker and counters', () async {
    await store.begin(model: 'whisper-turbo');
    await store.recordFailure(model: 'whisper-turbo', code: 'vulkan_init_failed');
    await store.reset();
    expect(file.existsSync(), isFalse);
    expect((await store.read()).open, isFalse);
  });

  test('corrupt state fails closed instead of trusting the GPU again', () async {
    file.writeAsStringSync('{not-json');
    final state = await store.read();
    expect(state.open, isTrue);
    expect(state.reason, 'corrupt_state');
  });
}
