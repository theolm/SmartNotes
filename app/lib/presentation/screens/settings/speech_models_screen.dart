import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';
import 'package:smartnotes/presentation/screens/settings/speech_models_store.dart';
import 'package:smartnotes/presentation/widgets/local_model_size.dart';
import 'package:smartnotes/presentation/widgets/model_settings_page.dart';
import 'package:smartnotes/presentation/widgets/speech_model_catalog.dart';
import 'package:smartnotes/presentation/widgets/audio_language_options.dart';
import 'package:smartnotes/data/services/speech_model_service.dart';
import 'package:smartnotes/presentation/screens/settings/local_data_store.dart';

@RoutePage()
class SpeechModelsScreen extends StatefulWidget {
  const SpeechModelsScreen({
    super.key,
    this.changeLanguage = false,
    this.requestedLanguage,
  });
  final bool changeLanguage;
  final String? requestedLanguage;
  @override
  State<SpeechModelsScreen> createState() => _SpeechModelsScreenState();
}

class _SpeechModelsScreenState extends State<SpeechModelsScreen>
    with WidgetsBindingObserver {
  final store = getIt<SpeechModelsStore>();
  late String? _requestedLanguage;
  bool _changingLanguage = false;
  bool _retrying = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestedLanguage = widget.changeLanguage
        ? widget.requestedLanguage
        : getIt<SettingsStore>().audioLanguage;
    unawaited(
      store.load(_requestedLanguage),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        store.load(_requestedLanguage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Observer(
      builder: (_) => ModelSettingsPage(
        title: l10n.transcriptionSettingsTitle,
        canPop: !store.busy || store.activatingId != null,
        children: [
          Text(
            l10n.speechModelsManageIntro,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          if (store.language != getIt<SettingsStore>().audioLanguage &&
              !store.activeReady) ...[
            Text(l10n.speechModelLanguageChange),
            const SizedBox(height: AppSpacing.md),
          ],
          DropdownButtonFormField<String>(
            initialValue: store.language ?? 'auto',
            key: ValueKey((store.language, _changingLanguage)),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.audioLanguage,
            ),
            items:
                {
                      'auto': l10n.audioLanguageAutomatic,
                      ...audioLanguageOptions,
                    }.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
            onChanged: store.busy || store.loading || _changingLanguage
                ? null
                : (value) async {
                    final language = value == 'auto' ? null : value;
                    setState(() => _changingLanguage = true);
                    try {
                      await getIt<SettingsStore>().setAudioLanguage(language);
                      _requestedLanguage = language;
                      store.setLanguage(language);
                    } on SpeechModelException catch (error) {
                      if (error.problem == SpeechModelProblem.incompatible ||
                          error.problem == SpeechModelProblem.notReady) {
                        _requestedLanguage = language;
                        store.setLanguage(language);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          SnackBar(
                            content: Text(
                              speechModelError(l10n, error),
                            ),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          SnackBar(
                            content: Text(
                              speechModelError(l10n, error),
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(
                          () => _changingLanguage = false,
                        );
                      }
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.speechModelStorageSummary(
              localModelSize(context, store.installedBytes),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (store.error != null && !store.busy)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => store.load(_requestedLanguage),
                child: Text(l10n.retry),
              ),
            ),
          AbsorbPointer(
            absorbing: _changingLanguage,
            child: SpeechModelCatalog(store: store),
          ),
          const SizedBox(height: AppSpacing.lg),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.retryRecordings),
            children: [
              Text(l10n.transcriptionRecoveryHelp),
              const SizedBox(height: AppSpacing.sm),
              if (_retrying) const LinearProgressIndicator(),
              OutlinedButton(
                onPressed: _retrying || store.busy || !store.activeReady
                    ? null
                    : () async {
                        setState(() => _retrying = true);
                        try {
                          await getIt<LocalDataStore>().retryRecordings();
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.transcriptionRecoveryDone,
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  speechModelError(l10n, error),
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _retrying = false);
                          }
                        }
                      },
                child: Text(l10n.retryRecordings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
