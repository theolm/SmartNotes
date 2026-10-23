import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_local_model_installation.dart';

abstract class ISpeechModelService
    extends ILocalModelInstallation<SpeechModel> {
  String? get configuredModelId;
  String get activeModelId;
  SpeechModel get model;

  /// Size-only presence check. Full SHA-256 verification happens on activation.
  Future<bool> isPresent(String modelId);
  Future<int> storedBytes(String modelId, {bool partial = false});
  Future<void> activate(String modelId, {required String? language});
  Future<void> remove(String modelId);
  Future<String> requireModelPath();
}
