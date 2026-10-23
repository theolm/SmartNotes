import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:llamadart/llamadart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/data/services/local_embedding_service.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/data/services/local_entry_search_service.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';

class _Model extends LocalModelDownload implements IEmbeddingModelService {
  @override
  Stream<bool> get readinessChanges => const Stream.empty();
  _Model(String path)
    : super(
        MockClient((_) async => throw StateError('Must be offline')),
        model: LocalAiModel.qwenEmbedding,
        directory: () async => Directory(p.dirname(path)),
        folder: '',
      );
}

/// Real GGUF smoke test, not a retrieval benchmark. Never touches user data.
/// --dart-define=EMBEDDING_MODEL_PATH=/absolute/path/Qwen3-Embedding-0.6B-Q8_0.gguf
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const path = String.fromEnvironment('EMBEDDING_MODEL_PATH');
  const referencePath = String.fromEnvironment('EMBEDDING_REFERENCE_PATH');
  testWidgets(
    'native tokenizer, pooling and Q8 vectors match author reference',
    (tester) async {
      final reference =
          jsonDecode(await File(referencePath).readAsString()) as Map;
      expect(reference['revision'], '97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3');
      final engine = LlamaEngine(LlamaBackend());
      try {
        await engine.setModel(
          LlamaModel(ModelSource.path(path)),
          params: const ModelParams(
            contextSize: 1024,
            device: ComputeDevice.cpu,
            gpuLayers: 0,
            numberOfThreads: 4,
            numberOfThreadsBatch: 4,
            batchSize: 1024,
            microBatchSize: 1024,
          ),
        );
        final metadata = await engine.getMetadata();
        expect(metadata['general.architecture'], 'qwen3');
        expect(metadata['qwen3.pooling_type'], '3');
        final texts = <String>[];
        final vectors = <List<double>>[];
        for (final example in reference['examples'] as List) {
          final text = example['text'] as String;
          expect(await engine.tokenize(text), example['tokens'], reason: text);
          final actual = await engine.embed(text, normalize: false);
          final expected = (example['vector'] as List)
              .cast<num>()
              .map((n) => n.toDouble())
              .toList();
          expect(actual.length, 1024);
          expect(
            _cosine(actual, expected),
            greaterThan(0.99),
            reason: 'Q8 versus FP32: $text',
          );
          expect(
            _cosine(normalizeEmbedding(actual), normalizeEmbedding(expected)),
            greaterThan(0.99),
          );
          texts.add(text);
          vectors.add(actual);
        }
        final batched = await engine.embedBatch(texts, normalize: false);
        for (var i = 0; i < batched.length; i++) {
          expect(_cosine(batched[i], vectors[i]), greaterThan(0.9999));
        }
      } finally {
        await engine.dispose();
      }
    },
    skip: path.isEmpty || referencePath.isEmpty,
  );
  testWidgets('real Qwen embeddings preserve multilingual retrieval offline', (
    tester,
  ) async {
    final model = _Model(path);
    expect(await model.isReady(), true);
    final service = LocalEmbeddingService(model, LocalInferenceQueue());
    final vacation = (await service.embedDocument(
      'Passei as férias na praia com a minha família.',
    )).single;
    final cooking = (await service.embedDocument(
      'Preparei uma receita de bolo de chocolate para o jantar.',
    )).single;
    for (final query in [
      'Onde passei as férias?',
      'Where did I spend my vacation?',
    ]) {
      final vector = await service.embedQuery(query);
      expect(vector, hasLength(512));
      double dot(List<double> other) => List.generate(
        512,
        (i) => vector[i] * other[i],
      ).reduce((a, b) => a + b);
      expect(dot(vacation), greaterThan(dot(cooking)));
      expect(
        vector.fold<double>(0, (sum, v) => sum + v * v),
        closeTo(1, 0.00001),
      );
    }
  }, skip: path.isEmpty);
  testWidgets('real offline indexing and sqlite-vec search work end to end', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'smartnotes-embedding-smoke-',
    );
    final database = LocalDatabase();
    try {
      await database.open(path: p.join(directory.path, 'journal.sqlite'));
      final now = DateTime.now();
      for (final content in {
        'vacation': 'Passei as férias na praia com a minha família.',
        'cooking': 'Preparei uma receita de bolo de chocolate para o jantar.',
      }.entries) {
        await database.insertEntry(
          JournalEntry(
            id: content.key,
            title: content.key,
            transcription: content.value,
            formattedNote: content.value,
            createdAt: now,
            updatedAt: now,
            status: EntryStatus.completed,
          ),
        );
      }
      final embeddings = LocalEmbeddingService(
        _Model(path),
        LocalInferenceQueue(),
      );
      final search = LocalEntrySearchService(database, embeddings);
      await search.indexPending();
      expect((await database.indexStatus()).indexed, 2);
      expect(
        (await search.searchSemantic(
          'Where did I spend my vacation?',
        )).first.entry.id,
        'vacation',
      );
      expect(
        (await search.searchSemantic('Onde passei as férias?')).first.entry.id,
        'vacation',
      );
      final match = (await search.searchSemantic('Onde passei as férias?')).first;
      expect(match.excerpt, contains(match.entry.body));
      expect(match.sources, isNotEmpty);
      expect(match.byMeaning, true);
      expect(await search.searchText('bolo'), hasLength(1));
      expect((await database.all()).length, 2);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  }, skip: path.isEmpty);
}

double _cosine(List<double> a, List<double> b) {
  var dot = 0.0;
  var aa = 0.0;
  var bb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    aa += a[i] * a[i];
    bb += b[i] * b[i];
  }
  return dot / math.sqrt(aa * bb);
}
