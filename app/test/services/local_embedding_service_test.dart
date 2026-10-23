import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/data/services/local_embedding_service.dart';
import 'package:smartnotes/data/services/local_embedding_session.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/embedding_pipeline.dart';
import 'package:smartnotes/domain/entities/inference_cancelled.dart';
import '../helpers/local_services.dart';

class FakeSession implements LocalEmbeddingSession {
  final inputs = <String>[];
  bool disposed = false;
  bool fail = false;
  Completer<void>? disposal;
  Completer<void>? forward;
  void Function()? onCount;
  void Function()? onEmbed;
  List<double> vector = List.filled(1024, 1);
  @override
  Future<void> load(String path) async {
    if (fail) throw StateError('Private native error');
  }

  @override
  Future<int> countTokens(String text) async {
    onCount?.call();
    return text.runes.length;
  }

  @override
  Future<List<double>> embed(String text) async {
    inputs.add(text);
    onEmbed?.call();
    await forward?.future;
    return vector;
  }

  @override
  Future<void> dispose() async {
    await disposal?.future;
    disposed = true;
  }
}

void main() {
  late List<FakeSession> sessions;
  late MemoryEmbeddingModels models;
  late LocalInferenceQueue queue;
  late LocalEmbeddingService service;
  setUp(() {
    sessions = [];
    models = MemoryEmbeddingModels();
    queue = LocalInferenceQueue();
    service = LocalEmbeddingService.forTesting(models, queue, () {
      final session = FakeSession();
      sessions.add(session);
      return session;
    });
  });
  test('query has exactly one instruction; documents remain raw', () async {
    await service.embedQuery('férias');
    await service.embedDocument('Praia com família.');
    expect(sessions.first.inputs.single, EmbeddingPipeline.query('férias'));
    expect(sessions.last.inputs.single, 'Praia com família.');
    expect(sessions.every((s) => s.disposed), true);
  });
  test('MRL slices 1024 to 512 then L2 normalizes', () {
    final output = normalizeEmbedding([
      ...List.filled(512, 2.0),
      ...List.filled(512, 100.0),
    ]);
    expect(output.length, 512);
    expect(output.fold<double>(0, (s, v) => s + v * v), closeTo(1, 1e-12));
  });
  for (final invalid in [
    <double>[],
    List.filled(512, 1.0),
    List.filled(1024, 0.0),
    [...List.filled(1023, 1.0), double.nan],
    List.filled(1024, double.infinity),
  ]) {
    test(
      'rejects invalid native vector (${invalid.length}, ${invalid.isEmpty ? 'empty' : invalid.last})',
      () {
        expect(() => normalizeEmbedding(invalid), throwsA(isA<AiFailure>()));
      },
    );
  }
  test(
    'token-aware chunks retain Unicode and source tail without truncation',
    () async {
      final text = List.generate(
        80,
        (i) => 'Parágrafo $i: férias em São Paulo 👨‍👩‍👧. 日本語\n',
      ).join();
      final chunks = await chunkEmbeddingText(
        text,
        (s) async => s.runes.length,
      );
      expect(chunks.length, greaterThan(4));
      expect(chunks.every((c) => c.runes.length <= 384), true);
      expect(chunks.first, startsWith('Parágrafo 0'));
      expect(chunks.last, endsWith('日本語\n'));
      var rebuilt = chunks.first;
      for (final chunk in chunks.skip(1)) {
        final a = rebuilt.runes.toList();
        final b = chunk.runes.toList();
        var overlap = 0;
        for (var n = 1; n <= 64 && n <= a.length && n <= b.length; n++) {
          if (String.fromCharCodes(a.sublist(a.length - n)) ==
              String.fromCharCodes(b.take(n))) {
            overlap = n;
          }
        }
        rebuilt += String.fromCharCodes(b.skip(overlap));
      }
      expect(rebuilt, text);
    },
  );
  test('long indexing yields and unloads every four chunks', () async {
    final vectors = await service.embedDocument('a' * 3000);
    expect(vectors.length, greaterThan(4));
    expect(sessions.length, greaterThan(1));
    expect(sessions.every((s) => s.inputs.length <= 4 && s.disposed), true);
  });
  test(
    'passage offsets identify the exact embedded Unicode and overlapping text',
    () async {
      final text = '🌻 repeated text. ' * 160;
      final passages = <({String text, int start})>[];
      final vectors = await service.embedDocument(
        text,
        onPassage: (text, start) => passages.add((text: text, start: start)),
      );
      expect(passages.length, vectors.length);
      expect(passages.length, greaterThan(4));
      expect(passages.first.start, 0);
      for (var i = 0; i < passages.length; i++) {
        final passage = passages[i];
        expect(
          text.substring(passage.start, passage.start + passage.text.length),
          passage.text,
        );
        if (i > 0) {
          expect(passage.start, greaterThan(passages[i - 1].start));
          expect(
            passage.start,
            lessThan(passages[i - 1].start + passages[i - 1].text.length),
          );
        }
      }
      expect(passages.last.start + passages.last.text.length, text.length);
      expect(
        sessions.expand((s) => s.inputs).toList(),
        passages.map((p) => p.text).toList(),
      );
    },
  );
  test('oversized query fails rather than silently truncating', () async {
    await expectLater(
      service.embedQuery('x' * 1024),
      throwsA(
        isA<AiFailure>().having(
          (e) => e.code,
          'code',
          AiFailureCode.queryTooLong,
        ),
      ),
    );
    expect(sessions.single.inputs, isEmpty);
    expect(sessions.single.disposed, true);
  });
  test(
    'missing model never loads native engine or falls back online',
    () async {
      models.ready = false;
      await expectLater(
        service.embedQuery('x'),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.code,
            'code',
            AiFailureCode.modelMissing,
          ),
        ),
      );
      expect(sessions, isEmpty);
    },
  );
  test('cancellation discards document vectors', () async {
    await expectLater(
      service.embedDocument('x', isCancelled: () => true),
      throwsStateError,
    );
    expect(sessions, isEmpty);
  });
  test(
    'cancelled queued work never creates a model session and queue recovers',
    () async {
      final gate = Completer<void>();
      final lease = queue.run(() => gate.future);
      var cancelled = false;
      final query = service.embedQuery('old', isCancelled: () => cancelled);
      final document = service.embedDocument(
        'old',
        isCancelled: () => cancelled,
      );
      final queryCheck = expectLater(query, throwsA(isA<InferenceCancelled>()));
      final documentCheck = expectLater(
        document,
        throwsA(isA<InferenceCancelled>()),
      );
      cancelled = true;
      gate.complete();
      await Future.wait([lease, queryCheck, documentCheck]);
      expect(sessions, isEmpty);
      expect(await service.embedQuery('new'), hasLength(512));
    },
  );
  test(
    'cancellation during tokenization skips the native forward pass',
    () async {
      var cancelled = false;
      final session = FakeSession()..onCount = () => cancelled = true;
      final embedding = LocalEmbeddingService.forTesting(
        models,
        queue,
        () => session,
      );
      await expectLater(
        embedding.embedDocument('x' * 3000, isCancelled: () => cancelled),
        throwsA(isA<InferenceCancelled>()),
      );
      expect(session.inputs, isEmpty);
      expect(session.disposed, true);
    },
  );
  test(
    'active forward completes before disposal; cancellation stops next chunk',
    () async {
      var cancelled = false;
      final forward = Completer<void>();
      final disposal = Completer<void>();
      final session = FakeSession()
        ..forward = forward
        ..disposal = disposal;
      final embedding = LocalEmbeddingService.forTesting(
        models,
        queue,
        () => session,
      );
      final pending = embedding.embedDocument(
        'x' * 3000,
        isCancelled: () => cancelled,
      );
      final checked = expectLater(pending, throwsA(isA<InferenceCancelled>()));
      await pumpEventQueue();
      expect(session.inputs, hasLength(1));
      cancelled = true;
      var nextRan = false;
      final next = queue.run(() async => nextRan = true);
      await pumpEventQueue();
      expect(session.disposed, false);
      expect(nextRan, false);
      forward.complete();
      await pumpEventQueue();
      expect(nextRan, false);
      expect(session.inputs, hasLength(1));
      disposal.complete();
      await checked;
      await next;
      expect(session.disposed, true);
      expect(nextRan, true);
    },
  );
  test('superseded batch is skipped before reloading the model', () async {
    var cancelled = false;
    final session = FakeSession();
    Future<void>? foreground;
    session.onEmbed = () {
      if (session.inputs.length == 4) {
        foreground = queue.run(() async => cancelled = true);
      }
    };
    final embedding = LocalEmbeddingService.forTesting(models, queue, () {
      expect(
        session.disposed,
        false,
        reason: 'No second session may be loaded',
      );
      return session;
    });
    await expectLater(
      embedding.embedDocument('x' * 3000, isCancelled: () => cancelled),
      throwsA(isA<InferenceCancelled>()),
    );
    await foreground;
    expect(session.inputs, hasLength(4));
    expect(session.disposed, true);
  });
  test('failed load disposes native session and queue recovers', () async {
    final failed = FakeSession()..fail = true;
    final broken = LocalEmbeddingService.forTesting(
      models,
      queue,
      () => failed,
    );
    await expectLater(broken.embedQuery('x'), throwsA(isA<AiFailure>()));
    expect(failed.disposed, true);
    expect(await service.embedQuery('x'), hasLength(512));
  });
  test(
    'shared lease waits for embedding disposal before another model',
    () async {
      final disposal = Completer<void>();
      final session = FakeSession()..disposal = disposal;
      final blocked = LocalEmbeddingService.forTesting(
        models,
        queue,
        () => session,
      );
      final embedding = blocked.embedQuery('x');
      await pumpEventQueue();
      var nextLoaded = false;
      final next = queue.run(() async {
        nextLoaded = true;
      });
      await pumpEventQueue();
      expect(nextLoaded, false);
      disposal.complete();
      await embedding;
      await next;
      expect(session.disposed, true);
      expect(nextLoaded, true);
    },
  );
  test('interactive jobs precede backlog, with bounded fairness', () async {
    final order = <String>[];
    final gate = Completer<void>();
    final first = queue.run(() => gate.future);
    final background = queue.run(() async {
      order.add('background');
    }, background: true);
    final foreground = List.generate(
      10,
      (i) => queue.run(() async {
        order.add('foreground-$i');
      }),
    );
    gate.complete();
    await Future.wait([first, background, ...foreground]);
    expect(order.first, 'foreground-0');
    expect(order.indexOf('background'), lessThan(10));
  });
}
