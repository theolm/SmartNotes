import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import 'package:smartnotes/domain/services/i_file_storage_service.dart';

@Injectable(as: IFileStorageService)
class FileStorageService implements IFileStorageService {
  @override
  Future<String> getAudioDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${directory.path}/audio');
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }
    return audioDir.path;
  }

  @override
  Future<String> generateAudioFilePath() async {
    final directory = await getAudioDirectoryPath();
    return '$directory/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  @override
  Future<bool> exists(String path) async {
    return File(path).existsSync();
  }
}
