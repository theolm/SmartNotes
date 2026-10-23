import 'dart:async';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/presentation/screens/onboarding/onboarding_store.dart';
import 'package:smartnotes/presentation/widgets/audio_language_options.dart';
import 'package:smartnotes/presentation/widgets/formatting_model_catalog.dart';
import 'package:smartnotes/presentation/widgets/speech_model_catalog.dart';
import 'package:smartnotes/presentation/widgets/model_download_notice.dart';

@RoutePage()
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.fromSettings = false});
  final bool fromSettings;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _store = getIt<OnboardingStore>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_store.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_store.downloads.supported && _store.isDownloading) {
      _store.cancelDownload();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_store.reconcileDownload());
    }
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    if (!await _store.finish() || !mounted) return;
    await _leaveSetup();
  }

  Future<void> _leaveSetup() async {
    if (widget.fromSettings) {
      await context.maybePop<void>();
    } else {
      await context.replaceRoute<void>(const HomeRoute());
    }
  }

  Future<void> _continueFromLanguage() async {
    if (!_store.shouldOfferNotificationPermission) {
      _store.next();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.notificationPermissionTitle),
        content: Text(l10n.notificationPermissionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.notificationPermissionAllow),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (allow == true) {
      await _store.requestProcessingNotifications();
    } else {
      await _store.declineProcessingNotifications();
    }
    if (mounted) _store.next();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Observer(
      builder: (_) {
        final step = _store.step;
        final VoidCallback? primaryAction = step == OnboardingStep.speech
            ? (_store.isBusy || !_store.modelReady ? null : _store.next)
            : step == OnboardingStep.formatting
            ? (_store.isBusy ? null : _store.next)
            : step == OnboardingStep.embedding
            ? (_store.isBusy
                  ? null
                  : _store.embeddingModelReady
                  ? () => _finish()
                  : _store.downloadModel)
            : (_store.isBusy
                  ? null
                  : step == OnboardingStep.language
                  ? _continueFromLanguage
                  : _store.next);
        final primaryLabel = step == OnboardingStep.embedding
            ? (_store.embeddingModelReady
                  ? l10n.onboardingStart
                  : l10n.onboardingModelDownload)
            : step == OnboardingStep.formatting
            ? (_store.formattingReady
                  ? l10n.onboardingContinue
                  : l10n.onboardingFormattingSkip)
            : l10n.onboardingContinue;
        return PopScope(
          canPop:
              widget.fromSettings ||
              (step == OnboardingStep.welcome && !_store.isBusy),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _store.back();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.appTitle),
              automaticallyImplyLeading: false,
              leading: step != OnboardingStep.welcome
                  ? IconButton(
                      tooltip: l10n.onboardingBack,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _store.isBusy ? null : _store.back,
                    )
                  : null,
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: SingleChildScrollView(
                          key: ValueKey(step),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.xl,
                            AppSpacing.xl,
                            AppSpacing.lg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.onboardingProgress(step.index + 1),
                                style: text.labelMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              LinearProgressIndicator(
                                value:
                                    (step.index + 1) /
                                    OnboardingStep.values.length,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                switch (step) {
                                  OnboardingStep.welcome =>
                                    l10n.onboardingWelcomeTitle,
                                  OnboardingStep.language =>
                                    l10n.onboardingLanguageTitle,
                                  OnboardingStep.speech =>
                                    l10n.onboardingModelTitle,
                                  OnboardingStep.formatting =>
                                    l10n.onboardingFormattingTitle,
                                  OnboardingStep.embedding =>
                                    l10n.onboardingEmbeddingTitle,
                                },
                                style: step == OnboardingStep.welcome
                                    ? text.headlineLarge
                                    : text.headlineSmall,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (step == OnboardingStep.welcome) ...[
                                Text(
                                  l10n.onboardingWelcomeBody,
                                  style: text.bodyLarge,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                _Explanation(
                                  icon: Icons.mic_none_outlined,
                                  title: l10n.onboardingCaptureTitle,
                                  body: l10n.onboardingCaptureBody,
                                ),
                                _Explanation(
                                  icon: Icons.notes_outlined,
                                  title: l10n.onboardingNoteTitle,
                                  body: l10n.onboardingNoteBody,
                                ),
                                _Explanation(
                                  icon: Icons.phone_android_outlined,
                                  title: l10n.onboardingLocalTitle,
                                  body: l10n.onboardingLocalBody,
                                ),
                              ],
                              if (step == OnboardingStep.language) ...[
                                Text(
                                  l10n.onboardingLanguageBody,
                                  style: text.bodyLarge,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      audioLanguageOptions.containsKey(
                                        _store.audioLanguage,
                                      )
                                      ? _store.audioLanguage
                                      : '',
                                  isExpanded: true,
                                  itemHeight: null,
                                  decoration: InputDecoration(
                                    labelText: l10n.audioLanguage,
                                  ),
                                  items:
                                      <String, String>{
                                            '': l10n.audioLanguageAutomatic,
                                            ...audioLanguageOptions,
                                          }.entries
                                          .map(
                                            (entry) => DropdownMenuItem(
                                              value: entry.key,
                                              child: Text(entry.value),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: _store.isBusy
                                      ? null
                                      : (value) => _store.selectLanguage(
                                          value == '' ? null : value,
                                        ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  l10n.onboardingUiLanguage,
                                  style: text.bodyMedium,
                                ),
                              ],
                              if (step == OnboardingStep.speech) ...[
                                Text(
                                  l10n.speechModelsIntro,
                                  style: text.bodyLarge,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                SpeechModelCatalog(store: _store.speech),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  l10n.speechModelEmbeddingSeparate,
                                  style: text.bodyMedium,
                                ),
                              ],
                              if (step == OnboardingStep.formatting) ...[
                                Text(
                                  l10n.onboardingFormattingBody,
                                  style: text.bodyLarge,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                FormattingModelCatalog(
                                  store: _store.formatting,
                                ),
                              ],
                              if (step == OnboardingStep.embedding) ...[
                                if (_store.embeddingChecking) ...[
                                  const LinearProgressIndicator(),
                                  Text(l10n.onboardingModelVerifying),
                                ],
                                ModelDownloadNotice(store: _store.downloads),
                                Text(
                                  l10n.onboardingEmbeddingBody,
                                  style: text.bodyLarge,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                Text(
                                  _store.model.name,
                                  style: text.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  l10n.onboardingEmbeddingSize(
                                    (_store.model.bytes / 1000000)
                                        .toStringAsFixed(1),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                if (_store.currentModelReady)
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(l10n.onboardingEmbeddingReady),
                                  )
                                else if (_store.embeddingTransferState ==
                                    ModelTransferState.cancelled)
                                  Text(l10n.modelDownloadCancelled)
                                else if (_store.isDownloading) ...[
                                  LinearProgressIndicator(
                                    value:
                                        _store.downloadedBytes ==
                                            _store.model.bytes
                                        ? null
                                        : _store.downloadProgress,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _store.downloadedBytes ==
                                              _store.model.bytes
                                          ? l10n.onboardingModelVerifying
                                          : l10n.onboardingModelProgress(
                                              (_store.downloadProgress * 100)
                                                  .floor(),
                                            ),
                                    ),
                                  ),
                                ],
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              if (_store.error != null) ...[
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    switch (_store.error!) {
                                      OnboardingFailure.load =>
                                        l10n.onboardingLoadFailed,
                                      OnboardingFailure.save =>
                                        l10n.onboardingSaveFailed,
                                      OnboardingFailure.modelDownload =>
                                        l10n.onboardingModelFailed,
                                    },
                                    style: text.bodyMedium?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              if (_store.isBusy && !_store.isDownloading) ...[
                                const LinearProgressIndicator(),
                                const SizedBox(height: AppSpacing.md),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.md,
                          AppSpacing.xl,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_store.error == OnboardingFailure.load)
                              FilledButton(
                                onPressed: _store.isBusy ? null : _store.load,
                                child: Text(l10n.retry),
                              )
                            else
                              FilledButton(
                                onPressed: primaryAction,
                                child: Text(primaryLabel),
                              ),
                            if (_store.isDownloading)
                              TextButton(
                                onPressed: _store.cancelDownload,
                                child: Text(l10n.cancel),
                              ),
                            if (_store.canBrowseJournal)
                              TextButton(
                                onPressed: _store.isBusy
                                    ? null
                                    : () async {
                                        _store.browseJournal();
                                        await _leaveSetup();
                                      },
                                child: Text(l10n.browseJournal),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );
}
