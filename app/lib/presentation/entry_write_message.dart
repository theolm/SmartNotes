import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/domain/entities/entry_write_failure.dart';

String entryWriteMessage(
  AppLocalizations l10n,
  EntryWriteFailureKind kind, {
  bool hasDraft = true,
}) => switch (kind) {
  EntryWriteFailureKind.changed =>
    hasDraft ? l10n.entryChangedHelp : l10n.entryChangedWithoutDraft,
  EntryWriteFailureKind.deleted =>
    hasDraft ? l10n.entryDeletedHelp : l10n.entryDeletedWithoutDraft,
  EntryWriteFailureKind.busy => l10n.entryBusyHelp,
  EntryWriteFailureKind.unavailable =>
    hasDraft ? l10n.entryStorageHelp : l10n.entryStorageWithoutDraft,
};
