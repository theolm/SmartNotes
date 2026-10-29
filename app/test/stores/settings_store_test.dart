import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';

class MockSettingsService extends Mock implements ISettingsService {}

class MockLocalAuthService extends Mock implements ILocalAuthService {}

void main() {
  late MockSettingsService mockService;
  late MockLocalAuthService mockLocalAuthService;
  late SettingsStore store;

  setUp(() {
    mockService = MockSettingsService();
    mockLocalAuthService = MockLocalAuthService();
    when(() => mockService.getLockAppEnabled()).thenReturn(false);
    when(() => mockService.getSpeechGpuPreferred()).thenReturn(true);
    when(
      () => mockLocalAuthService.isAvailable(),
    ).thenAnswer((_) async => true);
    store = SettingsStore.forTesting(mockService, mockLocalAuthService);
  });

  group('SettingsStore', () {
    test('load sets themeMode from service', () async {
      when(() => mockService.getThemeMode()).thenReturn('dark');
      when(() => mockService.getAudioLanguage()).thenReturn('en');
      when(() => mockService.getAppLocale()).thenReturn('en');

      await store.load();

      expect(store.themeMode, ThemeMode.dark);
      expect(store.audioLanguage, 'en');
      expect(store.appLocale, 'en');
    });

    test(
      'load uses defaults when service returns null for themeMode',
      () async {
        when(() => mockService.getThemeMode()).thenReturn(null);
        when(() => mockService.getAudioLanguage()).thenReturn(null);
        when(() => mockService.getAppLocale()).thenReturn('en');

        await store.load();

        expect(store.themeMode, ThemeMode.system);
        expect(store.audioLanguage, null);
      },
    );

    test('load falls back to system theme for unknown value', () async {
      when(() => mockService.getThemeMode()).thenReturn('invalid');
      when(() => mockService.getAudioLanguage()).thenReturn(null);
      when(() => mockService.getAppLocale()).thenReturn('en');

      await store.load();

      expect(store.themeMode, ThemeMode.system);
    });

    test('setThemeMode updates observable and persists', () async {
      when(() => mockService.setThemeMode('dark')).thenAnswer((_) async => {});

      await store.setThemeMode(ThemeMode.dark);

      expect(store.themeMode, ThemeMode.dark);
      verify(() => mockService.setThemeMode('dark')).called(1);
    });

    test('setAudioLanguage updates observable and persists', () async {
      when(
        () => mockService.setAudioLanguage('pt'),
      ).thenAnswer((_) async => {});

      await store.setAudioLanguage('pt');

      expect(store.audioLanguage, 'pt');
      verify(() => mockService.setAudioLanguage('pt')).called(1);
    });

    test('setAudioLanguage with null persists as null', () async {
      when(
        () => mockService.setAudioLanguage(null),
      ).thenAnswer((_) async => {});

      await store.setAudioLanguage(null);
      expect(store.audioLanguage, null);
      verify(() => mockService.setAudioLanguage(null)).called(1);
    });

    test('setAppLocale updates observable and persists', () async {
      when(() => mockService.setAppLocale('en')).thenAnswer((_) async => {});

      await store.setAppLocale('en');

      expect(store.appLocale, 'en');
      verify(() => mockService.setAppLocale('en')).called(1);
    });

    test('load reads lockAppEnabled from service', () async {
      when(() => mockService.getThemeMode()).thenReturn(null);
      when(() => mockService.getAudioLanguage()).thenReturn(null);
      when(() => mockService.getAppLocale()).thenReturn('en');
      when(() => mockService.getLockAppEnabled()).thenReturn(true);

      await store.load();

      expect(store.lockAppEnabled, true);
    });

    test('load defaults lockAppEnabled to false', () async {
      when(() => mockService.getThemeMode()).thenReturn(null);
      when(() => mockService.getAudioLanguage()).thenReturn(null);
      when(() => mockService.getAppLocale()).thenReturn('en');

      await store.load();

      expect(store.lockAppEnabled, false);
    });

    test('load sets lockAppAvailable from the local auth service', () async {
      when(() => mockService.getThemeMode()).thenReturn(null);
      when(() => mockService.getAudioLanguage()).thenReturn(null);
      when(() => mockService.getAppLocale()).thenReturn('en');
      when(
        () => mockLocalAuthService.isAvailable(),
      ).thenAnswer((_) async => true);

      await store.load();

      expect(store.lockAppAvailable, true);
      verify(() => mockLocalAuthService.isAvailable()).called(1);
    });

    test('load sets lockAppAvailable to false when unsupported', () async {
      when(() => mockService.getThemeMode()).thenReturn(null);
      when(() => mockService.getAudioLanguage()).thenReturn(null);
      when(() => mockService.getAppLocale()).thenReturn('en');
      when(
        () => mockLocalAuthService.isAvailable(),
      ).thenAnswer((_) async => false);

      await store.load();

      expect(store.lockAppAvailable, false);
    });

    test(
      'setLockAppEnabled(true) persists only after successful authentication',
      () async {
        when(
          () => mockLocalAuthService.authenticate(reason: any(named: 'reason')),
        ).thenAnswer((_) async => LocalAuthResult.success);
        when(
          () => mockService.setLockAppEnabled(true),
        ).thenAnswer((_) async => {});

        final applied = await store.setLockAppEnabled(
          true,
          reason: 'Confirm your identity to enable app lock',
        );

        expect(applied, true);
        expect(store.lockAppEnabled, true);
        verify(() => mockService.setLockAppEnabled(true)).called(1);
      },
    );

    test(
      'setLockAppEnabled(true) does not persist when authentication is cancelled',
      () async {
        when(
          () => mockLocalAuthService.authenticate(reason: any(named: 'reason')),
        ).thenAnswer((_) async => LocalAuthResult.cancelled);

        final applied = await store.setLockAppEnabled(
          true,
          reason: 'Confirm your identity to enable app lock',
        );

        expect(applied, false);
        expect(store.lockAppEnabled, false);
        verifyNever(() => mockService.setLockAppEnabled(any()));
      },
    );

    test(
      'setLockAppEnabled(true) does not persist when authentication is unavailable',
      () async {
        when(
          () => mockLocalAuthService.authenticate(reason: any(named: 'reason')),
        ).thenAnswer((_) async => LocalAuthResult.unavailable);

        final applied = await store.setLockAppEnabled(
          true,
          reason: 'Confirm your identity to enable app lock',
        );

        expect(applied, false);
        expect(store.lockAppEnabled, false);
        verifyNever(() => mockService.setLockAppEnabled(any()));
      },
    );

    test('setLockAppEnabled(false) disables without prompting', () async {
      when(
        () => mockService.setLockAppEnabled(false),
      ).thenAnswer((_) async => {});

      final applied = await store.setLockAppEnabled(
        false,
        reason: 'Confirm your identity to enable app lock',
      );

      expect(applied, true);
      expect(store.lockAppEnabled, false);
      verify(() => mockService.setLockAppEnabled(false)).called(1);
      verifyNever(
        () => mockLocalAuthService.authenticate(reason: any(named: 'reason')),
      );
    });
  });
}
