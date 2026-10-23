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
  _InstalledModel(String path)
    : _download = LocalModelDownload(
        MockClient(
          (_) async => throw StateError('Native formatting must be offline'),
        ),
        model: FormattingModel.qwen3_1_7b,
        directory: () async => Directory(p.dirname(path)),
        folder: '',
      );

  final LocalModelDownload _download;

  @override
  List<FormattingModel> get catalog => [FormattingModel.qwen3_1_7b];

  @override
  String? get configuredModelId => FormattingModel.qwen3_1_7b.id;

  @override
  String get activeModelId => FormattingModel.qwen3_1_7b.id;

  @override
  FormattingModel? get activeModel => FormattingModel.qwen3_1_7b;

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

/// Opt-in real GGUF smoke test, not a multilingual fidelity benchmark.
/// flutter test integration_test/local_formatting_platform_test.dart -d macos
/// --dart-define=FORMATTING_MODEL_PATH=/absolute/path/Qwen3-1.7B-Q4_K_M.gguf
/// Does not read or write the user's journal, settings, credentials or models.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const path = String.fromEnvironment('FORMATTING_MODEL_PATH');
  final models = _InstalledModel(path);
  final service = LocalNoteProcessingService(
    models,
    _UnusedTranscription(),
    LocalInferenceQueue(),
  );
  for (final action in AiAction.values) {
    testWidgets('real Qwen formats Portuguese ${action.name} offline', (
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
    }, skip: path.isEmpty);
  }
  for (final source in [
    'I spoke with Marina about the project in Lisbon. I will not travel tomorrow.',
    'Hablé con Marina sobre el proyecto en Lisboa. No voy a viajar mañana.',
    'J’ai parlé avec Marina du projet à Lisbonne. Je ne voyagerai pas demain.',
  ]) {
    testWidgets('real Qwen preserves source language: $source', (tester) async {
      final note = await service.formatTranscription(
        action: AiAction.faithfulTranscription,
        transcription: source,
      );
      expect(note.markdown, contains('Marina'));
      expect(note.transcription, source);
      expect(note.markdown, isNot(contains('<think>')));
      expect(note.markdown, isNot(contains('conversei')));
    }, skip: path.isEmpty);
  }
}
