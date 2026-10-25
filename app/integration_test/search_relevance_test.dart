import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/data/services/local_embedding_service.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/domain/entities/embedding_pipeline.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';

class _Model extends LocalModelDownload implements IEmbeddingModelService {
  _Model(String path)
    : super(
        MockClient((_) async => throw StateError('Must be offline')),
        model: LocalAiModel.qwenEmbedding,
        directory: () async => Directory(p.dirname(path)),
        folder: '',
      );

  @override
  Stream<bool> get readinessChanges => const Stream.empty();
}

/// Calibration evidence for [EmbeddingPipeline.maxDistance].
///
/// Synthetic journal only, written before measuring. No personal journal is
/// read or modified. Run with the real weights:
///
/// ```
/// flutter test integration_test/search_relevance_test.dart -d macos \
///   --dart-define=EMBEDDING_MODEL_PATH=/absolute/path/Qwen3-Embedding-0.6B-Q8_0.gguf
/// ```
const _notes = {
  'holiday':
      'Passei as férias na praia com minha família. Caminhamos na areia e nadamos no mar todos os dias.',
  'sleep':
      'I left my phone outside the bedroom and read a book before bed. I fell asleep quickly and woke up feeling rested.',
  'work':
      'Fiquei nervoso antes de apresentar o projeto para a equipe. Respirei fundo e a reunião correu melhor do que eu esperava.',
  'cooking':
      'Preparei um bolo de chocolate com a minha avó. Ela me ensinou a receita e tomamos café juntos na cozinha.',
  'friend':
      'I called an old friend after months without talking. Catching up made me feel less lonely.',
  'walk':
      'Fui caminhar no parque depois do almoço. Ver as árvores e ouvir os pássaros me ajudou a acalmar a cabeça.',
  'music':
      'Practiced the piano for half an hour. I can finally play the difficult passage without stopping.',
  'budget':
      'Revisei os gastos do mês e cancelei duas assinaturas que não usava. Quero economizar para trocar de apartamento.',
  'family':
      'Levei meus filhos ao parque no domingo. Eles correram atrás dos patos e riram muito; voltei para casa cansado e feliz.',
  'health':
      'Comecei a fazer alongamento todas as manhãs porque minha lombar doía. Em duas semanas a dor diminuiu bastante.',
  'commute':
      'O metrô atrasou quarenta minutos hoje. Aproveitei para terminar o capítulo do livro que estava lendo.',
  'reading':
      'Terminei o romance que comecei no mês passado. O final me surpreendeu e fiquei pensando nele o resto do dia.',
  'garden':
      'Plantei manjericão e tomate na varanda. As folhas estão crescendo e já consigo usar o manjericão no jantar.',
  'grief':
      'Faz um ano que meu avô morreu. Passei o dia lembrando das histórias que ele contava na varanda.',
  'gym':
      'Voltei à academia depois de meses parado. Fiz perna e saí com dificuldade de descer as escadas.',
  'deadline':
      'Entreguei o relatório no prazo apertado. Trabalhei até tarde três noites seguidas e dormi mal.',
};

/// `precise` queries have one clearly correct note and expect it first. The
/// others describe a topic that more than one note genuinely covers.
const _queries = <({String text, String? relevant, bool precise, bool holdout})>[
  (
    text: 'Onde passei as férias?',
    relevant: 'holiday',
    precise: true,
    holdout: false,
  ),
  (
    text: 'What helped me sleep better?',
    relevant: 'sleep',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Ansiedade antes de uma apresentação',
    relevant: 'work',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Cozinhando com minha avó',
    relevant: 'cooking',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Reconnecting with a friend',
    relevant: 'friend',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Natureza para relaxar',
    relevant: 'walk',
    precise: false,
    holdout: false,
  ),
  (
    text: 'Making progress on a musical instrument',
    relevant: 'music',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Como reduzi minhas despesas?',
    relevant: 'budget',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Domingo com as crianças',
    relevant: 'family',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Dor nas costas melhorando',
    relevant: 'health',
    precise: false,
    holdout: false,
  ),
  (
    text: 'Atraso no transporte público',
    relevant: 'commute',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Finishing a novel',
    relevant: 'reading',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Cultivando temperos em casa',
    relevant: 'garden',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Saudade do meu avô',
    relevant: 'grief',
    precise: true,
    holdout: false,
  ),
  (
    text: 'Voltando a treinar força',
    relevant: 'gym',
    precise: false,
    holdout: false,
  ),
  (
    text: 'Pressão no trabalho',
    relevant: 'work',
    precise: false,
    holdout: false,
  ),
  // Clearly outside every note: these must stay empty.
  (
    text: 'Minha consulta no dentista',
    relevant: null,
    precise: false,
    holdout: false,
  ),
  (
    text: 'Repairing my bicycle brakes',
    relevant: null,
    precise: false,
    holdout: false,
  ),
  (
    text: 'Adoção de um cachorro',
    relevant: null,
    precise: false,
    holdout: false,
  ),
  (
    text: 'Learning to write computer programs',
    relevant: null,
    precise: false,
    holdout: false,
  ),
  (
    text: 'Comprando um carro usado',
    relevant: null,
    precise: false,
    holdout: false,
  ),
  (
    text: 'Mudança de hábitos alimentares',
    relevant: null,
    precise: false,
    holdout: false,
  ),
  (
    text: 'Reparos no telhado da casa',
    relevant: null,
    precise: false,
    holdout: false,
  ),
  // Topically adjacent, so the model may retrieve a related note. The result is
  // useful enough to show; it only has to be a note that really touches it.
  (
    text: 'Planejando as férias do ano que vem',
    relevant: 'holiday',
    precise: false,
    holdout: false,
  ),
  (
    text: 'Aprendendo a tocar violão',
    relevant: 'music',
    precise: false,
    holdout: false,
  ),
  (
    text: 'Uma conversa difícil com um colega',
    relevant: 'friend',
    precise: false,
    holdout: false,
  ),
  (
    text: 'Where did I travel with my family?',
    relevant: 'holiday',
    precise: true,
    holdout: true,
  ),
  (
    text: 'O que me ajudou a dormir bem?',
    relevant: 'sleep',
    precise: true,
    holdout: true,
  ),
  (
    text: 'Feeling nervous about speaking to coworkers',
    relevant: 'work',
    precise: true,
    holdout: true,
  ),
  (
    text: 'Saving money for a new home',
    relevant: 'budget',
    precise: true,
    holdout: true,
  ),
  (
    text: 'Renovação do passaporte',
    relevant: null,
    precise: false,
    holdout: true,
  ),
  (
    text: 'Taking my cat to the vet',
    relevant: null,
    precise: false,
    holdout: true,
  ),
  (
    text: 'Replacing a broken car engine',
    relevant: null,
    precise: false,
    holdout: true,
  ),
  (
    text: 'Treino para correr uma maratona',
    relevant: 'health',
    precise: false,
    holdout: true,
  ),
];

