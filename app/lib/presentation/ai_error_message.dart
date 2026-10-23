import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';

/// Stores retain a stable failure code; only the presentation localizes it.
String aiErrorMessage(AppLocalizations l10n, String codeOrLegacyMessage) {
  final codes = AiFailureCode.values.where(
    (code) => code.name == codeOrLegacyMessage,
  );
  if (codes.isEmpty) return codeOrLegacyMessage;
  return switch (codes.single) {
    AiFailureCode.modelMissing => l10n.embeddingModelMissing,
    AiFailureCode.formattingModelMissing => l10n.aiFormattingModelMissing,
    AiFailureCode.unavailable => l10n.aiUnavailable,
    AiFailureCode.noSpeech => l10n.aiNoSpeech,
    AiFailureCode.incompleteNote => l10n.aiIncompleteNote,
    AiFailureCode.invalidNote => l10n.aiInvalidNote,
    AiFailureCode.invalidEmbedding => l10n.aiInvalidEmbedding,
    AiFailureCode.queryTooLong => l10n.aiQueryTooLong,
    AiFailureCode.noteTooLong => l10n.aiNoteTooLong,
    AiFailureCode.busy => l10n.aiBusy,
  };
}
