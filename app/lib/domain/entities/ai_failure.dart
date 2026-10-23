/// Safe to show in the UI and logs; never contains provider bodies or secrets.
enum AiFailureCode {
  modelMissing,
  formattingModelMissing,
  unavailable,
  noSpeech,
  incompleteNote,
  invalidNote,
  invalidEmbedding,
  queryTooLong,
  noteTooLong,
  busy,
}

class AiFailure implements Exception {
  const AiFailure(this.code);
  final AiFailureCode code;
  @override
  String toString() => 'AI failure: ${code.name}';
}
