import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.dart';
import 'package:smartnotes/domain/entities/app_update.dart';
import 'package:smartnotes/domain/services/i_app_update_service.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/stores/app_update_store.dart';
import 'package:smartnotes/presentation/widgets/app_update_widgets.dart';

class MockUpdates extends Mock implements IAppUpdateService {}

class MockApp extends Mock implements AppStore {}

class MockHome extends Mock implements HomeStore {}

class MockRouter extends Mock implements AppRouter {}

class MockRoute extends Mock implements RouteData<dynamic> {}

void main() {
  late MockUpdates service;
  late AppUpdateStore store;
  late MockApp app;
  late MockHome home;
  late MockRouter router;
  late MockRoute route;
  late GlobalKey<NavigatorState> key;
  final release = AppRelease(
    version: '0.3.0',
    url: Uri.parse('https://github.com/theolm/SmartNotes/releases/tag/v0.3.0'),
    assets: [],
  );

  setUp(() {
    service = MockUpdates();
    store = AppUpdateStore(service);
    app = MockApp();
    home = MockHome();
    router = MockRouter();
    route = MockRoute();
    key = GlobalKey<NavigatorState>();
    when(() => service.installedVersion()).thenAnswer((_) async => '0.2.0');
    when(() => service.check()).thenAnswer((_) async => release);
    when(() => service.androidAsset(release)).thenAnswer((_) async => null);
    when(() => service.shouldNotify(release)).thenReturn(true);
    when(() => service.defer(release, ignore: false)).thenAnswer((_) async {});
    when(() => service.defer(release, ignore: true)).thenAnswer((_) async {});
    when(
      () => service.downloadStatus(),
    ).thenAnswer((_) async => const UpdateDownload(state: 'idle'));
    when(() => service.takeOpenRequest()).thenAnswer((_) async => false);
    when(() => app.isUnlocked).thenReturn(true);
    when(() => app.hasCompletedOnboarding).thenReturn(true);
    when(() => home.isRecording).thenReturn(false);
    when(() => home.isProcessing).thenReturn(false);
    when(() => home.entries).thenReturn(ObservableList<JournalEntry>());
    when(() => router.topMostRouter()).thenReturn(router);
    when(() => router.hasPagelessTopRoute).thenReturn(false);
    when(() => router.topRoute).thenReturn(route);
    when(() => route.name).thenReturn('JournalEmptyRoute');
    when(() => router.navigatorKey).thenReturn(key);
  });
  tearDown(() => store.dispose());

  Future<void> mount(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('Journal')),
        builder: (context, child) => AppUpdateHost(
          store: store,
          app: app,
          home: home,
          router: router,
          child: child!,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows versions and Later persists deferral', (tester) async {
    await mount(tester);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Installed: 0.2.0\nAvailable: 0.3.0'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    verify(() => service.defer(release, ignore: false)).called(1);
    expect(find.text('Update available'), findsNothing);
    store.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('waits while locked and while recording', (tester) async {
    when(() => app.isUnlocked).thenReturn(false);
    await mount(tester);
    expect(find.text('Update available'), findsNothing);
    when(() => app.isUnlocked).thenReturn(true);
    when(() => home.isRecording).thenReturn(true);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Update available'), findsNothing);
    when(() => home.isRecording).thenReturn(false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Update available'), findsOneWidget);
    store.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('waits for editing and nested popups to finish', (tester) async {
    when(() => route.name).thenReturn('EntryEditRoute');
    await mount(tester);
    expect(find.text('Update available'), findsNothing);
    when(() => route.name).thenReturn('EntryDetailRoute');
    when(() => router.hasPagelessTopRoute).thenReturn(true);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Update available'), findsNothing);
    when(() => router.hasPagelessTopRoute).thenReturn(false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Update available'), findsOneWidget);
    store.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ready download has explicit disabled Install while busy', (
    tester,
  ) async {
    when(() => service.downloadStatus()).thenAnswer(
      (_) async =>
          const UpdateDownload(state: 'ready', version: '0.3.0', progress: 1),
    );
    await store.refresh();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppUpdateSettings(store: store, canInstall: () => false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update ready to install'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Install'))
          .onPressed,
      isNull,
    );
    verifyNever(() => service.install());
  });
}
