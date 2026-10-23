import 'dart:typed_data';
import 'dart:async';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:diacritic/diacritic.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';
import 'package:smartnotes/domain/entities/search_index_status.dart';
import 'package:smartnotes/domain/entities/search_result.dart';
import 'package:smartnotes/domain/entities/search_options.dart';
export 'package:smartnotes/domain/entities/search_options.dart';
export 'package:smartnotes/domain/entities/search_result.dart';
import 'package:smartnotes/domain/services/i_entry_search_service.dart';
import 'package:smartnotes/domain/services/i_journal_archive_service.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/data/services/formatting_model_service.dart';
import 'package:smartnotes/data/services/speech_model_service.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/services/i_formatting_model_service.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';

class MemoryDeviceProfile extends DeviceProfileService {
  @override
  Future<DeviceProfile> read() async => const DeviceProfile();
  @override
  Future<int?> freeStorage() async => null;
}

class MemoryFormattingModels implements IFormattingModelService {
  @override
  Future<ModelCheckState> readiness({
    String? modelId,
    bool verify = false,
  }) async {
    if (!verify && isReadyGate != null) return ModelCheckState.unchecked;
    return await isReady(modelId)
        ? ModelCheckState.ready
        : ModelCheckState.missing;
  }

  MemoryFormattingModels({bool ready = true, String? activeId}) {
    if (ready) {
      _active = activeId ?? FormattingModel.qwen3_1_7b.id;
      _installed.add(_active);
      _configured = _active;
    } else {
      _active = activeId ?? '';
    }
  }
  final _installed = <String>{};
  String _active = '';
  String? _configured;
  Completer<bool>? isReadyGate;

  bool get ready => _active.isNotEmpty && _installed.contains(_active);
  set ready(bool value) {
    if (value) {
      _active = FormattingModel.qwen3_1_7b.id;
      _installed.add(_active);
      _configured = _active;
    } else {
      _installed.clear();
      _configured = null;
      _active = '';
    }
  }

  @override
  List<FormattingModel> get catalog => FormattingModel.catalog;

  @override
  String? get configuredModelId => _configured;

  @override
  String get activeModelId => _active;

  @override
  FormattingModel? get activeModel => FormattingModel.find(_active);

  @override
  Future<bool> isReady([String? modelId]) async {
    if (isReadyGate != null) return isReadyGate!.future;
    final id = modelId ?? _active;
    return id.isNotEmpty && _installed.contains(id);
  }

  @override
  Future<bool> isPresent(String modelId) async => _installed.contains(modelId);

  @override
  Future<int> storedBytes(String modelId, {bool partial = false}) async =>
      !partial && _installed.contains(modelId)
      ? FormattingModel.find(modelId)!.bytes
      : 0;

  @override
  Future<void> activate(String modelId) async {
    final item = FormattingModel.find(modelId);
    if (item == null || !_installed.contains(modelId)) {
      throw const FormattingModelException(FormattingModelProblem.notReady);
    }
    _active = modelId;
    _configured = modelId;
  }

  @override
  Future<void> remove(String modelId) async {
    if (modelId == _active) {
      throw const FormattingModelException(FormattingModelProblem.inUse);
    }
    _installed.remove(modelId);
  }

  @override
  Future<String> requireModelPath() async {
    if (!await isReady()) {
      throw const FormattingModelException(FormattingModelProblem.notReady);
    }
    return '/models/${activeModel!.fileName}';
  }

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    final id = modelId ?? _active;
    final item = FormattingModel.find(id);
    if (item == null) throw ArgumentError.value(id);
    _installed.add(id);
    onProgress(item.bytes, item.bytes);
  }

  @override
  void cancelDownload() {}
}

class MemorySpeechModels implements ISpeechModelService {
  @override
  Future<ModelCheckState> readiness({
    String? modelId,
    bool verify = false,
  }) async =>
      await isReady(modelId) ? ModelCheckState.ready : ModelCheckState.missing;
  MemorySpeechModels({bool ready = true, this.settings}) {
    if (ready) _installed.add(_active);
  }
  final ISettingsService? settings;
  String _active = SpeechModel.whisperBaseQ8.id;
  String? _configured;
  final _installed = <String>{};

  bool get ready => _installed.contains(_active);
  set ready(bool value) {
    if (value) {
      _installed.add(_active);
    } else {
      _installed.clear();
    }
  }

