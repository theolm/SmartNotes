import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:smartnotes/data/datasources/local/local_database.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_file_storage_service.dart';
import 'package:smartnotes/domain/services/i_journal_entry_service.dart';
import 'package:smartnotes/domain/services/i_entry_draft_repository.dart';

@LazySingleton(as: IJournalEntryService)
class SqliteJournalEntryService implements IJournalEntryService {
  SqliteJournalEntryService(this._database, this._files, [this._drafts]);
  final LocalDatabase _database;
  final IFileStorageService _files;
  final IEntryDraftRepository? _drafts;
  @override
  Stream<double?> watchSearchMaintenance() =>
      _database.watchSearchMaintenance();
  final _snapshots = StreamController<List<JournalEntry>>.broadcast(sync: true);
  StreamSubscription<String?>? _feedSubscription;
  List<JournalEntry>? _snapshot;
  int _listeners = 0;
  int _generation = 0;
  Future<void> _refreshQueue = Future.value();

  void _queueRefresh(String? id, int generation) {
    _refreshQueue = _refreshQueue.then((_) async {
      if (generation != _generation) return;
      try {
        final directory = await _files.getAudioDirectoryPath();
        final List<JournalEntry> entries;
        if (id == null || _snapshot == null) {
          entries = (await _database.all())
              .map((entry) => _resolveAudio(entry, directory))
              .toList();
        } else {
          final changed = await _database.entry(id);
          entries = [
            ..._snapshot!.where((entry) => entry.id != id),
            if (changed != null) _resolveAudio(changed, directory),
          ];
          entries.sort((a, b) {
            final date = b.effectiveEntryDate.compareTo(a.effectiveEntryDate);
            return date == 0 ? a.id.compareTo(b.id) : date;
          });
        }
        if (generation != _generation) return;
        _snapshot = List.unmodifiable(entries);
        _snapshots.add(_snapshot!);
      } catch (error, stack) {
        if (generation == _generation) _snapshots.addError(error, stack);
      }
    });
  }

  JournalEntry _resolveAudio(JournalEntry entry, String directory) {
    final audio = entry.audioPath;
    if (audio == null || p.isAbsolute(audio)) return entry;
    return entry.copyWith(audioPath: p.join(directory, audio));
  }

  JournalEntry _relativeAudio(JournalEntry entry, String directory) {
    final audio = entry.audioPath;
    return audio != null && p.isWithin(directory, audio)
        ? entry.copyWith(audioPath: p.relative(audio, from: directory))
        : entry;
  }

  @override
  Stream<List<JournalEntry>> watchAll() {
    return Stream.multi((controller) {
      final subscription = _snapshots.stream.listen(
        controller.addSync,
        onError: controller.addErrorSync,
        onDone: controller.closeSync,
      );
      if (_snapshot != null) controller.addSync(_snapshot!);
      if (_listeners++ == 0) {
        final generation = ++_generation;
        _feedSubscription = _database.entryChanges.listen(
          (id) => _queueRefresh(id, generation),
          onDone: _snapshots.close,
        );
        _queueRefresh(null, generation);
      }
      controller.onCancel = () async {
        await subscription.cancel();
        if (--_listeners == 0) {
          ++_generation;
          _snapshot = null;
          final feed = _feedSubscription;
          _feedSubscription = null;
          await feed?.cancel();
        }
      };
    });
  }

  @override
  Stream<JournalEntry?> watchById(String id) {
    late StreamController<JournalEntry?> controller;
    StreamSubscription<String?>? subscription;
    var revision = 0;
    Future<void> refresh() async {
      final currentRevision = ++revision;
      try {
        final entry = await getById(id);
        if (!controller.isClosed && currentRevision == revision) {
          controller.add(entry);
        }
      } catch (error, stack) {
        if (!controller.isClosed && currentRevision == revision) {
          controller.addError(error, stack);
        }
      }
    }

    controller = StreamController<JournalEntry?>(
      onListen: () {
        subscription = _database.entryChanges.listen((changedId) {
          if (changedId == null || changedId == id) unawaited(refresh());
        });
        unawaited(refresh());
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<JournalEntry?> getById(String id) async {
    final entry = await _database.entry(id);
    return entry == null || entry.audioPath == null
        ? entry
        : _resolveAudio(entry, await _files.getAudioDirectoryPath());
  }

  @override
  Future<JournalEntry> create({required String audioPath}) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: const Uuid().v4(),
      createdAt: now,
      updatedAt: now,
      entryDate: now,
      audioPath: audioPath,
      status: EntryStatus.processing,
    );
    final directory = await _files.getAudioDirectoryPath();
    final stored = p.isWithin(directory, audioPath)
        ? entry.copyWith(audioPath: p.relative(audioPath, from: directory))
        : entry;
    await _database.insertEntry(stored);
    return entry;
  }

  @override
  Future<JournalEntry> createTyped({
    required String id,
    required String text,
    String? title,
    String? subTitle,
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(null, 'text', 'Note text must not be blank');
    }
    final now = DateTime.now();
    final entry = JournalEntry(
      id: id,
      createdAt: now,
      updatedAt: now,
      entryDate: now,
      transcription: text,
      title: title?.trim().isEmpty == true ? null : title,
      subTitle: subTitle?.trim().isEmpty == true ? null : subTitle,
      status: EntryStatus.completed,
    );
    await _database.insertEntry(entry, exclusive: true);
    return entry;
  }

  @override
  Future<JournalEntry> update(
    JournalEntry entry, {
    JournalEntry? expected,
  }) async {
    final updated = entry.copyWith(updatedAt: DateTime.now());
    final directory = await _files.getAudioDirectoryPath();
    final stored = _relativeAudio(updated, directory);
    await _database.updateEntry(
      stored,
      expected: expected == null ? null : _relativeAudio(expected, directory),
    );
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final entry = await getById(id);
    await _database.deleteEntry(id);
    // Draft cleanup cannot turn a successful deletion into a failed deletion.
    try {
      await _drafts?.remove(id);
    } catch (_) {
      /* Best-effort cleanup. */
    }
    final audio = entry?.audioPath;
    if (audio != null &&
        p.isWithin(await _files.getAudioDirectoryPath(), audio)) {
      // A file cleanup failure must not resurrect a deleted journal entry.
      try {
        await _files.deleteFile(audio);
      } catch (_) {
        /* Retry via maintenance. */
      }
    }
  }
}
