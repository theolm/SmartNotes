abstract class IRecordingMetadata {
  /// Resolves availability without synchronous filesystem work on the UI.
  Future<bool> exists(String path);

  /// Reads the local file's duration without starting playback.
  Future<Duration?> duration(String path);
}
