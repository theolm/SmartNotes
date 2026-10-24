import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/presentation/screens/settings/local_data_store.dart';
import 'package:auto_route/auto_route.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';

enum LocalDataSection { search, backup }

class LocalDataSettings extends StatefulWidget {
  const LocalDataSettings({super.key, required this.section});
  final LocalDataSection section;
  @override
  State<LocalDataSettings> createState() => _LocalDataSettingsState();
}

class _LocalDataSettingsState extends State<LocalDataSettings> {
  final _store = getIt<LocalDataStore>();
  bool _working = false;

  @override
  void initState() {
    super.initState();
    if (widget.section == LocalDataSection.search) unawaited(_store.load());
  }

  void _notify(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                AppLocalizations.of(context)!.lockAppEnableFailedAction,
              ),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _backup({required bool importing}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _working = true);
    try {
      if (importing) {
        if (!await _confirm(l10n.importJournal, l10n.importConfirmation)) {
          return;
        }
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );
        if (file == null) return;
        final size = await file.length();
        if (size == null || size > 100 * 1024 * 1024) {
          _notify(l10n.backupFailed);
          return;
        }
        final count = await _store.importJournal(await file.readAsBytes());
        if (count != null) _notify(l10n.backupImported);
      } else {
        final bytes = await _store.exportJournal();
        if (bytes == null) return;
        final destination = await FilePicker.saveFile(
          dialogTitle: l10n.exportJournal,
          fileName:
              'smartnotes-${DateTime.now().toIso8601String().substring(0, 10)}.zip',
          mimeType: 'application/zip',
          bytes: bytes,
        );
        if (destination != null) {
          _notify(l10n.backupExported);
        }
      }
    } catch (_) {
      _notify(l10n.backupFailed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Observer(
      builder: (_) {
        final busy = _store.isBusy || _working;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.section == LocalDataSection.search) ...[
              Text(l10n.searchSettingsHelp),
              const SizedBox(height: AppSpacing.md),
              if (!_store.modelChecking && !_store.modelReady)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await context.pushRoute(
                            const EmbeddingModelsRoute(),
                          );
                          await _store.load();
                        },
                  child: Text(l10n.embeddingModelManage),
                ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.indexStatus(
                    _store.indexStatus.indexed,
                    _store.indexStatus.pending,
                    _store.indexStatus.failed,
                  ),
                ),
              ),
              if (_store.modelChecking) ...[
                const LinearProgressIndicator(),
                Text(l10n.onboardingModelVerifying),
              ] else if (_store.modelCheckFailed) ...[
                Text(l10n.onboardingLoadFailed),
                TextButton(
                  onPressed: _store.checkModel,
                  child: Text(l10n.retry),
                ),
              ] else if (!_store.modelReady)
                Text(l10n.embeddingModelMissing),
              if (_store.modelReady && _store.indexStatus.pending > 0)
                LinearProgressIndicator(
                  value:
                      _store.indexStatus.indexed /
                      (_store.indexStatus.indexed +
                          _store.indexStatus.pending +
                          _store.indexStatus.failed),
                ),
              ...[
                const SizedBox(height: AppSpacing.xl),
                if (_store.indexStatus.isIncomplete) ...[
                  Text(l10n.searchMaintenanceHelp),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed:
                        busy || _store.modelChecking || !_store.modelReady
                        ? null
                        : () async {
                            if (await _store.indexNotes()) {
                              _notify(
                                _store.indexStatus.isIncomplete
                                    ? l10n.indexIncomplete
                                    : l10n.indexComplete,
                              );
                            }
                          },
                    child: Text(l10n.indexNotes),
                  ),
                ] else if (_store.modelReady &&
                    !_store.modelChecking &&
                    !_store.modelCheckFailed)
                  Text(l10n.searchUpToDate),
                const SizedBox(height: AppSpacing.sm),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(l10n.advancedSettings),
                  children: [
                    Text(l10n.rebuildIndexMessage),
                    TextButton(
                      onPressed:
                          busy || _store.modelChecking || !_store.modelReady
                          ? null
                          : () async {
                              if (await _confirm(
                                l10n.rebuildIndex,
                                l10n.rebuildIndexMessage,
                              )) {
                                if (await _store.indexNotes(rebuild: true)) {
                                  _notify(
                                    _store.indexStatus.isIncomplete
                                        ? l10n.indexIncomplete
                                        : l10n.indexComplete,
                                  );
                                }
                              }
                            },
                      child: Text(l10n.rebuildIndex),
                    ),
                  ],
                ),
              ],
            ],
            if (busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: LinearProgressIndicator(value: _store.backupProgress),
              ),
            if (_store.error != null &&
                (widget.section == LocalDataSection.search
                    ? _store.error == LocalDataFailure.indexing
                    : _store.error != LocalDataFailure.indexing))
              Text(
                switch (_store.error!) {
                  LocalDataFailure.indexing => l10n.indexFailed,
                  LocalDataFailure.exporting => l10n.exportFailed,
                  LocalDataFailure.importing => l10n.importFailed,
                },
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            if (widget.section == LocalDataSection.backup) ...[
              Text(l10n.localDataPrivacy),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.backupPrivacy),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _backup(importing: false),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(l10n.exportJournal),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _backup(importing: true),
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(l10n.importJournal),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
