import 'dart:io';
import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:flutter/services.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:smartnotes/domain/services/i_platform_model_downloader.dart';
import 'package:smartnotes/core/l10n/app_localizations_en.dart';

Future<void> disposePlatformModelDownloader(
  IPlatformModelDownloader downloader,
) => (downloader as PlatformModelDownloader).dispose();

@LazySingleton(
  as: IPlatformModelDownloader,
  dispose: disposePlatformModelDownloader,
)
class PlatformModelDownloader implements IPlatformModelDownloader {
  PlatformModelDownloader();

  @override
  bool get supported => Platform.isAndroid || Platform.isIOS;
  final _notifications = StreamController<bool>.broadcast();
  @override
  Stream<bool> get notificationChanges => _notifications.stream;
  static const channel = MethodChannel('dev.theolm.smartnotes/model_downloads');

  @override
  Future<List<ModelTransfer>> status() async {
    if (!supported) return [];
    final values = await channel.invokeListMethod<Object?>('status') ?? [];
    return values
        .map((value) => ModelTransfer.fromMap(value as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<bool> notificationsAllowed() async =>
      !supported ||
      (await channel.invokeMethod<bool>('notificationsAllowed') ?? false);

  @override
  Future<bool> requestNotifications() async {
    if (!supported) return true;
    final allowed =
        await channel.invokeMethod<bool>('requestNotifications') ?? false;
    _notifications.add(allowed);
    return allowed;
  }

  @override
  Future<void> start(
    LocalAiModel model,
    String folder, {
    bool repair = false,
  }) => channel.invokeMethod<void>('start', {
    'id': model.id,
    'name': model.name,
    'url': model.url,
    'fileName': model.fileName,
    'folder': folder,
    'bytes': model.bytes,
    'sha256': model.sha256,
    'repair': repair,
    // Keep native notification text in Flutter's localization source. The
    // request persists it so workers do not need a running Flutter engine.
    'notification': {
      'channel': AppLocalizationsEn().modelDownloadNotificationChannel,
      'running': AppLocalizationsEn().modelDownloadNotificationRunning,
      'verifying': AppLocalizationsEn().modelDownloadNotificationVerifying,
      'completed': AppLocalizationsEn().modelDownloadNotificationComplete,
      'failed': AppLocalizationsEn().modelDownloadNotificationFailed,
      'started': AppLocalizationsEn().modelDownloadNotificationStarted,
      'cancel': AppLocalizationsEn().modelDownloadNotificationCancel,
    },
  });

  @override
  Future<void> cancel(String id) => channel.invokeMethod<void>('cancel', id);

  Future<void> dispose() => _notifications.close();
}
