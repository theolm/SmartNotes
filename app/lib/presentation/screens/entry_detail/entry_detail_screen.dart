import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartnotes/presentation/ai_error_message.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';

import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/presentation/widgets/entry_content.dart';
import 'package:smartnotes/presentation/widgets/recording_player.dart';
import 'package:smartnotes/presentation/entry_write_message.dart';
import 'package:smartnotes/domain/entities/entry_write_failure.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_recording_metadata.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart';
import 'package:smartnotes/presentation/screens/home/journal_workspace_scope.dart';

@RoutePage()
class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final EntryDetailStore _store = getIt<EntryDetailStore>();
  bool _recordingAvailable = false;
  Duration? _recordingDuration;
  String? _checkedAudioPath;

  Future<void> _loadRecordingInfo(JournalEntry entry) async {
    final path = entry.audioPath;
    if (path == null) {
      _checkedAudioPath = null;
      if (_recordingAvailable || _recordingDuration != null) {
        setState(() {
          _recordingAvailable = false;
          _recordingDuration = null;
        });
      }
      return;
    }
    if (_checkedAudioPath == path) return;
    _checkedAudioPath = path;
    final exists = await getIt<IRecordingMetadata>().exists(path);
    if (!mounted || _checkedAudioPath != path) return;
    setState(() {
      _recordingAvailable = exists;
      _recordingDuration = null;
    });
    final duration = await getIt<IRecordingMetadata>().duration(path);
    if (!mounted || _checkedAudioPath != path) return;
    if (duration != null && duration > Duration.zero) {
      setState(() => _recordingDuration = duration);
    }
  }

  String _formatRecordingDuration(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _retryTranscription() {
    if (_recordingAvailable) unawaited(_store.retryEntry());
  }

  Future<void> _showRecording() async {
    final path = _store.entry?.audioPath;
    if (path == null) return;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.originalRecording,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              RecordingPlayer(
                path: path,
                enabled: !_store.isProcessing && !_store.isDeleting,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _store.loadEntry(widget.entryId).then((_) {
      if (!mounted) return;
      final entry = _store.entry;
      if (entry != null) unawaited(_loadRecordingInfo(entry));
      _store.watchEntry(widget.entryId);
    });
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  Future<void> _showDeleteConfirmation() async {
    final context = this.context;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmationTitle),
        content: Text(l10n.deleteConfirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _store.deleteEntry();

    if (!mounted) return;

    if (!context.mounted) return;

    if (_store.errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.entryDeleted)),
      );
      context.router.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToDeleteEntry)),
      );
      await _store.loadEntry(widget.entryId);
    }
  }

  Future<void> _navigateToEdit() async {
    await context.pushRoute(EntryEditRoute(entryId: widget.entryId));
    if (!mounted) return;
    await _store.loadEntry(widget.entryId);
    final entry = _store.entry;
    if (mounted && entry != null) unawaited(_loadRecordingInfo(entry));
  }

  Future<void> _showAiActions() async {
    if (_store.isBusy || _store.isSaving || _store.isDeleting) return;
    await _openAiActionsSheet();
  }

  Future<void> _openAiActionsSheet() async {
    // The sheet opens before readiness is known; hashing a 639 MB/1.1 GB model
    // must never block the interaction.
    final action = await showModalBottomSheet<AiAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AiActionsSheet(
        store: _store,
        onOpenSettings: () async {
          await context.pushRoute(const FormattingModelsRoute());
        },
      ),
    );

    if (action != null && mounted) {
      await _runAiAction(action);
    }
  }

  Future<bool> _ensureFormattingModel() async {
    if (await _store.formattingReady()) return true;
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    final goToSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.formattingModelNeededTitle),
        content: Text(l10n.formattingModelNeededBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.formattingModelNeededSettings),
          ),
        ],
      ),
    );
    if (goToSettings != true || !mounted) return false;
    await context.pushRoute(const FormattingModelsRoute());
    if (!mounted) return false;
    return _store.formattingReady();
  }

  Future<void> _runAiAction(AiAction action) async {
    final succeeded = await _store.applyAiAction(action);
    if (!mounted) return;
    if (succeeded) {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        // Flutter keeps the handle draggable even when enableDrag is false.
        // Explicit Discard/Back protects an in-flight acceptance write.
        showDragHandle: false,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _AiDraftPreview(store: _store),
      );
      _store.discardAiDraft();
      if (mounted && result == 'applied') {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.aiChangesApplied),
            duration: const Duration(seconds: 8),
            persist: false,
            action: SnackBarAction(label: l10n.undo, onPressed: _undoChanges),
          ),
        );
      }
      if (mounted && result == 'regenerate') {
        await _store.loadEntry(widget.entryId);
        if (mounted) await _runAiAction(action);
      }
      return;
    }
    if (_store.aiErrorMessage == AiFailureCode.formattingModelMissing.name) {
      if (await _ensureFormattingModel() && mounted) {
        await _openAiActionsSheet();
      }
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiActionFailedTitle),
        content: Text(
          aiErrorMessage(
            l10n,
            _store.aiErrorMessage ?? l10n.aiActionFailedMessage,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );

    if (retry == true && mounted) {
      await _runAiAction(action);
    }
  }

  Future<void> _undoChanges() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final undone = await _store.undoAiAction();
    if (!mounted) return;
    final kind = _store.writeFailure ?? EntryWriteFailureKind.unavailable;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          undone
              ? l10n.aiChangesUndone
              : entryWriteMessage(l10n, kind, hasDraft: false),
        ),
        action: undone
            ? null
            : SnackBarAction(
                label:
                    kind == EntryWriteFailureKind.unavailable ||
                        kind == EntryWriteFailureKind.busy
                    ? l10n.retry
                    : l10n.reloadEntry,
                onPressed:
                    kind == EntryWriteFailureKind.unavailable ||
                        kind == EntryWriteFailureKind.busy
                    ? _undoChanges
                    : () => _store.loadEntry(widget.entryId),
              ),
      ),
    );
  }

  Future<void> _showOriginal() async {
    final l10n = AppLocalizations.of(context)!;
    final source = _store.entry;
    final original = source?.transcription;
    if (original == null) return;
    final restore = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.originalTranscription,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: SingleChildScrollView(child: SelectableText(original)),
                ),
                if (source?.formattedNote != null)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(l10n.restoreTranscription),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || restore != true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreTranscription),
        content: Text(l10n.restoreTranscriptionConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.restoreTranscription),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        !await _store.restoreTranscription(source: source) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            entryWriteMessage(
              l10n,
              _store.writeFailure ?? EntryWriteFailureKind.unavailable,
              hasDraft: false,
            ),
          ),
          action: SnackBarAction(
            label: l10n.reloadEntry,
            onPressed: () async {
              await _store.loadEntry(widget.entryId);
              if (mounted) await _showOriginal();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final captureInset =
        JournalWorkspaceScope.maybeOf(context)?.captureVisible == true
        ? AppSpacing.section
        : 0.0;

    return Observer(
      builder: (_) => PopScope(
        canPop: !_store.isDeleting,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                surfaceTintColor: Theme.of(context).colorScheme.surface,
                forceElevated: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.edit,
                    onPressed:
                        _store.entry == null ||
                            _store.isBusy ||
                            _store.isSaving ||
                            _store.isDeleting
                        ? null
                        : _navigateToEdit,
                  ),
                  Observer(
                    builder: (_) {
                      final entry = _store.entry;
                      final canApplyAiAction =
                          !_store.isLoading &&
                          !_store.isBusy &&
                          !_store.isSaving &&
                          !_store.isDeleting &&
                          entry?.status == EntryStatus.completed &&
                          entry?.body.trim().isNotEmpty == true;
                      if (!canApplyAiAction) return const SizedBox.shrink();

                      return IconButton(
                        icon: const Icon(Icons.auto_fix_high),
                        tooltip: l10n.aiActionsTitle,
                        onPressed: _showAiActions,
                      );
                    },
                  ),
                  Observer(
                    builder: (_) {
                      return _EntryActionsMenu(
                        isLoading:
                            _store.isLoading ||
                            _store.isBusy ||
                            _store.isSaving ||
                            _store.isDeleting ||
                            _store.entry == null,
                        onDelete: _showDeleteConfirmation,
                        onOriginal:
                            _store.entry?.transcription?.isNotEmpty == true
                            ? _showOriginal
                            : null,
                      );
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Observer(
                  builder: (_) {
                    if (_store.isLoading) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (_store.entry == null) {
                      return SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: _ErrorState(
                          message: _store.errorMessage == 'Entry not found'
                              ? l10n.entryNotFound
                              : l10n.failedToLoadEntry,
                          onRetry: () => _store.loadEntry(widget.entryId),
                        ),
                      );
                    }

                    final entry = _store.entry!;

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Padding(
                          padding: AppInsets.withBottomSystemPadding(
                            context,
                            EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg + captureInset,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (entry.title?.isNotEmpty == true) ...[
                                Semantics(
                                  header: true,
                                  child: Text(
                                    entry.title!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xxs,
                                children: [
                                  Semantics(
                                    header: entry.title?.isNotEmpty != true,
                                    child: Text(
                                      DateFormat.yMMMMd().add_Hm().format(
                                        entry.effectiveEntryDate,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  if (entry.audioPath != null)
                                    OutlinedButton.icon(
                                      onPressed:
                                          _store.isBusy ||
                                              _store.isSaving ||
                                              _store.isDeleting
                                          ? null
                                          : _showRecording,
                                      icon: Icon(
                                        Icons.play_arrow,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      label: Text(
                                        _recordingDuration == null
                                            ? l10n.listenOriginal
                                            : l10n.listenOriginalDuration(
                                                _formatRecordingDuration(
                                                  _recordingDuration!,
                                                ),
                                              ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        side: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.padded,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                        ),
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.all(
                                            AppTheme.plateRadius,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (_store.isDeleting ||
                                  _store.isSaving ||
                                  _store.isBusy ||
                                  entry.status == EntryStatus.processing ||
                                  entry.status == EntryStatus.recording) ...[
                                const LinearProgressIndicator(),
                                Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Text(
                                    _store.isSaving
                                        ? l10n.savingEntry
                                        : _store.isDeleting
                                        ? l10n.deletingEntry
                                        : _store.isPerformingAiAction
                                        ? l10n.aiActionProcessing
                                        : l10n.processing,
                                  ),
                                ),
                              ],
                              if (entry.status == EntryStatus.error ||
                                  _store.errorMessage != null) ...[
                                Text(
                                  _store.errorMessage == null
                                      ? l10n.transcriptionFailedHelp
                                      : aiErrorMessage(
                                          l10n,
                                          _store.errorMessage!,
                                        ),
                                ),
                                if (_recordingAvailable &&
                                    !_store.isBusy &&
                                    !_store.isDeleting)
                                  TextButton.icon(
                                    onPressed: _retryTranscription,
                                    icon: const Icon(Icons.replay),
                                    label: Text(l10n.retry),
                                  ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              if (entry.body.isEmpty &&
                                  entry.status == EntryStatus.completed) ...[
                                Text(l10n.emptyEntry),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed:
                                        _store.isBusy ||
                                            _store.isSaving ||
                                            _store.isDeleting
                                        ? null
                                        : _navigateToEdit,
                                    child: Text(l10n.edit),
                                  ),
                                ),
                              ] else
                                EntryContent(
                                  text: entry.body,
                                  markdown: entry.formattedNote != null,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiDraftPreview extends StatefulWidget {
  const _AiDraftPreview({required this.store});
  final EntryDetailStore store;

  @override
  State<_AiDraftPreview> createState() => _AiDraftPreviewState();
}

class _AiDraftPreviewState extends State<_AiDraftPreview> {
  bool _replaceMetadata = false;
  final _scrollController = ScrollController();
  final _currentScrollController = ScrollController();
  bool _showCurrent = false;
  JournalEntry? _latest;
  JournalEntry? _initialDraft;
  JournalEntry? _initialSource;

  @override
  void initState() {
    super.initState();
    // Keep the outgoing sheet stable while the accepted draft is cleared.
    _initialDraft = widget.store.aiDraft;
    _initialSource = widget.store.draftSource;
  }

  Future<void> _copyDraft() async {
    final draft = widget.store.aiDraft;
    if (draft == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: [
          if (_replaceMetadata && draft.title != null) draft.title!,
          if (_replaceMetadata && draft.subTitle != null) draft.subTitle!,
          draft.body,
        ].join('\n\n'),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.editsCopied)),
      );
    }
  }

  Future<void> _reload() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiRegenerate),
        content: Text(l10n.reloadAiDraftHelp),
        actions: [
          TextButton(onPressed: _copyDraft, child: Text(l10n.copyEdits)),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.aiRegenerate),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) Navigator.pop(context, 'regenerate');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _currentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Observer(
      builder: (_) {
        final store = widget.store;
        final draft = store.aiDraft ?? _initialDraft;
        final current = _latest ?? store.draftSource ?? _initialSource;
        return PopScope(
          canPop: !store.isSaving,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.85,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        ChoiceChip(
                          label: Text(
                            _latest == null
                                ? l10n.currentEntry
                                : l10n.latestSavedEntry,
                          ),
                          selected: _showCurrent,
                          onSelected: (_) =>
                              setState(() => _showCurrent = true),
                        ),
                        ChoiceChip(
                          label: Text(l10n.previewLabel),
                          selected: !_showCurrent,
                          onSelected: (_) =>
                              setState(() => _showCurrent = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: SingleChildScrollView(
                        key: ValueKey(_showCurrent),
                        controller: _showCurrent
                            ? _currentScrollController
                            : _scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (store.writeFailure != null) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  entryWriteMessage(l10n, store.writeFailure!),
                                ),
                              ),
                              Wrap(
                                spacing: AppSpacing.sm,
                                children: [
                                  TextButton(
                                    onPressed: store.isSaving
                                        ? null
                                        : _copyDraft,
                                    child: Text(l10n.copyEdits),
                                  ),
                                  if (store.writeFailure ==
                                      EntryWriteFailureKind.changed)
                                    TextButton(
                                      onPressed: store.isSaving
                                          ? null
                                          : () async {
                                              final latest = await store
                                                  .savedForComparison();
                                              if (mounted && latest != null) {
                                                setState(() {
                                                  _latest = latest;
                                                  _showCurrent = true;
                                                });
                                              }
                                            },
                                      child: Text(l10n.compareSaved),
                                    ),
                                  if (store.writeFailure ==
                                      EntryWriteFailureKind.changed)
                                    TextButton(
                                      onPressed: store.isSaving
                                          ? null
                                          : _reload,
                                      child: Text(l10n.aiRegenerate),
                                    ),
                                ],
                              ),
                            ],
                            Text(
                              l10n.aiPreviewTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(l10n.aiPreviewHelp),
                            const SizedBox(height: AppSpacing.md),
                            if (_showCurrent) ...[
                              if (current?.title?.isNotEmpty == true)
                                Text(
                                  current!.title!,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                            ] else if (_replaceMetadata) ...[
                              Text(
                                draft?.title ?? '',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (draft?.subTitle?.isNotEmpty == true)
                                Text(draft!.subTitle!),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            EntryContent(
                              text: _showCurrent
                                  ? current?.body ?? ''
                                  : draft?.body ?? '',
                              markdown:
                                  !_showCurrent ||
                                  current?.formattedNote != null,
                            ),
                            if (!_showCurrent)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.aiReplaceMetadata),
                                value: _replaceMetadata,
                                onChanged: store.isSaving
                                    ? null
                                    : (value) => setState(
                                        () => _replaceMetadata = value ?? false,
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: store.isSaving || store.aiDraft == null
                          ? null
                          : () async {
                              final applied = await store.acceptAiDraft(
                                replaceMetadata: _replaceMetadata,
                              );
                              if (applied && context.mounted) {
                                Navigator.of(context).pop('applied');
                              } else if (context.mounted &&
                                  _scrollController.hasClients) {
                                _scrollController.jumpTo(0);
                              }
                            },
                      child: Text(
                        store.isSaving ? l10n.processing : l10n.aiApply,
                      ),
                    ),
                    TextButton(
                      onPressed: store.isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.aiDiscard),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AiActionsSheet extends StatefulWidget {
  const _AiActionsSheet({required this.store, required this.onOpenSettings});
  final EntryDetailStore store;
  final Future<void> Function() onOpenSettings;

  @override
  State<_AiActionsSheet> createState() => _AiActionsSheetState();
}

class _AiActionsSheetState extends State<_AiActionsSheet> {
  late Future<bool> _readiness;

  @override
  void initState() {
    super.initState();
    _readiness = widget.store.formattingReady();
  }

  void _retry() {
    setState(() {
      _readiness = widget.store.formattingReady();
    });
  }

  Future<void> _openSettings() async {
    await widget.onOpenSettings();
    if (mounted) _retry();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = [
      _AiActionOption(
        action: AiAction.organizedNote,
        icon: Icons.notes_outlined,
        title: l10n.aiActionOrganizedNoteTitle,
        description: l10n.aiActionOrganizedNoteDescription,
      ),
      _AiActionOption(
        action: AiAction.journalEntry,
        icon: Icons.menu_book_outlined,
        title: l10n.aiActionJournalEntryTitle,
        description: l10n.aiActionJournalEntryDescription,
      ),
      _AiActionOption(
        action: AiAction.keyPoints,
        icon: Icons.format_list_bulleted,
        title: l10n.aiActionKeyPointsTitle,
        description: l10n.aiActionKeyPointsDescription,
      ),
      _AiActionOption(
        action: AiAction.faithfulTranscription,
        icon: Icons.record_voice_over_outlined,
        title: l10n.aiActionFaithfulTranscriptionTitle,
        description: l10n.aiActionFaithfulTranscriptionDescription,
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.aiActionsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: FutureBuilder<bool>(
                future: _readiness,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text(l10n.aiPreparingModel)),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.aiModelCheckFailed),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            onPressed: _retry,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.data != true) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.formattingModelNeededTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(l10n.formattingModelNeededBody),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: _openSettings,
                            child: Text(l10n.formattingModelNeededSettings),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.notNow),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: actions.length,
                    itemBuilder: (context, index) {
                      final option = actions[index];
                      return ListTile(
                        leading: Icon(option.icon),
                        title: Text(option.title),
                        subtitle: Text(option.description),
                        onTap: () => Navigator.of(context).pop(option.action),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiActionOption {
  const _AiActionOption({
    required this.action,
    required this.icon,
    required this.title,
    required this.description,
  });

  final AiAction action;
  final IconData icon;
  final String title;
  final String description;
}

enum _EntryAction { original, delete }

class _EntryActionsMenu extends StatelessWidget {
  const _EntryActionsMenu({
    required this.isLoading,
    required this.onDelete,
    this.onOriginal,
  });

  final bool isLoading;
  final VoidCallback onDelete;
  final VoidCallback? onOriginal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<_EntryAction>(
      icon: const Icon(Icons.more_vert),
      enabled: !isLoading,
      onSelected: (action) {
        switch (action) {
          case _EntryAction.original:
            onOriginal?.call();
          case _EntryAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_EntryAction>>[
        if (onOriginal != null) ...[
          PopupMenuItem(
            value: _EntryAction.original,
            child: Row(
              children: [
                const Icon(Icons.subject_outlined),
                const SizedBox(width: AppSpacing.md),
                Flexible(child: Text(l10n.originalTranscription)),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem<_EntryAction>(
          value: _EntryAction.delete,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                l10n.delete,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}
