import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/presentation/app_store.dart';
import '../helpers/local_services.dart';

class MockLocalAuthService extends Mock implements ILocalAuthService {}

class MockSettingsService extends Mock implements ISettingsService {}

class _BrokenSpeech extends MemorySpeechModels {
  int checks = 0;
  @override
  Future<bool> isReady([String? modelId]) async {
    checks++;
    throw StateError('Unreadable fixture');
  }
}

void main() {
  late MockLocalAuthService auth;
  late MockSettingsService settings;
  late AppStore store;
  setUp(() {
    auth = MockLocalAuthService();
    settings = MockSettingsService();
    when(() => settings.getOnboardingCompleted()).thenReturn(true);
    when(() => settings.getLockAppEnabled()).thenReturn(false);
    store = AppStore(
      auth,
      settings,
      MemorySpeechModels(),
      MemoryEmbeddingModels(),
    );
  });
  test('initializes offline with no account or credential', () async {
    await store.initialize();
    expect(store.isInitialized, true);
    expect(store.isUnlocked, true);
    verifyZeroInteractions(auth);
  });
  test(
    'existing installation remains readable when weights are absent',
    () async {
      store = AppStore(
        auth,
        settings,
        MemorySpeechModels(ready: false),
        MemoryEmbeddingModels(),
      );
      await store.initialize();
      expect(store.hasCompletedOnboarding, true);
      expect(store.isUnlocked, true);
    },
  );
  test(
    'formatting model is not a startup dependency',
    () async {
      store = AppStore(
        auth,
        settings,
        MemorySpeechModels(),
        MemoryEmbeddingModels(),
      );
      await store.initialize();
      expect(store.hasCompletedOnboarding, true);
      when(() => settings.setOnboardingCompleted()).thenAnswer((_) async {});
      await store.completeOnboarding();
    },
  );
  test('optional local lock protects the journal on startup', () async {
    when(() => settings.getLockAppEnabled()).thenReturn(true);
    await store.initialize();
    expect(store.isLocked, true);
    expect(store.isUnlocked, false);
  });
  test(
    'initialization never calls model verification and later failure is recoverable',
    () async {
      final speech = _BrokenSpeech();
      store = AppStore(auth, settings, speech, MemoryEmbeddingModels());
      await store.initialize();
      expect(speech.checks, 0);
      expect(store.hasCompletedOnboarding, true);
      await store.checkModels();
      expect(speech.checks, 1);
      expect(store.modelChecks['speech'], ModelCheckState.failed);
      expect(store.isUnlocked, true);
      expect(store.hasCompletedOnboarding, true);
    },
  );
  test('settings failure renders a fail-closed lock state', () async {
    when(
      () => settings.getLockAppEnabled(),
    ).thenThrow(StateError('Unavailable'));
    await store.initialize();
    expect(store.isInitialized, true);
    expect(store.isLocked, true);
    expect(store.isUnlocked, false);
  });
  for (final result in LocalAuthResult.values) {
    test('handles ${result.name} during local unlock', () async {
      when(() => settings.getLockAppEnabled()).thenReturn(true);
      when(
        () => auth.authenticate(reason: any(named: 'reason')),
      ).thenAnswer((_) async => result);
      await store.initialize();
      expect(
        await store.unlock(reason: 'Unlock'),
        result == LocalAuthResult.success,
      );
      expect(store.isLocked, result != LocalAuthResult.success);
      expect(
        store.lockErrorMessage,
        result == LocalAuthResult.success ? isNull : isNotNull,
      );
    });
  }
}
