import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/routes/local_lock_guard.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:smartnotes/domain/services/i_embedding_model_catalog.dart';
import 'package:smartnotes/presentation/screens/settings/embedding_models_store.dart';
import 'package:smartnotes/presentation/screens/settings/embedding_models_screen.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';
import 'package:smartnotes/presentation/widgets/embedding_model_catalog.dart';
import 'package:smartnotes/presentation/widgets/model_catalog_tile.dart';
import 'package:smartnotes/presentation/widgets/model_settings_page.dart';
import 'package:smartnotes/presentation/app_store.dart';
import '../helpers/local_services.dart';

class _AppStore extends Mock implements AppStore {}

class _Catalog extends MemoryEmbeddingModels implements IEmbeddingModelCatalog {
  EmbeddingModel selected = EmbeddingModel.qwen;
  Completer<void>? activation;
  Completer<void>? verification;
  Completer<void>? selection;
  String? removedId;
  final missing = <String>{};
  bool failActivation = false;
  @override
  List<LocalAiModel> get catalog => EmbeddingModel.catalog;
  @override
  LocalAiModel get model => selected;
  @override
  Future<ModelCheckState> readiness({
    String? modelId,
    bool verify = false,
  }) async {
    if (modelId == null) await selection?.future;
    if (missing.contains(modelId ?? selected.id)) {
      return ModelCheckState.missing;
    }
    if (verification != null && !verify) return ModelCheckState.unchecked;
    if (verify) await verification?.future;
    return ModelCheckState.ready;
  }

  @override
  Future<void> activate(String id) async {
    await activation?.future;
    if (failActivation) throw StateError('Synthetic activation failure');
    selected = EmbeddingModel.find(id)!;
  }

  @override
  Future<int> storedBytes(String id, {bool partial = false}) async => 0;
  @override
  Future<void> remove(String id) async {
    removedId = id;
  }

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    final item = EmbeddingModel.find(modelId ?? selected.id)!;
    missing.remove(item.id);
    onProgress(item.bytes, item.bytes);
  }
}

Widget _page(EmbeddingModelsStore store, {bool largeText = false}) =>
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: largeText
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            )
          : null,
      home: Scaffold(
        body: ListView(children: [EmbeddingModelCatalog(store: store)]),
      ),
    );

