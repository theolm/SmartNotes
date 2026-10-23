import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/services/i_local_model_installation.dart';

abstract class IFormattingModelService
    extends ILocalModelInstallation<FormattingModel> {
  String? get configuredModelId;
  String get activeModelId;
  FormattingModel? get activeModel;

  /// Size-only presence check. Full SHA-256 verification happens on activation.
  Future<bool> isPresent(String modelId);
  Future<int> storedBytes(String modelId, {bool partial = false});
  Future<void> activate(String modelId);
  Future<void> remove(String modelId);
  Future<String> requireModelPath();
}
