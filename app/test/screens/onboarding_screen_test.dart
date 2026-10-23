import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/data/datasources/local/shared_preferences_settings_service.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:smartnotes/presentation/screens/onboarding/onboarding_store.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';
import 'package:smartnotes/presentation/screens/settings/speech_models_store.dart';
import '../helpers/local_services.dart';

class MockAuth extends Mock implements ILocalAuthService {}

class MockRouter extends Mock implements StackRouter {}

void main() {
  late OnboardingStore store;
  late MemoryEmbeddingModels embeddingModels;
  late SharedPreferencesSettingsService settings;
  late MockRouter router;
  late MemorySpeechModels models;
  late MemoryFormattingModels formatting;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          DeviceProfileService.channel,
          (_) async => null,
        );
    SharedPreferences.setMockInitialValues({});
    settings = SharedPreferencesSettingsService(
      await SharedPreferences.getInstance(),
    );
    final auth = MockAuth();
    when(() => auth.isAvailable()).thenAnswer((_) async => false);
    models = MemorySpeechModels(settings: settings);
    formatting = MemoryFormattingModels(ready: false);
    embeddingModels = MemoryEmbeddingModels();
    final app = AppStore(
      auth,
      settings,
      models,
      embeddingModels,
    );
    await app.initialize();
    store = OnboardingStore(
      SettingsStore.forTesting(settings, auth),
      app,
      embeddingModels,
      SpeechModelsStore(models, MemoryDeviceProfile()),
      FormattingModelsStore(formatting, MemoryDeviceProfile()),
    );
    GetIt.I.registerFactory<OnboardingStore>(() => store);
    router = MockRouter();
    when(
      () => router.replace<void>(const HomeRoute()),
    ).thenAnswer((_) async {});
    when(() => router.maybePop<void>()).thenAnswer((_) async => true);
  });
  tearDown(() async => GetIt.I.reset());

  Future<void> render(
    WidgetTester tester, {
    bool compact = false,
    bool keyboard = false,
    bool fromSettings = false,
  }) async {
    if (compact) {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: compact ? AppTheme.dark : AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(
                context,
              ).copyWith(
                textScaler: TextScaler.linear(compact ? 2 : 1),
                viewInsets: EdgeInsets.only(bottom: keyboard ? 240 : 0),
              ),
          child: child!,
        ),
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: OnboardingScreen(fromSettings: fromSettings),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> skipFormatting(WidgetTester tester) async {
    if (store.step == OnboardingStep.formatting) {
      await tap(tester, 'Continue without formatting');
    }
  }

  testWidgets(
    'required model step blocks skipping and becomes ready after download',
    (tester) async {
      models.ready = false;
      await render(tester, compact: true);
      await tap(tester, 'Continue');
      await tap(tester, 'Continue');
      expect(store.step, OnboardingStep.speech);
      expect(find.text('Download offline transcription'), findsOneWidget);
      expect(find.text('Whisper base Q8'), findsWidgets);
      expect(find.text('Add a key later'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('download-whisper-base-q8_0')),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(
              const ValueKey('download-whisper-base-q8_0'),
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => store.speech.downloadOne(SpeechModel.whisperBaseQ8.id),
      );
      await tester.pumpAndSettle();
      expect(store.modelReady, true);
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      await tap(tester, 'Continue');
      await skipFormatting(tester);
      await tap(tester, 'Open my journal');
      expect(settings.getOnboardingCompleted(), true);
    },
  );

  testWidgets(
    'optional formatting step can be skipped without blocking setup',
    (tester) async {
      await render(tester, compact: true);
      await tap(tester, 'Continue');
      await tap(tester, 'Continue');
      await tap(tester, 'Continue');
      expect(store.step, OnboardingStep.formatting);
      expect(find.text('Choose a formatting model (optional)'), findsOneWidget);
      expect(find.text('Qwen3 0.6B Q8'), findsOneWidget);
      expect(find.text('Qwen3 1.7B Q4_K_M'), findsOneWidget);
      expect(
        find.text('Continue without formatting').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tap(tester, 'Continue without formatting');
      expect(store.step, OnboardingStep.embedding);
      await tap(tester, 'Open my journal');
      expect(settings.getOnboardingCompleted(), true);
    },
  );

  testWidgets(
    'onboarding action stays above the keyboard on a compact screen',
    (tester) async {
      await render(tester, compact: true, keyboard: true);
      await tap(tester, 'Continue');
      await tap(tester, 'Continue');
      await tap(tester, 'Continue');
      expect(
        find.text('Continue without formatting').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getBottomRight(find.text('Continue without formatting')).dy,
        lessThanOrEqualTo(400),
      );
      await tap(tester, 'Continue without formatting');
      expect(find.text('Open my journal').hitTestable(), findsOneWidget);
      expect(
        tester.getBottomRight(find.text('Open my journal')).dy,
        lessThanOrEqualTo(400),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explains app, asks audio language and enters journal without credentials',
    (tester) async {
      await render(tester);
      expect(find.text('A journal for your spoken thoughts'), findsOneWidget);
      await tap(tester, 'Continue');
      expect(find.text('What language do you speak?'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Português').last);
      await tester.pumpAndSettle();
      await tap(tester, 'Continue');
      expect(find.text('Download offline transcription'), findsOneWidget);
      await tap(tester, 'Continue');
      await skipFormatting(tester);
      expect(find.text('Download offline search by meaning'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tap(tester, 'Open my journal');
      expect(settings.getAudioLanguage(), 'pt');
      expect(settings.getOnboardingCompleted(), true);
      verify(() => router.replace<void>(const HomeRoute())).called(1);
    },
  );

  testWidgets('embedding download is mandatory and can be completed', (
    tester,
  ) async {
    embeddingModels.ready = false;
    await render(tester);
    await tap(tester, 'Continue');
    await tap(tester, 'Continue');
    await tap(tester, 'Continue');
    await skipFormatting(tester);
    expect(find.text('Download model').hitTestable(), findsOneWidget);
    expect(settings.getOnboardingCompleted(), false);
    await tap(tester, 'Download model');
    await tap(tester, 'Open my journal');
    expect(settings.getOnboardingCompleted(), true);
    verify(() => router.replace<void>(const HomeRoute())).called(1);
  });

  testWidgets('back preserves selected language', (
    tester,
  ) async {
    await render(tester);
    await tap(tester, 'Continue');
    await store.selectLanguage('pt');
    await tap(tester, 'Continue');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(store.audioLanguage, 'pt');
    await tap(tester, 'Continue');
    expect(store.audioLanguage, 'pt');
  });

  testWidgets('compact dark layout supports large text without overflow', (
    tester,
  ) async {
    await render(tester, compact: true);
    await tap(tester, 'Continue');
    expect(tester.takeException(), isNull);
    await tap(tester, 'Continue');
    expect(tester.takeException(), isNull);
    await tap(tester, 'Continue');
    await skipFormatting(tester);
    await tap(tester, 'Open my journal');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'primary action remains visible while reading onboarding content',
    (tester) async {
      await render(tester, compact: true);
      final action = find.text('Continue');
      expect(action.hitTestable(), findsOneWidget);
      await tap(tester, 'Continue');
      expect(action.hitTestable(), findsOneWidget);
      await tap(tester, 'Continue');
      expect(action.hitTestable(), findsOneWidget);
      await tap(tester, 'Continue');
      expect(
        find.text('Continue without formatting').hitTestable(),
        findsOneWidget,
      );
      await tap(tester, 'Continue without formatting');
      expect(find.text('Open my journal').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('embedding setup supports compact large text', (
    tester,
  ) async {
    embeddingModels.ready = false;
    await render(tester, compact: true);
    await tap(tester, 'Continue');
    await tap(tester, 'Continue');
    await tap(tester, 'Continue');
    await skipFormatting(tester);
    expect(find.text('Download offline search by meaning'), findsOneWidget);
    expect(find.text('Download model').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'model setup opened from settings returns without stacking a journal',
    (tester) async {
      await render(tester, fromSettings: true);
      await tap(tester, 'Continue');
      await tap(tester, 'Continue');
      await tap(tester, 'Continue');
      await skipFormatting(tester);
      await tap(tester, 'Open my journal');
      verify(() => router.maybePop<void>()).called(1);
      verifyNever(() => router.replace<void>(const HomeRoute()));
    },
  );
}
