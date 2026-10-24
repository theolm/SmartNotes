import 'package:flutter/material.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/app_spacing.dart';

/// Collects optional metadata only; Continue does not write a journal entry.
Future<({String title, String subtitle})?> showNewNoteMetadata(
  BuildContext context,
) {
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<({String title, String subtitle})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const NewNoteMetadataSheet(),
    );
  }
  return showDialog<({String title, String subtitle})>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: const NewNoteMetadataSheet(),
      ),
    ),
  );
}

class NewNoteMetadataSheet extends StatefulWidget {
  const NewNoteMetadataSheet({super.key});

  @override
  State<NewNoteMetadataSheet> createState() => _NewNoteMetadataSheetState();
}

class _NewNoteMetadataSheetState extends State<NewNoteMetadataSheet> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  bool _allowClose = false;
  bool _confirming = false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_confirming || _allowClose) return;
    final l10n = AppLocalizations.of(context)!;
    if (_title.text.isNotEmpty || _subtitle.text.isNotEmpty) {
      _confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.discardNewNoteTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.keepEditing),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.aiDiscard),
            ),
          ],
        ),
      );
      _confirming = false;
      if (!mounted || discard != true) return;
    }
    await _close();
  }

  Future<void> _close([({String title, String subtitle})? result]) async {
    if (_allowClose) return;
    setState(() => _allowClose = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: _allowClose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.newNoteTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.noteDetailsOptional),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.titleLabel),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _subtitle,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.subtitleLabel),
                ),
                const SizedBox(height: AppSpacing.lg),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: AppSpacing.sm,
                  children: [
                    TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
                    FilledButton(
                      onPressed: () => _close((
                        title: _title.text,
                        subtitle: _subtitle.text,
                      )),
                      child: Text(l10n.continueToNote),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
