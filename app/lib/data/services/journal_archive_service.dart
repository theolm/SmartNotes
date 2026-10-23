import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_file_storage_service.dart';
import 'package:smartnotes/domain/services/i_journal_archive_service.dart';

@LazySingleton(as: IJournalArchiveService)
class JournalArchiveService implements IJournalArchiveService {
  JournalArchiveService(this._database, this._files);
  final LocalDatabase _database;
  final IFileStorageService _files;

  @override
  Future<Uint8List> export({void Function(double)? onProgress}) async {
    await _database.open();
    final databasePath = _database.path;
    final audioDirectory = await _files.getAudioDirectoryPath();
    final progress = ReceivePort();
    final subscription = progress.listen(
      (value) => _reportProgress(onProgress, value as double),
    );
    final port = progress.sendPort;
    try {
      final result = await Isolate.run(
        () => _exportArchive(databasePath, audioDirectory, port),
      );
      _reportProgress(onProgress, 1);
      return result;
    } finally {
      await subscription.cancel();
      progress.close();
    }
  }

  @override
  Future<int> import(
    Uint8List bytes, {
    void Function(double)? onProgress,
  }) async {
    final directory = await _files.getAudioDirectoryPath();
    final progress = ReceivePort();
    final subscription = progress.listen(
      (value) => _reportProgress(onProgress, value as double),
    );
    final port = progress.sendPort;
    late (List<Map<String, dynamic>>, List<String>) restored;
    try {
      restored = await Isolate.run(() => _readArchive(bytes, directory, port));
    } finally {
      await subscription.cancel();
      progress.close();
    }
    _reportProgress(onProgress, 0.5);
    try {
      await _database.importJsonEntries(
        restored.$1,
        onProgress: (value) => _reportProgress(onProgress, 0.5 + value * 0.5),
      );
      return restored.$1.length;
    } catch (_) {
      for (final path in restored.$2) {
        try {
          await File(path).delete();
        } catch (_) {
          /* Best-effort rollback. */
        }
      }
      rethrow;
    }
  }
}

const _maxArchiveBytes = 100 * 1024 * 1024;
const _maxExpandedBytes = 500 * 1024 * 1024;

void _reportProgress(void Function(double)? callback, double value) {
  try {
    callback?.call(value);
  } catch (_) {
    // Observability must never roll back an already-published journal.
  }
}

Future<Uint8List> _exportArchive(
  String databasePath,
  String directory,
  SendPort progress,
) async {
  final temporary = Directory.systemTemp.createTempSync('smartnotes-export-');
  final db = sqlite3.open(databasePath, mode: OpenMode.readOnly);
  final encoder = ZipFileEncoder();
  var encoderOpen = false;
  RandomAccessFile? manifest;
  var total = 0;
  try {
    // WAL snapshot: background export never blocks the interactive DB worker.
    db.execute('BEGIN');
    final count =
        db.select('SELECT COUNT(*) AS n FROM entries').single['n'] as int;
    final zipPath = p.join(temporary.path, 'journal.zip');
    final manifestPath = p.join(temporary.path, 'journal.json');
    manifest = File(manifestPath).openSync(mode: FileMode.write);
    encoder.create(zipPath);
    encoderOpen = true;
    manifest.writeStringSync('{"format":"smartnotes","version":1,"entries":[');
    var cursor = 0;
    var completed = 0;
    var manifestBytes = 0;
    while (true) {
      final rows = db.select(
        'SELECT rowid, json FROM entries WHERE rowid > ? ORDER BY rowid LIMIT 25',
        [cursor],
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        cursor = row['rowid'] as int;
        final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
        final path = json['audioPath'] as String?;
        json['audioPath'] = null;
        if (path != null) {
          final resolved = p.isAbsolute(path) ? path : p.join(directory, path);
          if (p.isWithin(directory, resolved) && File(resolved).existsSync()) {
            final file = File(resolved);
            total += file.lengthSync();
            if (total > _maxExpandedBytes) {
              throw const FormatException(
                'Journal exceeds the 500 MB export limit.',
              );
            }
            final name = 'audio/${const Uuid().v4()}.m4a';
            // M4A is already compressed. Store its file stream directly rather
            // than archive's deflater buffering a recording-sized output.
            if (total > _maxArchiveBytes) {
              throw const FormatException(
                'Journal exceeds the 100 MB backup limit.',
              );
            }
            final input = InputFileStream(file.path);
            try {
              encoder.addArchiveFile(
                ArchiveFile.stream(name, input)
                  ..compression = CompressionType.none,
              );
            } finally {
              input.closeSync();
            }
            json['audioPath'] = name;
          }
        }
        final encoded = utf8.encode(jsonEncode(json));
        manifestBytes += encoded.length + 1;
        if (manifestBytes > 20 * 1024 * 1024 ||
            total + manifestBytes > _maxExpandedBytes) {
          throw const FormatException(
            'Journal exceeds the backup manifest limit.',
          );
        }
        if (completed++ > 0) manifest.writeStringSync(',');
        manifest.writeFromSync(encoded);
      }
      progress.send(count == 0 ? 1.0 : completed / count * 0.95);
      if (File(zipPath).lengthSync() > _maxArchiveBytes) {
        throw const FormatException('Journal exceeds the 100 MB backup limit.');
      }
    }
    manifest.writeStringSync(']}');
    manifest.closeSync();
    manifest = null;
    await encoder.addFile(File(manifestPath), 'journal.json');
    encoder.closeSync();
    encoderOpen = false;
    if (File(zipPath).lengthSync() > _maxArchiveBytes) {
      throw const FormatException('Journal exceeds the 100 MB backup limit.');
    }
    progress.send(1.0);
    return File(zipPath).readAsBytesSync();
  } finally {
    manifest?.closeSync();
    if (encoderOpen) encoder.closeSync();
    db.close();
    temporary.deleteSync(recursive: true);
  }
}

