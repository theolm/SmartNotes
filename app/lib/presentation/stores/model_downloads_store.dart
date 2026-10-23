import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:smartnotes/domain/services/i_platform_model_downloader.dart';

part 'model_downloads_store.g.dart';

Future<void> disposeModelDownloadsStore(ModelDownloadsStore store) =>
    store.dispose();

@LazySingleton(dispose: disposeModelDownloadsStore)
// ignore: library_private_types_in_public_api
class ModelDownloadsStore = _ModelDownloadsStore with _$ModelDownloadsStore;

abstract class _ModelDownloadsStore with Store {
  _ModelDownloadsStore(IPlatformModelDownloader platform)
    : _platform = platform {
    _subscription = platform.notificationChanges.listen(
      (allowed) => runInAction(() => notificationsAllowed = allowed),
    );
  }

  /// Explicit UI-only fixture/default for manually constructed stores in tests.
  // Invoked through the public MobX alias's inherited named constructor.
  // ignore: unused_element
  _ModelDownloadsStore.unsupported() : _platform = null, _subscription = null;

  final IPlatformModelDownloader? _platform;
  late final StreamSubscription<bool>? _subscription;
  bool get supported => _platform?.supported ?? false;
  @observable
  bool? notificationsAllowed;

  /// Queries permission without prompting when restoring existing work.
  @action
  Future<List<ModelTransfer>> refresh() async {
    final states = await _platform?.status() ?? [];
    notificationsAllowed = await _platform?.notificationsAllowed() ?? true;
    return states;
  }

  Future<void> dispose() async => _subscription?.cancel();
}
