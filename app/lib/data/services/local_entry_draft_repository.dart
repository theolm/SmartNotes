import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smartnotes/domain/services/i_entry_draft_repository.dart';

/// Separate from the journal database/audio directory and explicit archive data.
@LazySingleton(as: IEntryDraftRepository)
class LocalEntryDraftRepository implements IEntryDraftRepository {
  LocalEntryDraftRepository();
  LocalEntryDraftRepository.inDirectory(Directory directory)
    : _directory = directory;

  Directory? _directory;
  Future<void> _pending = Future.value();

  Future<File> _file(String id) async {
    final directory = _directory ??= Directory(
      p.join((await getApplicationSupportDirectory()).path, 'edit-drafts'),
    );
    await directory.create(recursive: true);
    final name = sha256.convert(utf8.encode(id)).toString();
    return File(p.join(directory.path, '$name.json'));
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<EntryEditDraft?> read(String id) => _serial(() async {
    final file = await _file(id);
    if (!await file.exists()) return null;
    final draft = EntryEditDraft.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
    if (draft.source.id != id) {
      throw const FormatException('Invalid edit draft');
    }
    return draft;
  });

  @override
  Future<void> write(EntryEditDraft draft) => _serial(() async {
    final file = await _file(draft.source.id);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(draft.toJson()), flush: true);
    await temporary.rename(file.path);
  });

  @override
  Future<void> remove(String id) => _serial(() async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
    final temporary = File('${file.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
  });
}
