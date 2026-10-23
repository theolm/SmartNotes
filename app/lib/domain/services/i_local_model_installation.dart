import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';

/// Installation of pinned local artifacts, independent of inference or selection.
abstract class ILocalModelInstallation<T extends LocalAiModel> {
  List<T> get catalog;

  /// Requires full size/SHA-256 verification or a matching persisted stat cache,
  /// never merely file presence. A cache miss may perform a full hash.
  /// Omitting [modelId] checks the adapter's current/default model.
  Future<bool> isReady([String? modelId]);

  /// Stat/cache-only unless [verify] is explicit. A cache miss is unchecked,
  /// not missing. Verification is shared with other callers for this artifact.
  Future<ModelCheckState> readiness({String? modelId, bool verify = false});

  /// Resumes a partial download and verifies it before publishing the artifact.
  /// Omitting [modelId] downloads the adapter's current/default model.
  Future<void> download({
    String? modelId,
    required void Function(int received, int total) onProgress,
  });

  /// Cancels the current download while preserving resumable partial files.
  void cancelDownload();
}
