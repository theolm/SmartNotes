import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_vec/sqlite3_vec.dart';

void main() {
  test('bundled sqlite-vec supports cosine KNN and FTS5', () {
    loadSqliteVec();
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    expect(
      db.select('SELECT vec_version() AS version').single['version'],
      startsWith('v0.1.9'),
    );
    db.execute(
      'CREATE VIRTUAL TABLE vectors USING vec0('
      'embedding float[3] distance_metric=cosine)',
    );
    db.execute('INSERT INTO vectors(rowid, embedding) VALUES (1, ?)', [
      Float32List.fromList([1, 0, 0]).buffer.asUint8List(),
    ]);
    expect(
      db.select('SELECT rowid FROM vectors WHERE embedding MATCH ? AND k = 1', [
        Float32List.fromList([1, 0, 0]).buffer.asUint8List(),
      ]).single['rowid'],
      1,
    );
    db.execute('CREATE VIRTUAL TABLE words USING fts5(content)');
    db.execute("INSERT INTO words VALUES ('private journal')");
    expect(
      db.select("SELECT * FROM words WHERE words MATCH 'journal'"),
      hasLength(1),
    );
  });
}
