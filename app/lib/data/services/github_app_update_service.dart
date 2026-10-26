import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartnotes/domain/entities/app_update.dart';
import 'package:smartnotes/domain/services/i_app_update_service.dart';

@LazySingleton(as: IAppUpdateService)
class GithubAppUpdateService implements IAppUpdateService {
  GithubAppUpdateService(this._client, this._prefs) : _android = null;
  GithubAppUpdateService.forTesting(
    this._client,
    this._prefs,
    this._android,
  );
  final http.Client _client;
  final SharedPreferences _prefs;
  final bool? _android;
  bool get _supportsApk => _android ?? Platform.isAndroid;
  static const _channel = MethodChannel('dev.theolm.smartnotes/app_updates');
  static const _repo = 'https://github.com/theolm/SmartNotes';
  static final endpoint = Uri.parse(
    'https://api.github.com/repos/theolm/SmartNotes/releases/latest',
  );

  @override
  Future<String> installedVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  static Version parseVersion(String value) =>
      Version.parse(value.replaceFirst(RegExp(r'^v'), '').split('+').first);

  static bool newer(String remote, String installed) =>
      parseVersion(remote) > parseVersion(installed);

  static bool trustedAsset(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      uri.path.startsWith('/theolm/SmartNotes/releases/download/') &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;

  @override
  Future<AppRelease?> check() async {
    final retryAt = _prefs.getInt('updates.retryAt') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < retryAt) {
      throw StateError('rateLimited');
    }
    final response = await _client
        .get(
          endpoint,
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'SmartNotes-update-check',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return null;
    if (response.statusCode == 403 || response.statusCode == 429) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      final reset = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
      await _prefs.setInt(
        'updates.retryAt',
        seconds != null
            ? DateTime.now()
                  .add(Duration(seconds: seconds))
                  .millisecondsSinceEpoch
            : reset != null
            ? reset * 1000
            : DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch,
      );
      throw StateError('rateLimited');
    }
    if (response.statusCode != 200) throw StateError('releaseUnavailable');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['draft'] is! bool || json['prerelease'] is! bool) {
      throw const FormatException('Invalid release metadata');
    }
    if (json['draft'] != false || json['prerelease'] != false) return null;
    final version = parseVersion(json['tag_name'] as String);
    if (version.isPreRelease ||
        !newer(version.toString(), await installedVersion())) {
      return null;
    }
    final url = Uri.parse(json['html_url'] as String);
    if (url.scheme != 'https' ||
        !url.toString().startsWith('$_repo/releases/tag/')) {
      throw const FormatException('Invalid release URL');
    }
    final assets = <ReleaseAsset>[];
    for (final item in json['assets'] as List) {
      final uri = Uri.parse(item['browser_download_url'] as String);
      if (!trustedAsset(uri)) continue;
      assets.add(
        ReleaseAsset(
          name: item['name'] as String,
          url: uri,
          bytes: item['size'] as int,
        ),
      );
    }
    return AppRelease(
      version: version.toString(),
      url: url,
      assets: List.unmodifiable(assets),
    );
  }

  @override
  bool shouldNotify(AppRelease release) =>
      _prefs.getString('updates.ignored') != release.version &&
      (_prefs.getString('updates.deferredVersion') != release.version ||
          DateTime.now().millisecondsSinceEpoch >=
              (_prefs.getInt('updates.deferredUntil') ?? 0));

  @override
  Future<void> defer(AppRelease release, {required bool ignore}) async {
    if (ignore) {
      await _prefs.setString('updates.ignored', release.version);
    } else {
      await _prefs.setString('updates.deferredVersion', release.version);
      await _prefs.setInt(
        'updates.deferredUntil',
        DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch,
      );
    }
  }

  @override
  Future<void> openRelease(AppRelease release) async {
    if (!await launchUrl(release.url, mode: LaunchMode.externalApplication)) {
      throw StateError('openFailed');
    }
  }

  @override
  Future<ReleaseAsset?> androidAsset(AppRelease release) async {
    if (!_supportsApk) return null;
    final abi = await _channel.invokeMethod<String>('abi');
    final name = 'SmartNotes-${release.version}-android-$abi.apk';
    if (!release.assets.any((a) => a.name == 'SHA256SUMS.txt')) return null;
    for (final asset in release.assets) {
      if (asset.name == name && asset.bytes > 0) return asset;
    }
    return null;
  }

  @override
  Future<void> download(
    AppRelease release,
    ReleaseAsset asset,
    Map<String, String> notification,
  ) async {
    final sums = release.assets.singleWhere((a) => a.name == 'SHA256SUMS.txt');
    final response = await _client
        .get(sums.url)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('checksumUnavailable');
    final matches = const LineSplitter()
        .convert(response.body)
        .map(
          (line) => RegExp(r'^([a-fA-F0-9]{64})\s+\*?(.+)$').firstMatch(line),
        )
        .where((match) => match != null && match[2] == asset.name)
        .toList();
    if (matches.length != 1) throw StateError('checksumUnavailable');
    await _channel.invokeMethod<void>('start', {
      'url': asset.url.toString(),
      'bytes': asset.bytes,
      'sha256': matches.single![1]!.toLowerCase(),
      'version': release.version,
      'notification': notification,
    });
  }

  @override
  Future<UpdateDownload> downloadStatus() async {
    if (!_supportsApk) return const UpdateDownload(state: 'idle');
    final result =
        await _channel.invokeMapMethod<String, dynamic>('status') ?? {};
    return UpdateDownload(
      state: result['state'] as String? ?? 'idle',
      progress: (result['progress'] as num?)?.toDouble() ?? 0,
      version: result['version'] as String?,
    );
  }

  @override
  Future<void> cancelDownload() => _channel.invokeMethod<void>('cancel');
  @override
  Future<void> install() => _channel.invokeMethod<void>('install');
  @override
  Future<void> prepareInstall() =>
      _channel.invokeMethod<void>('prepareInstall');
  @override
  Future<bool> takeOpenRequest() async =>
      _supportsApk && (await _channel.invokeMethod<bool>('takeOpen') ?? false);
}
