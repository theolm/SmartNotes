import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/data/services/embedding_model_service.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';
import 'package:smartnotes/domain/services/i_embedding_model_catalog.dart';

void main() {
  late Directory root;
  late LocalDatabase db;
  late LocalInferenceQueue queue;
  late EmbeddingModelService service;
  late Completer<void> probe;
  late Completer<void> probeStarted;
  late MockClient client;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('embedding-selection-');
    db = LocalDatabase();
    await db.open(path: '${root.path}/journal.sqlite');
    queue = LocalInferenceQueue();
    probe = Completer<void>();
    probeStarted = Completer<void>();
    client = MockClient(
      (_) async => throw StateError('No network in unit tests'),
    );
    service = EmbeddingModelService.catalogForTesting(
      client,
      directory: () async => root,
      database: db,
      queue: queue,
      probe: (_, _) {
        if (!probeStarted.isCompleted) probeStarted.complete();
        return probe.future;
      },
      hash: (file) async => EmbeddingModel.catalog
          .firstWhere((m) => file.path.endsWith(m.fileName))
          .sha256,
    );
    // Sparse synthetic artifacts: no model weights or downloads in unit tests.
    for (final model in [EmbeddingModel.qwen, EmbeddingModel.gemma]) {
      final file = File('${root.path}/embedding_models/${model.fileName}');
      await file.parent.create(recursive: true);
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(model.bytes);
      await handle.close();
    }
  });
  tearDown(() async {
    await service.dispose();
    await db.close();
    client.close();
    await root.delete(recursive: true);
  });

  test(
    'switch waits for the inference lease, then publishes even ready-to-ready',
    () async {
      final events = <bool>[];
      final subscription = service.readinessChanges.listen(events.add);
      addTearDown(subscription.cancel);
      await service.isReady();
      await pumpEventQueue();
      events.clear();
      final oldGeneration = await db.indexGeneration();
      final lease = Completer<void>();
      final running = queue.run(() => lease.future);
      final switching = service.activate(EmbeddingModel.gemma.id);
      await pumpEventQueue();
      expect(service.model.id, EmbeddingModel.qwen.id);
      expect(await db.indexGeneration(), oldGeneration);
      // Journal reads continue while the queued switch waits for native work.
      expect(await db.all(), isEmpty);
      lease.complete();
      await running;
      probe.complete();
      await switching;
      await pumpEventQueue();
      expect(service.model.id, EmbeddingModel.gemma.id);
      expect(await db.indexGeneration(), oldGeneration + 1);
      expect(events, [true]);
      await service.activate(EmbeddingModel.gemma.id);
      expect(await db.indexGeneration(), oldGeneration + 1);
    },
  );

  test(
    'failed inference preflight preserves previous model and generation',
    () async {
      final generation = await db.indexGeneration();
      final switching = service.activate(EmbeddingModel.gemma.id);
      final assertion = expectLater(switching, throwsStateError);
      await probeStarted.future;
      probe.completeError(StateError('Synthetic model-load failure'));
      await assertion;
      expect(service.model.id, EmbeddingModel.qwen.id);
      expect(await db.indexGeneration(), generation);
    },
  );

  test(
    'active models cannot be removed and unsupported weights cannot download',
    () async {
      await expectLater(
        service.remove(EmbeddingModel.qwen.id),
        throwsA(isA<EmbeddingModelException>()),
      );
      await expectLater(
        service.download(
          modelId: EmbeddingModel.gemma2.id,
          onProgress: (_, _) {},
        ),
        throwsA(isA<EmbeddingModelException>()),
      );
      await expectLater(
        service.activate(EmbeddingModel.gemma2.id),
        throwsA(isA<EmbeddingModelException>()),
      );
      expect(service.model.id, EmbeddingModel.qwen.id);
    },
  );
}
