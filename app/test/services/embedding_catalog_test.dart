import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_vec/sqlite3_vec.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/data/services/local_embedding_service.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';
import 'package:smartnotes/domain/entities/embedding_pipeline.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';

EmbeddingModel _validatedE5Fixture() => EmbeddingModel(
  id: EmbeddingModel.e5.id,
  name: 'Synthetic 384d test profile',
  fileName: EmbeddingModel.e5.fileName,
  url: EmbeddingModel.e5.url,
  bytes: EmbeddingModel.e5.bytes,
  sha256: EmbeddingModel.e5.sha256,
  family: EmbeddingFamily.e5,
  architecture: 'bert',
  nativeDimensions: 384,
  dimensions: 384,
  contextTokens: 512,
  maxDistance: 0.5,
);

void main() {
  test(
    'catalog artifacts are pinned; unsupported profiles have no fake cutoff',
    () {
      expect(EmbeddingModel.catalog.map((m) => m.id).toSet(), hasLength(4));
      for (final model in EmbeddingModel.catalog) {
        expect(model.url, matches(RegExp(r'/resolve/[a-f0-9]{40}/')));
        expect(model.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(model.bytes, greaterThan(0));
        expect(model.available, model.maxDistance != null);
        expect(model.pipelineId, contains(model.sha256));
        expect(
          model.pipelineId,
          contains('chunks${model.chunkTokens}-overlap${model.overlapTokens}'),
        );
      }
      expect(EmbeddingModel.qwen.pipelineId, EmbeddingPipeline.id);
      expect(EmbeddingModel.qwen.maxDistance, EmbeddingPipeline.maxDistance);
      expect(
        EmbeddingModel.gemma.pipelineId,
        isNot(EmbeddingModel.gemma2.pipelineId),
      );
    },
  );

  test('prefixes and normalization follow each model, never pad E5', () {
    expect(EmbeddingModel.e5.query('hello'), 'query: hello');
    expect(EmbeddingModel.e5.document('hello'), 'passage: hello');
    expect(EmbeddingModel.gemma.document('hello'), 'title: none | text: hello');
    final gemma = normalizeEmbedding(
      List.filled(768, 2.0),
      model: EmbeddingModel.gemma,
    );
    expect(gemma, hasLength(512));
    expect(gemma.fold<double>(0, (sum, v) => sum + v * v), closeTo(1, 1e-12));
    final e5 = normalizeEmbedding(
      List.filled(384, 3.0),
      model: EmbeddingModel.e5,
    );
    expect(e5, hasLength(384));
    expect(e5.first, closeTo(1 / math.sqrt(384), 1e-12));
    expect(
      () => normalizeEmbedding(List.filled(512, 1.0), model: EmbeddingModel.e5),
      throwsA(isA<AiFailure>()),
    );
    expect(
      () => normalizeEmbedding(
        List.filled(768, double.nan),
        model: EmbeddingModel.gemma,
      ),
      throwsA(isA<AiFailure>()),
    );
  });

  group('durable model/index transaction', () {
    late Directory root;
    late LocalDatabase db;
    late String path;
    late JournalEntry note;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('embedding-catalog-test-');
      path = '${root.path}/journal.sqlite';
      db = LocalDatabase.forTesting(
        embeddingCatalog: [
          EmbeddingModel.qwen,
          EmbeddingModel.gemma,
          _validatedE5Fixture(),
        ],
      );
      await db.open(path: path);
      note = JournalEntry(
        id: 'public',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        status: EntryStatus.completed,
        transcription: 'A synthetic journal entry about a walk.',
      );
      await db.insertEntry(note);
    });
    tearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });

    test(
      '512 to 384 to 512 preserves notes and FTS; rejects late work',
      () async {
        final oldGeneration = await db.indexGeneration();
        final v512 = List.generate(512, (i) => i == 0 ? 1.0 : 0.0);
        await db.indexEntry(note, [v512], generation: oldGeneration);
        expect((await db.indexStatus()).indexed, 1);
        final e5 = _validatedE5Fixture();
        await db.selectEmbeddingModel(e5);
        final newGeneration = await db.indexGeneration();
        expect(newGeneration, greaterThan(oldGeneration));
        expect(db.embeddingProfile.dimensions, 384);
        expect((await db.indexStatus()).pending, 1);
        expect(await db.searchText('walk'), hasLength(1));
        expect((await db.entry(note.id))!.transcription, note.transcription);
        await db.indexEntry(note, [v512], generation: oldGeneration);
        await db.markIndexFailed(note, generation: oldGeneration);
        expect((await db.indexStatus()).indexed, 0);
        expect((await db.indexStatus()).failed, 0);
        expect(await db.searchVector(v512, generation: oldGeneration), isEmpty);
        final v384 = List.generate(384, (i) => i == 0 ? 1.0 : 0.0);
        await db.indexEntry(note, [v384], generation: newGeneration);
        expect(await db.searchVector(v384), hasLength(1));
        await db.selectEmbeddingModel(EmbeddingModel.gemma);
        expect(db.embeddingProfile.dimensions, 512);
        expect((await db.indexStatus()).indexed, 0);
        expect(await db.searchText('walk'), hasLength(1));
      },
    );

    test(
      'selection survives relaunch and selecting same model is idempotent',
      () async {
        await db.selectEmbeddingModel(EmbeddingModel.gemma);
        final generation = await db.indexGeneration();
        final revision = db.contentRevision;
        await db.selectEmbeddingModel(EmbeddingModel.gemma);
        expect(await db.indexGeneration(), generation);
        expect(db.contentRevision, revision);
        await db.close();
        db = LocalDatabase();
        await db.open(path: path);
        expect(db.embeddingProfile.id, EmbeddingModel.gemma.id);
        expect(await db.indexGeneration(), generation);
        expect(await db.all(), hasLength(1));
      },
    );

    test(
      'unsupported switch leaves generation, selection and vectors intact',
      () async {
        final generation = await db.indexGeneration();
        await expectLater(
          db.selectEmbeddingModel(EmbeddingModel.gemma2),
          throwsStateError,
        );
        expect(db.embeddingProfile.id, EmbeddingModel.qwen.id);
        expect(await db.indexGeneration(), generation);
        expect(await db.searchText('walk'), hasLength(1));
      },
    );

    test(
      'failed switch rolls back vector-table replacement and selection together',
      () async {
        final vector = List.generate(512, (i) => i == 0 ? 1.0 : 0.0);
        final generation = await db.indexGeneration();
        await db.indexEntry(note, [vector], generation: generation);
        await db.close();
        loadSqliteVec();
        final raw = sqlite3.open(path);
        raw.execute(
          "CREATE TRIGGER abort_switch BEFORE DELETE ON chunks BEGIN SELECT RAISE(ABORT, 'Synthetic failure'); END",
        );
        raw.close();
        db = LocalDatabase();
        await db.open(path: path);
        await expectLater(
          db.selectEmbeddingModel(EmbeddingModel.gemma),
          throwsStateError,
        );
        expect(db.embeddingProfile.id, EmbeddingModel.qwen.id);
        expect(await db.indexGeneration(), generation);
        expect(await db.searchVector(vector), hasLength(1));
        expect(await db.searchText('walk'), hasLength(1));
        await db.close();
        db = LocalDatabase();
        await db.open(path: path);
        expect(db.embeddingProfile.id, EmbeddingModel.qwen.id);
        expect(await db.searchVector(vector), hasLength(1));
      },
    );
  });
}
