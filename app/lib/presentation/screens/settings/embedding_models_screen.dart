import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/presentation/screens/settings/embedding_models_store.dart';
import 'package:smartnotes/presentation/widgets/embedding_model_catalog.dart';
import 'package:smartnotes/presentation/widgets/model_settings_page.dart';

@RoutePage()
class EmbeddingModelsScreen extends StatelessWidget {
  const EmbeddingModelsScreen({super.key});

  @override
  Widget build(BuildContext context) => ModelSettingsPage(
    title: AppLocalizations.of(context)!.embeddingModelsTitle,
    children: [
      EmbeddingModelCatalog(store: getIt<EmbeddingModelsStore>()),
    ],
  );
}
