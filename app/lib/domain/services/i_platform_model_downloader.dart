import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';

abstract interface class IPlatformModelDownloader {
  bool get supported;
  Stream<bool> get notificationChanges;
  Future<List<ModelTransfer>> status();
  Future<bool> notificationsAllowed();
  Future<bool> requestNotifications();

  /// Start or attach to unique persisted work. Resumes retained partial bytes.
  Future<void> start(LocalAiModel model, String folder, {bool repair = false});
  Future<void> cancel(String id);
}
