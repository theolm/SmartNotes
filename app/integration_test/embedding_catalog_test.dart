import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';
import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:llamadart/llamadart.dart';
import 'package:smartnotes/data/services/local_embedding_service.dart';
import 'package:smartnotes/data/services/local_embedding_session.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';

import 'search_relevance_test.dart' show relevanceNotes, relevanceQueries;

Future<String> _digest(String path) => Isolate.run(
  () async => (await sha256.bind(File(path).openRead()).first).toString(),
);

/// Public weights + synthetic corpus only; never initializes the user's journal.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const root = String.fromEnvironment('EMBEDDING_MODELS_DIRECTORY');
  const report = String.fromEnvironment('EMBEDDING_CALIBRATION_REPORT');
  const qwenPath = String.fromEnvironment('QWEN_EMBEDDING_MODEL_PATH');
  const candidate = String.fromEnvironment('EMBEDDING_CANDIDATE');
  testWidgets(
    'calibrate available models and record unsupported candidate probes',
    (tester) async {
      final reports = <Map<String, Object?>>[];
      final candidates = [
        for (final model in EmbeddingModel.catalog.skip(1))
          (model, '$root/${model.fileName}'),
        if (qwenPath.isNotEmpty) (EmbeddingModel.qwen, qwenPath),
        if (candidate.startsWith('e5-'))
          (EmbeddingModel.e5, '$root/$candidate'),
      ];
      for (final (model, path) in candidates.where(
        (c) => candidate.isEmpty || c.$2.split('/').last == candidate,
      )) {
        final engine = LlamaEngine(LlamaBackend());
        final watch = Stopwatch()..start();
        try {
          final digest = await _digest(path);
          if (path.split('/').last == model.fileName) {
            expect(await File(path).length(), model.bytes);
            expect(digest, model.sha256);
          }
          await engine.setModel(
            LlamaModel(ModelSource.path(path)),
            params: ModelParams(
              contextSize: model.contextTokens,
              device: ComputeDevice.cpu,
              gpuLayers: 0,
              numberOfThreads: 4,
              numberOfThreadsBatch: 4,
              batchSize: 1024,
              microBatchSize: 1024,
            ),
          );
          final metadata = await engine.getMetadata();
          final docs = <String, List<double>>{};
          for (final entry in relevanceNotes.entries) {
            docs[entry.key] = normalizeEmbedding(
              await engine.embed(model.document(entry.value), normalize: false),
              model: model,
            );
          }
          final scores = <Map<String, Object?>>[];
          for (final query in relevanceQueries) {
            final vector = normalizeEmbedding(
              await engine.embed(model.query(query.text), normalize: false),
              model: model,
            );
            final distances = <String, double>{};
            for (final doc in docs.entries) {
              var dot = 0.0;
              for (var i = 0; i < vector.length; i++) {
                dot += vector[i] * doc.value[i];
              }
              distances[doc.key] = 1 - dot;
            }
            final ranked = distances.keys.toList()
              ..sort((a, b) => distances[a]!.compareTo(distances[b]!));
            scores.add({
              'query': query.text,
              'relevant': query.relevant,
              'precise': query.precise,
              'holdout': query.holdout,
              'nearest': ranked.first,
              'distances': distances,
            });
          }
          final training = scores.where((q) => q['holdout'] == false);
          final positive = training
              .where((q) => q['relevant'] != null)
              .map(
                (q) => (q['distances'] as Map<String, double>)[q['relevant']]!,
              );
          final negative = training
              .where((q) => q['relevant'] == null)
              .map(
                (q) => (q['distances'] as Map<String, double>).values.reduce(
                  math.min,
                ),
              );
          final maxPositive = positive.reduce(math.max);
          final minNegative = negative.reduce(math.min);
          final cutoff = maxPositive < minNegative
              ? (maxPositive + minNegative) / 2
              : minNegative - 0.005;
          reports.add({
            'model': model.id,
            'artifactSha256': digest,
            'file': path.split('/').last,
            'pipeline': model.pipelineId,
            'metadata': metadata,
            'maxTrainingPositive': maxPositive,
            'minTrainingNegative': minNegative,
            'suggestedCutoff': cutoff,
            'milliseconds': watch.elapsedMilliseconds,
            'scores': scores,
          });
        } catch (error) {
          reports.add({
            'model': model.id,
            'file': path.split('/').last,
            'error': '$error',
          });
        } finally {
          await engine.dispose();
          if (report.isNotEmpty) {
            await File(report).writeAsString(
              const JsonEncoder.withIndent('  ').convert(reports),
            );
          }
        }
      }
      final json = const JsonEncoder.withIndent('  ').convert(reports);
      if (report.isNotEmpty) await File(report).writeAsString(json);
      // Synthetic evidence only. Full reports stay in the explicit output file.
      for (final result in reports) {
        // ignore: avoid_print
        print(
          jsonEncode(
            {...result}
              ..remove('scores')
              ..remove('metadata'),
          ),
        );
        final model = EmbeddingModel.find(result['model']! as String)!;
        if (!model.available) continue;
        expect(result['error'], isNull, reason: model.id);
        final scores = (result['scores']! as List).cast<Map<String, Object?>>();
        final holdout = scores.where((q) => q['holdout'] == true);
        for (final query in holdout) {
          final distances = query['distances']! as Map<String, double>;
          if (query['relevant'] == null) {
            expect(
              distances.values.every((v) => v > model.maxDistance!),
              true,
              reason: '${model.id}: absent-topic holdout must remain empty',
            );
          } else if (query['precise'] == true) {
            expect(query['nearest'], query['relevant']);
          }
        }
        final positives = holdout.where((q) => q['relevant'] != null);
        final retained = positives
            .where(
              (q) =>
                  (q['distances']! as Map<String, double>)[q['relevant']]! <=
                  model.maxDistance!,
            )
            .length;
        expect(
          retained,
          greaterThanOrEqualTo(model.family == EmbeddingFamily.qwen ? 5 : 3),
        );
        expect(
          result['suggestedCutoff'] as double,
          closeTo(model.maxDistance!, 0.00005),
        );
      }
      expect(reports, isNotEmpty);
    },
    skip: root.isEmpty,
    timeout: const Timeout(Duration(minutes: 15)),
  );

  testWidgets(
    'production Gemma inference leaves Flutter controls responsive',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () => taps++,
              child: const Text('Journal control'),
            ),
          ),
        ),
      );
      final session = LlamaEmbeddingSession(model: EmbeddingModel.gemma);
      final clock = Stopwatch()..start();
      var lastTick = 0;
      var maxGap = 0;
      var ticks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final now = clock.elapsedMilliseconds;
        maxGap = math.max(maxGap, now - lastTick);
        lastTick = now;
        ticks++;
      });
      var completed = false;
      final work = () async {
        await session.load('$root/${EmbeddingModel.gemma.fileName}');
        for (var i = 0; i < 8; i++) {
          final input = EmbeddingModel.gemma.document(
            List.filled(80, 'A public synthetic journal passage.').join(' '),
          );
          final vector = normalizeEmbedding(
            await session.embed(input),
            model: EmbeddingModel.gemma,
          );
          expect(vector, hasLength(512));
        }
        completed = true;
      }();
      try {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tap(find.text('Journal control'));
        await tester.pump(const Duration(milliseconds: 16));
        expect(taps, 1);
        expect(
          completed,
          false,
          reason: 'Control must respond while native work is still running',
        );
        await work;
        expect(ticks, greaterThan(2));
        expect(maxGap, lessThan(500));
        // ignore: avoid_print
        print(
          'EMBEDDING_RESPONSIVENESS ticks=$ticks maxHeartbeatGapMs=$maxGap elapsedMs=${clock.elapsedMilliseconds}',
        );
      } finally {
        timer.cancel();
        await session.dispose();
      }
    },
    skip: root.isEmpty,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
