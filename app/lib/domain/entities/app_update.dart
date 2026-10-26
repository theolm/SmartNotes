/// Public release metadata; no journal data is sent to the release service.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.url,
    required this.assets,
  });
  final String version;
  final Uri url;
  final List<ReleaseAsset> assets;
}

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.bytes,
  });
  final String name;
  final Uri url;
  final int bytes;
}

class UpdateDownload {
  const UpdateDownload({required this.state, this.progress = 0, this.version});
  final String state;
  final double progress;
  final String? version;
  bool get active =>
      const ['queued', 'downloading', 'verifying'].contains(state);
}
