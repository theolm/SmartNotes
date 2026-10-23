import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:smartnotes/domain/services/i_platform_model_downloader.dart';

/// Explicit desktop/test adapter: never invokes a mobile platform channel.
class UnsupportedPlatformModelDownloader implements IPlatformModelDownloader {
  const UnsupportedPlatformModelDownloader();
  @override
  bool get supported => false;
  @override
  Stream<bool> get notificationChanges => const Stream.empty();
  @override
  Future<bool> notificationsAllowed() async => true;
  @override
  Future<bool> requestNotifications() async => true;
  @override
  Future<List<ModelTransfer>> status() async => [];
  @override
  Future<void> start(
    LocalAiModel model,
    String folder, {
    bool repair = false,
  }) async {}
  @override
  Future<void> cancel(String id) async {}
}
