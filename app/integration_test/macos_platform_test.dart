import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_vec/sqlite3_vec.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';

/// Verifies the platform-hosted dependencies under the real macOS runtime: the
/// bundled sqlite-vec native asset and the injected local embedding model.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(configureDependencies);
  tearDownAll(() async => getIt.reset());

  testWidgets('bundled sqlite-vec loads in the app container', (tester) async {
    loadSqliteVec();
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(
      directory.path,
      'integration_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    final db = sqlite3.open(path);
    addTearDown(() {
      db.close();
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    });
    expect(
      db.select('SELECT vec_version() AS v').single['v'],
      startsWith('v0.1.9'),
    );
    db.execute(
      'CREATE VIRTUAL TABLE items USING vec0(embedding float[2] distance_metric=cosine)',
    );
  });

  testWidgets('local embedding model is registered on macOS', (tester) async {
    expect(
      getIt<IEmbeddingModelService>().model.id,
      'qwen3-embedding-0.6b-q8_0',
    );
  });
}
