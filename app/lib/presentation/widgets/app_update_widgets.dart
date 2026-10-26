import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/stores/app_update_store.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';

bool updateWorkIsActive(HomeStore home) =>
    home.isRecording ||
    home.isProcessing ||
    home.entries.any((entry) => entry.status == EntryStatus.processing);

Map<String, String> updateNotification(AppLocalizations l) => {
  'channel': l.updateChannel,
  'title': l.updateNotificationTitle,
  'downloading': l.updateDownloading,
  'verifying': l.updateVerifying,
  'ready': l.updateReady,
  'failed': l.updateFailed,
  'cancel': l.updateCancel,
};

String? updateError(AppLocalizations l, String? error) => switch (error) {
  'checkFailed' => l.updateCheckFailed,
  'installFailed' => l.updateInstallFailed,
  'installBusy' => l.updateInstallBusy,
  'actionFailed' => l.updateActionFailed,
  _ => null,
};

class AppUpdateHost extends StatefulWidget {
  const AppUpdateHost({
    super.key,
    required this.store,
    required this.app,
    required this.home,
    required this.router,
    required this.child,
  });
  final AppUpdateStore store;
  final AppStore app;
  final HomeStore home;
  final AppRouter router;
  final Widget child;
  @override
  State<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends State<AppUpdateHost> {
  Timer? _timer;
  bool _showing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.store.start();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) => _offer());
  }

  Future<void> _offer() async {
    final w = widget;
    if (!mounted ||
        _showing ||
        (!w.store.promptPending && !w.store.openRequested) ||
        w.store.busy ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !w.app.isUnlocked ||
        !w.app.hasCompletedOnboarding ||
        updateWorkIsActive(w.home)) {
      return;
    }
    final top = w.router.topMostRouter();
    if (top is StackRouter && top.hasPagelessTopRoute) return;
    // Only idle reading/settings surfaces; never interrupt an editor or onboarding.
    if (!const [
      'JournalEmptyRoute',
      'EntryDetailRoute',
      'SettingsRoute',
      'HomeRoute',
    ].contains(w.router.topRoute.name)) {
      return;
    }
    final context = w.router.navigatorKey.currentContext;
    if (context == null) return;
    if (w.store.openRequested) {
      w.store.consumeOpenRequest();
      if (w.router.topRoute.name != 'SettingsRoute') {
        unawaited(w.router.push(const SettingsRoute()));
      }
      return;
    }
    _showing = true;
    w.store.consumePrompt();
    try {
      final l = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l.updateAvailable),
            content: SingleChildScrollView(
              child: Text(
                l.updateVersions(w.store.installed, w.store.release!.version),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  unawaited(w.store.defer(ignore: true));
                  Navigator.pop(context);
                },
                child: Text(l.updateIgnore),
              ),
              TextButton(
                onPressed: () {
                  unawaited(w.store.defer(ignore: false));
                  Navigator.pop(context);
                },
                child: Text(l.updateLater),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await w.store.act(updateNotification(l));
                  if (!mounted) return;
                  final rootContext = w.router.navigatorKey.currentContext;
                  if (rootContext == null || !rootContext.mounted) return;
                  final message =
                      updateError(l, w.store.error) ??
                      (w.store.asset != null ? l.updateDownloading : null);
                  if (message != null) {
                    ScaffoldMessenger.of(
                      rootContext,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                },
                child: Text(
                  w.store.asset == null
                      ? l.updateRelease
                      : l.updateDownload(
                          (w.store.asset!.bytes / 1000000).toStringAsFixed(1),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      _showing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppUpdateSettings extends StatelessWidget {
  const AppUpdateSettings({
    super.key,
    required this.store,
    required this.canInstall,
  });
  final AppUpdateStore store;
  final bool Function() canInstall;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Observer(
      builder: (_) {
        final d = store.download;
        final error = updateError(l, store.error);
        final stateText = switch (d.state) {
          'queued' || 'downloading' => l.updateDownloading,
          'verifying' => l.updateVerifying,
          'ready' => l.updateReady,
          'failed' => l.updateFailed,
          'cancelled' => l.updateCancelled,
          _ => null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.updateTitle, style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.updateCheck),
              subtitle: Text(
                store.busy
                    ? l.updateChecking
                    : store.release != null
                    ? l.updateVersions(store.installed, store.release!.version)
                    : store.checked
                    ? l.updateCurrent
                    : store.installed,
              ),
              onTap: store.busy ? null : () => store.check(manual: true),
            ),
            if (stateText != null) Text(stateText),
            if (d.active) ...[
              LinearProgressIndicator(
                value: d.state == 'verifying' ? null : d.progress,
              ),
              TextButton(onPressed: store.cancel, child: Text(l.updateCancel)),
            ],
            if (d.state == 'ready') ...[
              Text(l.updateInstallExplanation),
              FilledButton(
                onPressed: store.busy || !canInstall()
                    ? null
                    : () => store.install(allowed: canInstall),
                child: Text(l.updateInstall),
              ),
            ],
            if (!d.active && d.state != 'ready' && store.release != null)
              TextButton(
                onPressed: store.busy
                    ? null
                    : () => store.act(updateNotification(l)),
                child: Text(
                  store.asset == null
                      ? l.updateRelease
                      : l.updateDownload(
                          (store.asset!.bytes / 1000000).toStringAsFixed(1),
                        ),
                ),
              ),
            if (error != null)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (store.release != null && store.asset != null)
              TextButton(
                onPressed: store.busy ? null : store.openRelease,
                child: Text(l.updateRelease),
              ),
          ],
        );
      },
    );
  }
}
