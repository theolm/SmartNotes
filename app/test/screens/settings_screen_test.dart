import 'package:auto_route/auto_route.dart';
import 'package:smartnotes/application/journal_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';
import 'package:smartnotes/domain/services/i_formatting_model_service.dart';
import 'package:smartnotes/presentation/screens/settings/data_settings_screens.dart';
import 'package:smartnotes/presentation/screens/settings/settings_screen.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';
import 'package:smartnotes/presentation/screens/settings/local_data_store.dart';
import 'package:smartnotes/presentation/screens/settings/embedding_models_store.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';
import 'package:smartnotes/presentation/stores/app_update_store.dart';
import 'package:smartnotes/domain/services/i_app_update_service.dart';

import '../helpers/nav_bar_inset.dart';
import '../helpers/local_services.dart';

class MockSettingsService extends Mock implements ISettingsService {}

class MockAppUpdateService extends Mock implements IAppUpdateService {}

class MockLocalAuthService extends Mock implements ILocalAuthService {}

class MockRouter extends Mock implements StackRouter {}

class MockJournalLifecycle extends Mock implements JournalLifecycle {}

class _TestableSettingsScreen extends StatelessWidget {
  const _TestableSettingsScreen({this.router});

  final StackRouter? router;

  @override
  Widget build(BuildContext context) {
    final screen = withNavBarInset(const SettingsScreen());
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: router == null
          ? screen
          : StackRouterScope(
              controller: router!,
              stateHash: 0,
              child: screen,
            ),
    );
  }
}

