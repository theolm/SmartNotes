import 'package:llamadart/llamadart.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';

/// Testable lifetime of one native formatting job, never a persistent chat.
abstract class LocalFormattingSession {
  Future<void> load(String path);
  Future<int> countPrompt(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  );
  Future<LlamaCompletion> generate(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  );
  Future<void> dispose();
}

class LlamaFormattingSession implements LocalFormattingSession {
  final _engine = LlamaEngine(LlamaBackend());
  static const contextTokens = 4096;
  static const outputTokens = 1536;
  static const safetyTokens = 64;

  @override
  Future<void> load(String path) => _engine.setModel(
    LlamaModel(ModelSource.path(path)),
    // CPU is the portable mobile baseline. Native load/tokenization/generation
    // run in llamadart's worker isolate, not Flutter's UI isolate.
    params: const ModelParams(
      contextSize: contextTokens,
      device: ComputeDevice.cpu,
      gpuLayers: 0,
      numberOfThreads: 4,
      numberOfThreadsBatch: 4,
    ),
  );
  @override
  Future<int> countPrompt(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  ) async {
    final rendered = await _engine.chatTemplate(
      messages,
      enableThinking: false,
      responseFormat: format,
      includeTokenCount: true,
    );
    if (rendered.tokenCount == null) {
      throw const AiFailure(AiFailureCode.unavailable);
    }
    return rendered.tokenCount!;
  }

  @override
  Future<LlamaCompletion> generate(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  ) => _engine.complete(
    messages,
    enableThinking: false,
    responseFormat: format,
    params: const GenerationParams(
      maxTokens: outputTokens,
      temp: 0.3,
      penalty: 1.0,
      reusePromptPrefix: false,
    ),
  );
  @override
  Future<void> dispose() => _engine.dispose();
}
