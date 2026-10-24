import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/datasources/local/shared_preferences_settings_service.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/formatting_model_service.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/model_verification.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';

class _LowStorage extends DeviceProfileService {
  @override
  Future<int?> freeStorage() async => 0;
}

void main() {
  late Directory directory;
  final bytes = List<int>.generate(16, (i) => i);
  late FormattingModel model;
  late FormattingModel other;
  late SharedPreferencesSettingsService settings;
  late ModelVerificationStore verification;
  late Map<String, String> records;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    records = {};
    verification = ModelVerificationStore.forTesting(
      read: (key) => records[key],
      write: (key, value) async {
        if (value == null) {
          records.remove(key);
        } else {
          records[key] = value;
        }
      },
    );
    settings = SharedPreferencesSettingsService(
      await SharedPreferences.getInstance(),
    );
    directory = await Directory.systemTemp.createTemp('formatting-model-test-');
    model = FormattingModel(
      id: 'test-light',
      name: 'Test light',
      fileName: 'light.gguf',
      url: 'https://example.com/light.gguf',
      bytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      kind: FormattingModelKind.light,
      quantization: 'Q8_0',
    );
    other = FormattingModel(
      id: 'test-balanced',
      name: 'Test balanced',
      fileName: 'balanced.gguf',
      url: 'https://example.com/balanced.gguf',
      bytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      kind: FormattingModelKind.balanced,
      quantization: 'Q4_K_M',
    );
  });

  tearDown(() => directory.delete(recursive: true));

  FormattingModelService service(
    http.Client client, {
    DeviceProfileService? device,
    Future<String> Function(File)? hash,
  }) => FormattingModelService.forTesting(
    client,
    model: model,
    catalog: [model, other],
    directory: () async => directory,
    settings: settings,
    queue: LocalInferenceQueue(),
    device: device,
    verificationStore: verification,
    hash: hash,
  );

  File file(FormattingModel item) =>
      File('${directory.path}/formatting_models/${item.fileName}');
  File partial(FormattingModel item) =>
      File('${directory.path}/formatting_models/${item.fileName}.part');

  test(
    'A to B to A across cold instances retains both verification records',
    () async {
      var hashes = 0;
      final client = MockClient((_) async => http.Response.bytes(bytes, 200));
      addTearDown(client.close);
      Future<String> hash(File _) async {
        hashes++;
        return model.sha256;
      }

      final models = service(client, hash: hash);
      await models.download(modelId: model.id, onProgress: (_, _) {});
      await models.download(modelId: other.id, onProgress: (_, _) {});
      expect(hashes, 2);
      await models.activate(model.id);
      await models.activate(other.id);
      await service(client, hash: hash).activate(model.id);
      expect(hashes, 2);
      expect(records, hasLength(2));
    },
  );

  test('catalog metadata is pinned and stable', () {
    expect(FormattingModel.catalog, hasLength(4));
    expect(FormattingModel.qwen3_4bInstruct.bytes, 2497281120);
    expect(
      FormattingModel.qwen3_4bInstruct.sha256,
      '3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597',
    );
    expect(FormattingModel.gemma3_4b.bytes, 2489894016);
    expect(
      FormattingModel.gemma3_4b.sha256,
      '04a43a22e8d2003deda5acc262f68ec1005fa76c735a9962a8c77042a74a7d19',
    );
    expect(FormattingModel.gemma3_4b.requiresGemmaTerms, isTrue);
    expect(FormattingModel.gemma3_4b.license, 'Gemma Terms of Use');
    expect(FormattingModel.qwen3_4bInstruct.license, 'Apache-2.0');
    for (final item in FormattingModel.catalog) {
      expect(item.url, matches(RegExp(r'/resolve/[0-9a-f]{40}/')));
      expect(item.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(FormattingModel.find(item.id), same(item));
    }
    expect(FormattingModel.qwen3_0_6b.id, 'qwen3-0.6b-q8_0');
    expect(FormattingModel.qwen3_0_6b.bytes, 639446688);
    expect(
      FormattingModel.qwen3_0_6b.sha256,
      '9465e63a22add5354d9bb4b99e90117043c7124007664907259bd16d043bb031',
    );
    expect(
      FormattingModel.qwen3_0_6b.url,
      contains('/23749fefcc72300e3a2ad315e1317431b06b590a/'),
    );
    expect(FormattingModel.qwen3_1_7b.id, 'qwen3-1.7b-q4_k_m');
    expect(FormattingModel.qwen3_1_7b.bytes, 1107409472);
    expect(
      FormattingModel.qwen3_1_7b.sha256,
      'b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897',
    );
    expect(
      FormattingModel.qwen3_1_7b.url,
      contains('/d7f544eead698dbd1f15126ef60b45a1e1933222/'),
    );
  });

  test('only complete SHA-256 verified weights become ready', () async {
    var calls = 0;
    final models = service(
      MockClient((_) async {
        calls++;
        return http.Response.bytes(bytes, 200);
      }),
    );
    expect(await models.isReady(), false);
    await expectLater(
      models.requireModelPath(),
      throwsA(
        isA<FormattingModelException>().having(
          (error) => error.problem,
          'problem',
          FormattingModelProblem.notReady,
        ),
      ),
    );
    final progress = <int>[];
    await models.download(
      modelId: model.id,
      onProgress: (received, _) => progress.add(received),
    );
    expect(progress.last, bytes.length);
    expect(await models.isReady(model.id), true);
    expect(await models.isReady(), false);
    await models.activate(model.id);
    expect(models.activeModelId, model.id);
    expect(await models.requireModelPath(), file(model).path);
    await models.download(modelId: model.id, onProgress: (_, _) {});
    expect(calls, 1);
  });

  test('active selection survives a new service instance', () async {
    final models = service(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    await models.download(modelId: model.id, onProgress: (_, _) {});
    await models.activate(model.id);

    final reopened = service(
      MockClient((_) async => throw StateError('offline')),
    );
    expect(reopened.activeModelId, model.id);
    expect(reopened.activeModel?.id, model.id);
    expect(await reopened.isReady(), true);
  });

  test(
    'persisted verification is reused and invalidated by file changes',
    () async {
      final models = service(
        MockClient((_) async => http.Response.bytes(bytes, 200)),
      );
      await models.download(modelId: model.id, onProgress: (_, _) {});
      await models.activate(model.id);
      expect(records, isNotEmpty);

      final reopened = service(
        MockClient((_) async => throw StateError('offline')),
      );
      expect(await reopened.isReady(), true);

      await file(model).writeAsBytes(List.filled(bytes.length, 9));
      await file(model).setLastModified(
        DateTime.now().add(const Duration(seconds: 1)),
      );
      expect(await reopened.isReady(), false);
    },
  );

  test('missing active model is not ready and has no path', () async {
    await settings.setFormattingModelId(model.id);
    final models = service(
      MockClient((_) async => throw StateError('offline')),
    );
    expect(await models.isReady(), false);
    await expectLater(
      models.requireModelPath(),
      throwsA(isA<FormattingModelException>()),
    );
  });

  test('removes a non-active model and refuses the active one', () async {
    final models = service(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    await models.download(modelId: model.id, onProgress: (_, _) {});
    await models.activate(model.id);
    await expectLater(
      models.remove(model.id),
      throwsA(
        isA<FormattingModelException>().having(
          (error) => error.problem,
          'problem',
          FormattingModelProblem.inUse,
        ),
      ),
    );
    expect(await file(model).exists(), true);

    await models.activate(model.id);
    await models.remove(other.id);
    expect(await file(other).exists(), false);
  });

  test(
    'partial download resumes with Range and is atomically promoted',
    () async {
      await partial(model).parent.create(recursive: true);
      await partial(model).writeAsBytes(bytes.sublist(0, 5));
      final models = service(
        MockClient((request) async {
          expect(request.headers['Range'], 'bytes=5-');
          return http.Response.bytes(
            bytes.sublist(5),
            206,
            headers: {'content-range': 'bytes 5-15/16'},
          );
        }),
      );
      await models.download(modelId: model.id, onProgress: (_, _) {});
      expect(await file(model).readAsBytes(), bytes);
      expect(await partial(model).exists(), false);
    },
  );

  test('rejects corrupt bytes and never promotes the model', () async {
    final models = service(
      MockClient(
        (_) async => http.Response.bytes(List.filled(bytes.length, 9), 200),
      ),
    );
    await expectLater(
      models.download(modelId: model.id, onProgress: (_, _) {}),
      throwsA(isA<FormatException>()),
    );
    expect(await file(model).exists(), false);
    expect(await models.isReady(model.id), false);
  });

  test('free-storage preflight refuses a model that does not fit', () async {
    final models = service(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
      device: _LowStorage(),
    );
    await expectLater(
      models.download(modelId: model.id, onProgress: (_, _) {}),
      throwsA(
        isA<FormattingModelException>().having(
          (error) => error.problem,
          'problem',
          FormattingModelProblem.storage,
        ),
      ),
    );
    expect(await file(model).exists(), false);
  });

  test('unknown model ids are rejected', () async {
    final models = service(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    await expectLater(models.isReady('missing'), completion(false));
    await expectLater(
      models.download(modelId: 'missing', onProgress: (_, _) {}),
      throwsArgumentError,
    );
  });

  test('stored bytes expose full and partial artifacts', () async {
    final models = service(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    await partial(model).parent.create(recursive: true);
    await partial(model).writeAsBytes(bytes.sublist(0, 5));
    expect(await models.storedBytes(model.id), 0);
    expect(await models.storedBytes(model.id, partial: true), 5);
    expect(await models.storedBytes('missing'), 0);
  });
}
