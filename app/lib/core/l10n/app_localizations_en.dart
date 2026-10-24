// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get embeddingCatalogTitle => 'Available models';

  @override
  String get embeddingModelsTitle => 'Search model';

  @override
  String get embeddingModelConfirm => 'Continue';

  @override
  String embeddingModelSwitchTitle(String modelName) {
    return 'Use $modelName?';
  }

  @override
  String get embeddingModelActiveTitle => 'Active model';

  @override
  String get embeddingModelCheckingSelection => 'Checking active model…';

  @override
  String get embeddingModelReady => 'Ready';

  @override
  String get embeddingModelDownloadNeeded => 'Download needed';

  @override
  String get embeddingModelRepairNeeded => 'Needs repair';

  @override
  String get embeddingModelManage => 'Manage search model';

  @override
  String get embeddingModelsUnavailable => 'Unavailable models';

  @override
  String get embeddingModelSwitchingFromActive =>
      'Your current model stays active until the new one is ready.';

  @override
  String get embeddingModelTermsTitle => 'Gemma Terms of Use';

  @override
  String get embeddingModelTermsMessage =>
      'By continuing, you agree to the Gemma Terms of Use below, including the use restrictions in section 3.2 and the incorporated Prohibited Use Policy. Model installation does not upload your journal.';

  @override
  String get embeddingModelDownloading => 'Downloading…';

  @override
  String get embeddingCatalogHelp =>
      'Install more than one model and choose which one powers search by meaning. Changing models rebuilds the semantic index; your notes and word search stay available.';

  @override
  String get embeddingModelSwitching =>
      'Preparing the new search model. You can keep using your journal.';

  @override
  String get embeddingModelSwitchConfirmation =>
      'Changing the search model rebuilds the semantic index in the background. Your notes, recordings and word search are preserved. Meaning-based results may be incomplete until indexing finishes.';

  @override
  String get embeddingModelActivationFailed =>
      'Could not activate this search model. The previous model and index are unchanged.';

  @override
  String get embeddingModelRemovalFailed =>
      'Could not remove this model. Select a different active model first and try again.';

  @override
  String get embeddingModelUnsupported =>
      'Not available yet: runtime compatibility and search quality must be validated first.';

  @override
  String get embeddingModelE5Unavailable =>
      'Not available yet: tested GGUF conversions did not pass multilingual retrieval validation.';

  @override
  String embeddingModelDimensions(int count) {
    return '$count dimensions';
  }

  @override
  String get embeddingModelSelect => 'Use model';

  @override
  String get embeddingModelVerify => 'Verify';

  @override
  String get embeddingModelDownload => 'Download';

  @override
  String get embeddingModelResume => 'Resume';

  @override
  String get embeddingModelDeleteConfirmation =>
      'Remove the downloaded search model? Your notes and recordings will not be deleted.';

  @override
  String get writeNote => 'Write a note';

  @override
  String get discardNewNoteTitle => 'Discard this new note?';

  @override
  String get resumeNewNoteTitle => 'Resume your note?';

  @override
  String get resumeNewNoteHelp => 'An unfinished note is saved on this device.';

  @override
  String get resumeNewNoteConflictHelp =>
      'Another saved entry uses this note\'s identifier. Resume to keep your draft as a separate new note; the saved entry will not change.';

  @override
  String get resumeNewNote => 'Resume note';

  @override
  String get newNoteTitle => 'New note';

  @override
  String get continueToNote => 'Continue';

  @override
  String get noteBodyRequired => 'Write something before saving your note.';

  @override
  String get originalText => 'Original text';

  @override
  String get restoreOriginalText => 'Restore original text';

  @override
  String get restoreOriginalTextConfirmation =>
      'Replace the current note with its original text?';

  @override
  String get journalSelectEntry => 'Select an entry';

  @override
  String get journalSelectEntryHelp =>
      'Choose a thought from your journal, or record a new one.';

  @override
  String get editorExpand => 'Expand editor';

  @override
  String get editorRestore => 'Show journal alongside editor';

  @override
  String get journalMaintenance => 'Updating local search…';

  @override
  String get appTitle => 'SmartNotes';

  @override
  String get saveNoteTitle => 'Save note';

  @override
  String get noteDetailsOptional => 'Title and subtitle are optional.';

  @override
  String get backToEditing => 'Back to editing';

  @override
  String get markdownSupported => 'Supports Markdown';

  @override
  String get markdownHelpTitle => 'Formatting help';

  @override
  String get markdownHelpBody =>
      'Write plain text or use Markdown:\n\n# Heading\n## Subheading\n**Bold**\n*Italic*\n- List item\n1. Numbered item\n[Link text](https://example.com)\n\nFormatting appears in the saved note.';

  @override
  String get noteEditHint => 'Write your note here…';

  @override
  String get modelDownloadNotificationChannel => 'Model downloads';

  @override
  String get modelDownloadNotificationRunning => 'Downloading model';

  @override
  String get modelDownloadNotificationVerifying => 'Verifying model…';

  @override
  String get modelDownloadNotificationComplete => 'Model ready';

  @override
  String get modelDownloadNotificationFailed =>
      'Download failed. Open SmartNotes to retry.';

  @override
  String get modelDownloadNotificationStarted => 'Model download started';

  @override
  String get modelDownloadNotificationCancel => 'Cancel';

  @override
  String get modelDownloadCancelled =>
      'Download cancelled — tap download to resume';

  @override
  String get modelDownloadBackgroundHint =>
      'Downloads continue when you leave the app or lock your phone. On iOS, do not force-quit SmartNotes.';

  @override
  String get modelDownloadNotificationsDenied =>
      'Downloads still continue in the background. Notifications are off, so check progress here or enable notifications in your device settings.';

  @override
  String get processingNotificationChannel => 'Note processing';

  @override
  String get processingNotificationTitle => 'Processing note';

  @override
  String get processingNoteReadyTitle => 'Note ready';

  @override
  String get processingPreparingTranscription => 'Preparing transcription…';

  @override
  String get processingTranscribingAudio => 'Transcribing audio…';

  @override
  String get processingPreparingSearch => 'Preparing for search…';

  @override
  String get processingFinalizing => 'Finalizing…';

  @override
  String processingLoadingModel(String modelName) {
    return 'Loading $modelName';
  }

  @override
  String processingRunningModel(String modelName) {
    return 'Running $modelName';
  }

  @override
  String processingCreatingEmbeddings(String modelName) {
    return 'Creating embeddings with $modelName';
  }

  @override
  String get processingReleasingModels => 'Releasing models from memory';

  @override
  String get notificationPermissionTitle => 'Follow your notes as they process';

  @override
  String get notificationPermissionBody =>
      'SmartNotes uses silent notifications to show when it is downloading models, transcribing audio, preparing notes for search, and releasing models from memory. Your note content never appears in notifications.';

  @override
  String get notificationPermissionAllow => 'Allow notifications';

  @override
  String get speechModelsTitle => 'Transcription models';

  @override
  String get speechModelAvailable => 'Available to download';

  @override
  String get speechModelsIntro =>
      'Choose one or more models to download. Only one runs at a time, on this device. You can manage them later in Settings.';

  @override
  String get speechModelsManageIntro =>
      'Download, select, or remove transcription models. Changing models does not change saved notes.';

  @override
  String get speechModelRecommended => 'Recommended for this device';

  @override
  String get speechModelActive => 'Active model';

  @override
  String get speechModelActiveUnavailable =>
      'Your active model is missing, damaged, or incompatible with the current audio language. Choose a verified compatible model.';

  @override
  String get speechModelInstalled => 'Installed';

  @override
  String get speechModelEnglish => 'English only';

  @override
  String speechModelMultilingual(String language) {
    return 'Multilingual — includes $language';
  }

  @override
  String get speechModelAutomatic =>
      'Multilingual — automatic language detection';

  @override
  String get speechModelIncompatible =>
      'Cannot be active for the selected audio language. You may download it for later.';

  @override
  String get speechModelLanguages => 'Supported languages';

  @override
  String get speechModelAllLanguages =>
      'Afrikaans, Albanian, Amharic, Arabic, Armenian, Assamese, Azerbaijani, Bashkir, Basque, Belarusian, Bengali, Bosnian, Breton, Bulgarian, Burmese, Catalan, Chinese, Croatian, Czech, Danish, Dutch, English, Estonian, Faroese, Finnish, French, Galician, Georgian, German, Greek, Gujarati, Haitian Creole, Hausa, Hawaiian, Hebrew, Hindi, Hungarian, Icelandic, Indonesian, Italian, Japanese, Javanese, Kannada, Kazakh, Khmer, Korean, Lao, Latin, Latvian, Lingala, Lithuanian, Luxembourgish, Macedonian, Malagasy, Malay, Malayalam, Maltese, Maori, Marathi, Mongolian, Nepali, Norwegian, Nynorsk, Occitan, Pashto, Persian, Polish, Portuguese, Punjabi, Romanian, Russian, Sanskrit, Serbian, Shona, Sindhi, Sinhala, Slovak, Slovenian, Somali, Spanish, Sundanese, Swahili, Swedish, Tagalog, Tajik, Tamil, Tatar, Telugu, Thai, Tibetan, Turkish, Turkmen, Ukrainian, Urdu, Uzbek, Vietnamese, Welsh, Yiddish, Yoruba.';

  @override
  String get speechModelCantonese => 'Also supports Cantonese.';

  @override
  String speechModelLanguageDetails(String codes) {
    return 'Supported language codes: $codes';
  }

  @override
  String get speechModelBaseBenefit =>
      'Smallest download. An economical starting point, with lower recognition capacity.';

  @override
  String get speechModelSmallEnglishBenefit =>
      'Dedicated English weights with moderate model size. A balance of quality and processing cost.';

  @override
  String get speechModelMediumEnglishBenefit =>
      'More capacity for English recognition. Heavier CPU processing than Small.en.';

  @override
  String get speechModelSmallBenefit =>
      'More recognition capacity than Base, with a moderate download. A balanced multilingual option.';

  @override
  String get speechModelTurboBenefit =>
      'Large-v3 audio encoder with a smaller text decoder. A high-quality transcription candidate at lower decoding cost than full Large-v3.';

  @override
  String get speechModelLargeBenefit =>
      'Full Large-v3 model for prioritizing fidelity over processing cost. Not guaranteed to outperform Turbo on every recording.';

  @override
  String get speechModelHeavyWarning =>
      'Heavy CPU processing: may be slow, warm the device, or exceed available memory.';

  @override
  String get speechModelEstimateUnknown =>
      'Hardware information is incomplete. We suggest the smallest model conservatively.';

  @override
  String get speechModelEstimateEconomical =>
      'Based on available memory and CPU architecture, we suggest a smaller model.';

  @override
  String get speechModelEstimateBalanced =>
      'Based on available memory and CPU architecture, we suggest a balanced model for your audio language.';

  @override
  String get speechModelEstimatePowerful =>
      'This hardware profile qualifies for a larger model for your audio language.';

  @override
  String get speechModelEstimateDisclaimer =>
      'This is a hardware estimate, not a speed or memory guarantee. All models use the CPU; download size is not RAM usage.';

  @override
  String speechModelStorageSummary(String size) {
    return 'Model files and partial downloads use $size.';
  }

  @override
  String get speechModelEmbeddingSeparate =>
      'Offline search requires a separate 639 MB download in the next step.';

  @override
  String get speechModelQueued => 'Waiting to download';

  @override
  String get speechModelCancelled => 'Cancelled — tap download to resume';

  @override
  String get speechModelFailed => 'Download failed — tap download to retry';

  @override
  String get speechModelDownload => 'Download';

  @override
  String get speechModelRetry => 'Retry download';

  @override
  String get speechModelResumeDownload => 'Resume download';

  @override
  String get speechModelResume => 'Download paused — tap download to resume';

  @override
  String get speechModelActivating => 'Activating model…';

  @override
  String get speechModelActiveDeleteHint =>
      'Select another model before deleting the active model';

  @override
  String get speechModelRemoveTitle => 'Remove model files?';

  @override
  String get speechModelRemoveBody =>
      'These downloaded files will be removed. Notes and recordings stay unchanged. Select a replacement before removing the active model.';

  @override
  String get speechModelStorageError =>
      'Not enough free storage. Free some space or select fewer models, then retry.';

  @override
  String get speechModelInUseError =>
      'Select a compatible installed replacement before removing the active model. A model being downloaded cannot be removed.';

  @override
  String get speechModelLastError =>
      'Keep at least one installed model compatible with your audio language.';

  @override
  String get speechModelSelectError =>
      'Choose a verified model that supports your audio language.';

  @override
  String get speechModelLoadError =>
      'Could not load model information. Retry; your saved notes are unchanged.';

  @override
  String get speechModelLanguageChange =>
      'Choose a model for the new audio language. Your previous language and model stay active until you select Use this model.';

  @override
  String get formattingModelsTitle => 'Formatting models';

  @override
  String get formattingModelsManageIntro =>
      'Formatting models organize a note with AI on this device. Formatting is optional; install one and select it, or remove it later.';

  @override
  String get formattingModelRecommended => 'Recommended for this device';

  @override
  String get formattingModelActive => 'Active';

  @override
  String get formattingModelActiveUnavailable =>
      'The selected formatting model is missing or corrupt. Download it again or select another.';

  @override
  String get formattingModelInstalled => 'Installed';

  @override
  String get formattingModelAvailable => 'Not downloaded';

  @override
  String get formattingModelQueued => 'Waiting to download';

  @override
  String get formattingModelCancelled =>
      'Download cancelled — tap download to resume';

  @override
  String get formattingModelFailed => 'Download failed — tap download to retry';

  @override
  String get formattingModelResume =>
      'Download paused — tap download to resume';

  @override
  String get formattingModelDownload => 'Download';

  @override
  String get formattingModelRetry => 'Retry download';

  @override
  String get formattingModelResumeDownload => 'Resume download';

  @override
  String get formattingModelActivating => 'Selecting model…';

  @override
  String get formattingModelActiveDeleteHint =>
      'Select another model before removing this one';

  @override
  String get formattingModelRemoveTitle => 'Remove formatting model?';

  @override
  String get formattingModelRemoveBody =>
      'The model is deleted from this device. Your notes and transcriptions stay. You can download it again later.';

  @override
  String get formattingModelStorageError =>
      'Not enough free storage. Free some space, then retry.';

  @override
  String get formattingModelInUseError =>
      'Select another formatting model before removing the active one.';

  @override
  String get formattingModelSelectError =>
      'Could not select this model. Choose a verified formatting model.';

  @override
  String formattingModelStorageSummary(String size) {
    return 'Formatting models use $size.';
  }

  @override
  String get formattingModelEstimateUnknown =>
      'Hardware information is incomplete. The lighter model is suggested conservatively.';

  @override
  String get formattingModelEstimateEconomical =>
      'Based on available memory, the lighter model is recommended for this device.';

  @override
  String get formattingModelEstimateBalanced =>
      'Based on available memory, the balanced model is recommended for this device.';

  @override
  String get formattingModelEstimateDisclaimer =>
      'Recommendations are estimates based on device memory, not benchmarks. Both models run offline.';

  @override
  String get formattingModelCapabilities => 'Capabilities';

  @override
  String get formattingModelInfo => 'Model capabilities';

  @override
  String get formattingModelLanguages => 'Languages';

  @override
  String get formattingModelAllLanguages =>
      'Multilingual, including Portuguese and English';

  @override
  String get formattingModelCapabilityLight =>
      'Fastest and smallest. Best for short notes and low-memory devices; may omit details on long or complex notes.';

  @override
  String get formattingModelCapabilityBalanced =>
      'Better structure and fidelity. Recommended for most devices.';

  @override
  String get formattingModelMemoryLight => 'Uses less memory.';

  @override
  String get formattingModelMemoryBalanced =>
      'Uses more memory and may be slower on low-memory devices.';

  @override
  String get formattingModelNoteLimit =>
      'Formats notes within the app\'s 4,096-token budget.';

  @override
  String get formattingModelLicense => 'License';

  @override
  String get formattingModelNeededTitle => 'Formatting model needed';

  @override
  String get formattingModelNeededBody =>
      'AI actions run on your device and need a formatting model. Download and select one in Settings. Your note is not sent anywhere.';

  @override
  String get formattingModelNeededSettings => 'Go to settings';

  @override
  String get notNow => 'Not now';

  @override
  String onboardingProgress(int step) {
    return 'Step $step of 5';
  }

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingStart => 'Open my journal';

  @override
  String get onboardingWelcomeTitle => 'A journal for your spoken thoughts';

  @override
  String get onboardingWelcomeBody =>
      'Capture an idea while it is fresh. SmartNotes turns your voice into a note you can return to.';

  @override
  String get onboardingCaptureTitle => 'Tap, speak, tap to stop';

  @override
  String get onboardingCaptureBody =>
      'Record a thought or reflection. Your original recording is kept for playback and retry.';

  @override
  String get onboardingNoteTitle => 'From speech to a readable note';

  @override
  String get onboardingNoteBody =>
      'Whisper transcribes your recording into an editable note on this device. Your own words are saved first; organize them with AI later if you choose.';

  @override
  String get onboardingLocalTitle => 'Your journal lives on this device';

  @override
  String get onboardingLocalBody =>
      'No account or cloud sync. Text search works offline. Export backups regularly: uninstalling the app can erase your journal. Notes and recordings are not encrypted by the app.';

  @override
  String get onboardingLanguageTitle => 'What language do you speak?';

  @override
  String get onboardingLanguageBody =>
      'Let Whisper detect your language, or select it for more predictable results with short or noisy recordings. Transcription stays in the language you speak. You can change this in Settings.';

  @override
  String get onboardingModelTitle => 'Download offline transcription';

  @override
  String get onboardingFormattingTitle =>
      'Choose a formatting model (optional)';

  @override
  String get onboardingFormattingBody =>
      'A formatting model lets you organize a note with AI on this device. You can skip this step and install one later in Settings. Your words stay on this device.';

  @override
  String get onboardingFormattingSkip => 'Continue without formatting';

  @override
  String get onboardingEmbeddingTitle => 'Download offline search by meaning';

  @override
  String get onboardingEmbeddingBody =>
      'This required 639 MB model helps find your notes by meaning, including across languages. Use Wi-Fi and allow enough free storage. After setup, recording, transcription and both search modes work without internet. Notes are indexed in the background. Optional AI organization is offered in the previous step and can be installed later in Settings.';

  @override
  String get onboardingEmbeddingReady =>
      'Model verified. Offline search by meaning is ready.';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get appLockSummary =>
      'Protects access to the app, not the files on your device.';

  @override
  String get settingsVoiceAndAI => 'Voice and local AI';

  @override
  String get settingsYourJournal => 'Your journal';

  @override
  String get transcriptionSettingsTitle => 'Transcription';

  @override
  String get aiOrganizationTitle => 'AI organization';

  @override
  String get aiOrganizationNotConfigured => 'Optional · Not configured';

  @override
  String get searchSettingsTitle => 'Search by meaning';

  @override
  String get searchUpToDate => 'Search is up to date';

  @override
  String get searchSettingsHelp =>
      'Find entries by meaning, even when you use different words. Processing stays on this device.';

  @override
  String get searchMaintenanceHelp =>
      'Update pending or failed entries to complete search results. For large journals, keep the app open while indexing.';

  @override
  String get advancedSettings => 'Advanced';

  @override
  String get backupSettingsTitle => 'Backup and restore';

  @override
  String get backupSettingsSummary =>
      'Export or import your notes and recordings';

  @override
  String get transcriptionRecoveryHelp =>
      'Retry recordings that have not finished transcribing. Existing notes are kept.';

  @override
  String get transcriptionRecoveryDone =>
      'Pending recordings have been queued for transcription.';

  @override
  String get offlineModels => 'Offline AI models';

  @override
  String get offlineModelsBody =>
      'Transcription: select and manage Whisper models in Settings.\nFormatting: choose an optional AI organization model in Settings.\nSearch: install and select an embedding model in Search by meaning settings.\nInternet is only needed to download or repair models; notes and queries stay on this device.';

  @override
  String get aiPreviewTitle => 'Preview AI changes';

  @override
  String get aiPreviewHelp =>
      'Nothing changes until Apply. Compare your current words with this preview. Your original transcription and recording are kept.';

  @override
  String get previewLabel => 'Preview';

  @override
  String get latestSavedEntry => 'Latest saved entry';

  @override
  String get aiChangesApplied => 'Changes applied';

  @override
  String get aiChangesUndone => 'Previous note restored';

  @override
  String get undo => 'Undo';

  @override
  String get reloadAiDraftHelp =>
      'Reloading discards this AI draft and generates a new one from the latest saved entry. Copy this draft first if you want to keep it.';

  @override
  String get aiReplaceMetadata => 'Also replace the title and subtitle';

  @override
  String get aiApply => 'Apply';

  @override
  String get aiDiscard => 'Discard';

  @override
  String get aiRegenerate => 'Reload note and try again';

  @override
  String get aiDraftConflict =>
      'Could not save these changes. The note may have changed or been deleted. Reload before trying again; saved content has not been replaced.';

  @override
  String get originalTranscription => 'Original transcription';

  @override
  String get restoreTranscription => 'Restore original transcription';

  @override
  String get restoreTranscriptionConfirmation =>
      'Replace the current note with the original transcription? Current edits will be replaced. The title, subtitle, and recording will be kept.';

  @override
  String get modelSetup => 'Check model setup';

  @override
  String get browseJournal => 'Browse my existing journal';

  @override
  String get embeddingModelMissing =>
      'The offline search model is missing or damaged. Open Search model in Settings to repair or replace it. Word search and saved notes are still available.';

  @override
  String get indexIncomplete =>
      'Search by meaning is incomplete while notes are pending or failed. Text search still covers your saved notes.';

  @override
  String indexStatus(int indexed, int pending, int failed) {
    return 'Indexed: $indexed · Pending: $pending · Failed: $failed';
  }

  @override
  String get aiNoteTooLong =>
      'This transcript is too long for offline formatting. Your recording and transcript are saved. Shorten the recording for a new note; no text was sent to a server.';

  @override
  String onboardingModelSize(String size) {
    return '$size MB download · multilingual · stored on this device';
  }

  @override
  String get onboardingModelDownload => 'Download model';

  @override
  String onboardingModelProgress(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get onboardingModelVerifying => 'Verifying model…';

  @override
  String onboardingEmbeddingSize(String size) {
    return '$size MB download · stored on this device';
  }

  @override
  String get onboardingModelFailed =>
      'Could not prepare the model. Check your connection and free storage, then download again. An interrupted download can resume.';

  @override
  String get onboardingUiLanguage =>
      'This selects the audio language, not the interface language. The app interface is currently English.';

  @override
  String get onboardingLoadFailed =>
      'Could not load your settings or model readiness. Please retry.';

  @override
  String get onboardingSaveFailed =>
      'Could not finish setup. Your journal is safe. Please retry.';

  @override
  String get journalTitle => 'Journal';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get recordButtonHint => 'Tap to record';

  @override
  String get stopRecordingHint => 'Tap to stop';

  @override
  String get emptyStateTitle => 'Your journal is empty';

  @override
  String get emptyStateMessage =>
      'Tap the button below to record your first note.';

  @override
  String get settings => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get share => 'Share';

  @override
  String get deleteConfirmationTitle => 'Delete entry?';

  @override
  String get deleteConfirmationMessage => 'This action cannot be undone.';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get audioLanguage => 'Audio language';

  @override
  String get audioLanguageAutomatic => 'Automatic';

  @override
  String get appLanguage => 'App language';

  @override
  String get processing => 'Processing';

  @override
  String get completed => 'Completed';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Retry';

  @override
  String get reformat => 'Reformat';

  @override
  String get close => 'Close';

  @override
  String get aiActionsTitle => 'Organize with AI';

  @override
  String get aiPreparingModel => 'Preparing the offline model…';

  @override
  String get aiModelCheckFailed =>
      'Could not check the offline formatting model. Your note is unchanged. Try again.';

  @override
  String get aiActionProcessing => 'Transforming note…';

  @override
  String get aiActionFailedTitle => 'Could not transform note';

  @override
  String get aiActionFailedMessage =>
      'Your current note was not changed. Try again?';

  @override
  String get aiActionOrganizedNoteTitle => 'Organize';

  @override
  String get aiActionOrganizedNoteDescription =>
      'Create a clear, well-structured note while preserving details and tone.';

  @override
  String get aiActionJournalEntryTitle => 'Journal style';

  @override
  String get aiActionJournalEntryDescription =>
      'Rewrite the current note as a personal narrative, without adding facts or reflections.';

  @override
  String get aiActionKeyPointsTitle => 'Key points';

  @override
  String get aiActionKeyPointsDescription =>
      'Group ideas, tasks, and decisions into concise bullet points.';

  @override
  String get aiActionFormalSummaryTitle => 'Formal summary';

  @override
  String get aiActionFormalSummaryDescription =>
      'Create an objective, professional, structured record.';

  @override
  String get aiActionCasualRecapTitle => 'Casual recap';

  @override
  String get aiActionCasualRecapDescription =>
      'Create a light, direct, conversational recap.';

  @override
  String get aiActionFaithfulTranscriptionTitle => 'Clean up wording';

  @override
  String get aiActionFaithfulTranscriptionDescription =>
      'Clean up the current text into paragraphs, keeping its order and meaning. This does not retranscribe the recording.';

  @override
  String get originalRecording => 'Original recording';

  @override
  String get listenOriginal => 'Original';

  @override
  String listenOriginalDuration(String duration) {
    return 'Original · $duration';
  }

  @override
  String get playRecording => 'Play recording';

  @override
  String get pauseRecording => 'Pause recording';

  @override
  String get seekRecording => 'Recording position';

  @override
  String get recordingUnavailable =>
      'Original recording is unavailable. You can still read and edit your note.';

  @override
  String get recordingPlaybackFailed =>
      'Could not play this recording. Your saved note is unchanged.';

  @override
  String get durationUnknown => 'Duration unavailable';

  @override
  String get entryDetails => 'Entry details';

  @override
  String get currentEntry => 'Saved entry';

  @override
  String get yourEdits => 'Your edits';

  @override
  String get reloadReplacesDraft =>
      'Reloading replaces this editing draft with the saved entry. Copy your edits first if you want to keep them.';

  @override
  String get unsavedChanges => 'Save your changes?';

  @override
  String get unsavedChangesHelp => 'Your saved entry has not changed.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get resumeDraftTitle => 'Resume your edits?';

  @override
  String get resumeDraftHelp =>
      'There are unfinished edits saved on this device.';

  @override
  String get resumeDraft => 'Resume edits';

  @override
  String get draftRecoveryFailed =>
      'Could not load your editing draft. Retry before editing so it is not overwritten.';

  @override
  String get discardRecoveryDraft => 'Discard recovery draft';

  @override
  String get discardRecoveryDraftHelp =>
      'Permanently remove these unfinished edits from this device? Your saved journal entry will not change.';

  @override
  String get draftSaveFailed =>
      'Could not keep a recovery draft. Keep this screen open and save your changes before leaving.';

  @override
  String get draftChangedHelp =>
      'The saved entry changed since these edits began. Compare or copy your edits before choosing a new starting point.';

  @override
  String get copyEdits => 'Copy edits';

  @override
  String get editsCopied => 'Edits copied';

  @override
  String get compareSaved => 'Compare saved entry';

  @override
  String get useLatestEntry => 'Use saved entry as starting point';

  @override
  String get entryChangedHelp =>
      'This entry changed. Your draft is still here. Compare or copy it before reloading the saved entry.';

  @override
  String get entryDeletedHelp =>
      'This entry was deleted. Your draft has not been applied. You can still copy it.';

  @override
  String get entryBusyHelp =>
      'Another operation is using this entry. Wait a moment, then retry.';

  @override
  String get entryStorageHelp =>
      'Could not save to this device. Your draft is still here. Check available storage and retry.';

  @override
  String get entryChangedWithoutDraft =>
      'This entry changed. Reload the saved entry before trying again. No changes were applied.';

  @override
  String get entryDeletedWithoutDraft =>
      'This entry was deleted. No changes were applied.';

  @override
  String get entryStorageWithoutDraft =>
      'Could not save to this device. No changes were applied. Check available storage and retry.';

  @override
  String get reloadEntry => 'Reload entry';

  @override
  String get emptyEntry =>
      'This note is empty. You can edit it or revisit the original transcription.';

  @override
  String get deletingEntry => 'Deleting entry…';

  @override
  String get savingEntry => 'Saving changes…';

  @override
  String get transcriptionFailedHelp =>
      'Transcription could not finish. Your available recording and words are kept here.';

  @override
  String get entryNotFound => 'Entry not found';

  @override
  String get failedToLoadEntry => 'Failed to load entry';

  @override
  String get failedToSaveChanges =>
      'Could not save. Your edits are still here. The saved note may have changed; copy your edits before reopening it.';

  @override
  String get failedToDeleteEntry => 'Failed to delete entry';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get processingFailed => 'Processing failed';

  @override
  String get editEntryTitle => 'Edit entry';

  @override
  String get titleLabel => 'Title';

  @override
  String get subtitleLabel => 'Subtitle';

  @override
  String get entryDateLabel => 'Entry date';

  @override
  String get noteLabel => 'Note';

  @override
  String get searchHint => 'Search notes';

  @override
  String get entryDeleted => 'Entry deleted';

  @override
  String get noSearchResults => 'No entries match your search';

  @override
  String get preferencesTitle => 'Preferences';

  @override
  String get processingSearchTitle => 'Processing and search';

  @override
  String get processingSearchHelp =>
      'Retry unfinished recordings or update search by meaning on this device. Large libraries may take time to index; keep the app open.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get indexFailed =>
      'Indexing could not finish. Notes are safe; check model setup, then retry.';

  @override
  String get exportFailed =>
      'Could not export the journal. Backups are limited to 100 MB.';

  @override
  String get importFailed =>
      'Could not import this backup. Existing notes were not changed.';

  @override
  String get aiUnavailable =>
      'AI processing could not complete. Please retry. Your saved content is unchanged.';

  @override
  String get aiFormattingModelMissing =>
      'This note needs a formatting model. Download and select one in Settings.';

  @override
  String get aiNoSpeech =>
      'No speech was detected. Your recording is still saved.';

  @override
  String get recordingNoSpeech => 'No speech detected. Try recording again.';

  @override
  String get aiIncompleteNote =>
      'The local model did not finish formatting within its token limit. Your transcription is saved; retry.';

  @override
  String get aiInvalidNote =>
      'The local model returned an invalid note. Your transcription is saved; retry.';

  @override
  String get aiInvalidEmbedding =>
      'The local model could not produce a valid search vector. Your notes are unchanged; retry or check model setup.';

  @override
  String get aiQueryTooLong =>
      'This query exceeds the offline search token or length limit. Try a shorter query.';

  @override
  String get aiBusy => 'This note is already being processed. Please wait.';

  @override
  String get indexNotes => 'Index pending notes';

  @override
  String get rebuildIndex => 'Rebuild search index';

  @override
  String get rebuildIndexMessage =>
      'This discards the derived search index and rebuilds it locally. Search by meaning will be incomplete until finished; notes and text search are unaffected. Continue?';

  @override
  String get indexComplete => 'Search index is up to date';

  @override
  String get retryRecordings => 'Retry pending recordings';

  @override
  String get localData => 'Local journal';

  @override
  String get localDataPrivacy =>
      'There is no cloud sync or automatic Android backup. Export regularly: uninstalling the app or losing this device can lose your journal. The database and audio files are not encrypted by the app; the optional app lock protects the interface only.';

  @override
  String get exportJournal => 'Export journal';

  @override
  String get importJournal => 'Import journal';

  @override
  String get backupPrivacy =>
      'Backups contain readable notes and recordings, not AI models or the derived search index. Store them somewhere safe. Backup files are limited to 100 MB.';

  @override
  String get importConfirmation =>
      'Notes with matching IDs will be replaced. The search index can be rebuilt afterwards. Import this backup?';

  @override
  String get backupExported => 'Journal exported';

  @override
  String get backupImported => 'Journal imported';

  @override
  String get backupFailed =>
      'Could not open or save the backup file. Please retry.';

  @override
  String get textSearch => 'Text';

  @override
  String get embeddingModelSelectionHelp =>
      'Find journal entries by meaning, entirely on this device.';

  @override
  String get semanticSearch => 'Semantic';

  @override
  String get semanticSearchHint => 'Describe what you are looking for';

  @override
  String get semanticSearchReady => 'Tap Search to find entries by meaning.';

  @override
  String get searchSourceTitle => 'Title';

  @override
  String get searchSourceNote => 'Note';

  @override
  String get searchSourceOriginal => 'Original transcription';

  @override
  String get searchRelatedByMeaning => 'Related by meaning';

  @override
  String get searchExpandPassage => 'Show matching passage';

  @override
  String get searchCollapsePassage => 'Show less';

  @override
  String get searchEntryChanged =>
      'This entry has changed. Search again to refresh the matching passage.';

  @override
  String get searchUseWords => 'Search by words';

  @override
  String get searchUnifiedFieldHint => 'Search your journal';

  @override
  String get searchUnifiedHint => 'Search words, or describe a memory.';

  @override
  String get searchClearQuery => 'Clear search text';

  @override
  String get searchFindingWords => 'Finding matching words…';

  @override
  String get searchFindingMeaning => 'Finding related entries…';

  @override
  String get searchFindRelated => 'Find related entries';

  @override
  String get searchWordsStillAvailable =>
      'Word search remains available while search by meaning recovers.';

  @override
  String get searchKeepWords => 'Keep word results';

  @override
  String get searchRefresh => 'Results have changed · Refresh';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries shown',
      one: '1 entry shown',
      zero: 'No entries shown',
    );
    return '$_temp0';
  }

  @override
  String get searchLoadMore => 'Load more';

  @override
  String get searchLoadingMore => 'Loading more…';

  @override
  String get searchEndResults => 'All available results are shown';

  @override
  String get searchEndWordResults => 'All word matches are shown';

  @override
  String get searchEditQuery => 'Edit search';

  @override
  String get searchPreviousResults =>
      'Showing the previous results until search succeeds.';

  @override
  String get searchWordsEmptyHint =>
      'Try fewer words, a name, or a word you remember using.';

  @override
  String get searchMeaningEmptyHint =>
      'Try describing the moment differently, or look for words you remember using.';

  @override
  String get semanticSearchPrivacy =>
      'Submit to search by meaning on this device. No notes or queries are sent to a server.';

  @override
  String get offlineNotice =>
      'Recording, notes and search work offline after model setup.';

  @override
  String get lockApp => 'Lock app';

  @override
  String get lockAppEnableReason => 'Confirm your identity to enable app lock';

  @override
  String get lockAppEnableFailedTitle => 'Could not enable app lock';

  @override
  String get lockAppEnableFailedMessage =>
      'Biometric verification failed. App lock was not enabled.';

  @override
  String get lockAppEnableFailedAction => 'OK';

  @override
  String get lockTitle => 'Journal locked';

  @override
  String get lockSubtitle =>
      'Verify your identity with your fingerprint or device credentials to unlock your journal.';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockReason => 'Unlock SmartNotes';
}
