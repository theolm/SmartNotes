import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/routes/app_route.dart';
import 'package:smartnotes/core/theme/app_pane_layout.dart';
import 'package:smartnotes/core/theme/app_spacing.dart';
import 'package:smartnotes/presentation/screens/home/home_screen.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/screens/home/widgets/journal_capture.dart';
import 'package:smartnotes/presentation/screens/home/journal_workspace_scope.dart';
import 'package:smartnotes/presentation/widgets/adaptive_panes.dart';

@RoutePage(name: 'HomeRoute')
class JournalWorkspaceScreen extends StatefulWidget {
  const JournalWorkspaceScreen({super.key});

  @override
  State<JournalWorkspaceScreen> createState() => _JournalWorkspaceScreenState();
}

class _JournalWorkspaceScreenState extends State<JournalWorkspaceScreen> {
  final _session = JournalNavigationSession();
  final _homeStore = getIt<HomeStore>();
  bool _isSearching = false;
  bool _editorExpanded = false;
  bool _opening = false;
  AppRouter? _appRouter;
  StackRouter? _paneRouter;

  Future<void> _openRequestedEntry(String id) async {
    final router = _paneRouter;
    if (router != null) await _openEntry(router, id);
  }

  @override
  void dispose() {
    if (_appRouter?.journalEntryOpener == _openRequestedEntry) {
      _appRouter?.journalEntryOpener = null;
    }
    super.dispose();
  }

  Future<void> _openEntry(StackRouter router, String id) async {
    if (_opening) return;
    final args = router.current.args;
    final currentId = switch (args) {
      EntryDetailRouteArgs(:final entryId) => entryId,
      EntryEditRouteArgs(:final entryId) => entryId,
      _ => null,
    };
    if (currentId == id) return;
    _opening = true;
    try {
      final leave = _session.leaveEditor;
      if (leave != null && !await leave()) return;
      if (!mounted) return;
      setState(() => _editorExpanded = false);
      // Keep a single detail entry above the empty route. Selecting notes is
      // not a growing history of detail screens; Back returns to the journal.
      if (router.current.name == EntryDetailRoute.name) {
        unawaited(
          router.replace<void>(
            EntryDetailRoute(key: ValueKey(id), entryId: id),
          ),
        );
      } else {
        // Do not await a pushed route's completion: that completes on pop.
        unawaited(
          router.push<void>(EntryDetailRoute(key: ValueKey(id), entryId: id)),
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => AutoRouter(
    builder: (context, navigator) {
      final router = AutoRouter.of(context, watch: true);
      _paneRouter = router;
      final root = router.root;
      if (root is AppRouter) {
        _appRouter = root;
        root.journalEntryOpener = _openRequestedEntry;
      }
      final args = router.current.args;
      final selectedId = switch (args) {
        EntryDetailRouteArgs(:final entryId) => entryId,
        EntryEditRouteArgs(:final entryId) => entryId,
        _ => null,
      };
      final editing = router.current.name == EntryEditRoute.name;
      return LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final layout = AppPaneLayout.resolve(
            size: constraints.biggest,
            textScaler: media.textScaler,
            displayFeatures: media.displayFeatures,
            padding: EdgeInsets.only(
              left: media.padding.left,
              right: media.padding.right,
            ),
            viewInsets: media.viewInsets,
            direction: Directionality.of(context),
          );
          final showCapture =
              !_isSearching && (layout.canSplit || selectedId == null);
          return JournalWorkspaceScope(
            session: _session,
            selectedEntryId: selectedId,
            canExpand: layout.canSplit,
            editorExpanded: _editorExpanded && editing,
            toggleEditorExpanded: () =>
                setState(() => _editorExpanded = !_editorExpanded),
            openEntry: (id) => _openEntry(router, id),
            captureVisible: showCapture,
            child: JournalCapture(
              store: _homeStore,
              alignEnd: layout.canSplit,
              controlRegion: layout.canSplit ? layout.secondary : layout.single,
              showAction: showCapture,
              child: AdaptivePanes(
                layout: layout,
                showSecondary: selectedId != null,
                expanded: _editorExpanded && editing,
                primary: HomeScreen(
                  onSearchModeChanged: (value) =>
                      setState(() => _isSearching = value),
                ),
                secondary: navigator,
              ),
            ),
          );
        },
      );
    },
  );
}

@RoutePage()
class JournalEmptyScreen extends StatelessWidget {
  const JournalEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.journalSelectEntry,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.journalSelectEntryHelp,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
