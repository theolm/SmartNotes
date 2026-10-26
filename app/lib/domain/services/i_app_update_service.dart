import 'package:smartnotes/domain/entities/app_update.dart';

abstract interface class IAppUpdateService {
  Future<String> installedVersion();
  Future<AppRelease?> check();
  bool shouldNotify(AppRelease release);
  Future<void> defer(AppRelease release, {required bool ignore});
  Future<void> openRelease(AppRelease release);
  Future<ReleaseAsset?> androidAsset(AppRelease release);
  Future<void> download(
    AppRelease release,
    ReleaseAsset asset,
    Map<String, String> notification,
  );
  Future<UpdateDownload> downloadStatus();
  Future<void> cancelDownload();
  Future<void> install();
  Future<void> prepareInstall();
  Future<bool> takeOpenRequest();
}
