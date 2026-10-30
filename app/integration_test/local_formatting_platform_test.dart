import 'dart:io';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/data/services/local_note_processing_service.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/services/i_formatting_model_service.dart';
import 'package:smartnotes/domain/services/i_transcription_service.dart';

class _InstalledModel implements IFormattingModelService {
  @override
  Future<ModelCheckState> readiness({String? modelId, bool verify = false}) =>
      _download.readiness(modelId: modelId, verify: verify);
  _InstalledModel(String path, this.selected)
    : _download = LocalModelDownload(
        MockClient(
          (_) async => throw StateError('Native formatting must be offline'),
        ),
        model: selected,
        directory: () async => Directory(p.dirname(path)),
        folder: '',
      );

  final LocalModelDownload _download;
  final FormattingModel selected;

  @override
  List<FormattingModel> get catalog => [selected];

  @override
  String? get configuredModelId => selected.id;

  @override
  String get activeModelId => selected.id;

  @override
  FormattingModel? get activeModel => selected;

  @override
  Future<bool> isReady([String? modelId]) => _download.isReady();

  @override
  Future<bool> isPresent(String modelId) => _download.isReady();

  @override
  Future<int> storedBytes(String modelId, {bool partial = false}) async => 0;

  @override
  Future<void> activate(String modelId) async {}

  @override
  Future<void> remove(String modelId) async {}

  @override
  Future<String> requireModelPath() => _download.requireModelPath();

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) => _download.download(onProgress: onProgress);

  @override
  void cancelDownload() => _download.cancelDownload();
}

class _UnusedTranscription implements ITranscriptionService {
  @override
  Future<String> transcribe(String audioPath) =>
      throw StateError('Not an STT test');
}

