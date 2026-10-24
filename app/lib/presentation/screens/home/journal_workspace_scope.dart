import 'package:flutter/widgets.dart';

/// Coordinates leaving an editor without coupling the feed to an editor widget.
/// Owned by the workspace; never recreated when the pane geometry changes.
class JournalNavigationSession {
  Future<bool> Function()? leaveEditor;
}

class JournalWorkspaceScope extends InheritedWidget {
  const JournalWorkspaceScope({
    super.key,
    required this.session,
    required this.selectedEntryId,
    required this.canExpand,
    required this.editorExpanded,
    required this.toggleEditorExpanded,
    required this.openEntry,
    required this.captureVisible,
    required super.child,
  });

  final JournalNavigationSession session;
  final String? selectedEntryId;
  final bool canExpand;
  final bool editorExpanded;
  final VoidCallback toggleEditorExpanded;
  final Future<void> Function(String) openEntry;
  final bool captureVisible;

  static JournalWorkspaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<JournalWorkspaceScope>();

  @override
  bool updateShouldNotify(JournalWorkspaceScope oldWidget) =>
      selectedEntryId != oldWidget.selectedEntryId ||
      canExpand != oldWidget.canExpand ||
      captureVisible != oldWidget.captureVisible ||
      editorExpanded != oldWidget.editorExpanded;
}
