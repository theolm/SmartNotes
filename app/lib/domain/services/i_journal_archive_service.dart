import 'dart:typed_data';

abstract class IJournalArchiveService {
  Future<Uint8List> export({void Function(double)? onProgress});
  Future<int> import(Uint8List bytes, {void Function(double)? onProgress});
}