void main() {
  late MockSettingsService mockService;
  late MockLocalAuthService mockLocalAuthService;

  setUp(() {
    mockService = MockSettingsService();
    GetIt.I.registerSingleton<AppUpdateStore>(
      AppUpdateStore(MockAppUpdateService()),
    );
    mockLocalAuthService = MockLocalAuthService();
    GetIt.I.registerSingleton<ISpeechModelService>(MemorySpeechModels());
    GetIt.I.registerSingleton<IFormattingModelService>(
      MemoryFormattingModels(),
    );
    GetIt.I.registerSingleton<LocalDataStore>(
      LocalDataStore(
        MemorySearch(),
        MemoryArchive(),
        MemoryEmbeddingModels(),
        MockJournalLifecycle(),
      ),
    );
    GetIt.I.registerSingleton<EmbeddingModelsStore>(
      EmbeddingModelsStore(
        MemoryEmbeddingModels(),
        ModelDownloadsStore.unsupported(),
      ),
    );
    GetIt.I.registerSingleton<SettingsStore>(
      SettingsStore.forTesting(mockService, mockLocalAuthService)
        ..lockAppAvailable = true,
    );
  });

  tearDown(() {
    GetIt.I.reset();
  });

  testWidgets('shows the installed version discreetly at the bottom', (
    tester,
  ) async {
    final updates = GetIt.I<AppUpdateStore>();
    runInAction(() => updates.installed = '1.2.3');
    await tester.pumpWidget(const _TestableSettingsScreen());
    await tester.pumpAndSettle();
    final footer = find.text('Version 1.2.3');
    await tester.scrollUntilVisible(footer, 200);
    final text = tester.widget<Text>(footer);
    final theme = Theme.of(tester.element(footer));
    expect(text.textAlign, TextAlign.center);
    expect(text.style?.fontSize, theme.textTheme.bodySmall?.fontSize);
    expect(text.style?.color, theme.colorScheme.onSurfaceVariant);
    expect(
      tester.getTopLeft(footer).dy,
      greaterThan(tester.getTopLeft(find.text('App updates')).dy),
    );
  });

  testWidgets('version footer updates when local metadata becomes available', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestableSettingsScreen());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.2.3'), findsNothing);
    runInAction(() => GetIt.I<AppUpdateStore>().installed = '1.2.3');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Version 1.2.3'), 200);
    expect(find.text('Version 1.2.3'), findsOneWidget);
  });

  testWidgets(
    'shows focused destinations without inline maintenance or language controls',
    (
      tester,
    ) async {
      await tester.pumpWidget(const _TestableSettingsScreen());
      await tester.pumpAndSettle();
      expect(find.text('Transcription'), findsOneWidget);
      expect(find.text('AI organization'), findsOneWidget);
      expect(find.text('Search model'), findsOneWidget);
      expect(find.text('Qwen3 Embedding 0.6B Q8 · Ready'), findsOneWidget);
      expect(find.text('Search by meaning'), findsOneWidget);
      await tester.ensureVisible(find.text('Backup and restore'));
      expect(find.text('Backup and restore'), findsOneWidget);
      expect(find.text('Offline AI models'), findsNothing);
      expect(find.text('Check model setup'), findsNothing);
      expect(find.text('Indexed: 0 · Pending: 0 · Failed: 0'), findsNothing);
      expect(find.text('App language'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('opens the formatting model screen from Settings', (
    tester,
  ) async {
    final router = MockRouter();
    when(
      () => router.push<Object?>(const FormattingModelsRoute()),
    ).thenAnswer((_) async => null);
    await tester.pumpWidget(_TestableSettingsScreen(router: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AI organization'));
    await tester.tap(find.text('AI organization'));
    await tester.pumpAndSettle();
    verify(
      () => router.push<Object?>(const FormattingModelsRoute()),
    ).called(1);
  });

  testWidgets('pads the settings list clear of the navigation bar inset', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestableSettingsScreen());
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));

    expect(
      listView.padding,
      const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
        bottom: AppSpacing.xl + kNavBarInset,
      ),
    );
  });

  for (final destination in <String, PageRouteInfo>{
    'Search model': const EmbeddingModelsRoute(),
    'Search by meaning': const SearchSettingsRoute(),
    'Backup and restore': const BackupSettingsRoute(),
  }.entries) {
    testWidgets('opens ${destination.key}', (tester) async {
      final router = MockRouter();
      when(
        () => router.push<Object?>(destination.value),
      ).thenAnswer((_) async => null);
      await tester.pumpWidget(_TestableSettingsScreen(router: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(destination.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(destination.key));
      await tester.pumpAndSettle();
      verify(() => router.push<Object?>(destination.value)).called(1);
    });
  }

  testWidgets('search keeps rebuild in advanced options and backup separate', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Indexed: 0 · Pending: 0 · Failed: 0'), findsOneWidget);
    expect(find.text('Export journal'), findsNothing);
    expect(find.text('Rebuild search index'), findsNothing);
    expect(find.text('Available models'), findsNothing);
    expect(find.text('Active model'), findsNothing);
    expect(find.text('Qwen3 Embedding 0.6B Q8'), findsNothing);
    expect(find.text('Use model'), findsNothing);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Rebuild search index'), findsOneWidget);
  });

  testWidgets('missing search model links directly to the model screen', (
    tester,
  ) async {
    GetIt.I.unregister<LocalDataStore>();
    GetIt.I.registerSingleton<LocalDataStore>(
      LocalDataStore(
        MemorySearch(),
        MemoryArchive(),
        MemoryEmbeddingModels(ready: false),
        MockJournalLifecycle(),
      ),
    );
    final router = MockRouter();
    when(
      () => router.push<Object?>(const EmbeddingModelsRoute()),
    ).thenAnswer((_) async => null);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const SearchSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage search model'));
    await tester.pumpAndSettle();
    verify(() => router.push<Object?>(const EmbeddingModelsRoute())).called(1);
    expect(find.text('Use model'), findsNothing);
  });

  testWidgets('backup exposes export and import without model maintenance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BackupSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Export journal'), findsOneWidget);
    expect(find.text('Import journal'), findsOneWidget);
    expect(find.text('Check model setup'), findsNothing);
    expect(find.text('Advanced'), findsNothing);
  });

  testWidgets('compact settings support large text and do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the Lock app switch, disabled by default', (tester) async {
    await tester.pumpWidget(const _TestableSettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Lock app'), findsOneWidget);
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, false);
  });

  testWidgets('hides the Lock app option when local auth is unsupported', (
    tester,
  ) async {
    GetIt.I.get<SettingsStore>().lockAppAvailable = false;

    await tester.pumpWidget(const _TestableSettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Lock app'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('toggling the Lock app switch persists after authentication', (
    tester,
  ) async {
    when(
      () => mockLocalAuthService.authenticate(reason: any(named: 'reason')),
    ).thenAnswer((_) async => LocalAuthResult.success);
    when(
      () => mockService.setLockAppEnabled(true),
    ).thenAnswer((_) async => {});

    await tester.pumpWidget(const _TestableSettingsScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    verify(
      () => mockLocalAuthService.authenticate(
        reason: 'Confirm your identity to enable app lock',
      ),
    ).called(1);
    verify(() => mockService.setLockAppEnabled(true)).called(1);
  });

  testWidgets(
    'does not enable the Lock app switch when authentication is cancelled',
    (tester) async {
      when(
        () => mockLocalAuthService.authenticate(reason: any(named: 'reason')),
      ).thenAnswer((_) async => LocalAuthResult.cancelled);

      await tester.pumpWidget(const _TestableSettingsScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      verifyNever(() => mockService.setLockAppEnabled(any()));
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);
    },
  );

  testWidgets(
    'shows an error dialog and keeps Lock app disabled when biometric validation fails',
    (tester) async {
      when(
        () => mockLocalAuthService.authenticate(reason: any(named: 'reason')),
      ).thenAnswer((_) async => LocalAuthResult.failed);

      await tester.pumpWidget(const _TestableSettingsScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Could not enable app lock'), findsOneWidget);
      expect(
        find.text('Biometric verification failed. App lock was not enabled.'),
        findsOneWidget,
      );
      verifyNever(() => mockService.setLockAppEnabled(any()));
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);
    },
  );
}
