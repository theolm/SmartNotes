import 'package:flutter/material.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';

/// Permission denial affects visibility, never the transfer itself.
class ModelDownloadNotice extends StatelessWidget {
  const ModelDownloadNotice({super.key, required this.store});
  final ModelDownloadsStore store;

  @override
  Widget build(BuildContext context) {
    if (!store.supported) return const SizedBox.shrink();
    return Observer(
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Semantics(
          liveRegion: true,
          child: Text(
            store.notificationsAllowed == false
                ? AppLocalizations.of(context)!.modelDownloadNotificationsDenied
                : AppLocalizations.of(context)!.modelDownloadBackgroundHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
