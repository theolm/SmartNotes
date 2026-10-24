import 'dart:async';
import 'package:smartnotes/domain/entities/entry_write_failure.dart';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_vec/sqlite3_vec.dart';

import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/entities/embedding_pipeline.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';
import 'package:smartnotes/domain/entities/search_index_status.dart';
import 'package:smartnotes/domain/entities/search_result.dart';
import 'package:smartnotes/domain/entities/search_options.dart';

/// Owns one SQLite connection on a worker isolate. No SQL runs on the UI isolate.
@singleton
class LocalDatabase {
  LocalDatabase();
  LocalDatabase.forTesting({required List<EmbeddingModel> embeddingCatalog})
    // Keep the fixture argument public and the runtime registry private.
    // ignore: prefer_initializing_formals
    : _embeddingCatalog = embeddingCatalog;
  List<EmbeddingModel> _embeddingCatalog = EmbeddingModel.catalog;

  SendPort? _worker;
  Future<void>? _opening;
  Isolate? _isolate;
  String? _path;
  Future<void>? _maintenance;
  final _maintenanceChanges = StreamController<double?>.broadcast();
  double? _maintenanceProgress;
  Stream<double?> watchSearchMaintenance() => Stream.multi((controller) {
    final subscription = _maintenanceChanges.stream.listen(
      controller.addSync,
      onDone: controller.closeSync,
    );
    controller.addSync(_maintenanceProgress);
    controller.onCancel = subscription.cancel;
  });
  String get path {
    if (_path == null) throw StateError('The local journal is not open.');
    return _path!;
  }

  final _changes = StreamController<void>.broadcast();
  final _entryChanges = StreamController<String?>.broadcast();

  /// An ID for ordinary writes; null requests full reconciliation after import.
  Stream<String?> get entryChanges => _entryChanges.stream;
  final _indexChanges = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  /// In-process fence for cooperative cancellation of derived indexing work.
  int get contentRevision => _contentRevision;
  int _contentRevision = 0;

  static const embeddingModel = EmbeddingPipeline.id;
  static const embeddingDimensions = EmbeddingPipeline.dimensions;

  EmbeddingModel _embeddingProfile = EmbeddingModel.qwen;
  EmbeddingModel get embeddingProfile => _embeddingProfile;

  /// The database is the durable authority for both selection and index identity.
  /// One transaction prevents a crash from pairing new weights with old vectors.
  Future<void> selectEmbeddingModel(EmbeddingModel model) async {
    final selected = _embeddingCatalog.firstWhere((m) => m.id == model.id);
    await _request('selectEmbeddingModel', selected.id);
    _embeddingProfile = selected;
  }