void main() {
  test('embedding model route is protected by the journal lock guard', () {
    GetIt.I.registerSingleton<AppStore>(_AppStore());
    addTearDown(() => GetIt.I.reset());
    final route = AppRouter().routes.singleWhere(
      (r) => r.page.name == EmbeddingModelsRoute.name,
    );
    expect(route.guards, contains(isA<LocalLockGuard>()));
  });

  test(
    'downloading another model does not change the active selection',
    () async {
      final models = _Catalog()..missing.add(EmbeddingModel.gemma.id);
      final store = EmbeddingModelsStore(
        models,
        ModelDownloadsStore.unsupported(),
      );
      await store.load();
      await store.download(EmbeddingModel.gemma.id);
      expect(store.ready(EmbeddingModel.gemma.id), true);
      expect(store.activeId, EmbeddingModel.qwen.id);
      expect(models.selected.id, EmbeddingModel.qwen.id);
      await models.readinessEvents.close();
    },
  );

  testWidgets(
    'does not label the default active before persisted selection resolves',
    (tester) async {
      final gate = Completer<void>();
      final models = _Catalog()
        ..selected = EmbeddingModel.gemma
        ..selection = gate;
      final store = EmbeddingModelsStore(
        models,
        ModelDownloadsStore.unsupported(),
      );
      await tester.pumpWidget(_page(store));
      await tester.pump();
      expect(find.text('Checking active model…'), findsOneWidget);
      expect(find.text('Active'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      final card = tester.widget<ModelCatalogTile>(
        find.byKey(ValueKey('embedding-model-${EmbeddingModel.gemma.id}')),
      );
      expect(card.active, isTrue);
      await models.readinessEvents.close();
    },
  );

  testWidgets(
    'dedicated screen shows active model and collapses unavailable candidates',
    (tester) async {
      final models = _Catalog();
      final store = EmbeddingModelsStore(
        models,
        ModelDownloadsStore.unsupported(),
      );
      GetIt.I.registerSingleton<EmbeddingModelsStore>(store);
      addTearDown(() => GetIt.I.reset());
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EmbeddingModelsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Search model'), findsOneWidget);
      expect(find.byType(ModelSettingsPage), findsOneWidget);
      expect(find.byType(ModelCatalogTile), findsNWidgets(2));
      expect(find.text('Active'), findsOneWidget);
      expect(find.text(EmbeddingModel.gemma2.name), findsNothing);
      expect(find.text(EmbeddingModel.e5.name), findsNothing);
      await tester.ensureVisible(find.text('Unavailable models'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unavailable models'));
      await tester.pumpAndSettle();
      expect(find.text(EmbeddingModel.gemma2.name), findsOneWidget);
      expect(find.text(EmbeddingModel.e5.name), findsOneWidget);
      expect(find.text('Use model'), findsNothing);
      await models.readinessEvents.close();
    },
  );

  testWidgets('switch requires confirmation and updates active indicators', (
    tester,
  ) async {
    final models = _Catalog();
    final store = EmbeddingModelsStore(
      models,
      ModelDownloadsStore.unsupported(),
    );
    await tester.pumpWidget(_page(store));
    await tester.pumpAndSettle();
    final select = find.text(EmbeddingModel.gemma.name);
    await tester.ensureVisible(select);
    await tester.pumpAndSettle();
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(store.activeId, EmbeddingModel.qwen.id);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.activeId, EmbeddingModel.qwen.id);
    await tester.tap(select);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(store.activeId, EmbeddingModel.gemma.id);
    expect(
      tester
          .widget<ModelCatalogTile>(
            find.byKey(ValueKey('embedding-model-${EmbeddingModel.gemma.id}')),
          )
          .active,
      isTrue,
    );
    await models.readinessEvents.close();
  });

  testWidgets('information dialog retains explicit nonblocking verification', (
    tester,
  ) async {
    final models = _Catalog();
    final store = EmbeddingModelsStore(
      models,
      ModelDownloadsStore.unsupported(),
    );
    await tester.pumpWidget(_page(store));
    await tester.pumpAndSettle();
    final row = find.byKey(
      ValueKey('embedding-model-${EmbeddingModel.qwen.id}'),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.info_outline)),
    );
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    models.verification = gate;
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.states[EmbeddingModel.qwen.id], ModelCheckState.checking);
    gate.complete();
    await tester.pumpAndSettle();
    expect(store.ready(EmbeddingModel.qwen.id), isTrue);
    await models.readinessEvents.close();
  });

  testWidgets(
    'active deletion is disabled and inactive deletion requires confirmation',
    (tester) async {
      final models = _Catalog();
      final store = EmbeddingModelsStore(
        models,
        ModelDownloadsStore.unsupported(),
      );
      await tester.pumpWidget(_page(store));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(
                ValueKey('embedding-delete-${EmbeddingModel.qwen.id}'),
              ),
            )
            .onPressed,
        isNull,
      );
      final delete = find.byKey(
        ValueKey('embedding-delete-${EmbeddingModel.gemma.id}'),
      );
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(models.removedId, isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(models.removedId, EmbeddingModel.gemma.id);
      expect(
        find.byKey(ValueKey('embedding-download-${EmbeddingModel.gemma.id}')),
        findsOneWidget,
      );
      await models.readinessEvents.close();
    },
  );

  testWidgets('partial model retains both resume and deletion controls', (
    tester,
  ) async {
    final models = _Catalog()..missing.add(EmbeddingModel.gemma.id);
    final store = EmbeddingModelsStore(
      models,
      ModelDownloadsStore.unsupported(),
    );
    await tester.pumpWidget(_page(store));
    await tester.pumpAndSettle();
    store.partial[EmbeddingModel.gemma.id] = 123;
    await tester.pump();
    final download = find.byKey(
      ValueKey('embedding-download-${EmbeddingModel.gemma.id}'),
    );
    final delete = find.byKey(
      ValueKey('embedding-delete-${EmbeddingModel.gemma.id}'),
    );
    expect(tester.widget<IconButton>(download).onPressed, isNotNull);
    expect(tester.widget<IconButton>(delete).onPressed, isNotNull);
    expect(tester.widget<IconButton>(download).tooltip, 'Resume');
    await models.readinessEvents.close();
  });

  testWidgets('compact model catalog supports large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final models = _Catalog();
    final store = EmbeddingModelsStore(
      models,
      ModelDownloadsStore.unsupported(),
    );
    await tester.pumpWidget(_page(store, largeText: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Unavailable models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unavailable models'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(EmbeddingModel.e5.name));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await models.readinessEvents.close();
  });
  testWidgets(
    'shared model rows retain vertical spacing and trailing controls',
    (tester) async {
      final models = _Catalog();
      final store = EmbeddingModelsStore(
        models,
        ModelDownloadsStore.unsupported(),
      );
      await tester.pumpWidget(_page(store));
      await tester.pumpAndSettle();

      Finder card(String id) => find.byKey(ValueKey('embedding-model-$id'));
      Finder surface(String id) =>
          find.descendant(of: card(id), matching: find.byType(Material)).first;
      final first = tester.getRect(surface(EmbeddingModel.qwen.id));
      final second = tester.getRect(surface(EmbeddingModel.gemma.id));
      expect(second.top - first.bottom, greaterThanOrEqualTo(AppSpacing.lg));

      final actions = find.descendant(
        of: card(EmbeddingModel.gemma.id),
        matching: find.byType(ModelCatalogActionButton),
      );
      expect(actions, findsOneWidget);
      expect(
        tester
            .getSize(
              find.descendant(of: actions, matching: find.byType(IconButton)),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      await models.readinessEvents.close();
    },
  );
  test(
    'failed activation leaves selected model intact with a stable failure',
    () async {
      final models = _Catalog()..failActivation = true;
      final store = EmbeddingModelsStore(
        models,
        ModelDownloadsStore.unsupported(),
      );
      await store.load();
      await store.activate(EmbeddingModel.gemma.id);
      expect(store.activeId, EmbeddingModel.qwen.id);
      expect(store.failure, EmbeddingCatalogFailure.activation);
      expect(store.activatingId, isNull);
      await models.readinessEvents.close();
    },
  );

  for (final checking in [false, true]) {
    testWidgets(
      'journal controls remain responsive during ${checking ? 'verification' : 'activation'}',
      (tester) async {
        final gate = Completer<void>();
        final models = _Catalog();
        if (checking) {
          models.verification = gate;
        } else {
          models.activation = gate;
        }
        final store = EmbeddingModelsStore(
          models,
          ModelDownloadsStore.unsupported(),
        );
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => taps++,
                    child: const Text('Journal control'),
                  ),
                  Expanded(
                    child: ListView(
                      children: [EmbeddingModelCatalog(store: store)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        Future<void>? activation;
        if (!checking) {
          await store.load();
          activation = store.activate(EmbeddingModel.gemma.id);
        }
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tap(find.text('Journal control'));
        await tester.pump(const Duration(milliseconds: 16));
        expect(taps, 1);
        expect(find.byType(AlertDialog), findsNothing);
        expect(gate.isCompleted, false);
        gate.complete();
        await activation;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await models.readinessEvents.close();
      },
    );
  }
}