// Shared, predetermined synthetic corpus. Calibration must not tune on holdout.
const relevanceNotes = _notes;
const relevanceQueries = _queries;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const modelPath = String.fromEnvironment('EMBEDDING_MODEL_PATH');
  testWidgets(
    'real embeddings keep relevant notes and drop unrelated ones',
    (
      tester,
    ) async {
      final directory = await Directory.systemTemp.createTemp(
        'search-relevance-',
      );
      final database = LocalDatabase();
      final scores = <Map<String, Object?>>[];
      final actual = <List<String>>[];
      try {
        await database.open(path: p.join(directory.path, 'journal.sqlite'));
        final embeddings = LocalEmbeddingService(
          _Model(modelPath),
          LocalInferenceQueue(),
        );
        final vectors = <String, List<List<double>>>{};
        final now = DateTime(2026);
        for (final note in _notes.entries) {
          final entry = JournalEntry(
            id: note.key,
            createdAt: now,
            updatedAt: now,
            status: EntryStatus.completed,
            transcription: note.value,
          );
          await database.insertEntry(entry);
          final passages = <({String text, int start})>[];
          final chunks = await embeddings.embedDocument(
            entrySource(entry),
            onPassage: (text, start) =>
                passages.add((text: text, start: start)),
          );
          vectors[note.key] = chunks;
          await database.indexEntry(
            entry,
            chunks,
            generation: await database.indexGeneration(),
            passages: passages,
          );
        }
        for (final query in _queries) {
          final vector = await embeddings.embedQuery(query.text);
          final distances = {
            for (final note in vectors.entries)
              note.key: note.value
                  .map(
                    (chunk) =>
                        1 -
                        List.generate(
                          vector.length,
                          (i) => vector[i] * chunk[i],
                        ).reduce((a, b) => a + b),
                  )
                  .reduce(math.min),
          };
          scores.add({
            'query': query.text,
            'relevant': query.relevant,
            'holdout': query.holdout,
            'distances': distances,
          });
          final results = await database.searchVector(vector);
          for (final result in results) {
            expect(result.excerpt, isNotEmpty);
            expect(result.entry.body, contains(result.excerpt));
          }
          actual.add(results.map((e) => e.entry.id).toList());
        }
        // Printed for reproducible calibration; synthetic text only.
        // ignore: avoid_print
        print(
          'SEARCH_RELEVANCE ${jsonEncode({'pipeline': EmbeddingPipeline.id, 'cutoff': EmbeddingPipeline.maxDistance, 'scores': scores})}',
        );
        for (var i = 0; i < _queries.length; i++) {
          final query = _queries[i];
          if (query.relevant == null) {
            expect(actual[i], isEmpty, reason: query.text);
            continue;
          }
          expect(
            actual[i],
            contains(query.relevant),
            reason: '${query.text} -> $actual',
          );
          if (query.precise) {
            expect(actual[i].first, query.relevant, reason: query.text);
          }
          // Everything returned must clear the calibrated band, in rank order.
          final distances = (scores[i]['distances']! as Map<String, double>);
          for (final id in actual[i]) {
            expect(
              distances[id]!,
              lessThanOrEqualTo(EmbeddingPipeline.maxDistance),
              reason: '${query.text} -> $id',
            );
          }
        }
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
    skip: modelPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
