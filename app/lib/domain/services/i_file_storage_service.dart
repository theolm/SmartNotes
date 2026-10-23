abstract class IFileStorageService {
  Future<String> getAudioDirectoryPath();
  Future<String> generateAudioFilePath();
  Future<void> deleteFile(String path);
  Future<bool> exists(String path);
}
