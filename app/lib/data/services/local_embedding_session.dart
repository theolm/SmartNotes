import 'package:llamadart/llamadart.dart';
import 'package:smartnotes/core/utils/inference_trace.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';

abstract class LocalEmbeddingSession {
  Future<void> load(String path);
  Future<int> countTokens(String text);
  Future<List<double>> embed(String text);
  Future<void> dispose();
}

class LlamaEmbeddingSession implements LocalEmbeddingSession {
  LlamaEmbeddingSession({this.model = EmbeddingModel.qwen});
  final EmbeddingModel model;
  final _engine = LlamaEngine(LlamaBackend());
  @override
  Future<void> load(String path) async {
    InferenceTrace.event('embedding.model', {'model': model.id});
    await InferenceTrace.run(
      'embedding.load',
      () => _engine.setModel(
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
      ),
    );
    final metadata = await _engine.getMetadata();
    // Check the representation contract; never silently accept a default pool.
    if (metadata['general.architecture'] != model.architecture ||
        metadata['${model.architecture}.pooling_type'] != '${model.pooling}') {
      throw StateError('Unsupported embedding model metadata.');
    }
  }

  @override
  Future<int> countTokens(String text) async => (await InferenceTrace.run(
    'embedding.tokenize',
    () => _engine.tokenize(text),
  )).length;
  @override
  Future<List<double>> embed(String text) => InferenceTrace.run(
    'embedding.generate',
    () => _engine.embed(text, normalize: false),
  );
  @override
  Future<void> dispose() =>
      InferenceTrace.run('embedding.dispose', _engine.dispose);
}
