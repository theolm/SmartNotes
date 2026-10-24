import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/data/datasources/local/shared_preferences_settings_service.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';
import 'package:smartnotes/presentation/screens/settings/speech_models_screen.dart';
import 'package:smartnotes/presentation/screens/settings/speech_models_store.dart';
import 'package:smartnotes/presentation/widgets/model_catalog_tile.dart';
import 'package:smartnotes/presentation/widgets/model_settings_page.dart';
import '../helpers/local_services.dart';

class _Auth extends Mock implements ILocalAuthService {}

class _Device extends DeviceProfileService {
  @override
  Future<DeviceProfile> read() async => const DeviceProfile(
    memoryBytes: 8 * 1024 * 1024 * 1024,
    is64Bit: true,
    processors: 8,
  );
}

void main() {
  late SpeechModelsStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'audioLanguage': 'pt'});
    final settings = SharedPreferencesSettingsService(
      await SharedPreferences.getInstance(),
    );
    final auth = _Auth();
    when(() => auth.isAvailable()).thenAnswer((_) async => false);
    final models = MemorySpeechModels(settings: settings);
    final preferences = SettingsStore(settings, auth, models);
    await preferences.load();
    store = SpeechModelsStore(
      models,
      _Device(),
    );
    GetIt.I.registerSingleton(store);
    GetIt.I.registerSingleton(preferences);
  });
  tearDown(() async => GetIt.I.reset());
  Future<void> render(WidgetTester tester, {bool compact = false}) async {
    tester.view.physicalSize = compact
        ? const Size(320, 640)
        : const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: compact ? AppTheme.dark : AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(compact ? 2 : 1)),
          child: child!,
        ),
        home: const SpeechModelsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows compact rows with download/delete actions and a stable recommendation order',
    (tester) async {
      await render(tester);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        find.byKey(ValueKey('model-row-${SpeechModel.whisperBaseQ8.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('delete-${SpeechModel.whisperBaseQ8.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('download-${SpeechModel.small.id}')),
        findsOneWidget,
      );
      expect(find.text('Audio language'), findsOneWidget);
      expect(find.text('Português'), findsOneWidget);
      expect(find.textContaining('190.1 MB'), findsOneWidget);
      expect(find.text('English only'), findsNWidgets(2));
      expect(find.text('Recommended for this device'), findsOneWidget);
      expect(find.byType(ModelSettingsPage), findsOneWidget);
      expect(
        find.byType(ModelCatalogTile),
        findsNWidgets(SpeechModel.catalog.length),
      );
      expect(store.recommendation.model, SpeechModel.small);
      expect(store.activeId, SpeechModel.whisperBaseQ8.id);
      final activeDelete = tester.widget<IconButton>(
        find.byKey(ValueKey('delete-${SpeechModel.whisperBaseQ8.id}')),
      );
      expect(activeDelete.onPressed, isNull);
      expect(
        tester
            .getTopLeft(
              find.byKey(ValueKey('model-row-${SpeechModel.small.id}')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(
                  ValueKey('model-row-${SpeechModel.whisperBaseQ8.id}'),
                ),
              )
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'language changes are saved with a compatible model on the same page',
    (tester) async {
      await render(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(GetIt.I<SettingsStore>().audioLanguage, 'en');
      expect(store.language, 'en');
      expect(store.activeReady, isTrue);
      expect(find.byType(SpeechModelsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'incompatible language stays pending until a compatible model is selected',
    (tester) async {
      await GetIt.I<SettingsStore>().setAudioLanguage('en');
      await store.load('en');
      await store.downloadOne(SpeechModel.smallEnglish.id);
      await store.activate(SpeechModel.smallEnglish.id);
      await render(tester);
      final field = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      field.onChanged!('pt');
      await tester.pumpAndSettle();
      expect(GetIt.I<SettingsStore>().audioLanguage, 'en');
      expect(store.language, 'pt');
      expect(store.activeReady, isFalse);
      await tester.ensureVisible(
        find.byKey(ValueKey('model-row-${SpeechModel.whisperBaseQ8.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(SpeechModel.whisperBaseQ8.name));
      await tester.pumpAndSettle();
      await GetIt.I<SettingsStore>().load();
      expect(GetIt.I<SettingsStore>().audioLanguage, 'pt');
      expect(store.activeReady, isTrue);
    },
  );

  testWidgets(
    'tapping a row activates it in place without reordering',
    (tester) async {
      await render(tester);
      await tester.runAsync(
        () => store.downloadOne(SpeechModel.turbo.id),
      );
      await tester.pumpAndSettle();
      expect(store.ready(SpeechModel.turbo.id), isTrue);
      expect(store.activeId, SpeechModel.whisperBaseQ8.id);
      expect(
        find.byKey(ValueKey('delete-${SpeechModel.turbo.id}')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(ValueKey('model-row-${SpeechModel.turbo.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Whisper Large-v3-turbo'));
      await tester.pumpAndSettle();
      expect(store.activeId, SpeechModel.turbo.id);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(ValueKey('delete-${SpeechModel.turbo.id}')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(ValueKey('delete-${SpeechModel.whisperBaseQ8.id}')),
            )
            .onPressed,
        isNotNull,
      );
      // The selected card stays where it was; only its state changes.
      expect(
        tester
            .getTopLeft(
              find.byKey(ValueKey('model-row-${SpeechModel.small.id}')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(
                  ValueKey('model-row-${SpeechModel.turbo.id}'),
                ),
              )
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(
                ValueKey('model-row-${SpeechModel.whisperBaseQ8.id}'),
              ),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(
                  ValueKey('model-row-${SpeechModel.turbo.id}'),
                ),
              )
              .dy,
        ),
      );
    },
  );
  testWidgets(
    'deleting an installed inactive model returns it to download',
    (tester) async {
      await render(tester);
      await tester.runAsync(
        () => store.downloadOne(SpeechModel.small.id),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(ValueKey('delete-${SpeechModel.small.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('delete-${SpeechModel.small.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Remove model files?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(store.ready(SpeechModel.small.id), isFalse);
      expect(
        find.byKey(ValueKey('download-${SpeechModel.small.id}')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'compact dark screen with large text keeps actions visible without overflow',
    (tester) async {
      await render(tester, compact: true);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('model-row-${SpeechModel.whisperBaseQ8.id}')),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(ValueKey('delete-${SpeechModel.whisperBaseQ8.id}'))
            .hitTestable(),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('model-row-${SpeechModel.small.id}')),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('download-${SpeechModel.small.id}')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
