import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart';
import 'package:smartnotes/presentation/widgets/formatting_model_catalog.dart';
import 'package:smartnotes/presentation/widgets/local_model_size.dart';
import 'package:smartnotes/presentation/widgets/model_settings_page.dart';

@RoutePage()
class FormattingModelsScreen extends StatefulWidget {
  const FormattingModelsScreen({super.key});

  @override
  State<FormattingModelsScreen> createState() => _FormattingModelsScreenState();
}

class _FormattingModelsScreenState extends State<FormattingModelsScreen>
    with WidgetsBindingObserver {
  final store = getIt<FormattingModelsStore>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(store.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(store.load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Observer(
      builder: (_) => ModelSettingsPage(
        title: l10n.aiOrganizationTitle,
        canPop: !store.busy || store.activatingId != null,
        children: [
          Text(
            l10n.formattingModelsManageIntro,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.formattingModelStorageSummary(
              localModelSize(context, store.installedBytes),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FormattingModelCatalog(store: store),
        ],
      ),
    );
  }
}