  @override
  List<SpeechModel> get catalog => SpeechModel.catalog;
  @override
  String? get configuredModelId => _configured;
  @override
  String get activeModelId => _active;
  @override
  SpeechModel get model => SpeechModel.find(_active)!;
  @override
  Future<bool> isReady([String? modelId]) async =>
      _installed.contains(modelId ?? _active);
  @override
  Future<bool> isPresent(String modelId) async => _installed.contains(modelId);
  @override
  Future<int> storedBytes(String modelId, {bool partial = false}) async =>
      !partial && _installed.contains(modelId)
      ? SpeechModel.find(modelId)!.bytes
      : 0;
  @override
  Future<void> activate(String modelId, {required String? language}) async {
    final item = SpeechModel.find(modelId);
    if (item == null || !item.supports(language)) {
      throw const SpeechModelException(SpeechModelProblem.incompatible);
    }
    if (!_installed.contains(modelId)) {
      throw const SpeechModelException(SpeechModelProblem.notReady);
    }
    _active = modelId;
    _configured = modelId;
    await settings?.setSpeechConfiguration(modelId, language);
  }

  @override
  Future<void> remove(String modelId) async {
    if (modelId == _active) {
      throw const SpeechModelException(SpeechModelProblem.inUse);
    }
    _installed.remove(modelId);
  }

  @override
  Future<String> requireModelPath() async {
    if (!ready) throw StateError('Model not ready');
    return '/models/${model.fileName}';
  }

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    final id = modelId ?? _active;
    final item = SpeechModel.find(id)!;
    _installed.add(id);
    onProgress(item.bytes, item.bytes);
  }

  @override
  void cancelDownload() {}
}

class MemoryEmbeddingModels implements IEmbeddingModelService {
  @override
  Future<ModelCheckState> readiness({
    String? modelId,
    bool verify = false,
  }) async =>
      await isReady(modelId) ? ModelCheckState.ready : ModelCheckState.missing;
  MemoryEmbeddingModels({this.ready = true});
  bool ready;
  final readinessEvents = StreamController<bool>.broadcast();
  @override
  Stream<bool> get readinessChanges => readinessEvents.stream;
  @override
  LocalAiModel get model => LocalAiModel.qwenEmbedding;
  @override
  List<LocalAiModel> get catalog => [model];
  @override
  Future<bool> isReady([String? modelId]) async =>
      (modelId == null || modelId == model.id) && ready;
  @override
  Future<String> requireModelPath() async {
    if (!ready) throw StateError('Embedding model not ready');
    return '/models/${model.fileName}';
  }

  @override
  Future<void> download({
    String? modelId,
    required void Function(int, int) onProgress,
  }) async {
    if (modelId != null && modelId != model.id) {
      throw ArgumentError.value(modelId);
    }
    onProgress(model.bytes, model.bytes);
    ready = true;
    readinessEvents.add(true);
  }

  @override
  void cancelDownload() {}
}

SearchResult searchResult(JournalEntry entry) => SearchResult(
  entry: entry,
  excerpt: entry.body,
  sources: {SearchSource.note},
  score: 0,
);

class MemorySearch implements IEntrySearchService {
  @override
  void cancelTextSearch() {}
  @override
  Stream<SearchIndexStatus> watchIndexStatus() =>
      Stream.value(const SearchIndexStatus());
  MemorySearch([this.entries]);
  final List<JournalEntry> Function()? entries;
  @override
  Future<List<SearchResult>> searchText(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) async => (entries?.call() ?? [])
      .where((entry) {
        final text = removeDiacritics(
          '${entry.title} ${entry.formattedNote} ${entry.transcription}',
        ).toLowerCase();
        return text.contains(removeDiacritics(query).toLowerCase());
      })
      .skip(options.offset)
      .take(options.limit)
      .map(searchResult)
      .toList();
  @override
  Future<List<SearchResult>> searchSemantic(
    String query, {
    bool Function()? isCancelled,
    SearchOptions options = const SearchOptions(),
  }) => searchText(query, options: options);
  @override
  Future<void> indexPending({bool retryFailures = false}) async {}
  @override
  Future<void> rebuild() async {}
}

class MemoryArchive implements IJournalArchiveService {
  @override
  Future<Uint8List> export({void Function(double)? onProgress}) async =>
      Uint8List(0);
  @override
  Future<int> import(
    Uint8List bytes, {
    void Function(double)? onProgress,
  }) async => 0;
}
