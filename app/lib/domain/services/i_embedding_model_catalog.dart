import 'package:smartnotes/domain/services/i_embedding_model_service.dart';

/// Selection is separate from installation. Existing single-model adapters may
/// still implement IEmbeddingModelService (e.g. offline integration fixtures).
abstract class IEmbeddingModelCatalog implements IEmbeddingModelService {
  Future<void> activate(String modelId);
  Future<void> remove(String modelId);
  Future<int> storedBytes(String modelId, {bool partial = false});
}

enum EmbeddingModelProblem { notReady, inUse, unsupported }

class EmbeddingModelException implements Exception {
  const EmbeddingModelException(this.problem);
  final EmbeddingModelProblem problem;
}
