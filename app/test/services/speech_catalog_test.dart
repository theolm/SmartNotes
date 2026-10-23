import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/datasources/local/shared_preferences_settings_service.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/speech_model_service.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/presentation/screens/settings/speech_models_store.dart';

class _Device extends DeviceProfileService {
  int? free;
  DeviceProfile profile = const DeviceProfile();
  @override
  Future<int?> freeStorage() async => free;
  @override
  Future<DeviceProfile> read() async => profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SharedPreferences prefs;
  late SharedPreferencesSettingsService settings;
  late LocalInferenceQueue queue;
  final payload = List<int>.generate(32, (i) => i);
  SpeechModel artifact(String id, {bool english = false}) => SpeechModel(
    id: id,
    name: id,
    fileName: '$id.bin',
    url: 'https://example.com/$id.bin',
    bytes: payload.length,
    sha256: sha256.convert(payload).toString(),
    englishOnly: english,
  );
  final multilingual = artifact('multi');
  final english = artifact('english', english: true);
  final alternate = artifact('alternate');
  late SpeechModelService service;
  late _Device device;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('speech-catalog-');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    settings = SharedPreferencesSettingsService(prefs);
    queue = LocalInferenceQueue();
    device = _Device();
    service = SpeechModelService.forTesting(
      MockClient((_) async => http.Response.bytes(payload, 200)),
      model: multilingual,
      catalog: [multilingual, english, alternate],
      directory: () async => root,
      settings: settings,
      queue: queue,
      device: device,
    );
  });
  tearDown(() => root.delete(recursive: true));
  Future<void> install(String id) =>
      service.download(modelId: id, onProgress: (_, _) {});

  test(
    'six catalog artifacts have fixed revisions, unique files, hashes and correct language constraints',
    () {
      expect(SpeechModel.catalog, hasLength(6));
      expect(SpeechModel.catalog.map((m) => m.fileName).toSet(), hasLength(6));
      expect(SpeechModel.catalog.map((m) => m.id).toSet(), hasLength(6));
      for (final model in SpeechModel.catalog) {
        expect(model.url, contains(SpeechModel.revision));
        expect(model.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(model.supports('en'), isTrue);
        expect(model.supports('pt-BR'), !model.englishOnly);
        expect(model.supports(null), !model.englishOnly);
        expect(model.supports('xx'), isFalse);
      }
      expect(SpeechModel.small.supports('yue'), isFalse);
      expect(SpeechModel.turbo.supports('yue'), isTrue);
    },
  );

  test(
    'active model and language are committed together and survive restart',
    () async {
      await install(english.id);
      await service.activate(english.id, language: 'en');
      expect(settings.getSpeechModelId(), english.id);
      expect(settings.getAudioLanguage(), 'en');
      expect(await service.isReady(), isTrue);
      await expectLater(
        service.activate(english.id, language: 'pt'),
        throwsA(isA<SpeechModelException>()),
      );
      await expectLater(
        service.activate(english.id, language: null),
        throwsA(isA<SpeechModelException>()),
      );
      expect(settings.getAudioLanguage(), 'en');
      expect(service.model, english);
    },
  );

  test(
    'legacy Base migration does not download or reset completed setup',
    () async {
      await prefs.setBool('onboardingCompleted', true);
      await prefs.setString('audioLanguage', 'pt');
      expect(service.activeModelId, multilingual.id);
      expect(settings.getAudioLanguage(), 'pt');
      await install(multilingual.id);
      expect(await service.isReady(), isTrue);
      expect(settings.getOnboardingCompleted(), isTrue);
    },
  );

  test(
    'invalid persisted active model requires repair, never a silent fallback',
    () async {
      await install(multilingual.id);
      await settings.setSpeechConfiguration('missing-id', 'pt');
      expect(await service.isReady(), isFalse);
      await expectLater(service.requireModelPath(), throwsStateError);
      final store = SpeechModelsStore(service, device);
      await store.load('pt');
      expect(store.activeId, 'missing-id');
      expect(store.activeUnavailable, isTrue);
      expect(store.orderedCatalog.first.id, multilingual.id);
    },
  );

  test(
    'cannot activate missing weights or remove active or last compatible weights',
    () async {
      await expectLater(
        service.activate(english.id, language: 'en'),
        throwsA(isA<SpeechModelException>()),
      );
      await install(multilingual.id);
      await install(english.id);
      await service.activate(english.id, language: 'en');
      await expectLater(
        service.remove(english.id),
        throwsA(isA<SpeechModelException>()),
      );
      await service.remove(multilingual.id);
      expect(await service.isReady(multilingual.id), isFalse);
      expect(await service.isReady(), isTrue);
    },
  );

  test(
    'switching and deletion wait until an inference lease is released',
    () async {
      await install(multilingual.id);
      await install(alternate.id);
      final release = Completer<void>();
      final started = Completer<void>();
      final inference = queue.run(() async {
        started.complete();
        await release.future;
      });
      await started.future;
      var switched = false;
      final activation = service
          .activate(alternate.id, language: 'pt')
          .then((_) => switched = true);
      await Future<void>.delayed(Duration.zero);
      expect(switched, isFalse);
      release.complete();
      await inference;
      await activation;
      await service.remove(multilingual.id);
      expect(await service.isReady(), isTrue);
    },
  );

  test(
    'a same-size corrupt inactive artifact becomes repairable on activation',
    () async {
      await install(multilingual.id);
      await install(english.id);
      await install(alternate.id);
      await service.activate(english.id, language: 'en');
      await File(
        '${root.path}/speech_models/${alternate.fileName}',
      ).writeAsBytes(List.filled(payload.length, 99));
      final store = SpeechModelsStore(service, device);
      await store.load('en');
      expect(store.ready(alternate.id), isTrue);
      expect(await store.activate(alternate.id), isFalse);
      expect(store.error, isA<SpeechModelException>());
      expect(store.ready(alternate.id), isFalse);
      await store.downloadOne(alternate.id);
      expect(store.ready(alternate.id), isTrue);
      expect(store.activeId, english.id);
    },
  );

  test('storage exhaustion fails before any artifact is published', () async {
    device.free = 1;
    await expectLater(
      install(multilingual.id),
      throwsA(
        isA<SpeechModelException>().having(
          (e) => e.problem,
          'problem',
          SpeechModelProblem.storage,
        ),
      ),
    );
    expect(await service.isReady(), isFalse);
  });

  test(
    'downloads queue in order and the first compatible one becomes active',
    () async {
      final store = SpeechModelsStore(service, device);
      await store.load('en');
      final first = store.downloadOne(multilingual.id);
      final second = store.downloadOne(english.id);
      await Future.wait([first, second]);
      expect(store.ready(multilingual.id), isTrue);
      expect(store.ready(english.id), isTrue);
      expect(store.activeId, multilingual.id);
      expect(store.orderedCatalog.first.id, multilingual.id);
      expect(await store.activate(english.id), isTrue);
      expect(store.activeId, english.id);
      // Activating a model must not move it to the top of the list.
      expect(store.orderedCatalog.first.id, multilingual.id);
      expect(store.orderedCatalog[1].id, english.id);
      expect((await store.activate(multilingual.id)), isTrue);
      expect(store.activeId, multilingual.id);
      expect(store.orderedCatalog.first.id, multilingual.id);
    },
  );

  test(
    'a queued download can be cancelled without stopping the current one',
    () async {
      final stream = StreamController<List<int>>();
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(stream.stream, 200),
      );
      final streamingService = SpeechModelService.forTesting(
        client,
        model: multilingual,
        catalog: [multilingual, english, alternate],
        directory: () async => root,
        settings: settings,
        queue: LocalInferenceQueue(),
        device: device,
      );
      final store = SpeechModelsStore(streamingService, device);
      await store.load('en');
      final first = store.downloadOne(multilingual.id);
      final second = store.downloadOne(english.id);
      await Future<void>.delayed(Duration.zero);
      expect(store.states[english.id], SpeechDownloadState.queued);
      store.cancelDownload(english.id);
      expect(store.states[english.id], SpeechDownloadState.cancelled);
      await second;
      stream.add(payload);
      await stream.close();
      await first;
      expect(store.ready(multilingual.id), isTrue);
      expect(store.ready(english.id), isFalse);
    },
  );

  test(
    'a complete partial download verifies without another transfer',
    () async {
      final directory = Directory('${root.path}/speech_models');
      await directory.create();
      await File('${directory.path}/multi.bin.part').writeAsBytes(payload);
      device.free = 1;
      final store = SpeechModelsStore(service, device);
      await store.load('pt');
      await store.downloadOne(multilingual.id);
      expect(store.ready(multilingual.id), isTrue);
      expect(store.activeId, multilingual.id);
    },
  );

  test(
    'an English-only download stays installed but is never activated for Portuguese',
    () async {
      final store = SpeechModelsStore(service, device);
      await store.load('pt');
      await store.downloadOne(english.id);
      expect(store.ready(english.id), isTrue);
      expect(store.activeId, isNot(english.id));
      expect(store.activeReady, isFalse);
      expect(await store.activate(english.id), isFalse);
      expect(store.activeId, isNot(english.id));
    },
  );
}
