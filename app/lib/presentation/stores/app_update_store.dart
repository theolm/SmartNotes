import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:smartnotes/domain/entities/app_update.dart';
import 'package:smartnotes/domain/services/i_app_update_service.dart';

part 'app_update_store.g.dart';

@lazySingleton
// ignore: library_private_types_in_public_api
class AppUpdateStore = _AppUpdateStore with _$AppUpdateStore;

abstract class _AppUpdateStore with Store {
  _AppUpdateStore(this._service);
  final IAppUpdateService _service;
  Timer? _poll;
  bool _refreshing = false;
  bool _started = false;
  @observable
  bool busy = false;
  @observable
  String? error;
  @observable
  String installed = '';
  @observable
  AppRelease? release;
  @observable
  ReleaseAsset? asset;
  @observable
  bool promptPending = false;
  @observable
  bool checked = false;
  @observable
  bool openRequested = false;
  @observable
  UpdateDownload download = const UpdateDownload(state: 'idle');

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_initialize());
    _poll = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(refresh()),
    );
  }

  Future<void> _initialize() async {
    await refresh();
    await check();
  }

  @action
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final state = await _service.downloadStatus();
      runInAction(() => download = state);
      if (await _service.takeOpenRequest()) {
        runInAction(() => openRequested = true);
      }
    } catch (_) {
      // Unsupported or temporarily unavailable platform; checking still works.
    } finally {
      _refreshing = false;
    }
  }

  @action
  Future<void> check({bool manual = false}) async {
    if (busy) return;
    busy = true;
    error = null;
    try {
      installed = await _service.installedVersion();
      final latest = await _service.check();
      ReleaseAsset? apk;
      if (latest != null) {
        try {
          apk = await _service.androidAsset(latest);
        } catch (_) {
          /* Browser fallback. */
        }
      }
      runInAction(() {
        release = latest;
        asset = apk;
        checked = true;
        promptPending =
            latest != null &&
            !(download.version == latest.version &&
                (download.active || download.state == 'ready')) &&
            (manual || _service.shouldNotify(latest));
      });
    } catch (_) {
      if (manual) runInAction(() => error = 'checkFailed');
    } finally {
      runInAction(() => busy = false);
    }
  }

  @action
  void consumePrompt() => promptPending = false;
  @action
  void consumeOpenRequest() => openRequested = false;

  @action
  Future<void> defer({required bool ignore}) async {
    promptPending = false;
    try {
      await _service.defer(release!, ignore: ignore);
    } catch (_) {
      error = 'actionFailed';
    }
  }

  @action
  Future<void> act(Map<String, String> notification) async {
    if (busy || release == null) return;
    busy = true;
    error = null;
    try {
      if (asset == null) {
        await _service.openRelease(release!);
      } else {
        await _service.download(release!, asset!, notification);
        await refresh();
      }
    } catch (_) {
      runInAction(() => error = 'actionFailed');
    } finally {
      runInAction(() => busy = false);
    }
  }

  @action
  Future<void> openRelease() async {
    if (release == null || busy) return;
    busy = true;
    error = null;
    try {
      await _service.openRelease(release!);
    } catch (_) {
      runInAction(() => error = 'actionFailed');
    } finally {
      runInAction(() => busy = false);
    }
  }

  @action
  Future<void> install({required bool Function() allowed}) async {
    if (busy) return;
    busy = true;
    error = null;
    try {
      if (!allowed()) {
        error = 'installBusy';
        return;
      }
      await _service.prepareInstall();
      if (!allowed()) {
        runInAction(() => error = 'installBusy');
        return;
      }
      await _service.install();
    } catch (_) {
      runInAction(() => error = 'installFailed');
      await refresh();
    } finally {
      runInAction(() => busy = false);
    }
  }

  @action
  Future<void> cancel() async {
    try {
      await _service.cancelDownload();
      await refresh();
    } catch (_) {
      error = 'actionFailed';
    }
  }

  @disposeMethod
  void dispose() => _poll?.cancel();
}