  Stream<SearchIndexStatus> watchIndexStatus() {
    late StreamController<SearchIndexStatus> controller;
    StreamSubscription<void>? subscription;
    var cancelled = false;
    Timer? timer;
    var running = false;
    var dirty = false;
    Future<void> emit() async {
      if (running || cancelled) return;
      running = true;
      dirty = false;
      try {
        final status = await indexStatus();
        if (!cancelled && !controller.isClosed) controller.add(status);
      } catch (error, stack) {
        if (!cancelled && !controller.isClosed) {
          controller.addError(error, stack);
        }
      } finally {
        running = false;
        if (dirty && !cancelled) {
          timer ??= Timer(const Duration(milliseconds: 100), () {
            timer = null;
            unawaited(emit());
          });
        }
      }
    }

    controller = StreamController<SearchIndexStatus>(
      onListen: () {
        // Subscribe before the initial query so no update is missed.
        subscription = _indexChanges.stream.listen(
          (_) {
            dirty = true;
            if (!running) {
              timer ??= Timer(const Duration(milliseconds: 100), () {
                timer = null;
                unawaited(emit());
              });
            }
          },
          onDone: () {
            timer?.cancel();
            unawaited(controller.close());
          },
        );
        unawaited(emit());
      },
      onCancel: () async {
        cancelled = true;
        timer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<SearchIndexStatus> indexStatus() async {
    final values = (await _request('indexStatus') as List).cast<int>();
    return SearchIndexStatus(
      indexed: values[0],
      pending: values[1],
      failed: values[2],
      generation: values[3],
    );
  }

  Future<int> indexGeneration() async =>
      await _request('indexGeneration') as int;

  Future<void> open({String? path}) {
    return _opening ??= _open(path);
  }

  Future<void> _open(String? path) async {
    final databasePath =
        path ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'smartnotes.sqlite',
        );
    final ready = ReceivePort();
    _isolate = await Isolate.spawn(_databaseWorker, [
      databasePath,
      ready.sendPort,
      _embeddingCatalog,
    ]);
    final result = await ready.first as List;
    ready.close();
    if (result[0] != true) {
      _isolate?.kill();
      _opening = null;
      throw StateError('Could not open the local journal: ${result[1]}');
    }
    _worker = result[1] as SendPort;
    _embeddingProfile = _embeddingCatalog.firstWhere((m) => m.id == result[2]);
    _path = databasePath;
    // Hash maintenance is resumable and does not delay the first journal read.
    _maintenance =
        _request('migrateHashes', null, (value) {
              _maintenanceProgress = value;
              _maintenanceChanges.add(value);
            })
            .then((changed) {
              if (changed == true) {
                _changes.add(null);
                _entryChanges.add(null);
                _indexChanges.add(null);
              }
            })
            .catchError((Object _) {
              // The durable migration marker is retried on next launch. Never expose
              // an unhandled background exception (or journal data) to the UI logger.
            })
            .whenComplete(() {
              _maintenanceProgress = null;
              _maintenanceChanges.add(null);
            });
  }

  Future<dynamic> _request(
    String operation, [
    dynamic arguments,
    void Function(double)? onProgress,
  ]) async {
    await open();
    final response = ReceivePort();
    _worker!.send([operation, arguments, response.sendPort]);
    final result = await response.cast<List<dynamic>>().firstWhere((message) {
      if (message[0] == null) {
        try {
          onProgress?.call(message[1] as double);
        } catch (_) {
          // A progress listener cannot change the outcome of an atomic write.
        }
        return false;
      }
      return true;
    });
    response.close();
    if (result[0] != true) {
      if (result.length > 2 && result[2] != null) {
        throw EntryWriteFailure(
          EntryWriteFailureKind.values.byName(result[2] as String),
        );
      }
      throw StateError(result[1] as String);
    }
    if (operation == 'selectEmbeddingModel' && result[1] != true) {
      return result[1];
    }
    if (operation == 'save' ||
        operation == 'create' ||
        operation == 'createExclusive' ||
        operation == 'delete' ||
        operation == 'import') {
      _changes.add(null);
      _entryChanges.add(switch (operation) {
        'save' => (arguments as Map)['entry']['id'] as String,
        'create' => (arguments as Map)['id'] as String,
        'createExclusive' => (arguments as Map)['id'] as String,
        'delete' => arguments as String,
        _ => null,
      });
      _contentRevision++;
    }
    if (operation == 'resetIndex' || operation == 'selectEmbeddingModel') {
      _contentRevision++;
    }
    if ([
      'save',
      'create',
      'createExclusive',
      'delete',
      'import',
      'index',
      'indexFailed',
      'resetIndex',
      'selectEmbeddingModel',
      'retryIndexFailures',
    ].contains(operation)) {
      _indexChanges.add(null);
    }
    return result[1];
  }

  Future<List<JournalEntry>> all() async => _decode(await _request('all'));

  Future<JournalEntry?> entry(String id) async {
    final json = await _request('get', id);
    return json == null
        ? null
        : JournalEntry.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> insertEntry(
    JournalEntry entry, {
    bool exclusive = false,
  }) async =>
      _request(exclusive ? 'createExclusive' : 'create', entry.toJson());
  Future<void> updateEntry(
    JournalEntry entry, {
    JournalEntry? expected,
  }) async => _request('save', {
    'entry': entry.toJson(),
    'expected': expected?.toJson(),
  });
  Future<void> deleteEntry(String id) async => _request('delete', id);
  Future<void> importEntries(List<JournalEntry> entries) async =>
      _request('import', entries.map((entry) => entry.toJson()).toList());
  Future<void> importJsonEntries(
    List<Map<String, dynamic>> entries, {
    void Function(double)? onProgress,
  }) async {
    await _request('import', entries, onProgress);
    try {
      onProgress?.call(1.0);
    } catch (_) {
      // The import is already committed.
    }
  }

  Future<List<JournalEntry>> pendingEntries({
    bool retryFailures = false,
    int? limit,
  }) async => _decode(
    await _request('pending', {'retryFailures': retryFailures, 'limit': limit}),
  );
  Future<void> retryIndexFailures({required int generation}) async =>
      _request('retryIndexFailures', generation);
  Future<void> indexEntry(
    JournalEntry entry,
    List<List<double>> vectors, {
    required int generation,
    List<({String text, int start})> passages = const [],
  }) async => _request('index', {
    'id': entry.id,
    'source': entry.toJson(),
    'vectors': vectors,
    'passages': [
      for (final p in passages) {'text': p.text, 'start': p.start},
    ],
    'generation': generation,
  });
  Future<void> markIndexFailed(
    JournalEntry entry, {
    required int generation,
  }) async => _request('indexFailed', {
    'id': entry.id,
    'source': entry.toJson(),
    'generation': generation,
  });
  Future<void> resetIndex() async => _request('resetIndex');

  static List<JournalEntry> _decode(dynamic rows) => (rows as List)
      .map(
        (json) => JournalEntry.fromJson(Map<String, dynamic>.from(json as Map)),
      )
      .toList();

  int _textRevision = 0;
  void cancelTextSearch() {
    final revision = ++_textRevision;
    _worker?.send(['cancelText', revision, null]);
  }

  Future<List<SearchResult>> searchText(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) async {
    final revision = ++_textRevision;
    await open();
    if (revision != _textRevision) return [];
    final rows = await _request('text', {
      'query': query,
      'revision': revision,
      ...options.toMap(),
    });
    // Ignore superseded work at the database boundary, before UI decoding.
    if (revision != _textRevision) return [];
    return (rows as List)
        .map((row) => SearchResult.fromRow(row as Map))
        .toList();
  }

  Future<List<SearchResult>> searchVector(
    List<double> vector, {
    SearchOptions options = const SearchOptions(),
    int? generation,
  }) async =>
      ((await _request('vector', {
                'vector': vector,
                'generation': generation,
                ...options.toMap(),
              }))
              as List)
          .map((row) => SearchResult.fromRow(row as Map))
          .toList();

  Future<void> close() async {
    await _maintenance;
    if (_worker != null) await _request('close');
    _worker = null;
    _isolate?.kill();
    _isolate = null;
    _opening = null;
    await _changes.close();
    await _entryChanges.close();
    await _indexChanges.close();
    await _maintenanceChanges.close();
  }
}

String _source(Map<String, dynamic> entry) {
  final original = (entry['transcription'] as String?)?.trim() ?? '';
  final body =
      ((entry['formattedNote'] ?? entry['transcription']) as String?)?.trim() ??
      '';
  return [
        entry['title'],
        body,
        if (original != body) original,
      ]
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join('\n\n');
}

String _hash(Map<String, dynamic> entry) =>
    sha256.convert(utf8.encode(_source(entry))).toString();

void _databaseWorker(List<dynamic> startup) {
  final catalog = startup[2] as List<EmbeddingModel>;
  EmbeddingModel? findModel(String id) {
    for (final model in catalog) {
      if (model.id == id) return model;
    }
    return null;
  }

  var embeddingProfile = EmbeddingModel.qwen;
  final databasePath = startup[0] as String;
  final ready = startup[1] as SendPort;
  final commands = ReceivePort();
  late Database db;
  var databaseOpened = false;
  try {
    loadSqliteVec();
    db = sqlite3.open(databasePath);
    databaseOpened = true;
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA busy_timeout = 5000');
    final version = db.select('PRAGMA user_version').single.values.first as int;
    if (version > 3) {
      throw StateError('This journal needs a newer app version.');
    }
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute('''CREATE TABLE IF NOT EXISTS embedding_selection (
        singleton INTEGER PRIMARY KEY CHECK(singleton = 1), model_id TEXT NOT NULL
      )''');
      final selection = db.select('SELECT model_id FROM embedding_selection');
      if (selection.isNotEmpty) {
        final selected = findModel(selection.single['model_id'] as String);
        if (selected == null) throw StateError('Unsupported search model.');
        embeddingProfile = selected;
      } else {
        db.execute('INSERT INTO embedding_selection VALUES (1, ?)', [
          embeddingProfile.id,
        ]);
      }
      db.execute('''
      CREATE TABLE IF NOT EXISTS entries (
        id TEXT PRIMARY KEY, entry_date TEXT NOT NULL,
        json TEXT NOT NULL, source_hash TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS entries_date ON entries(entry_date DESC);
      CREATE VIRTUAL TABLE IF NOT EXISTS entry_fts USING fts5(
        id UNINDEXED, title, note, transcription,
        tokenize='unicode61 remove_diacritics 2'
      );
      CREATE TABLE IF NOT EXISTS indexed_entries (
        id TEXT PRIMARY KEY REFERENCES entries(id) ON DELETE CASCADE,
        source_hash TEXT NOT NULL, model TEXT NOT NULL, dimensions INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE
      );
      CREATE INDEX IF NOT EXISTS chunks_entry ON chunks(entry_id);
      CREATE TABLE IF NOT EXISTS chunk_passages (
        chunk_id INTEGER PRIMARY KEY REFERENCES chunks(id) ON DELETE CASCADE,
        text TEXT NOT NULL, start INTEGER NOT NULL, end INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS failed_index_entries (
        id TEXT PRIMARY KEY REFERENCES entries(id) ON DELETE CASCADE,
        source_hash TEXT NOT NULL
      );
      CREATE VIRTUAL TABLE IF NOT EXISTS entry_vectors USING vec0(
        embedding float[${embeddingProfile.dimensions}] distance_metric=cosine
      );
      CREATE TABLE IF NOT EXISTS embedding_pipeline (
        singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
        identity TEXT NOT NULL, generation INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS source_hash_migration (
        id TEXT PRIMARY KEY REFERENCES entries(id) ON DELETE CASCADE
      );
    ''');
      final pipeline = db.select(
        'SELECT identity FROM embedding_pipeline WHERE singleton = 1',
      );
      if (pipeline.isEmpty ||
          pipeline.single['identity'] != embeddingProfile.pipelineId) {
        db.execute('DROP TABLE entry_vectors');
        db.execute(
          'CREATE VIRTUAL TABLE entry_vectors USING vec0(embedding float[${embeddingProfile.dimensions}] distance_metric=cosine)',
        );
        db.execute('DELETE FROM chunks');
        db.execute('DELETE FROM indexed_entries');
        db.execute('DELETE FROM failed_index_entries');
        db.execute(
          '''INSERT INTO embedding_pipeline VALUES (1, ?, 1)
          ON CONFLICT(singleton) DO UPDATE SET identity=excluded.identity, generation=generation+1''',
          [embeddingProfile.pipelineId],
        );
        // Invalidate vectors atomically, then repair hashes in short batches.
        // Persist IDs so an interrupted upgrade resumes safely on next launch.
        db.execute(
          'INSERT OR IGNORE INTO source_hash_migration SELECT id FROM entries',
        );
      }
      db.execute('PRAGMA user_version = 3');
      // Staging is never journal data; discard an interrupted unpublished import.
      db.execute('DROP TABLE IF EXISTS import_staging');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    ready.send([true, commands.sendPort, embeddingProfile.id]);
  } catch (error) {
    if (databaseOpened) db.close();
    ready.send([false, 'Local journal storage is unavailable.']);
    commands.close();
    return;
  }

  void transaction(void Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      action();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void removeVectors(String id) {
    for (final row in db.select('SELECT id FROM chunks WHERE entry_id = ?', [
      id,
    ])) {
      db.execute('DELETE FROM entry_vectors WHERE rowid = ?', [row['id']]);
    }
    db.execute('DELETE FROM chunks WHERE entry_id = ?', [id]);
    db.execute('DELETE FROM indexed_entries WHERE id = ?', [id]);
    db.execute('DELETE FROM failed_index_entries WHERE id = ?', [id]);
  }

  void save(Map<String, dynamic> entry) {
    final id = entry['id'] as String;
    if (id.isEmpty) throw StateError('Invalid entry ID.');
    final hash = _hash(entry);
    final old = db.select('SELECT source_hash FROM entries WHERE id = ?', [id]);
    if (old.isNotEmpty && old.single['source_hash'] != hash) removeVectors(id);
    db.execute(
      '''INSERT INTO entries(id, entry_date, json, source_hash)
      VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET
      entry_date=excluded.entry_date, json=excluded.json, source_hash=excluded.source_hash''',
      [
        id,
        DateTime.parse(
          (entry['entryDate'] ?? entry['createdAt']) as String,
        ).toUtc().toIso8601String(),
        jsonEncode(entry),
        hash,
      ],
    );
    db.execute('DELETE FROM entry_fts WHERE id = ?', [id]);
    db.execute(
      'INSERT INTO entry_fts(id, title, note, transcription) VALUES (?, ?, ?, ?)',
      [
        id,
        entry['title'] ?? '',
        entry['formattedNote'] ?? '',
        entry['transcription'] ?? '',
      ],
    );
    db.execute('DELETE FROM source_hash_migration WHERE id = ?', [id]);
  }

  List<dynamic> decode(ResultSet rows) =>
      rows.map((r) => jsonDecode(r['json'] as String)).toList();

  List<dynamic> decodeSearch(ResultSet rows) => [
    for (final row in rows)
      {...row, 'entry': jsonDecode(row['json'] as String)}..remove('json'),
  ];

  var migrating = false;
  var importing = false;
  Future<void>? publishing;
  var textRevision = 0;
  commands.listen((dynamic message) async {
    final request = message as List;
    final op = request[0] as String;
    final arg = request[1];
    if (op == 'cancelText') {
      if ((arg as int) > textRevision) textRevision = arg;
      return;
    }
    final reply = request[2] as SendPort;
    try {
      // The publisher uses a separate WAL connection. Queue competing writes
      // cooperatively instead of blocking this read worker on SQLite's mutex.
      if (publishing != null &&
          const {
            'save',
            'create',
            'createExclusive',
            'delete',
            'import',
            'index',
            'indexFailed',
            'resetIndex',
            'selectEmbeddingModel',
            'retryIndexFailures',
          }.contains(op)) {
        await publishing!.catchError((Object _) {});
      }
      dynamic result;
      switch (op) {
        case 'migrateHashes':
          if (migrating) break;
          migrating = true;
          result = false;
          try {
            final total =
                db
                        .select(
                          'SELECT COUNT(*) AS n FROM source_hash_migration',
                        )
                        .single['n']
                    as int;
            var completed = 0;
            final progressWatch = Stopwatch()..start();
            if (total > 0) reply.send([null, 0.0]);
            while (true) {
              if (publishing != null) {
                await publishing!.catchError((Object _) {});
              }
              final rows = db.select('''SELECT e.id, e.json FROM entries e
                JOIN source_hash_migration m ON m.id=e.id LIMIT 25''');
              if (rows.isEmpty) break;
              result = true;
              transaction(() {
                for (final row in rows) {
                  final entry =
                      jsonDecode(row['json'] as String) as Map<String, dynamic>;
                  db.execute('UPDATE entries SET source_hash=? WHERE id=?', [
                    _hash(entry),
                    row['id'],
                  ]);
                  db.execute('DELETE FROM source_hash_migration WHERE id=?', [
                    row['id'],
                  ]);
                }
              });
              completed += rows.length;
              if (progressWatch.elapsedMilliseconds >= 100) {
                reply.send([null, (completed / total).clamp(0.0, 1.0)]);
                progressWatch.reset();
              }
              await Future<void>.delayed(Duration.zero);
            }
          } finally {
            migrating = false;
          }
        case 'indexGeneration':
          result = db
              .select('SELECT generation FROM embedding_pipeline')
              .single['generation'];
        case 'indexStatus':
          final rows = db.select('''SELECT
            SUM(CASE WHEN i.id IS NOT NULL THEN 1 ELSE 0 END) AS indexed,
            SUM(CASE WHEN i.id IS NULL AND f.id IS NULL THEN 1 ELSE 0 END) AS pending,
            SUM(CASE WHEN i.id IS NULL AND f.id IS NOT NULL THEN 1 ELSE 0 END) AS failed
            FROM entries e
            LEFT JOIN indexed_entries i ON i.id=e.id AND i.source_hash=e.source_hash
            LEFT JOIN failed_index_entries f ON f.id=e.id AND f.source_hash=e.source_hash
            WHERE json_extract(e.json, '\$.status') = 'completed' ''').single;
          result = [
            rows['indexed'] ?? 0,
            rows['pending'] ?? 0,
            rows['failed'] ?? 0,
            db
                .select('SELECT generation FROM embedding_pipeline')
                .single['generation'],
          ];
        case 'all':
          result = decode(
            db.select('SELECT json FROM entries ORDER BY entry_date DESC, id'),
          );
        case 'get':
          final rows = db.select('SELECT json FROM entries WHERE id = ?', [
            arg,
          ]);
          result = rows.isEmpty
              ? null
              : jsonDecode(rows.single['json'] as String);
        case 'save':
          final data = arg as Map;
          final json = Map<String, dynamic>.from(data['entry'] as Map);
          final rows = db.select('SELECT json FROM entries WHERE id = ?', [
            json['id'],
          ]);
          if (rows.isEmpty) {
            throw EntryWriteFailure(EntryWriteFailureKind.deleted);
          }
          if (data['expected'] != null &&
              rows.single['json'] != jsonEncode(data['expected'])) {
            throw EntryWriteFailure(EntryWriteFailureKind.changed);
          }
          transaction(() => save(json));
        case 'create':
          transaction(() => save(Map<String, dynamic>.from(arg as Map)));
        case 'createExclusive':
          transaction(() {
            final json = Map<String, dynamic>.from(arg as Map);
            if (db.select('SELECT id FROM entries WHERE id = ?', [
              json['id'],
            ]).isNotEmpty) {
              throw EntryWriteFailure(EntryWriteFailureKind.changed);
            }
            save(json);
          });
        case 'delete':
          transaction(() {
            removeVectors(arg as String);
            db.execute('DELETE FROM entry_fts WHERE id = ?', [arg]);
            db.execute('DELETE FROM entries WHERE id = ?', [arg]);
          });
        case 'import':
          if (importing) throw StateError('An import is already running.');
          importing = true;
          try {
            db.execute('''CREATE TABLE import_staging (
              id TEXT PRIMARY KEY, entry_date TEXT NOT NULL,
              json TEXT NOT NULL, source_hash TEXT NOT NULL)''');
            final entries = arg as List;
            final progressWatch = Stopwatch()..start();
            for (var start = 0; start < entries.length; start += 25) {
              final end = (start + 25).clamp(0, entries.length);
              transaction(() {
                for (var i = start; i < end; i++) {
                  final entry = Map<String, dynamic>.from(entries[i] as Map);
                  final id = entry['id'] as String;
                  if (id.isEmpty) throw StateError('Invalid entry ID.');
                  db.execute('INSERT INTO import_staging VALUES (?, ?, ?, ?)', [
                    id,
                    DateTime.parse(
                      (entry['entryDate'] ?? entry['createdAt']) as String,
                    ).toUtc().toIso8601String(),
                    jsonEncode(entry),
                    _hash(entry),
                  ]);
                }
              });
              if (start == 0 ||
                  end == entries.length ||
                  progressWatch.elapsedMilliseconds >= 100) {
                reply.send([null, end / entries.length * 0.9]);
                progressWatch.reset();
              }
              await Future<void>.delayed(Duration.zero);
            }
            // Atomic publication must not monopolize this isolate either.
            // WAL readers retain the old journal until the publisher commits.
            publishing = _publishImportInBackground(databasePath);
            await publishing;
          } finally {
            publishing = null;
            db.execute('DROP TABLE IF EXISTS import_staging');
            importing = false;
          }
        case 'text':
          final data = arg as Map;
          final revision = data['revision'] as int;
          result = <dynamic>[];
          if (revision < textRevision) break;
          textRevision = revision;
          // Drain newer input/cancellation messages before starting SQLite FTS.
          await Future<void>.delayed(Duration.zero);
          if (revision != textRevision) break;
          final words =
              RegExp(
                    r'[\p{L}\p{N}]+',
                    unicode: true,
                  )
                  .allMatches(data['query'] as String)
                  .map((m) => '"${m[0]}"*')
                  .toList();
          result = words.isEmpty
              ? <dynamic>[]
              : decodeSearch(
                  db.select(
                    '''
            SELECT e.json, f.rank AS score,
              snippet(entry_fts, 1, '${SearchResult.matchStart}', '${SearchResult.matchEnd}', '…', 36) AS title_excerpt,
              snippet(entry_fts, 2, '${SearchResult.matchStart}', '${SearchResult.matchEnd}', '…', 36) AS note_excerpt,
              snippet(entry_fts, 3, '${SearchResult.matchStart}', '${SearchResult.matchEnd}', '…', 36) AS original_excerpt
            FROM entry_fts f JOIN entries e ON e.id = f.id
            WHERE entry_fts MATCH ?
            ORDER BY rank, e.id LIMIT ? OFFSET ?
          ''',
                    [
                      words.join(' AND '),
                      data['limit'],
                      data['offset'],
                    ],
                  ),
                );
        case 'pending':
          final options = arg as Map;
          result = decode(
            db.select(
              '''SELECT e.json FROM entries e
            LEFT JOIN indexed_entries i ON i.id = e.id AND i.source_hash = e.source_hash
            LEFT JOIN failed_index_entries f ON f.id = e.id AND f.source_hash = e.source_hash
             WHERE i.id IS NULL AND json_extract(e.json, '\$.status') = 'completed'
             AND NOT EXISTS (SELECT 1 FROM source_hash_migration m WHERE m.id=e.id)
            AND (? OR f.id IS NULL) ORDER BY e.entry_date LIMIT ?''',
              [
                options['retryFailures'] == true ? 1 : 0,
                options['limit'] ?? -1,
              ],
            ),
          );
        case 'indexFailed':
          final data = arg as Map;
          data['hash'] = _hash(
            Map<String, dynamic>.from(data['source'] as Map),
          );
          if (data['generation'] != null &&
              data['generation'] !=
                  db
                      .select('SELECT generation FROM embedding_pipeline')
                      .single['generation']) {
            break;
          }
          db.execute(
            '''INSERT OR REPLACE INTO failed_index_entries(id, source_hash)
            SELECT id, source_hash FROM entries WHERE id = ? AND source_hash = ?''',
            [data['id'], data['hash']],
          );
        case 'retryIndexFailures':
          if (arg ==
              db
                  .select('SELECT generation FROM embedding_pipeline')
                  .single['generation']) {
            db.execute('DELETE FROM failed_index_entries');
          }
        case 'index':
          final data = arg as Map;
          data['hash'] = _hash(
            Map<String, dynamic>.from(data['source'] as Map),
          );
          if (data['generation'] != null &&
              data['generation'] !=
                  db
                      .select('SELECT generation FROM embedding_pipeline')
                      .single['generation']) {
            break;
          }
          final id = data['id'] as String;
          final rows = db.select(
            'SELECT source_hash FROM entries WHERE id = ?',
            [id],
          );
          // Discard a response for a deleted or edited note.
          if (rows.isNotEmpty && rows.single['source_hash'] == data['hash']) {
            transaction(() {
              removeVectors(id);
              final vectors = data['vectors'] as List;
              final passages = data['passages'] as List;
              if (passages.isNotEmpty && passages.length != vectors.length) {
                throw StateError('Passage/vector count mismatch.');
              }
              for (var index = 0; index < vectors.length; index++) {
                final values = vectors[index];
                final vector = (values as List).cast<double>();
                if (vector.length != embeddingProfile.dimensions ||
                    vector.any((v) => !v.isFinite) ||
                    vector.every((v) => v == 0)) {
                  throw StateError('Invalid embedding.');
                }
                db.execute('INSERT INTO chunks(entry_id) VALUES (?)', [id]);
                final chunkId = db.lastInsertRowId;
                if (passages.isNotEmpty) {
                  final passage = passages[index] as Map;
                  final text = passage['text'] as String;
                  final start = passage['start'] as int;
                  db.execute('INSERT INTO chunk_passages VALUES (?, ?, ?, ?)', [
                    chunkId,
                    text,
                    start,
                    start + text.length,
                  ]);
                }
                final bytes = ByteData(vector.length * 4);
                for (var i = 0; i < vector.length; i++) {
                  bytes.setFloat32(i * 4, vector[i], Endian.little);
                }
                db.execute(
                  'INSERT INTO entry_vectors(rowid, embedding) VALUES (?, ?)',
                  [chunkId, bytes.buffer.asUint8List()],
                );
              }
              db.execute('INSERT INTO indexed_entries VALUES (?, ?, ?, ?)', [
                id,
                data['hash'],
                embeddingProfile.pipelineId,
                embeddingProfile.dimensions,
              ]);
            });
          }
        case 'selectEmbeddingModel':
          final selected = findModel(arg as String);
          if (selected == null ||
              !selected.available ||
              selected.maxDistance == null) {
            throw StateError('Unsupported search model.');
          }
          if (selected.pipelineId == embeddingProfile.pipelineId) {
            result = false;
            break;
          }
          transaction(() {
            db.execute('DROP TABLE entry_vectors');
            db.execute(
              'CREATE VIRTUAL TABLE entry_vectors USING vec0(embedding float[${selected.dimensions}] distance_metric=cosine)',
            );
            db.execute('DELETE FROM chunks');
            db.execute('DELETE FROM indexed_entries');
            db.execute('DELETE FROM failed_index_entries');
            db.execute('UPDATE embedding_selection SET model_id=?', [
              selected.id,
            ]);
            db.execute(
              'UPDATE embedding_pipeline SET identity=?, generation=generation+1',
              [selected.pipelineId],
            );
          });
          embeddingProfile = selected;
          result = true;
        case 'resetIndex':
          transaction(() {
            db.execute('UPDATE embedding_pipeline SET generation=generation+1');
            db.execute('DELETE FROM entry_vectors');
            db.execute('DELETE FROM chunks');
            db.execute('DELETE FROM indexed_entries');
            db.execute('DELETE FROM failed_index_entries');
          });
        case 'vector':
          final data = arg as Map;
          if (data['generation'] != null &&
              data['generation'] !=
                  db
                      .select('SELECT generation FROM embedding_pipeline')
                      .single['generation']) {
            result = <Object>[];
            break;
          }
          final vector = (data['vector'] as List).cast<double>();
          if (vector.length != embeddingProfile.dimensions ||
              vector.any((v) => !v.isFinite) ||
              vector.every((v) => v == 0)) {
            throw StateError('Invalid query embedding.');
          }
          final bytes = ByteData(vector.length * 4);
          for (var i = 0; i < vector.length; i++) {
            bytes.setFloat32(i * 4, vector[i], Endian.little);
          }
          // Page ranked entries, not a fixed KNN chunk pool: one long note must
          // not crowd out later pages.
          // SQLite's single MIN binds chunk_id to the winning passage. Fetch
          // full JSON and passage text only for the selected page.
          result = decodeSearch(
            db.select(
              '''
            SELECT e.json, matches.score, p.text AS excerpt, p.start, p.end
            FROM (
              SELECT c.entry_id, c.id AS chunk_id,
                MIN(vec_distance_cosine(v.embedding, ?)) AS score
              FROM entry_vectors v
              JOIN chunks c ON c.id = v.rowid
              GROUP BY c.entry_id HAVING score <= ?
              ORDER BY score, c.entry_id LIMIT ? OFFSET ?
            ) matches
            JOIN entries e ON e.id = matches.entry_id
            LEFT JOIN chunk_passages p ON p.chunk_id = matches.chunk_id
            ORDER BY matches.score, e.id
          ''',
              [
                bytes.buffer.asUint8List(),
                embeddingProfile.maxDistance,
                data['limit'],
                data['offset'],
              ],
            ),
          );
        case 'close':
          // Async maintenance/import owns this connection until its reply.
          while (migrating || importing) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
          db.close();
          commands.close();
        default:
          throw StateError('Unknown database operation.');
      }
      reply.send([true, result]);
    } catch (error) {
      reply.send([
        false,
        'Local journal operation failed.',
        error is EntryWriteFailure ? error.kind.name : null,
      ]);
    }
  });
}

/// Shared by indexing and the worker's invalidation check.
String entrySource(JournalEntry entry) => _source(entry.toJson());
String entrySourceHash(JournalEntry entry) => _hash(entry.toJson());

Future<void> _publishImportInBackground(String path) =>
    Isolate.run(() => _publishImport(path));

void _publishImport(String path) {
  loadSqliteVec();
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('BEGIN IMMEDIATE');
    try {
      const changed =
          '''SELECT s.id FROM import_staging s JOIN entries e ON e.id=s.id
        WHERE s.source_hash != e.source_hash''';
      db.execute(
        'DELETE FROM entry_vectors WHERE rowid IN (SELECT id FROM chunks WHERE entry_id IN ($changed))',
      );
      db.execute('DELETE FROM chunks WHERE entry_id IN ($changed)');
      db.execute('DELETE FROM indexed_entries WHERE id IN ($changed)');
      db.execute('DELETE FROM failed_index_entries WHERE id IN ($changed)');
      db.execute(
        'DELETE FROM entry_fts WHERE id IN (SELECT id FROM import_staging)',
      );
      db.execute('''INSERT INTO entries SELECT * FROM import_staging WHERE true
        ON CONFLICT(id) DO UPDATE SET entry_date=excluded.entry_date,
          json=excluded.json, source_hash=excluded.source_hash''');
      db.execute(
        '''INSERT INTO entry_fts SELECT id,
        COALESCE(json_extract(json, '\$.title'), ''),
        COALESCE(json_extract(json, '\$.formattedNote'), ''),
        COALESCE(json_extract(json, '\$.transcription'), '') FROM import_staging''',
      );
      db.execute(
        'DELETE FROM source_hash_migration WHERE id IN (SELECT id FROM import_staging)',
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  } finally {
    db.close();
  }
}
