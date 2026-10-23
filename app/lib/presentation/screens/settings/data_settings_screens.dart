import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/presentation/screens/settings/local_data_settings.dart';

@RoutePage()
class SearchSettingsScreen extends StatelessWidget {
  const SearchSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => _DataSettingsPage(
    title: AppLocalizations.of(context)!.searchSettingsTitle,
    section: LocalDataSection.search,
  );
}

@RoutePage()
class BackupSettingsScreen extends StatelessWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => _DataSettingsPage(
    title: AppLocalizations.of(context)!.backupSettingsTitle,
    section: LocalDataSection.backup,
  );
}

class _DataSettingsPage extends StatelessWidget {
  const _DataSettingsPage({required this.title, required this.section});
  final String title;
  final LocalDataSection section;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: AppInsets.withBottomSystemPadding(
            context,
            const EdgeInsets.all(AppSpacing.lg),
          ),
          children: [LocalDataSettings(section: section)],
        ),
      ),
    ),
  );
}
