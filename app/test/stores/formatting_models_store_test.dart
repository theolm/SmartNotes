import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart';
import '../helpers/local_services.dart';

class _Device extends DeviceProfileService {
  _Device(this.profile);

  final DeviceProfile profile;

  @override
  Future<DeviceProfile> read() async => profile;
}

class _ControlledFormattingModels extends MemoryFormattingModels {
  _ControlledFormattingModels() : super(ready: false);

  final gates = <String, Completer<void>>{};
  final started = <String>[];

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    final id = modelId!;
    started.add(id);
    final item = FormattingModel.find(id)!;
    onProgress(item.bytes ~/ 2, item.bytes);
    await (gates[id] ??= Completer<void>()).future;
    await super.download(modelId: id, onProgress: onProgress);
  }

  void release(String id) => (gates[id] ??= Completer<void>()).complete();
}

void main() {
  for (final model in [
    FormattingModel.qwen3_4bInstruct,
    FormattingModel.gemma3_4b,
  ]) {
    test(
      '${model.id} supports explicit selection, stable order and removal',
      () async {
        final store = FormattingModelsStore(
          MemoryFormattingModels(ready: false),
          MemoryDeviceProfile(),
        );
        await store.load();
        final order = store.orderedCatalog.map((m) => m.id).toList();
        await store.downloadOne(FormattingModel.qwen3_0_6b.id);
        await store.downloadOne(model.id);
        expect(store.activeId, FormattingModel.qwen3_0_6b.id);
        expect(await store.activate(model.id), isTrue);
        expect(store.orderedCatalog.map((m) => m.id), order);
        await store.remove(model.id);
        expect(store.ready(model.id), isTrue);
        await store.activate(FormattingModel.qwen3_0_6b.id);
        await store.remove(model.id);
        expect(store.ready(model.id), isFalse);
      },
    );
  }
  test(
    'pending legacy verification is visible and does not block loading the catalog',
    () async {
      final models = MemoryFormattingModels()..isReadyGate = Completer<bool>();
      final store = FormattingModelsStore(
        models,
        _Device(const DeviceProfile()),
      );
      await store.load();
      expect(store.loading, false);
      expect(store.busy, false);
      expect(store.activeUnavailable, false);
      expect(
        store.states[models.activeModelId],
        FormattingDownloadState.checking,
      );
      models.isReadyGate!.complete(true);
      await pumpEventQueue();
      expect(store.activeReady, true);
    },
  );
  test('reconciliation reattaches once and restores terminal states', () async {
    final models = _ControlledFormattingModels();
    final store = FormattingModelsStore(models, _Device(const DeviceProfile()));
    await store.load();
    final model = FormattingModel.qwen3_0_6b;
    final running = ModelTransfer(
      id: model.id,
      state: ModelTransferState.downloading,
      received: 42,
      total: model.bytes,
    );
    store.reconcileTransfers([running]);
    store.reconcileTransfers([running]);
    await pumpEventQueue();
    expect(models.started, [model.id]);
    models.release(model.id);
    await pumpEventQueue();
    expect(store.ready(model.id), true);

    final other = FormattingModel.qwen3_1_7b;
    for (final state in [
      ModelTransferState.cancelled,
      ModelTransferState.failed,
    ]) {
      store.reconcileTransfers([
        ModelTransfer(
          id: other.id,
          state: state,
          received: 1,
          total: other.bytes,
        ),
      ]);
      expect(
        store.states[other.id],
        state == ModelTransferState.failed
            ? FormattingDownloadState.failed
            : FormattingDownloadState.cancelled,
      );
    }
    expect(models.started, [model.id]);
  });
  test('recommendation is conservative for unknown and low-memory devices', () {
    const unknown = DeviceProfile();
    expect(
      FormattingRecommendationPolicy.recommend(unknown).model,
      FormattingModel.qwen3_0_6b,
    );
    expect(
      FormattingRecommendationPolicy.recommend(unknown).reason,
      FormattingRecommendationReason.unknown,
    );
    expect(
      FormattingRecommendationPolicy.recommend(
        const DeviceProfile(
          memoryBytes: 3 * 1024 * 1024 * 1024,
          is64Bit: true,
          processors: 8,
        ),
      ).reason,
      FormattingRecommendationReason.economical,
    );
    expect(
      FormattingRecommendationPolicy.recommend(
        const DeviceProfile(
          memoryBytes: 8 * 1024 * 1024 * 1024,
          is64Bit: true,
          processors: 8,
        ),
      ).model,
      FormattingModel.qwen3_1_7b,
    );
  });

  test('load, download, activation, ordering, and storage summary', () async {
    final models = MemoryFormattingModels(ready: false);
    final store = FormattingModelsStore(
      models,
      _Device(
        const DeviceProfile(
          memoryBytes: 8 * 1024 * 1024 * 1024,
          is64Bit: true,
          processors: 8,
        ),
      ),
    );
    await store.load();
    expect(store.activeReady, false);
    expect(store.recommendation.model, FormattingModel.qwen3_1_7b);
    expect(store.orderedCatalog.first, FormattingModel.qwen3_1_7b);
    expect(store.installedBytes, 0);

    await store.downloadOne(FormattingModel.qwen3_0_6b.id);
    expect(store.ready(FormattingModel.qwen3_0_6b.id), true);
    expect(store.activeId, FormattingModel.qwen3_0_6b.id);
    expect(store.activeReady, true);
    expect(store.installedBytes, FormattingModel.qwen3_0_6b.bytes);

    await store.downloadOne(FormattingModel.qwen3_1_7b.id);
    expect(store.ready(FormattingModel.qwen3_1_7b.id), true);
    expect(store.activeId, FormattingModel.qwen3_0_6b.id);

    expect(await store.activate(FormattingModel.qwen3_1_7b.id), true);
    expect(store.activeId, FormattingModel.qwen3_1_7b.id);
    // The recommended row stays first, even after activation.
    expect(store.orderedCatalog.first, FormattingModel.qwen3_1_7b);
  });

  test('active model cannot be removed; another model can', () async {
    final models = MemoryFormattingModels(ready: false);
    final store = FormattingModelsStore(models, MemoryDeviceProfile());
    await store.load();
    await store.downloadOne(FormattingModel.qwen3_1_7b.id);
    expect(store.activeId, FormattingModel.qwen3_1_7b.id);

    await store.remove(FormattingModel.qwen3_1_7b.id);
    expect(store.ready(FormattingModel.qwen3_1_7b.id), true);
    expect(store.activeReady, true);

    await store.downloadOne(FormattingModel.qwen3_0_6b.id);
    await store.remove(FormattingModel.qwen3_0_6b.id);
    expect(store.ready(FormattingModel.qwen3_0_6b.id), false);
  });

  test(
    'downloads run sequentially and only the first becomes active',
    () async {
      final models = _ControlledFormattingModels();
      final store = FormattingModelsStore(models, MemoryDeviceProfile());
      await store.load();

      final first = store.downloadOne(FormattingModel.qwen3_0_6b.id);
      await pumpEventQueue();
      final second = store.downloadOne(FormattingModel.qwen3_1_7b.id);
      await pumpEventQueue();

      expect(models.started, [FormattingModel.qwen3_0_6b.id]);
      expect(
        store.states[FormattingModel.qwen3_1_7b.id],
        FormattingDownloadState.queued,
      );

      models.release(FormattingModel.qwen3_0_6b.id);
      await first;
      await pumpEventQueue();
      expect(models.started, [
        FormattingModel.qwen3_0_6b.id,
        FormattingModel.qwen3_1_7b.id,
      ]);
      expect(store.activeId, FormattingModel.qwen3_0_6b.id);

      models.release(FormattingModel.qwen3_1_7b.id);
      await second;
      expect(store.activeId, FormattingModel.qwen3_0_6b.id);
      expect(store.ready(FormattingModel.qwen3_1_7b.id), true);
    },
  );

  test(
    'a queued download can be cancelled without affecting the active one',
    () async {
      final models = _ControlledFormattingModels();
      final store = FormattingModelsStore(models, MemoryDeviceProfile());
      await store.load();

      final first = store.downloadOne(FormattingModel.qwen3_0_6b.id);
      await pumpEventQueue();
      final second = store.downloadOne(FormattingModel.qwen3_1_7b.id);
      await pumpEventQueue();

      store.cancelDownload(FormattingModel.qwen3_1_7b.id);
      await second;
      expect(
        store.states[FormattingModel.qwen3_1_7b.id],
        FormattingDownloadState.cancelled,
      );

      models.release(FormattingModel.qwen3_0_6b.id);
      await first;
      expect(store.activeId, FormattingModel.qwen3_0_6b.id);
    },
  );
}
