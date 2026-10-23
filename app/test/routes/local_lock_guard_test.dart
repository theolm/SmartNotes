import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/routes/local_lock_guard.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/presentation/app_store.dart';
import '../helpers/local_services.dart';

class MockLocalAuth extends Mock implements ILocalAuthService {}

class MockSettings extends Mock implements ISettingsService {}

class MockResolver extends Mock implements NavigationResolver {}

class MockRouter extends Mock implements StackRouter {}

void main() {
  setUpAll(() => registerFallbackValue(const LockRoute()));
  for (final locked in [false, true]) {
    test('local lock $locked resolves without a login route', () async {
      final settings = MockSettings();
      when(() => settings.getOnboardingCompleted()).thenReturn(true);
      when(() => settings.getLockAppEnabled()).thenReturn(locked);
      final store = AppStore(
        MockLocalAuth(),
        settings,
        MemorySpeechModels(),
        MemoryEmbeddingModels(),
      );
      await store.initialize();
      final resolver = MockResolver();
      when(() => resolver.next()).thenReturn(null);
      when(() => resolver.redirectUntil(any())).thenReturn(null);
      LocalLockGuard(store).onNavigation(resolver, MockRouter());
      if (locked) {
        verify(() => resolver.redirectUntil(const LockRoute())).called(1);
        verifyNever(() => resolver.next());
      } else {
        verify(() => resolver.next()).called(1);
        verifyNever(() => resolver.redirectUntil(any()));
      }
    });
  }
  test('waits for local startup before allowing navigation', () async {
    final settings = MockSettings();
    when(() => settings.getOnboardingCompleted()).thenReturn(true);
    when(() => settings.getLockAppEnabled()).thenReturn(false);
    final store = AppStore(
      MockLocalAuth(),
      settings,
      MemorySpeechModels(),
      MemoryEmbeddingModels(),
    );
    final resolver = MockResolver();
    when(() => resolver.next()).thenReturn(null);
    LocalLockGuard(store).onNavigation(resolver, MockRouter());
    verifyNever(() => resolver.next());
    await store.initialize();
    await pumpEventQueue();
    verify(() => resolver.next()).called(1);
  });
  for (final locked in [false, true]) {
    test('incomplete onboarding with lock $locked redirects safely', () async {
      final settings = MockSettings();
      when(() => settings.getOnboardingCompleted()).thenReturn(false);
      when(() => settings.getLockAppEnabled()).thenReturn(locked);
      final store = AppStore(
        MockLocalAuth(),
        settings,
        MemorySpeechModels(),
        MemoryEmbeddingModels(),
      );
      await store.initialize();
      final resolver = MockResolver();
      when(() => resolver.redirectUntil(any())).thenReturn(null);
      LocalLockGuard(store).onNavigation(resolver, MockRouter());
      verify(
        () => resolver.redirectUntil(
          locked ? const LockRoute() : OnboardingRoute(),
        ),
      ).called(1);
      verifyNever(() => resolver.next());
    });
  }
}
