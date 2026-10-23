import 'package:flutter/material.dart';

import 'package:smartnotes/core/l10n/app_localizations.dart';

class RecordFab extends StatelessWidget {
  const RecordFab({
    super.key,
    required this.isVisible,
    required this.isRecording,
    required this.onPressed,
  });

  final bool isVisible;
  final bool isRecording;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: !isVisible
          ? const SizedBox.shrink(key: ValueKey('hidden'))
          : FloatingActionButton.extended(
              key: ValueKey(isRecording),
              onPressed: onPressed,
              backgroundColor: isRecording
                  ? Theme.of(context).colorScheme.primary
                  : null,
              icon: Icon(
                isRecording ? Icons.stop : Icons.mic,
              ),
              label: Text(
                isRecording ? l10n.stopRecordingHint : l10n.recordButtonHint,
              ),
            ),
    );
  }
}
