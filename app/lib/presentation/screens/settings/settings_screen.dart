import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/services/i_speech_model_service.dart';
import 'package:smartnotes/domain/services/i_formatting_model_service.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';
import 'package:smartnotes/presentation/screens/settings/local_data_store.dart';
import 'package:smartnotes/presentation/screens/settings/embedding_models_store.dart';
import 'package:smartnotes/presentation/widgets/embedding_model_status.dart';
import 'package:smartnotes/presentation/widgets/audio_language_options.dart';
import 'package:smartnotes/presentation/widgets/app_update_widgets.dart';
import 'package:smartnotes/presentation/stores/app_update_store.dart';
import 'package:smartnotes/presentation/screens/home/home_store.dart';
import 'package:smartnotes/presentation/app_store.dart';

@RoutePage()
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final store = getIt<SettingsStore>();
  final data = getIt<LocalDataStore>();
  final embeddings = getIt<EmbeddingModelsStore>();

  @override
  void initState() {
    super.initState();
    unawaited(data.load());
    unawaited(embeddings.load());
  }

  Future<void> _open(PageRouteInfo route) async {
    await context.pushRoute(route);
    if (route is SpeechModelsRoute) await store.load();
    if (route is EmbeddingModelsRoute) await embeddings.load();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final speech = getIt<ISpeechModelService>();
    final formatting = getIt<IFormattingModelService>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Observer(
        builder: (_) {
          final language =
              audioLanguageOptions[store.audioLanguage] ??
              l10n.audioLanguageAutomatic;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: AppInsets.withBottomSystemPadding(
                  context,
                  const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                ),
                children: [
                  if (store.lockAppAvailable) ...[
                    _heading(context, l10n.settingsPrivacy),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.lockApp),
                      subtitle: Text(l10n.appLockSummary),
                      value: store.lockAppEnabled,
                      onChanged: store.isUpdatingLockApp
                          ? null
                          : (value) async {
                              final applied = await store.setLockAppEnabled(
                                value,
                                reason: l10n.lockAppEnableReason,
                              );
                              if (!context.mounted || applied) return;
                              await showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(l10n.lockAppEnableFailedTitle),
                                  content: Text(
                                    l10n.lockAppEnableFailedMessage,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text(
                                        l10n.lockAppEnableFailedAction,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  _heading(context, l10n.settingsVoiceAndAI),
                  _destination(
                    l10n.transcriptionSettingsTitle,
                    speech.configuredModelId == null
                        ? language
                        : '$language · ${speech.model.name}',
                    () => _open(SpeechModelsRoute()),
                  ),
                  _destination(
                    l10n.aiOrganizationTitle,
                    formatting.configuredModelId == null
                        ? l10n.aiOrganizationNotConfigured
                        : formatting.activeModel?.name ??
                              l10n.aiOrganizationNotConfigured,
                    () => _open(const FormattingModelsRoute()),
                  ),
                  _destination(
                    l10n.embeddingModelsTitle,
                    embeddings.activeModel == null
                        ? embeddingModelStatus(l10n, embeddings)
                        : '${embeddings.activeModel!.name} · ${embeddingModelStatus(l10n, embeddings)}',
                    () => _open(const EmbeddingModelsRoute()),
                  ),
                  _destination(
                    l10n.searchSettingsTitle,
                    data.modelChecking
                        ? l10n.onboardingModelVerifying
                        : data.modelCheckFailed
                        ? l10n.onboardingLoadFailed
                        : !data.modelReady
                        ? l10n.embeddingModelMissing
                        : data.indexStatus.isIncomplete
                        ? l10n.indexIncomplete
                        : l10n.searchUpToDate,
                    () => _open(const SearchSettingsRoute()),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _heading(context, l10n.settingsYourJournal),
                  _destination(
                    l10n.backupSettingsTitle,
                    l10n.backupSettingsSummary,
                    () => _open(const BackupSettingsRoute()),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppUpdateSettings(
                    store: getIt<AppUpdateStore>(),
                    canInstall: () {
                      if (!mounted ||
                          WidgetsBinding.instance.lifecycleState !=
                              AppLifecycleState.resumed ||
                          context.router.root.topRoute.name !=
                              SettingsRoute.name ||
                          context.router.hasPagelessTopRoute) {
                        return false;
                      }
                      final home = getIt<HomeStore>();
                      return getIt<AppStore>().isUnlocked &&
                          !updateWorkIsActive(home) &&
                          context.router.root
                                  .innerRouterOf<StackRouter>(HomeRoute.name)
                                  ?.current
                                  .name !=
                              EntryEditRoute.name;
                    },
                  ),
                  Observer(
                    builder: (_) {
                      final version = getIt<AppUpdateStore>().installed;
                      if (version.isEmpty) return const SizedBox.shrink();
                      final theme = Theme.of(context);
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xl),
                        child: Text(
                          l10n.settingsAppVersion(version),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _heading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _destination(String title, String summary, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(summary),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
