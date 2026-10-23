abstract class ITranscriptionService {
  Future<String> transcribe(String audioPath);
}
