import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/domain/entities/enums/entry_status.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/domain/entities/model_check_state.dart';
import 'package:smartnotes/presentation/ai_error_message.dart';
import 'package:smartnotes/presentation/screens/home/widgets/journal_timeline.dart';
import 'package:smartnotes/presentation/screens/home/widgets/empty_state.dart';
import 'package:smartnotes/presentation/screens/home/widgets/unified_search_controls.dart';
import 'package:smartnotes/presentation/screens/home/widgets/timeline_item.dart';
import 'package:smartnotes/domain/entities/processing_feedback.dart';
import 'package:smartnotes/presentation/screens/home/journal_workspace_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onSearchModeChanged, this.onCreateNote});

  final ValueChanged<bool>? onSearchModeChanged;
  final Future<void> Function()? onCreateNote;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeStore _homeStore = getIt<HomeStore>();
  final AppStore _appStore = getIt<AppStore>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    _searchFocusNode.requestFocus();
    widget.onSearchModeChanged?.call(true);
  }

  void _stopSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    _homeStore.clearSearch();
    setState(() {
      _isSearching = false;
    });
    widget.onSearchModeChanged?.call(false);
  }

  void _clearQuery() {
    _searchController.clear();
    _homeStore.submitSearch('');
    _searchFocusNode.requestFocus();
  }

  void _search() {
    _searchFocusNode.unfocus();
    _homeStore.runSearch();
  }

  Future<void> _confirmDelete(JournalEntry entry) async {
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

    final deleted = await _homeStore.deleteEntry(entry);
    if (!mounted) return;
    _homeStore.errorMessage = null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? l10n.entryDeleted : l10n.failedToDeleteEntry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasOpenEntry =
        JournalWorkspaceScope.maybeOf(context)?.selectedEntryId != null;

    return Observer(
      builder: (_) => PopScope(
        canPop: !_isSearching || hasOpenEntry,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isSearching && !hasOpenEntry) _stopSearch();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: _isSearching ? 0 : null,
            leading: _isSearching
                ? IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: _stopSearch,
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Theme.of(context).colorScheme.surface,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: l10n.searchUnifiedFieldHint,
                      suffixIcon: _homeStore.searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: l10n.searchClearQuery,
                              onPressed: _clearQuery,
                              icon: const Icon(Icons.close),
                            )
                          : null,
                      hintStyle: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                    onChanged: _homeStore.submitSearch,
                    onSubmitted: (_) => _search(),
                  )
                : Text(
                    l10n.journalTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            actions: [
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.search,
                  onPressed: _homeStore.isSearchingMeaning ? null : _search,
                ),
              if (!_isSearching) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.writeNote,
                  onPressed: _homeStore.isRecording
                      ? null
                      : widget.onCreateNote,
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.search,
                  onPressed: _startSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: l10n.settingsTitle,
                  onPressed: () async {
                    await context.pushRoute(const SettingsRoute());
                    await _appStore.checkModels();
                  },
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              Observer(
                builder: (_) => _homeStore.maintenanceProgress == null
                    ? const SizedBox.shrink()
                    : Semantics(
                        label: l10n.journalMaintenance,
                        liveRegion: true,
                        child: LinearProgressIndicator(
                          value: _homeStore.maintenanceProgress,
                        ),
                      ),
              ),
              if (_appStore.modelChecks.values.contains(
                ModelCheckState.checking,
              ))
                Semantics(
                  liveRegion: true,
                  child: Column(
                    children: [
                      const LinearProgressIndicator(),
                      Text(l10n.onboardingModelVerifying),
                    ],
                  ),
                )
              else if (_appStore.modelChecks.values.any(
                (state) => state != ModelCheckState.ready,
              ))
                MaterialBanner(
                  content: Text(l10n.onboardingLoadFailed),
                  actions: [
                    TextButton(
                      onPressed: _appStore.checkModels,
                      child: Text(l10n.retry),
                    ),
                    TextButton(
                      onPressed: () async {
                        await context.pushRoute(const SettingsRoute());
                        await _appStore.checkModels();
                      },
                      child: Text(l10n.modelSetup),
                    ),
                    TextButton(
                      onPressed: _appStore.modelChecks.clear,
                      child: Text(l10n.close),
                    ),
                  ],
                ),
              Expanded(
                child: Observer(
                  builder: (_) {
                    if (_homeStore.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_homeStore.errorMessage != null) {
                      // The timeline remains accessible; processing failures are recoverable.
                      return Column(
                        children: [
                          MaterialBanner(
                            content: Text(
                              aiErrorMessage(l10n, _homeStore.errorMessage!),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    context.pushRoute(const SettingsRoute()),
                                child: Text(l10n.settings),
                              ),
                              TextButton(
                                onPressed: () => _homeStore.errorMessage = null,
                                child: Text(l10n.close),
                              ),
                            ],
                          ),
                          Expanded(child: _timeline(l10n)),
                        ],
                      );
                    }

                    if (_homeStore.entries.isEmpty && !_isSearching) {
                      return EmptyState(l10n: l10n);
                    }

                    return StreamBuilder<ProcessingFeedback?>(
                      stream: _homeStore.processingFeedback.changes,
                      initialData: _homeStore.processingFeedback.current,
                      builder: (_, snapshot) => Observer(
                        builder: (_) => Stack(
                          children: [
                            _timeline(l10n, feedback: snapshot.data),
                            if (_homeStore.isSearching)
                              const Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(),
                              ),
                          ],
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

  Widget _timeline(
    AppLocalizations l10n, {
    ProcessingFeedback? feedback,
  }) {
    return JournalTimeline(
      entries: _homeStore.displayedEntries,
      isSearching: _isSearching,
      showDayHeaders: _homeStore.searchQuery.isEmpty,
      scrollIdentity: (_isSearching, _homeStore.searchScrollRevision),
      header: _isSearching
          ? UnifiedSearchControls(
              store: _homeStore,
              onEdit: _searchFocusNode.requestFocus,
              onSearch: _search,
            )
          : null,
      footer: _isSearching
          ? UnifiedSearchFooter(
              store: _homeStore,
              onEdit: _searchFocusNode.requestFocus,
            )
          : null,
      itemBuilder: (entry) {
        return TimelineItem(
          key: ValueKey(entry.id),
          entry: entry,
          selected:
              JournalWorkspaceScope.maybeOf(context)?.selectedEntryId ==
              entry.id,
          onOpen: () {
            final workspace = JournalWorkspaceScope.maybeOf(context);
            if (workspace != null) {
              workspace.openEntry(entry.id);
            } else {
              context.pushRoute(EntryDetailRoute(entryId: entry.id));
            }
          },
          showDate: _homeStore.searchQuery.isNotEmpty,
          searchResult: _homeStore.searchQuery.isNotEmpty
              ? _homeStore.searchResultFor(entry)
              : null,
          onDelete: () => _confirmDelete(entry),
          onRetry: entry.status == EntryStatus.error
              ? () => _homeStore.retryProcessing(entry)
              : null,
          feedback: feedback,
        );
      },
    );
  }
}
