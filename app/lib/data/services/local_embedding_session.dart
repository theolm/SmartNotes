import 'package:llamadart/llamadart.dart';
import 'package:smartnotes/domain/entities/embedding_pipeline.dart';

abstract class LocalEmbeddingSession {
  Future<void> load(String path);
  Future<int> countTokens(String text);
  Future<List<double>> embed(String text);
  Future<void> dispose();
}

class LlamaEmbeddingSession implements LocalEmbeddingSession {
  final _engine = LlamaEngine(LlamaBackend());
  @override
  Future<void> load(String path) async {
    await _engine.setModel(
      LlamaModel(ModelSource.path(path)),
      params: const ModelParams(
        contextSize: EmbeddingPipeline.contextTokens,
        device: ComputeDevice.cpu,
        gpuLayers: 0,
        numberOfThreads: 4,
        numberOfThreadsBatch: 4,
        batchSize: 1024,
        microBatchSize: 1024,
      ),
    );
    final metadata = await _engine.getMetadata();
    // Official Qwen GGUF must specify LAST (3), never silently use mean pooling.
    if (metadata['general.architecture'] != 'qwen3' ||
        metadata['qwen3.pooling_type'] != '3') {
      throw StateError('Unsupported embedding model metadata.');
    }
  }

  @override
  Future<int> countTokens(String text) async =>
      (await _engine.tokenize(text)).length;
  @override
  Future<List<double>> embed(String text) =>
      _engine.embed(text, normalize: false);
  @override
  Future<void> dispose() => _engine.dispose();
}
