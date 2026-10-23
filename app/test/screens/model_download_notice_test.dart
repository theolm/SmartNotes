import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/data/services/unsupported_platform_model_downloader.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';
import 'package:smartnotes/presentation/widgets/model_download_notice.dart';

class _Platform extends UnsupportedPlatformModelDownloader {
  final events = StreamController<bool>.broadcast();
  @override
  bool get supported => true;
  @override
  Stream<bool> get notificationChanges => events.stream;
  @override
  Future<bool> notificationsAllowed() async => false;
}

void main() {
  testWidgets(
    'denied permission explanation survives restart and reacts to changes',
    (tester) async {
      final platform = _Platform();
      final store = ModelDownloadsStore(platform);
      addTearDown(platform.events.close);
      addTearDown(store.dispose);
      await store.refresh();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ModelDownloadNotice(store: store)),
        ),
      );
      final context = tester.element(find.byType(ModelDownloadNotice));
      final l10n = AppLocalizations.of(context)!;
      expect(find.text(l10n.modelDownloadNotificationsDenied), findsOneWidget);
      platform.events.add(true);
      await tester.pumpAndSettle();
      expect(find.text(l10n.modelDownloadNotificationsDenied), findsNothing);
      expect(find.text(l10n.modelDownloadBackgroundHint), findsOneWidget);
    },
  );
}
