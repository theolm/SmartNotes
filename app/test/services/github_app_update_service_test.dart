import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/services/github_app_update_service.dart';
import 'package:smartnotes/domain/entities/app_update.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  const channel = MethodChannel('dev.theolm.smartnotes/app_updates');
  const base = 'https://github.com/theolm/SmartNotes/releases/download/v0.3.0/';
  Map<String, Object?> releaseJson({
    String tag = 'v0.3.0',
    bool prerelease = false,
    bool draft = false,
  }) => {
    'tag_name': tag,
    'prerelease': prerelease,
    'draft': draft,
    'html_url': 'https://github.com/theolm/SmartNotes/releases/tag/$tag',
    'assets': [
      {
        'name': 'SmartNotes-0.3.0-android-arm64-v8a.apk',
        'size': 100,
        'browser_download_url': '${base}SmartNotes-0.3.0-android-arm64-v8a.apk',
      },
      {
        'name': 'SHA256SUMS.txt',
        'size': 100,
        'browser_download_url': '${base}SHA256SUMS.txt',
      },
    ],
  };

  GithubAppUpdateService service(http.Client client, {bool android = false}) =>
      GithubAppUpdateService.forTesting(client, prefs, android);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    PackageInfo.setMockInitialValues(
      appName: 'SmartNotes',
      packageName: 'dev.theolm.smartnotes',
      version: '0.2.0',
      buildNumber: '4',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'abi' ? 'arm64-v8a' : null,
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('semantic comparison prevents downgrade and ignores build metadata', () {
    expect(GithubAppUpdateService.newer('v0.10.0', '0.9.9'), isTrue);
    expect(GithubAppUpdateService.newer('0.2.0+99', '0.2.0+4'), isFalse);
    expect(GithubAppUpdateService.newer('0.2.0', '0.3.0'), isFalse);
    expect(GithubAppUpdateService.newer('0.3.0', '0.3.0-rc.1'), isTrue);
    expect(
      () => GithubAppUpdateService.parseVersion('invalid'),
      throwsFormatException,
    );
  });

  test('queries fixed public endpoint without credentials', () async {
    final s = service(
      MockClient((request) async {
        expect(request.url, GithubAppUpdateService.endpoint);
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.body, isEmpty);
        return http.Response(jsonEncode(releaseJson()), 200);
      }),
    );
    final release = await s.check();
    expect(release!.version, '0.3.0');
    expect(release.assets.length, 2);
  });

  test(
    'equal, older, prerelease and draft releases are not candidates',
    () async {
      for (final data in [
        releaseJson(tag: 'v0.2.0'),
        releaseJson(tag: 'v0.1.0'),
        releaseJson(prerelease: true),
        releaseJson(draft: true),
        releaseJson(tag: 'v0.3.0-rc.1'),
      ]) {
        expect(
          await service(
            MockClient((_) async => http.Response(jsonEncode(data), 200)),
          ).check(),
          isNull,
        );
      }
    },
  );

  test(
    'missing releases are not an error; malformed releases and failures are errors',
    () async {
      expect(
        await service(MockClient((_) async => http.Response('', 404))).check(),
        isNull,
      );
      for (final response in [
        http.Response('{}', 200),
        http.Response('bad', 200),
        http.Response('', 500),
      ]) {
        await expectLater(
          service(MockClient((_) async => response)).check(),
          throwsA(anything),
        );
      }
    },
  );

  test('rate limit backoff persists and prevents another request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('', 429, headers: {'retry-after': '120'});
    });
    await expectLater(service(client).check(), throwsStateError);
    await expectLater(service(client).check(), throwsStateError);
    expect(calls, 1);
    expect(
      prefs.getInt('updates.retryAt'),
      greaterThan(DateTime.now().millisecondsSinceEpoch),
    );
  });

  test('defer is version scoped and expires; ignore persists', () async {
    final s = service(
      MockClient((_) async => http.Response(jsonEncode(releaseJson()), 200)),
    );
    final release = (await s.check())!;
    expect(s.shouldNotify(release), isTrue);
    await s.defer(release, ignore: false);
    expect(s.shouldNotify(release), isFalse);
    expect(
      s.shouldNotify(
        AppRelease(version: '0.4.0', url: release.url, assets: []),
      ),
      isTrue,
    );
    await prefs.setInt('updates.deferredUntil', 0);
    expect(s.shouldNotify(release), isTrue);
    await s.defer(release, ignore: true);
    expect(
      service(
        MockClient((_) async => http.Response('', 404)),
      ).shouldNotify(release),
      isFalse,
    );
  });

  test('asset URLs must belong to the release repository', () {
    expect(
      GithubAppUpdateService.trustedAsset(Uri.parse('${base}app.apk')),
      isTrue,
    );
    for (final url in [
      'http://github.com/theolm/SmartNotes/releases/download/v1/app.apk',
      'https://github.com/evil/SmartNotes/releases/download/v1/app.apk',
      'https://evil.com/theolm/SmartNotes/releases/download/v1/app.apk',
      'https://github.com/theolm/SmartNotes/releases/download/v1/app.apk?redirect=evil',
    ]) {
      expect(GithubAppUpdateService.trustedAsset(Uri.parse(url)), isFalse);
    }
  });

  test('selects process ABI and requires checksum asset', () async {
    final s = service(
      MockClient((_) async => http.Response(jsonEncode(releaseJson()), 200)),
      android: true,
    );
    final release = (await s.check())!;
    expect((await s.androidAsset(release))!.name, endsWith('arm64-v8a.apk'));
    expect(
      await s.androidAsset(
        AppRelease(
          version: release.version,
          url: release.url,
          assets: release.assets
              .where((a) => a.name != 'SHA256SUMS.txt')
              .toList(),
        ),
      ),
      isNull,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'armeabi-v7a');
    expect(await s.androidAsset(release), isNull);
    expect(
      await service(
        MockClient((_) async => http.Response('', 404)),
      ).androidAsset(release),
      isNull,
    );
  });

  test(
    'download sends only the selected asset and exact checksum to native',
    () async {
      final digest = List.filled(64, 'a').join();
      MethodCall? started;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'abi') return 'arm64-v8a';
            if (call.method == 'start') started = call;
            return null;
          });
      final s = service(
        MockClient(
          (request) async => request.url.path.endsWith('SHA256SUMS.txt')
              ? http.Response(
                  '$digest  SmartNotes-0.3.0-android-arm64-v8a.apk\n',
                  200,
                )
              : http.Response(jsonEncode(releaseJson()), 200),
        ),
        android: true,
      );
      final release = (await s.check())!;
      await s.download(release, (await s.androidAsset(release))!, {
        'title': 'Update',
      });
      expect((started!.arguments as Map)['sha256'], digest);
      expect((started!.arguments as Map)['bytes'], 100);
    },
  );

  test('invalid or missing checksum prevents native download', () async {
    for (final sums in [
      'bad checksum',
      '${List.filled(64, 'a').join()}  another.apk',
    ]) {
      final s = service(
        MockClient(
          (request) async => request.url.path.endsWith('SHA256SUMS.txt')
              ? http.Response(sums, 200)
              : http.Response(jsonEncode(releaseJson()), 200),
        ),
        android: true,
      );
      final release = (await s.check())!;
      await expectLater(
        s.download(release, (await s.androidAsset(release))!, {}),
        throwsStateError,
      );
    }
  });
}
