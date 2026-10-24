import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/entry_write_failure.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/domain/services/i_entry_draft_repository.dart';
import 'package:smartnotes/presentation/entry_write_message.dart';
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_store.dart';
import 'package:smartnotes/presentation/screens/home/journal_workspace_scope.dart';

@RoutePage()
class EntryEditScreen extends StatefulWidget {
  const EntryEditScreen({
    super.key,
    this.entryId,
    this.initialTitle = '',
    this.initialSubtitle = '',
  });
  final String? entryId;
  final String initialTitle;
  final String initialSubtitle;

  @override
  State<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends State<EntryEditScreen>
    with WidgetsBindingObserver {
  final EntryEditStore _store = getIt<EntryEditStore>();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _body = TextEditingController();
  final _bodyFocus = FocusNode();
  JournalNavigationSession? _navigationSession;
  Timer? _debounce;
  bool _ready = false;
  bool _allowPop = false;
  bool _dialogOpen = false;
  bool _draftError = false;
  bool _recoveryError = false;
  bool _awaitingResume = false;
  bool _closing = false;
  bool _saveInProgress = false;
  EntryEditDraft? _orphanDraft;
  bool get _saving => _saveInProgress || _store.isSaving;
  bool get _newNote => widget.entryId == null;
  String get _draftId => widget.entryId ?? EntryEditDraft.creationKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = JournalWorkspaceScope.maybeOf(context)?.session;
    if (_navigationSession != session) {
      if (_navigationSession?.leaveEditor == _leaveForNavigation) {
        _navigationSession?.leaveEditor = null;
      }
      _navigationSession = session;
      session?.leaveEditor = _leaveForNavigation;
    }
  }

  Future<bool> _leaveForNavigation() async {
    await _exit();
    return _allowPop;
  }

  bool get _dirty {
    final entry = _store.entry;
    if (_newNote && _store.isCreating) {
      return _ready &&
          (_body.text.isNotEmpty ||
              _title.text.isNotEmpty ||
              _subtitle.text.isNotEmpty);
    }
    return _ready &&
        entry != null &&
        (_title.text != (entry.title ?? '') ||
            _subtitle.text != (entry.subTitle ?? '') ||
            _body.text != entry.body ||
            _store.selectedEntryDate != entry.effectiveEntryDate);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bodyFocus.addListener(_bodyFocusChanged);
    for (final controller in [_title, _subtitle, _body]) {
      controller.addListener(_changed);
    }
    unawaited(_load());
  }

  void _fill(JournalEntry entry, [EntryEditDraft? draft]) {
    _title.text = draft?.title ?? entry.title ?? '';
    _subtitle.text = draft?.subtitle ?? entry.subTitle ?? '';
    _body.text = draft?.body ?? entry.body;
    _store.selectEntryDate(draft?.entryDate ?? entry.effectiveEntryDate);
  }

