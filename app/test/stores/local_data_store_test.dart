import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/application/journal_lifecycle.dart';
import 'package:smartnotes/presentation/screens/settings/local_data_store.dart';
import '../helpers/local_services.dart';

class MockJournalLifecycle extends Mock implements JournalLifecycle {}

class _CheckingEmbeddings extends MemoryEmbeddingModels {
  final gate = Completer<ModelCheckState>();
  @override
  Future<ModelCheckState> readiness({String? modelId, bool verify = false}) =>
      gate.future;
}

class CountingSearch extends MemorySearch {
  int calls = 0;
  bool retried = false;
  @override
  Future<void> indexPending({bool retryFailures = false}) async {
    calls++;
    retried = retryFailures;
  }
}

void main() {
  test(
    'checking is not missing and does not disable independent archive actions',
    () async {
      final models = _CheckingEmbeddings();
      final store = LocalDataStore(
        MemorySearch(),
        MemoryArchive(),
        models,
        MockJournalLifecycle(),
      );
      addTearDown(store.dispose);
      addTearDown(models.readinessEvents.close);
      final loading = store.load();
      await pumpEventQueue();
      expect(store.modelChecking, true);
      expect(store.modelCheckFailed, false);
      expect(store.isBusy, false);
      expect(await store.exportJournal(), isNotNull);
      expect(await store.indexNotes(), false);
      models.gate.complete(ModelCheckState.ready);
      await loading;
      expect(store.modelChecking, false);
      expect(store.modelReady, true);
    },
  );
  test(
    'failed check can be retried without marking the artifact missing',
    () async {
      final models = _CheckingEmbeddings();
      final store = LocalDataStore(
        MemorySearch(),
        MemoryArchive(),
        models,
        MockJournalLifecycle(),
      );
      addTearDown(store.dispose);
      addTearDown(models.readinessEvents.close);
      models.gate.complete(ModelCheckState.failed);
      await store.load();
      expect(store.modelChecking, false);
      expect(store.modelCheckFailed, true);
      expect(store.modelReady, false);
    },
  );
  test('loads local model and index status without credentials', () async {
    final search = CountingSearch();
    final store = LocalDataStore(
      search,
      MemoryArchive(),
      MemoryEmbeddingModels(),
      MockJournalLifecycle(),
    );
    addTearDown(store.dispose);
    await store.load();
    await store.load();
    expect(search.calls, 0);
    expect(store.modelReady, true);
    expect(store.error, isNull);
    expect(await store.indexNotes(), true);
    expect(search.calls, 1);
    expect(search.retried, true);
  });
  test('reports missing local model', () async {
    final store = LocalDataStore(
      MemorySearch(),
      MemoryArchive(),
      MemoryEmbeddingModels(ready: false),
      MockJournalLifecycle(),
    );
    addTearDown(store.dispose);
    await store.load();
    expect(store.modelReady, false);
  });

  test('recording retry delegates an explicit application command', () async {
    final lifecycle = MockJournalLifecycle();
    when(() => lifecycle.retryRecordings()).thenAnswer((_) async {});
    final store = LocalDataStore(
      MemorySearch(),
      MemoryArchive(),
      MemoryEmbeddingModels(),
      lifecycle,
    );
    addTearDown(store.dispose);
    await store.retryRecordings();
    verify(() => lifecycle.retryRecordings()).called(1);
  });
}
