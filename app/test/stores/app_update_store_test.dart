import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/domain/entities/app_update.dart';
import 'package:smartnotes/domain/services/i_app_update_service.dart';
import 'package:smartnotes/presentation/stores/app_update_store.dart';

class MockUpdates extends Mock implements IAppUpdateService {}

void main() {
  late MockUpdates service;
  late AppUpdateStore store;
  final release = AppRelease(
    version: '0.3.0',
    url: Uri.parse('https://github.com/theolm/SmartNotes/releases/tag/v0.3.0'),
    assets: [],
  );
  setUp(() {
    service = MockUpdates();
    store = AppUpdateStore(service);
    when(() => service.installedVersion()).thenAnswer((_) async => '0.2.0');
    when(() => service.check()).thenAnswer((_) async => release);
    when(() => service.shouldNotify(release)).thenReturn(true);
    when(() => service.androidAsset(release)).thenAnswer((_) async => null);
    when(
      () => service.downloadStatus(),
    ).thenAnswer((_) async => const UpdateDownload(state: 'idle'));
    when(() => service.takeOpenRequest()).thenAnswer((_) async => false);
  });
  tearDown(() => store.dispose());

  test('startup runs only once and does not recheck on refresh', () async {
    store.start();
    store.start();
    await Future<void>.delayed(Duration.zero);
    await store.refresh();
    verify(() => service.check()).called(1);
    expect(store.promptPending, isTrue);
  });

  test('manual check bypasses ignore/defer', () async {
    when(() => service.shouldNotify(release)).thenReturn(false);
    await store.check();
    expect(store.promptPending, isFalse);
    await store.check(manual: true);
    expect(store.promptPending, isTrue);
  });

  test('automatic failures silent; manual failures visible', () async {
    when(() => service.check()).thenThrow(StateError('offline'));
    await store.check();
    expect(store.error, isNull);
    await store.check(manual: true);
    expect(store.error, 'checkFailed');
    expect(store.busy, isFalse);
  });

  test('concurrent checks are coalesced', () async {
    final pending = Completer<AppRelease?>();
    when(() => service.check()).thenAnswer((_) => pending.future);
    final first = store.check();
    await Future<void>.delayed(Duration.zero);
    await store.check();
    pending.complete(release);
    await first;
    verify(() => service.check()).called(1);
  });

  test('non Android action opens release', () async {
    when(() => service.openRelease(release)).thenAnswer((_) async {});
    await store.check();
    await store.act({});
    verify(() => service.openRelease(release)).called(1);
  });

  test('ready update suppresses redundant download popup', () async {
    when(() => service.downloadStatus()).thenAnswer(
      (_) async =>
          const UpdateDownload(state: 'ready', version: '0.3.0', progress: 1),
    );
    await store.refresh();
    await store.check();
    expect(store.promptPending, isFalse);
    expect(store.download.state, 'ready');
  });

  test('install rechecks safety after expensive validation', () async {
    var allowed = true;
    when(() => service.prepareInstall()).thenAnswer((_) async {
      allowed = false;
    });
    await store.install(allowed: () => allowed);
    verifyNever(() => service.install());
    expect(store.error, 'installBusy');
    expect(store.busy, isFalse);
  });

  test('install is user driven and errors remain actionable', () async {
    when(() => service.prepareInstall()).thenAnswer((_) async {});
    when(() => service.install()).thenThrow(StateError('permission'));
    await store.install(allowed: () => true);
    expect(store.error, 'installFailed');
    verify(() => service.install()).called(1);
  });

  test('notification navigation is retained until consumed', () async {
    when(() => service.takeOpenRequest()).thenAnswer((_) async => true);
    await store.refresh();
    expect(store.openRequested, isTrue);
    store.consumeOpenRequest();
    expect(store.openRequested, isFalse);
  });
}