/// Opt-in real GGUF preset regression test, not a multilingual benchmark.
/// flutter test integration_test/local_formatting_platform_test.dart -d macos
/// --dart-define=FORMATTING_MODEL_PATH=/absolute/path/Qwen3-1.7B-Q4_K_M.gguf
/// Select another catalog artifact with --dart-define=FORMATTING_MODEL_ID=...
/// Download separately after accepting its license; this test never downloads.
/// Does not read or write the user's journal, settings, credentials or models.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const path = String.fromEnvironment('FORMATTING_MODEL_PATH');
  const id = String.fromEnvironment(
    'FORMATTING_MODEL_ID',
    defaultValue: 'qwen3-1.7b-q4_k_m',
  );
  final selected = FormattingModel.find(id);
  if (selected == null) throw ArgumentError.value(id, 'FORMATTING_MODEL_ID');
  final models = _InstalledModel(path, selected);
  final service = LocalNoteProcessingService(
    models,
    _UnusedTranscription(),
    LocalInferenceQueue(),
  );
  testWidgets('real ${selected.id} generates metadata offline', (tester) async {
    final metadata = await service.generateMetadata(
      'Hoje conversei com Marina sobre o projeto em Lisboa. Não vou viajar amanhã.',
    );
    expect(metadata, isNotNull);
    expect(metadata!.title, isNotEmpty);
    expect(metadata.subTitle, isNotEmpty);
    expect(
      '${metadata.title} ${metadata.subTitle}',
      isNot(contains('<think>')),
    );
  }, skip: path.isEmpty);
  for (final action in AiAction.values) {
    testWidgets('real ${selected.id} formats Portuguese ${action.name} offline', (
      tester,
    ) async {
      expect(await models.isReady(), true);
      const source =
          'Hoje conversei com Marina sobre o projeto em Lisboa. Não vou viajar amanhã.';
      final note = await service.formatTranscription(
        action: action,
        transcription: source,
      );
      expect(note.title, isNotEmpty);
      expect(note.markdown, contains('Marina'));
      expect(note.markdown, contains('Lisboa'));
      expect(note.markdown.toLowerCase(), contains('não'));
      expect(note.transcription, source);
      expect(note.markdown, isNot(contains('<think>')));
      _expectPresentation(action, note.markdown);
      if (action == AiAction.journalEntry) {
        expect(note.markdown.toLowerCase(), contains('conversei'));
      }
      if (action == AiAction.faithfulTranscription) {
        // This source already has correct grammar: no rewriting is needed.
        expect(note.markdown.trim(), source);
      }
    }, skip: path.isEmpty);
  }
  testWidgets('real ${selected.id} converts key points back to journal prose', (
    tester,
  ) async {
    const source =
        'Hoje conversei com Marina sobre o projeto em Lisboa. Não vou viajar amanhã.';
    final bullets = await service.formatTranscription(
      action: AiAction.keyPoints,
      transcription: source,
    );
    _expectPresentation(AiAction.keyPoints, bullets.markdown);
    final journal = await service.formatTranscription(
      action: AiAction.journalEntry,
      transcription: bullets.markdown,
    );
    _expectPresentation(AiAction.journalEntry, journal.markdown);
    expect(journal.markdown, contains('Marina'));
    expect(journal.markdown, contains('Lisboa'));
    expect(journal.markdown.toLowerCase(), contains('não'));
    expect(journal.markdown.toLowerCase(), contains('amanhã'));
    expect(journal.transcription, bullets.markdown);
  }, skip: path.isEmpty);
  for (final source in [
    'I spoke with Marina about the project in Lisbon. I will not travel tomorrow.',
    'Hablé con Marina sobre el proyecto en Lisboa. No voy a viajar mañana.',
    'J’ai parlé avec Marina du projet à Lisbonne. Je ne voyagerai pas demain.',
  ]) {
    testWidgets('real ${selected.id} preserves source language: $source', (
      tester,
    ) async {
      final note = await service.formatTranscription(
        action: AiAction.faithfulTranscription,
        transcription: source,
      );
      expect(note.markdown, contains('Marina'));
      expect(note.transcription, source);
      expect(note.markdown, isNot(contains('<think>')));
      expect(note.markdown, isNot(contains('conversei')));
      expect(note.markdown.trim(), source);
    }, skip: path.isEmpty);
  }
  for (final fixture in [
    (
      language: 'Portuguese',
      source:
          'Não vou viajar amanhã. Talvez eu envie 3 páginas na sexta-feira.',
      requiredWords: ['não', 'amanhã', 'talvez', '3', 'páginas', 'sexta'],
    ),
    (
      language: 'Spanish',
      source: 'No voy a viajar mañana. Quizás envíe 3 páginas el viernes.',
      requiredWords: ['no', 'mañana', 'quizás', '3', 'páginas', 'viernes'],
    ),
    (
      language: 'French',
      source:
          'Je ne voyagerai pas demain. J’enverrai peut-être 3 pages vendredi.',
      requiredWords: ['pas', 'demain', 'peut-être', '3', 'pages', 'vendredi'],
    ),
    (
      language: 'mixed Portuguese and English',
      source: 'Não vou viajar amanhã. I might send 3 pages on Friday.',
      requiredWords: ['não', 'amanhã', 'might', '3', 'pages', 'friday'],
    ),
  ]) {
    testWidgets(
      'real ${selected.id} key points preserves ${fixture.language}',
      (tester) async {
        final note = await service.formatTranscription(
          action: AiAction.keyPoints,
          transcription: fixture.source,
        );
        _expectPresentation(AiAction.keyPoints, note.markdown);
        for (final word in fixture.requiredWords) {
          expect(note.markdown.toLowerCase(), contains(word));
        }
        expect(note.transcription, fixture.source);
        expect(note.markdown, isNot(contains('<think>')));
      },
      skip: path.isEmpty,
    );
  }
  testWidgets(
    'real ${selected.id} faithful preset preserves existing lists and details',
    (
      tester,
    ) async {
      const source =
          '- Hoje conversei com Marina em Lisboa.\n'
          '- Não vou viajar amanhã.\n'
          '- Talvez eu envie 3 páginas na sexta-feira.';
      final note = await service.formatTranscription(
        action: AiAction.faithfulTranscription,
        transcription: source,
      );
      expect(note.markdown.trim(), source);
      expect(note.transcription, source);
    },
    skip: path.isEmpty,
  );
}

void _expectPresentation(AiAction action, String body) {
  final listMarker = RegExp(r'^\s*(?:[-*+]|\d+[.)])\s+', multiLine: true);
  final heading = RegExp(r'^\s*#{1,6}\s+', multiLine: true);
  switch (action) {
    case AiAction.keyPoints:
      final lines = body.split('\n').where((line) => line.trim().isNotEmpty);
      expect(lines, isNotEmpty);
      expect(lines, everyElement(matches(r'^\s*-\s+\S')));
      expect(heading.hasMatch(body), false);
    case AiAction.journalEntry:
    case AiAction.formalSummary:
    case AiAction.casualRecap:
    case AiAction.faithfulTranscription:
      // The faithful-transcription fixtures are prose, not source lists.
      expect(listMarker.hasMatch(body), false);
      expect(heading.hasMatch(body), false);
    case AiAction.organizedNote:
      expect(RegExp(r'^\s*#\s+', multiLine: true).hasMatch(body), false);
  }
}
