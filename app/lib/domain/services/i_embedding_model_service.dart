import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/services/i_local_model_installation.dart';

abstract class IEmbeddingModelService
    extends ILocalModelInstallation<LocalAiModel> {
  LocalAiModel get model;

  /// Verified readiness after installation/repair or active-identity change.
  /// A ready-to-ready switch emits true again: consumers must not deduplicate
  /// this stream by boolean value. Read [model] for the committed identity.
  /// Subscribe before calling [isReady] for the initial state.
  Stream<bool> get readinessChanges;
  Future<String> requireModelPath();
}
