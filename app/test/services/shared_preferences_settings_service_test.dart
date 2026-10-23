import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/datasources/local/shared_preferences_settings_service.dart';

void main() {
  group('SharedPreferencesSettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<SharedPreferencesSettingsService> makeService() async {
      final prefs = await SharedPreferences.getInstance();
      return SharedPreferencesSettingsService(prefs);
    }

    group('theme mode', () {
      test('defaults to null', () async {
        final service = await makeService();
        expect(service.getThemeMode(), isNull);
      });

      test('set and get theme mode', () async {
        final service = await makeService();
        await service.setThemeMode('dark');
        expect(service.getThemeMode(), 'dark');
      });
    });

    group('audio language', () {
      test('defaults to null', () async {
        final service = await makeService();
        expect(service.getAudioLanguage(), isNull);
      });

      test('set and get audio language', () async {
        final service = await makeService();
        await service.setAudioLanguage('pt-BR');
        expect(service.getAudioLanguage(), 'pt-BR');
      });

      test('set null removes value', () async {
        final service = await makeService();
        await service.setAudioLanguage('en');
        await service.setAudioLanguage(null);
        expect(service.getAudioLanguage(), isNull);
      });
    });

    group('formatting model', () {
      test('defaults to no selection', () async {
        final service = await makeService();
        expect(service.getFormattingModelId(), isNull);
      });

      test('set and get the active formatting model', () async {
        final service = await makeService();
        await service.setFormattingModelId('qwen3-0.6b-q8_0');
        expect(service.getFormattingModelId(), 'qwen3-0.6b-q8_0');
      });

      test('set null removes the selection', () async {
        final service = await makeService();
        await service.setFormattingModelId('qwen3-0.6b-q8_0');
        await service.setFormattingModelId(null);
        expect(service.getFormattingModelId(), isNull);
      });
    });

    group('app locale', () {
      test('defaults to en', () async {
        final service = await makeService();
        expect(service.getAppLocale(), 'en');
      });

      test('set and get app locale', () async {
        final service = await makeService();
        await service.setAppLocale('pt');
        expect(service.getAppLocale(), 'pt');
      });
    });

    group('lock app', () {
      test('defaults to disabled', () async {
        final service = await makeService();
        expect(service.getLockAppEnabled(), false);
      });

      test('set and get lock app enabled', () async {
        final service = await makeService();
        await service.setLockAppEnabled(true);
        expect(service.getLockAppEnabled(), true);
      });

      test('set disabled persists false', () async {
        final service = await makeService();
        await service.setLockAppEnabled(true);
        await service.setLockAppEnabled(false);
        expect(service.getLockAppEnabled(), false);
      });
    });
  });
}
