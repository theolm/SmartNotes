import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/services/i_local_model_installation.dart';

abstract class IEmbeddingModelService
    extends ILocalModelInstallation<LocalAiModel> {
  LocalAiModel get model;

  /// Verified readiness changes after installation/repair. Consumers should
  /// subscribe before calling [isReady] for the initial state.
  Stream<bool> get readinessChanges;
  Future<String> requireModelPath();
}