  Future<void> _load() async {
    setState(() {
      _ready = false;
      _recoveryError = false;
    });
    if (_newNote) {
      await _loadCreation();
      return;
    }
    await _store.loadEntry(widget.entryId!);
    if (!mounted) return;
    EntryEditDraft? draft;
    try {
      draft = await _store.drafts?.read(_draftId);
    } catch (_) {
      if (mounted) setState(() => _recoveryError = true);
      return;
    }
    if (!mounted) return;
    final entry = _store.entry;
    if (entry == null) {
      setState(() {
        _orphanDraft = draft;
        _ready = true;
      });
      return;
    }
    if (draft != null) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _awaitingResume = true);
      final resume = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(l10n.resumeDraftTitle),
          content: Text(
            draft!.source == entry
                ? l10n.resumeDraftHelp
                : l10n.draftChangedHelp,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.aiDiscard),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.resumeDraft),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _awaitingResume = false);
      if (resume == null) {
        // Back closes recovery without treating it as an explicit discard.
        await _pop();
        return;
      }
      if (resume == true) {
        // Preserve the original expected snapshot until explicit conflict recovery.
        _store.entry = draft.source;
        if (draft.source != entry) {
          _store.writeFailure = EntryWriteFailureKind.changed;
        }
      } else {
        try {
          await _store.drafts?.remove(_draftId);
        } catch (_) {
          if (mounted) setState(() => _recoveryError = true);
          return;
        }
        draft = null;
      }
    }
    if (!mounted) return;
    _fill(_store.entry!, draft);
    setState(() => _ready = true);
  }

  Future<void> _loadCreation() async {
    try {
      final draft = await _store.drafts?.read(_draftId);
      if (!mounted) return;
      if (draft != null) {
        // A crash after commit but before draft cleanup must not create a copy.
        final saved = await _store.findCreatedEntry(draft.creationId!);
        if (!mounted) return;
        if (saved != null &&
            saved.audioPath == null &&
            saved.transcription == draft.body) {
          await _store.drafts?.remove(_draftId);
          if (mounted) {
            await context.replaceRoute(EntryDetailRoute(entryId: saved.id));
          }
          return;
        }
        final l10n = AppLocalizations.of(context)!;
        setState(() => _awaitingResume = true);
        final resume = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(l10n.resumeNewNoteTitle),
            content: Text(
              saved == null
                  ? l10n.resumeNewNoteHelp
                  : l10n.resumeNewNoteConflictHelp,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.aiDiscard),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.resumeNewNote),
              ),
            ],
          ),
        );
        if (!mounted) return;
        setState(() => _awaitingResume = false);
        if (resume == null) {
          await _pop();
          return;
        }
        if (resume) {
          _store.startCreation(id: saved == null ? draft.creationId : null);
          _title.text = draft.title;
          _subtitle.text = draft.subtitle;
          _body.text = draft.body;
        } else {
          await _store.drafts?.remove(_draftId);
          _startCreation();
        }
      } else {
        _startCreation();
      }
      if (!mounted) return;
      setState(() => _ready = true);
      await _persist();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bodyFocus.requestFocus();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _recoveryError = true;
          _awaitingResume = false;
        });
      }
    }
  }

  void _startCreation() {
    _store.startCreation();
    _title.text = widget.initialTitle;
    _subtitle.text = widget.initialSubtitle;
    _body.clear();
  }

  void _bodyFocusChanged() {
    if (mounted) setState(() {});
  }

  void _changed() {
    if (!_ready || _closing) return;
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_persist()),
    );
  }

  Future<void> _persist() async {
    if (!_ready || _closing || (_store.entry == null && !_store.isCreating)) {
      return;
    }
    if (_newNote && !_store.isCreating) return;
    try {
      if (_dirty) {
        await _store.drafts?.write(
          EntryEditDraft(
            source: _newNote ? null : _store.entry!,
            creationId: _newNote ? _store.creationId : null,
            title: _title.text,
            subtitle: _subtitle.text,
            body: _body.text,
            entryDate:
                _store.selectedEntryDate ?? _store.entry!.effectiveEntryDate,
          ),
        );
      } else {
        await _store.drafts?.remove(_draftId);
      }
      if (mounted && _draftError) setState(() => _draftError = false);
    } catch (_) {
      if (mounted) setState(() => _draftError = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _debounce?.cancel();
      unawaited(_persist());
    }
  }

  @override
  void dispose() {
    if (_navigationSession?.leaveEditor == _leaveForNavigation) {
      _navigationSession?.leaveEditor = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    // Queue a final best-effort snapshot before disposing the controllers.
    if (!_closing) unawaited(_persist());
    _title.dispose();
    _subtitle.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    if (_saveInProgress || _store.isSaving || _dialogOpen) return;
    if (!_dirty) {
      await _pop();
      return;
    }
    _dialogOpen = true;
    final l10n = AppLocalizations.of(context)!;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unsavedChanges),
        content: Text(l10n.unsavedChangesHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(l10n.aiDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (choice == 'save') await _reviewAndSave();
    if (choice == 'discard') {
      _debounce?.cancel();
      _closing = true;
      try {
        await _store.drafts?.remove(_draftId);
      } catch (_) {
        _closing = false;
        if (mounted) setState(() => _draftError = true);
        return;
      }
      if (mounted) await _pop();
    }
  }

  Future<void> _pop() async {
    _closing = true;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reviewAndSave() async {
    if (_newNote) {
      if (_saving || _dialogOpen || !_ready) return;
      if (_body.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.noteBodyRequired),
          ),
        );
        _bodyFocus.requestFocus();
        return;
      }
      await _save();
      return;
    }
    if (_saving || _dialogOpen || !_ready || _store.entry == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _dialogOpen = true;
    final l10n = AppLocalizations.of(context)!;
    Widget details(BuildContext panelContext) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.saveNoteTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.noteDetailsOptional),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.titleLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _subtitle,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.subtitleLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          Observer(
            builder: (_) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(l10n.entryDateLabel),
              subtitle: Text(
                DateFormat.yMMMMd().add_Hm().format(_store.selectedEntryDate!),
              ),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: AppSpacing.sm,
            overflowSpacing: AppSpacing.sm,
            children: [
              TextButton(
                onPressed: () => Navigator.of(panelContext).pop(false),
                child: Text(l10n.backToEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.of(panelContext).pop(true),
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
    bool? confirmed;
    try {
      if (MediaQuery.sizeOf(context).width < 600) {
        confirmed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(top: false, child: details(context)),
          ),
        );
      } else {
        confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: details(context),
            ),
          ),
        );
      }
    } finally {
      _dialogOpen = false;
    }
    if (mounted && confirmed == true) await _save();
  }

  Future<void> _showMarkdownHelp() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final l10n = AppLocalizations.of(context)!;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.markdownHelpTitle),
          content: SingleChildScrollView(child: Text(l10n.markdownHelpBody)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.backToEditing),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _save() async {
    if (_saveInProgress || _store.isSaving) return;
    setState(() => _saveInProgress = true);
    try {
      _debounce?.cancel();
      await _persist();
      final saved = await _store.saveEntry(
        title: _title.text,
        subTitle: _subtitle.text,
        rawMarkdown: _body.text,
      );
      if (!mounted || saved == null) return;
      _closing = true;
      try {
        await _store.drafts?.remove(_draftId);
      } catch (_) {
        // The canonical write succeeded. Keep the user here to retry cleanup,
        // rather than letting an obsolete draft silently reappear next time.
        _closing = false;
        if (mounted) setState(() => _draftError = true);
        return;
      }
      if (mounted) {
        if (_newNote) {
          setState(() => _allowPop = true);
          await context.replaceRoute(EntryDetailRoute(entryId: saved.id));
        } else {
          await _pop();
        }
      }
    } finally {
      if (mounted) setState(() => _saveInProgress = false);
    }
  }

  Future<void> _copy([EntryEditDraft? draft]) async {
    final l10n = AppLocalizations.of(context)!;
    final title = draft?.title ?? _title.text;
    final subtitle = draft?.subtitle ?? _subtitle.text;
    final date = draft?.entryDate ?? _store.selectedEntryDate;
    await Clipboard.setData(
      ClipboardData(
        text: [
          if (title.isNotEmpty) '${l10n.titleLabel}: $title',
          if (subtitle.isNotEmpty) '${l10n.subtitleLabel}: $subtitle',
          if (date != null)
            '${l10n.entryDateLabel}: ${DateFormat.yMMMMd().add_Hm().format(date)}',
          draft?.body ?? _body.text,
        ].join('\n\n'),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.editsCopied)),
      );
    }
  }

  Future<void> _compare() async {
    final l10n = AppLocalizations.of(context)!;
    final latest = await _store.latestEntry();
    if (!mounted || latest == null) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.compareSaved),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.currentEntry,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (latest.title?.isNotEmpty == true) Text(latest.title!),
                if (latest.subTitle?.isNotEmpty == true) Text(latest.subTitle!),
                Text(
                  DateFormat.yMMMMd().add_Hm().format(
                    latest.effectiveEntryDate,
                  ),
                ),
                SelectableText(latest.body),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.yourEdits,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_title.text.isNotEmpty) Text(_title.text),
                if (_subtitle.text.isNotEmpty) Text(_subtitle.text),
                Text(
                  DateFormat.yMMMMd().add_Hm().format(
                    _store.selectedEntryDate!,
                  ),
                ),
                SelectableText(_body.text),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.reloadReplacesDraft),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => _copy(), child: Text(l10n.copyEdits)),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.useLatestEntry),
          ),
        ],
      ),
    );
    if (replace != true || !mounted) return;
    _debounce?.cancel();
    try {
      await _store.drafts?.remove(_draftId);
    } catch (_) {
      if (mounted) setState(() => _draftError = true);
      return;
    }
    if (!mounted) return;
    _ready = false;
    _store.entry = latest;
    _store.writeFailure = null;
    _store.errorMessage = null;
    _fill(latest);
    setState(() => _ready = true);
  }

  Future<void> _pickDate() async {
    final initial =
        _store.selectedEntryDate ?? _store.entry!.effectiveEntryDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // Match the Material 3 calendar's preferred size, but snap its width
        // to whole logical pixels. Fractional Android font scales otherwise
        // trigger a precision assertion in Flutter's 3,601-page month pager.
        // Constrain the dialog, not text scaling or the supported date range.
        final preferredWidth = media.orientation == Orientation.portrait
            ? 360.0
            : 496.0;
        final scale = media.textScaler.clamp(maxScaleFactor: 3).scale(14) / 14;
        final availableWidth =
            media.size.width -
            media.viewInsets.horizontal -
            media.padding.horizontal -
            32;
        final width = (preferredWidth * scale)
            .clamp(0.0, availableWidth.clamp(0.0, double.infinity))
            .floorToDouble();
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            dialogTheme: theme.dialogTheme.copyWith(
              constraints: BoxConstraints.tightFor(width: width),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    _store.selectEntryDate(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
    _changed();
  }

  Future<void> _discardRecovery() async {
    final l10n = AppLocalizations.of(context)!;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardRecoveryDraft),
        content: Text(l10n.discardRecoveryDraftHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.aiDiscard),
          ),
        ],
      ),
    );
    if (!mounted || discard != true) return;
    try {
      await _store.drafts?.remove(_draftId);
    } catch (_) {
      if (mounted) setState(() => _recoveryError = true);
      return;
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspace = JournalWorkspaceScope.maybeOf(context);
    final captureInset = workspace?.captureVisible == true
        ? AppSpacing.section
        : 0.0;
    return Observer(
      builder: (_) => PopScope(
        canPop: _allowPop || (!_saveInProgress && !_store.isSaving && !_dirty),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_exit());
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _newNote ? l10n.newNoteTitle : l10n.editEntryTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: BackButton(
              onPressed: _saveInProgress || _store.isSaving ? null : _exit,
            ),
            actions: [
              if (workspace?.canExpand == true)
                IconButton(
                  tooltip: workspace!.editorExpanded
                      ? l10n.editorRestore
                      : l10n.editorExpand,
                  onPressed: workspace.toggleEditorExpanded,
                  icon: Icon(
                    workspace.editorExpanded
                        ? Icons.close_fullscreen
                        : Icons.open_in_full,
                  ),
                ),
              TextButton.icon(
                onPressed:
                    !_ready ||
                        (_store.entry == null && !_store.isCreating) ||
                        _store.isSaving ||
                        _saveInProgress
                    ? null
                    : _reviewAndSave,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                label: Text(_saving ? l10n.processing : l10n.save),
              ),
            ],
          ),
          body: _recoveryError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.draftRecoveryFailed),
                      TextButton(onPressed: _load, child: Text(l10n.retry)),
                      TextButton(
                        onPressed: _discardRecovery,
                        child: Text(l10n.discardRecoveryDraft),
                      ),
                    ],
                  ),
                )
              : !_ready
              ? _awaitingResume
                    ? const SizedBox.shrink()
                    : const Center(child: CircularProgressIndicator())
              : _store.entry == null && !_store.isCreating
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _store.errorMessage == 'Entry not found'
                              ? l10n.entryNotFound
                              : l10n.failedToLoadEntry,
                        ),
                        if (_orphanDraft != null)
                          TextButton(
                            onPressed: () => _copy(_orphanDraft),
                            child: Text(l10n.copyEdits),
                          ),
                        if (_orphanDraft != null)
                          TextButton(
                            onPressed: _discardRecovery,
                            child: Text(l10n.discardRecoveryDraft),
                          ),
                        TextButton(onPressed: _load, child: Text(l10n.retry)),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: AppInsets.withBottomSystemPadding(
                    context,
                    EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg + captureInset,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_draftError)
                            Semantics(
                              liveRegion: true,
                              child: Text(l10n.draftSaveFailed),
                            ),
                          if (_store.writeFailure != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                entryWriteMessage(l10n, _store.writeFailure!),
                              ),
                            ),
                            Wrap(
                              spacing: AppSpacing.sm,
                              children: [
                                TextButton(
                                  onPressed: _saving ? null : () => _copy(),
                                  child: Text(l10n.copyEdits),
                                ),
                                if (!_newNote)
                                  TextButton(
                                    onPressed: _saving ? null : _compare,
                                    child: Text(l10n.compareSaved),
                                  ),
                              ],
                            ),
                          ],
                          InputDecorator(
                            key: const ValueKey('note-editor'),
                            isFocused: _bodyFocus.hasFocus,
                            isEmpty: _body.text.isEmpty,
                            decoration: InputDecoration(
                              enabled: !_saving,
                              labelText: l10n.noteLabel,
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              filled: false,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(
                                  label: l10n.noteLabel,
                                  child: TextFormField(
                                    controller: _body,
                                    focusNode: _bodyFocus,
                                    enabled: !_saving,
                                    maxLines: null,
                                    minLines: 10,
                                    keyboardType: TextInputType.multiline,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                    decoration: InputDecoration(
                                      hintText: l10n.noteEditHint,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                      filled: false,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.markdownSupported,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _saving
                                          ? null
                                          : _showMarkdownHelp,
                                      tooltip: l10n.markdownHelpTitle,
                                      iconSize: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      icon: const Icon(Icons.help_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
