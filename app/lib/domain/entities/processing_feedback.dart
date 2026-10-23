enum ProcessingPhase {
  preparingTranscription,
  transcribing,
  preparingSearch,
  finalizing,
}

class ProcessingFeedback {
  const ProcessingFeedback({
    required this.entryId,
    required this.phase,
    required this.modelName,
  });

  final String entryId;
  final ProcessingPhase phase;
  final String modelName;
}
