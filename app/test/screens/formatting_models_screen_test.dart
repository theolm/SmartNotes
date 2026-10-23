import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_screen.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart';
import '../helpers/local_services.dart';

class _Device extends DeviceProfileService {
  @override
  Future<DeviceProfile> read() async => const DeviceProfile(
    memoryBytes: 8 * 1024 * 1024 * 1024,
    is64Bit: true,
    processors: 8,
  );
}

class _FailingFormattingModels extends MemoryFormattingModels {
  _FailingFormattingModels() : super(ready: false);

  @override
  Future<bool> isPresent(String modelId) async =>
      throw StateError('catalog failure');
}

void main() {
  late FormattingModelsStore store;

  setUp(() {
    store = FormattingModelsStore(
      MemoryFormattingModels(ready: false),
      _Device(),
    );
    GetIt.I.registerSingleton(store);
  });

  tearDown(() => GetIt.I.reset());

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
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(compact ? 2 : 1),
          ),
          child: child!,
        ),
        home: const FormattingModelsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists recommended model with size, capabilities, and actions', (
    tester,
  ) async {
    await render(tester);
    expect(find.text('AI organization'), findsOneWidget);
    expect(find.text('Recommended for this device'), findsOneWidget);
    expect(find.text('Qwen3 1.7B Q4_K_M'), findsOneWidget);
    expect(find.text('Qwen3 0.6B Q8'), findsOneWidget);
    expect(find.textContaining('1.11 GB'), findsOneWidget);
    expect(find.textContaining('639.4 MB'), findsOneWidget);
    expect(
      find.text('Better structure and fidelity. Recommended for most devices.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Fastest and smallest. Best for short notes and low-memory devices; may omit details on long or complex notes.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey('formatting-download-${FormattingModel.qwen3_1_7b.id}'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('downloaded model becomes active and cannot be deleted', (
    tester,
  ) async {
    await render(tester);
    await tester.runAsync(
      () => store.downloadOne(FormattingModel.qwen3_1_7b.id),
    );
    await tester.pumpAndSettle();
    expect(store.activeId, FormattingModel.qwen3_1_7b.id);
    expect(find.text('Active'), findsOneWidget);
    final delete = tester.widget<IconButton>(
      find.byKey(
        ValueKey('formatting-delete-${FormattingModel.qwen3_1_7b.id}'),
      ),
    );
    expect(delete.onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(
              ValueKey('formatting-download-${FormattingModel.qwen3_0_6b.id}'),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('tapping an installed row switches the active model', (
    tester,
  ) async {
    await store.downloadOne(FormattingModel.qwen3_1_7b.id);
    await tester.runAsync(
      () => store.downloadOne(FormattingModel.qwen3_0_6b.id),
    );
    await render(tester);
    expect(store.activeId, FormattingModel.qwen3_1_7b.id);
    await tester.ensureVisible(
      find.byKey(
        ValueKey('formatting-model-row-${FormattingModel.qwen3_0_6b.id}'),
      ),
    );
    await tester.tap(find.text('Qwen3 0.6B Q8'));
    await tester.pumpAndSettle();
    expect(store.activeId, FormattingModel.qwen3_0_6b.id);
  });

  testWidgets('info dialog explains languages, memory, and license', (
    tester,
  ) async {
    await render(tester);
    await tester.tap(find.byTooltip('Model capabilities').first);
    await tester.pumpAndSettle();
    expect(find.text('Capabilities'), findsOneWidget);
    expect(find.text('Languages'), findsOneWidget);
    expect(
      find.text('Multilingual, including Portuguese and English'),
      findsOneWidget,
    );
    expect(
      find.text('Formats notes within the app\'s 4,096-token budget.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('catalog failure shows an inline retry', (tester) async {
    GetIt.I.unregister<FormattingModelsStore>();
    store = FormattingModelsStore(_FailingFormattingModels(), _Device());
    GetIt.I.registerSingleton(store);
    await render(tester);
    expect(
      find.text(
        'Could not prepare the model. Check your connection and free storage, then download again. An interrupted download can resume.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact large text does not overflow', (tester) async {
    await render(tester, compact: true);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
