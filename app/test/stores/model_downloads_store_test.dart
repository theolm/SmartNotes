import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/data/services/unsupported_platform_model_downloader.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';

class _Platform extends UnsupportedPlatformModelDownloader {
  final events = StreamController<bool>.broadcast();
  int prompts = 0;
  @override
  bool get supported => true;
  @override
  Stream<bool> get notificationChanges => events.stream;
  @override
  Future<bool> notificationsAllowed() async => false;
  @override
  Future<bool> requestNotifications() async {
    prompts++;
    events.add(true);
    return true;
  }
}

void main() {
  test(
    'restores denied permission without a prompt and observes later changes',
    () async {
      final platform = _Platform();
      final store = ModelDownloadsStore(platform);
      addTearDown(platform.events.close);
      addTearDown(store.dispose);
      await store.refresh();
      expect(store.supported, true);
      expect(store.notificationsAllowed, false);
      expect(platform.prompts, 0);
      await platform.requestNotifications();
      await pumpEventQueue();
      expect(store.notificationsAllowed, true);
    },
  );
}