(List<Map<String, dynamic>>, List<String>) _readArchive(
  Uint8List bytes,
  String directory,
  SendPort progress,
) {
  if (bytes.length > _maxArchiveBytes) {
    throw const FormatException('Backup exceeds the 100 MB import limit.');
  }
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final files = <String, ArchiveFile>{};
  var total = 0;
  for (final file in archive.files) {
    total += file.size;
    if (total > _maxExpandedBytes || files.containsKey(file.name)) {
      throw const FormatException('Invalid or oversized backup.');
    }
    files[file.name] = file;
  }
  final manifest = files['journal.json'];
  if (manifest == null || manifest.size > 20 * 1024 * 1024) {
    throw const FormatException('Missing or oversized journal manifest.');
  }
  final json =
      jsonDecode(utf8.decode(manifest.content)) as Map<String, dynamic>;
  if (json['format'] != 'smartnotes' || json['version'] != 1) {
    throw const FormatException('Unsupported backup format.');
  }
  final records = json['entries'] as List;
  if (records.length > 100000) {
    throw const FormatException('Too many notes in backup.');
  }
  final entries = <Map<String, dynamic>>[];
  final ids = <String>{};
  // Validate the entire manifest before writing anything. Never extract paths from ZIP.
  for (final record in records) {
    final entry = JournalEntry.fromJson(
      Map<String, dynamic>.from(record as Map),
    );
    if (entry.id.isEmpty || !ids.add(entry.id)) {
      throw const FormatException('Invalid note ID.');
    }
    final audio = entry.audioPath;
    if (audio != null &&
        (!RegExp(r'^audio/[a-zA-Z0-9_-]+\.m4a$').hasMatch(audio) ||
            files[audio] == null ||
            !files[audio]!.isFile)) {
      throw const FormatException('Invalid audio reference in backup.');
    }
    entries.add(
      entry
          .copyWith(
            status:
                entry.status == EntryStatus.processing ||
                    entry.status == EntryStatus.recording
                ? EntryStatus.error
                : entry.status,
          )
          .toJson(),
    );
  }
  final written = <String>[];
  try {
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i % 25 == 0) {
        progress.send(entries.isEmpty ? 0.5 : i / entries.length * 0.5);
      }
      final audio = entry['audioPath'] as String?;
      if (audio == null) continue;
      final name = 'restored_${const Uuid().v4()}.m4a';
      final destination = p.join(directory, name);
      written.add(destination);
      final output = OutputFileStream(destination);
      try {
        files[audio]!.writeContent(output);
      } finally {
        output.closeSync();
      }
      entry['audioPath'] = name;
    }
    return (entries, written);
  } catch (_) {
    for (final path in written) {
      try {
        File(path).deleteSync();
      } catch (_) {
        /* Best-effort rollback. */
      }
    }
    rethrow;
  }
}
