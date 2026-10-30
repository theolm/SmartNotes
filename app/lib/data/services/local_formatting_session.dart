import 'package:llamadart/llamadart.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/formatting_acceleration.dart';

/// Only verified backend failures may initiate a CPU retry. No provider text
/// crosses the service boundary or reaches diagnostics.
class FormattingGpuUnavailable implements Exception {
  const FormattingGpuUnavailable();
}

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
  LlamaFormattingSession({
    this.decision = const FormattingBackendDecision.cpu(
      FormattingBackendReason.userDisabled,
    ),
  });
  final FormattingBackendDecision decision;
  final _engine = LlamaEngine(LlamaBackend());
  String? backendName;
  int? resolvedGpuLayers;
  static const contextTokens = 4096;
  static const outputTokens = 1536;
  static const safetyTokens = 64;

  ModelParams get modelParams => ModelParams(
    contextSize: contextTokens,
    device: decision.usesGpu ? ComputeDevice.gpu : ComputeDevice.cpu,
    preferredBackend: switch (decision.backend) {
      FormattingBackend.cpu => GpuBackend.cpu,
      FormattingBackend.vulkan => GpuBackend.vulkan,
      FormattingBackend.metal => GpuBackend.metal,
    },
    gpuLayers: decision.profile?.gpuLayers ?? 0,
    numberOfThreads: 4,
    numberOfThreadsBatch: 4,
    // Leave microBatchSize unset: 0.11.1 caps Android Vulkan text prefill
    // at eight tokens to mitigate incorrect output on affected drivers.
  );

  @override
  Future<void> load(String path) async {
    try {
      await _engine.setModel(
        LlamaModel(ModelSource.path(path)),
        params: modelParams,
      );
    } on LlamaUnsupportedException catch (error) {
      // Pinned 0.11.1's explicit-device selection error, before model loading.
      // Other unsupported operations/models/grammars must not be retried.
      if (decision.usesGpu &&
          error.message.startsWith('ComputeDevice.gpu needs ')) {
        throw const FormattingGpuUnavailable();
      }
      rethrow;
    }
    backendName = await _engine.getBackendName();
    resolvedGpuLayers = await _engine.getResolvedGpuLayers();
    if (decision.usesGpu) {
      final name = backendName!.toLowerCase();
      final expected = decision.backend == FormattingBackend.vulkan
          ? name.contains('vulkan')
          : (name.contains('metal') || name.contains('mtl'));
      if (!expected || (resolvedGpuLayers ?? 0) <= 0) {
        throw const FormattingGpuUnavailable();
      }
    }
  }

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
