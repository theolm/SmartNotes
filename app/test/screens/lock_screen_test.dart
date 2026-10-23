import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/presentation/screens/lock/lock_screen.dart';
import '../helpers/local_services.dart';

class MockLocalAuthService extends Mock implements ILocalAuthService {}

class MockSettingsService extends Mock implements ISettingsService {}

class _TestableLockScreen extends StatelessWidget {
  const _TestableLockScreen();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LockScreen(),
    );
  }
}

void main() {
  late MockLocalAuthService mockLocalAuthService;
  late MockSettingsService mockSettingsService;
  late AppStore appStore;

  setUp(() {
    mockLocalAuthService = MockLocalAuthService();
    mockSettingsService = MockSettingsService();
    when(() => mockSettingsService.getOnboardingCompleted()).thenReturn(true);
    when(
      () => mockSettingsService.getLockAppEnabled(),
    ).thenReturn(true);
    appStore = AppStore(
      mockLocalAuthService,
      mockSettingsService,
      MemorySpeechModels(),
      MemoryEmbeddingModels(),
    );
    GetIt.I.registerSingleton<AppStore>(appStore);
  });

  tearDown(() {
    GetIt.I.reset();
  });

  group('LockScreen', () {
    testWidgets('renders local unlock without sign out or login', (
      tester,
    ) async {
      await tester.pumpWidget(const _TestableLockScreen());
      await tester.pumpAndSettle();

      expect(find.text('Journal locked'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets(
      'tapping Unlock prompts local authentication and shows the retry path '
      'when cancelled',
      (tester) async {
        when(
          () => mockLocalAuthService.authenticate(reason: any(named: 'reason')),
        ).thenAnswer((_) async => LocalAuthResult.cancelled);

        await tester.pumpWidget(const _TestableLockScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Unlock'));
        await tester.pumpAndSettle();

        verify(
          () => mockLocalAuthService.authenticate(
            reason: 'Unlock SmartNotes',
          ),
        ).called(1);
        expect(find.text('Authentication cancelled'), findsOneWidget);
        // Still locked: the retry button remains.
        expect(find.text('Unlock'), findsOneWidget);
      },
    );

    testWidgets(
      'shows the unavailable message and keeps the retry path when the device '
      'has no biometrics or credentials',
      (tester) async {
        when(
          () => mockLocalAuthService.authenticate(reason: any(named: 'reason')),
        ).thenAnswer((_) async => LocalAuthResult.unavailable);

        await tester.pumpWidget(const _TestableLockScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Unlock'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'No biometrics or device credentials are available on this device',
          ),
          findsOneWidget,
        );
        expect(find.text('Unlock'), findsOneWidget);
      },
    );
  });
}
