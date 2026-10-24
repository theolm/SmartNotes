import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @journalSelectEntry.
  ///
  /// In en, this message translates to:
  /// **'Select an entry'**
  String get journalSelectEntry;

  /// No description provided for @journalSelectEntryHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a thought from your journal, or record a new one.'**
  String get journalSelectEntryHelp;

  /// No description provided for @editorExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand editor'**
  String get editorExpand;

  /// No description provided for @editorRestore.
  ///
  /// In en, this message translates to:
  /// **'Show journal alongside editor'**
  String get editorRestore;

  /// No description provided for @journalMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Updating local search…'**
  String get journalMaintenance;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SmartNotes'**
  String get appTitle;

  /// No description provided for @saveNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get saveNoteTitle;

  /// No description provided for @noteDetailsOptional.
  ///
  /// In en, this message translates to:
  /// **'Title and subtitle are optional.'**
  String get noteDetailsOptional;

  /// No description provided for @backToEditing.
  ///
  /// In en, this message translates to:
  /// **'Back to editing'**
  String get backToEditing;

  /// No description provided for @markdownSupported.
  ///
  /// In en, this message translates to:
  /// **'Supports Markdown'**
  String get markdownSupported;

  /// No description provided for @markdownHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Formatting help'**
  String get markdownHelpTitle;

  /// No description provided for @markdownHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Write plain text or use Markdown:\n\n# Heading\n## Subheading\n**Bold**\n*Italic*\n- List item\n1. Numbered item\n[Link text](https://example.com)\n\nFormatting appears in the saved note.'**
  String get markdownHelpBody;

  /// No description provided for @noteEditHint.
  ///
  /// In en, this message translates to:
  /// **'Write your note here…'**
  String get noteEditHint;

  /// No description provided for @modelDownloadNotificationChannel.
  ///
  /// In en, this message translates to:
  /// **'Model downloads'**
  String get modelDownloadNotificationChannel;

  /// No description provided for @modelDownloadNotificationRunning.
  ///
  /// In en, this message translates to:
  /// **'Downloading model'**
  String get modelDownloadNotificationRunning;

  /// No description provided for @modelDownloadNotificationVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying model…'**
  String get modelDownloadNotificationVerifying;

  /// No description provided for @modelDownloadNotificationComplete.
  ///
  /// In en, this message translates to:
  /// **'Model ready'**
  String get modelDownloadNotificationComplete;

  /// No description provided for @modelDownloadNotificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Open SmartNotes to retry.'**
  String get modelDownloadNotificationFailed;

  /// No description provided for @modelDownloadNotificationStarted.
  ///
  /// In en, this message translates to:
  /// **'Model download started'**
  String get modelDownloadNotificationStarted;

  /// No description provided for @modelDownloadNotificationCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get modelDownloadNotificationCancel;

  /// No description provided for @modelDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled — tap download to resume'**
  String get modelDownloadCancelled;

  /// No description provided for @modelDownloadBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'Downloads continue when you leave the app or lock your phone. On iOS, do not force-quit SmartNotes.'**
  String get modelDownloadBackgroundHint;

  /// No description provided for @modelDownloadNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Downloads still continue in the background. Notifications are off, so check progress here or enable notifications in your device settings.'**
  String get modelDownloadNotificationsDenied;

  /// No description provided for @processingNotificationChannel.
  ///
  /// In en, this message translates to:
  /// **'Note processing'**
  String get processingNotificationChannel;

  /// No description provided for @processingNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing note'**
  String get processingNotificationTitle;

  /// No description provided for @processingNoteReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Note ready'**
  String get processingNoteReadyTitle;

  /// No description provided for @processingPreparingTranscription.
  ///
  /// In en, this message translates to:
  /// **'Preparing transcription…'**
  String get processingPreparingTranscription;

  /// No description provided for @processingTranscribingAudio.
  ///
  /// In en, this message translates to:
  /// **'Transcribing audio…'**
  String get processingTranscribingAudio;

  /// No description provided for @processingPreparingSearch.
  ///
  /// In en, this message translates to:
  /// **'Preparing for search…'**
  String get processingPreparingSearch;

  /// No description provided for @processingFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing…'**
  String get processingFinalizing;

  /// No description provided for @processingLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading {modelName}'**
  String processingLoadingModel(String modelName);

  /// No description provided for @processingRunningModel.
  ///
  /// In en, this message translates to:
  /// **'Running {modelName}'**
  String processingRunningModel(String modelName);

  /// No description provided for @processingCreatingEmbeddings.
  ///
  /// In en, this message translates to:
  /// **'Creating embeddings with {modelName}'**
  String processingCreatingEmbeddings(String modelName);

  /// No description provided for @processingReleasingModels.
  ///
  /// In en, this message translates to:
  /// **'Releasing models from memory'**
  String get processingReleasingModels;

  /// No description provided for @notificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow your notes as they process'**
  String get notificationPermissionTitle;

  /// No description provided for @notificationPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'SmartNotes uses silent notifications to show when it is downloading models, transcribing audio, preparing notes for search, and releasing models from memory. Your note content never appears in notifications.'**
  String get notificationPermissionBody;

  /// No description provided for @notificationPermissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notificationPermissionAllow;

  /// No description provided for @speechModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcription models'**
  String get speechModelsTitle;

  /// No description provided for @speechModelAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available to download'**
  String get speechModelAvailable;

  /// No description provided for @speechModelsIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more models to download. Only one runs at a time, on this device. You can manage them later in Settings.'**
  String get speechModelsIntro;

  /// No description provided for @speechModelsManageIntro.
  ///
  /// In en, this message translates to:
  /// **'Download, select, or remove transcription models. Changing models does not change saved notes.'**
  String get speechModelsManageIntro;

  /// No description provided for @speechModelRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended for this device'**
  String get speechModelRecommended;

  /// No description provided for @speechModelActive.
  ///
  /// In en, this message translates to:
  /// **'Active model'**
  String get speechModelActive;

  /// No description provided for @speechModelActiveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your active model is missing, damaged, or incompatible with the current audio language. Choose a verified compatible model.'**
  String get speechModelActiveUnavailable;

  /// No description provided for @speechModelInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get speechModelInstalled;

  /// No description provided for @speechModelEnglish.
  ///
  /// In en, this message translates to:
  /// **'English only'**
  String get speechModelEnglish;

  /// No description provided for @speechModelMultilingual.
  ///
  /// In en, this message translates to:
  /// **'Multilingual — includes {language}'**
  String speechModelMultilingual(String language);

  /// No description provided for @speechModelAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Multilingual — automatic language detection'**
  String get speechModelAutomatic;

  /// No description provided for @speechModelIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Cannot be active for the selected audio language. You may download it for later.'**
  String get speechModelIncompatible;

  /// No description provided for @speechModelLanguages.
  ///
  /// In en, this message translates to:
  /// **'Supported languages'**
  String get speechModelLanguages;

  /// No description provided for @speechModelAllLanguages.
  ///
  /// In en, this message translates to:
  /// **'Afrikaans, Albanian, Amharic, Arabic, Armenian, Assamese, Azerbaijani, Bashkir, Basque, Belarusian, Bengali, Bosnian, Breton, Bulgarian, Burmese, Catalan, Chinese, Croatian, Czech, Danish, Dutch, English, Estonian, Faroese, Finnish, French, Galician, Georgian, German, Greek, Gujarati, Haitian Creole, Hausa, Hawaiian, Hebrew, Hindi, Hungarian, Icelandic, Indonesian, Italian, Japanese, Javanese, Kannada, Kazakh, Khmer, Korean, Lao, Latin, Latvian, Lingala, Lithuanian, Luxembourgish, Macedonian, Malagasy, Malay, Malayalam, Maltese, Maori, Marathi, Mongolian, Nepali, Norwegian, Nynorsk, Occitan, Pashto, Persian, Polish, Portuguese, Punjabi, Romanian, Russian, Sanskrit, Serbian, Shona, Sindhi, Sinhala, Slovak, Slovenian, Somali, Spanish, Sundanese, Swahili, Swedish, Tagalog, Tajik, Tamil, Tatar, Telugu, Thai, Tibetan, Turkish, Turkmen, Ukrainian, Urdu, Uzbek, Vietnamese, Welsh, Yiddish, Yoruba.'**
  String get speechModelAllLanguages;

  /// No description provided for @speechModelCantonese.
  ///
  /// In en, this message translates to:
  /// **'Also supports Cantonese.'**
  String get speechModelCantonese;

  /// No description provided for @speechModelLanguageDetails.
  ///
  /// In en, this message translates to:
  /// **'Supported language codes: {codes}'**
  String speechModelLanguageDetails(String codes);

  /// No description provided for @speechModelBaseBenefit.
  ///
  /// In en, this message translates to:
  /// **'Smallest download. An economical starting point, with lower recognition capacity.'**
  String get speechModelBaseBenefit;

  /// No description provided for @speechModelSmallEnglishBenefit.
  ///
  /// In en, this message translates to:
  /// **'Dedicated English weights with moderate model size. A balance of quality and processing cost.'**
  String get speechModelSmallEnglishBenefit;

  /// No description provided for @speechModelMediumEnglishBenefit.
  ///
  /// In en, this message translates to:
  /// **'More capacity for English recognition. Heavier CPU processing than Small.en.'**
  String get speechModelMediumEnglishBenefit;

  /// No description provided for @speechModelSmallBenefit.
  ///
  /// In en, this message translates to:
  /// **'More recognition capacity than Base, with a moderate download. A balanced multilingual option.'**
  String get speechModelSmallBenefit;

  /// No description provided for @speechModelTurboBenefit.
  ///
  /// In en, this message translates to:
  /// **'Large-v3 audio encoder with a smaller text decoder. A high-quality transcription candidate at lower decoding cost than full Large-v3.'**
  String get speechModelTurboBenefit;

  /// No description provided for @speechModelLargeBenefit.
  ///
  /// In en, this message translates to:
  /// **'Full Large-v3 model for prioritizing fidelity over processing cost. Not guaranteed to outperform Turbo on every recording.'**
  String get speechModelLargeBenefit;

  /// No description provided for @speechModelHeavyWarning.
  ///
  /// In en, this message translates to:
  /// **'Heavy CPU processing: may be slow, warm the device, or exceed available memory.'**
  String get speechModelHeavyWarning;

  /// No description provided for @speechModelEstimateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Hardware information is incomplete. We suggest the smallest model conservatively.'**
  String get speechModelEstimateUnknown;

  /// No description provided for @speechModelEstimateEconomical.
  ///
  /// In en, this message translates to:
  /// **'Based on available memory and CPU architecture, we suggest a smaller model.'**
  String get speechModelEstimateEconomical;

  /// No description provided for @speechModelEstimateBalanced.
  ///
  /// In en, this message translates to:
  /// **'Based on available memory and CPU architecture, we suggest a balanced model for your audio language.'**
  String get speechModelEstimateBalanced;

  /// No description provided for @speechModelEstimatePowerful.
  ///
  /// In en, this message translates to:
  /// **'This hardware profile qualifies for a larger model for your audio language.'**
  String get speechModelEstimatePowerful;

  /// No description provided for @speechModelEstimateDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This is a hardware estimate, not a speed or memory guarantee. All models use the CPU; download size is not RAM usage.'**
  String get speechModelEstimateDisclaimer;

  /// No description provided for @speechModelStorageSummary.
  ///
  /// In en, this message translates to:
  /// **'Model files and partial downloads use {size}.'**
  String speechModelStorageSummary(String size);

  /// No description provided for @speechModelEmbeddingSeparate.
  ///
  /// In en, this message translates to:
  /// **'Offline search requires a separate 639 MB download in the next step.'**
  String get speechModelEmbeddingSeparate;

  /// No description provided for @speechModelQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting to download'**
  String get speechModelQueued;

  /// No description provided for @speechModelCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — tap download to resume'**
  String get speechModelCancelled;

  /// No description provided for @speechModelFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed — tap download to retry'**
  String get speechModelFailed;

  /// No description provided for @speechModelDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get speechModelDownload;

  /// No description provided for @speechModelRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry download'**
  String get speechModelRetry;

  /// No description provided for @speechModelResumeDownload.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get speechModelResumeDownload;

  /// No description provided for @speechModelResume.
  ///
  /// In en, this message translates to:
  /// **'Download paused — tap download to resume'**
  String get speechModelResume;

  /// No description provided for @speechModelActivating.
  ///
  /// In en, this message translates to:
  /// **'Activating model…'**
  String get speechModelActivating;

  /// No description provided for @speechModelActiveDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Select another model before deleting the active model'**
  String get speechModelActiveDeleteHint;

  /// No description provided for @speechModelRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove model files?'**
  String get speechModelRemoveTitle;

  /// No description provided for @speechModelRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'These downloaded files will be removed. Notes and recordings stay unchanged. Select a replacement before removing the active model.'**
  String get speechModelRemoveBody;

  /// No description provided for @speechModelStorageError.
  ///
  /// In en, this message translates to:
  /// **'Not enough free storage. Free some space or select fewer models, then retry.'**
  String get speechModelStorageError;

  /// No description provided for @speechModelInUseError.
  ///
  /// In en, this message translates to:
  /// **'Select a compatible installed replacement before removing the active model. A model being downloaded cannot be removed.'**
  String get speechModelInUseError;

  /// No description provided for @speechModelLastError.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one installed model compatible with your audio language.'**
  String get speechModelLastError;

  /// No description provided for @speechModelSelectError.
  ///
  /// In en, this message translates to:
  /// **'Choose a verified model that supports your audio language.'**
  String get speechModelSelectError;

  /// No description provided for @speechModelLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load model information. Retry; your saved notes are unchanged.'**
  String get speechModelLoadError;

  /// No description provided for @speechModelLanguageChange.
  ///
  /// In en, this message translates to:
  /// **'Choose a model for the new audio language. Your previous language and model stay active until you select Use this model.'**
  String get speechModelLanguageChange;

  /// No description provided for @formattingModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Formatting models'**
  String get formattingModelsTitle;

  /// No description provided for @formattingModelsManageIntro.
  ///
  /// In en, this message translates to:
  /// **'Formatting models organize a note with AI on this device. Formatting is optional; install one and select it, or remove it later.'**
  String get formattingModelsManageIntro;

  /// No description provided for @formattingModelRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended for this device'**
  String get formattingModelRecommended;

  /// No description provided for @formattingModelActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get formattingModelActive;

  /// No description provided for @formattingModelActiveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected formatting model is missing or corrupt. Download it again or select another.'**
  String get formattingModelActiveUnavailable;

  /// No description provided for @formattingModelInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get formattingModelInstalled;

  /// No description provided for @formattingModelAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get formattingModelAvailable;

  /// No description provided for @formattingModelQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting to download'**
  String get formattingModelQueued;

  /// No description provided for @formattingModelCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled — tap download to resume'**
  String get formattingModelCancelled;

  /// No description provided for @formattingModelFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed — tap download to retry'**
  String get formattingModelFailed;

  /// No description provided for @formattingModelResume.
  ///
  /// In en, this message translates to:
  /// **'Download paused — tap download to resume'**
  String get formattingModelResume;

  /// No description provided for @formattingModelDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get formattingModelDownload;

  /// No description provided for @formattingModelRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry download'**
  String get formattingModelRetry;

  /// No description provided for @formattingModelResumeDownload.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get formattingModelResumeDownload;

  /// No description provided for @formattingModelActivating.
  ///
  /// In en, this message translates to:
  /// **'Selecting model…'**
  String get formattingModelActivating;

  /// No description provided for @formattingModelActiveDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Select another model before removing this one'**
  String get formattingModelActiveDeleteHint;

  /// No description provided for @formattingModelRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove formatting model?'**
  String get formattingModelRemoveTitle;

  /// No description provided for @formattingModelRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The model is deleted from this device. Your notes and transcriptions stay. You can download it again later.'**
  String get formattingModelRemoveBody;

  /// No description provided for @formattingModelStorageError.
  ///
  /// In en, this message translates to:
  /// **'Not enough free storage. Free some space, then retry.'**
  String get formattingModelStorageError;

  /// No description provided for @formattingModelInUseError.
  ///
  /// In en, this message translates to:
  /// **'Select another formatting model before removing the active one.'**
  String get formattingModelInUseError;

  /// No description provided for @formattingModelSelectError.
  ///
  /// In en, this message translates to:
  /// **'Could not select this model. Choose a verified formatting model.'**
  String get formattingModelSelectError;

  /// No description provided for @formattingModelStorageSummary.
  ///
  /// In en, this message translates to:
  /// **'Formatting models use {size}.'**
  String formattingModelStorageSummary(String size);

  /// No description provided for @formattingModelEstimateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Hardware information is incomplete. The lighter model is suggested conservatively.'**
  String get formattingModelEstimateUnknown;

  /// No description provided for @formattingModelEstimateEconomical.
  ///
  /// In en, this message translates to:
  /// **'Based on available memory, the lighter model is recommended for this device.'**
  String get formattingModelEstimateEconomical;

  /// No description provided for @formattingModelEstimateBalanced.
  ///
  /// In en, this message translates to:
  /// **'Based on available memory, the balanced model is recommended for this device.'**
  String get formattingModelEstimateBalanced;

  /// No description provided for @formattingModelEstimateDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Recommendations are estimates based on device memory, not benchmarks. Both models run offline.'**
  String get formattingModelEstimateDisclaimer;

  /// No description provided for @formattingModelCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get formattingModelCapabilities;

  /// No description provided for @formattingModelInfo.
  ///
  /// In en, this message translates to:
  /// **'Model capabilities'**
  String get formattingModelInfo;

  /// No description provided for @formattingModelLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get formattingModelLanguages;

  /// No description provided for @formattingModelAllLanguages.
  ///
  /// In en, this message translates to:
  /// **'Multilingual, including Portuguese and English'**
  String get formattingModelAllLanguages;

  /// No description provided for @formattingModelCapabilityLight.
  ///
  /// In en, this message translates to:
  /// **'Fastest and smallest. Best for short notes and low-memory devices; may omit details on long or complex notes.'**
  String get formattingModelCapabilityLight;

  /// No description provided for @formattingModelCapabilityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Better structure and fidelity. Recommended for most devices.'**
  String get formattingModelCapabilityBalanced;

  /// No description provided for @formattingModelMemoryLight.
  ///
  /// In en, this message translates to:
  /// **'Uses less memory.'**
  String get formattingModelMemoryLight;

  /// No description provided for @formattingModelMemoryBalanced.
  ///
  /// In en, this message translates to:
  /// **'Uses more memory and may be slower on low-memory devices.'**
  String get formattingModelMemoryBalanced;

  /// No description provided for @formattingModelNoteLimit.
  ///
  /// In en, this message translates to:
  /// **'Formats notes within the app\'s 4,096-token budget.'**
  String get formattingModelNoteLimit;

  /// No description provided for @formattingModelLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get formattingModelLicense;

  /// No description provided for @formattingModelNeededTitle.
  ///
  /// In en, this message translates to:
  /// **'Formatting model needed'**
  String get formattingModelNeededTitle;

  /// No description provided for @formattingModelNeededBody.
  ///
  /// In en, this message translates to:
  /// **'AI actions run on your device and need a formatting model. Download and select one in Settings. Your note is not sent anywhere.'**
  String get formattingModelNeededBody;

  /// No description provided for @formattingModelNeededSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to settings'**
  String get formattingModelNeededSettings;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @onboardingProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 5'**
  String onboardingProgress(int step);

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Open my journal'**
  String get onboardingStart;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'A journal for your spoken thoughts'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Capture an idea while it is fresh. SmartNotes turns your voice into a note you can return to.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Tap, speak, tap to stop'**
  String get onboardingCaptureTitle;

  /// No description provided for @onboardingCaptureBody.
  ///
  /// In en, this message translates to:
  /// **'Record a thought or reflection. Your original recording is kept for playback and retry.'**
  String get onboardingCaptureBody;

  /// No description provided for @onboardingNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'From speech to a readable note'**
  String get onboardingNoteTitle;

  /// No description provided for @onboardingNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Whisper transcribes your recording into an editable note on this device. Your own words are saved first; organize them with AI later if you choose.'**
  String get onboardingNoteBody;

  /// No description provided for @onboardingLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Your journal lives on this device'**
  String get onboardingLocalTitle;

  /// No description provided for @onboardingLocalBody.
  ///
  /// In en, this message translates to:
  /// **'No account or cloud sync. Text search works offline. Export backups regularly: uninstalling the app can erase your journal. Notes and recordings are not encrypted by the app.'**
  String get onboardingLocalBody;

  /// No description provided for @onboardingLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'What language do you speak?'**
  String get onboardingLanguageTitle;

  /// No description provided for @onboardingLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'Let Whisper detect your language, or select it for more predictable results with short or noisy recordings. Transcription stays in the language you speak. You can change this in Settings.'**
  String get onboardingLanguageBody;

  /// No description provided for @onboardingModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Download offline transcription'**
  String get onboardingModelTitle;

  /// No description provided for @onboardingFormattingTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a formatting model (optional)'**
  String get onboardingFormattingTitle;

  /// No description provided for @onboardingFormattingBody.
  ///
  /// In en, this message translates to:
  /// **'A formatting model lets you organize a note with AI on this device. You can skip this step and install one later in Settings. Your words stay on this device.'**
  String get onboardingFormattingBody;

  /// No description provided for @onboardingFormattingSkip.
  ///
  /// In en, this message translates to:
  /// **'Continue without formatting'**
  String get onboardingFormattingSkip;

  /// No description provided for @onboardingEmbeddingTitle.
  ///
  /// In en, this message translates to:
  /// **'Download offline search by meaning'**
  String get onboardingEmbeddingTitle;

  /// No description provided for @onboardingEmbeddingBody.
  ///
  /// In en, this message translates to:
  /// **'This required 639 MB model helps find your notes by meaning, including across languages. Use Wi-Fi and allow enough free storage. After setup, recording, transcription and both search modes work without internet. Notes are indexed in the background. Optional AI organization is offered in the previous step and can be installed later in Settings.'**
  String get onboardingEmbeddingBody;

  /// No description provided for @onboardingEmbeddingReady.
  ///
  /// In en, this message translates to:
  /// **'Model verified. Offline search by meaning is ready.'**
  String get onboardingEmbeddingReady;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @appLockSummary.
  ///
  /// In en, this message translates to:
  /// **'Protects access to the app, not the files on your device.'**
  String get appLockSummary;

  /// No description provided for @settingsVoiceAndAI.
  ///
  /// In en, this message translates to:
  /// **'Voice and local AI'**
  String get settingsVoiceAndAI;

  /// No description provided for @settingsYourJournal.
  ///
  /// In en, this message translates to:
  /// **'Your journal'**
  String get settingsYourJournal;

  /// No description provided for @transcriptionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get transcriptionSettingsTitle;

  /// No description provided for @aiOrganizationTitle.
  ///
  /// In en, this message translates to:
  /// **'AI organization'**
  String get aiOrganizationTitle;

  /// No description provided for @aiOrganizationNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Optional · Not configured'**
  String get aiOrganizationNotConfigured;

  /// No description provided for @searchSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search by meaning'**
  String get searchSettingsTitle;

  /// No description provided for @searchUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Search is up to date'**
  String get searchUpToDate;

  /// No description provided for @searchSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Find entries by meaning, even when you use different words. Processing stays on this device.'**
  String get searchSettingsHelp;

  /// No description provided for @searchMaintenanceHelp.
  ///
  /// In en, this message translates to:
  /// **'Update pending or failed entries to complete search results. For large journals, keep the app open while indexing.'**
  String get searchMaintenanceHelp;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSettings;

  /// No description provided for @backupSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get backupSettingsTitle;

  /// No description provided for @backupSettingsSummary.
  ///
  /// In en, this message translates to:
  /// **'Export or import your notes and recordings'**
  String get backupSettingsSummary;

  /// No description provided for @transcriptionRecoveryHelp.
  ///
  /// In en, this message translates to:
  /// **'Retry recordings that have not finished transcribing. Existing notes are kept.'**
  String get transcriptionRecoveryHelp;

  /// No description provided for @transcriptionRecoveryDone.
  ///
  /// In en, this message translates to:
  /// **'Pending recordings have been queued for transcription.'**
  String get transcriptionRecoveryDone;

  /// No description provided for @offlineModels.
  ///
  /// In en, this message translates to:
  /// **'Offline AI models'**
  String get offlineModels;

  /// No description provided for @offlineModelsBody.
  ///
  /// In en, this message translates to:
  /// **'Transcription: select and manage Whisper models in Settings.\nFormatting: choose an optional AI organization model in Settings.\nSearch: Qwen3 Embedding 0.6B Q8 · 639.2 MB\nInternet is only needed to download or repair models; notes and queries stay on this device.'**
  String get offlineModelsBody;

  /// No description provided for @aiPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview AI changes'**
  String get aiPreviewTitle;

  /// No description provided for @aiPreviewHelp.
  ///
  /// In en, this message translates to:
  /// **'Nothing changes until Apply. Compare your current words with this preview. Your original transcription and recording are kept.'**
  String get aiPreviewHelp;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewLabel;

  /// No description provided for @latestSavedEntry.
  ///
  /// In en, this message translates to:
  /// **'Latest saved entry'**
  String get latestSavedEntry;

  /// No description provided for @aiChangesApplied.
  ///
  /// In en, this message translates to:
  /// **'Changes applied'**
  String get aiChangesApplied;

  /// No description provided for @aiChangesUndone.
  ///
  /// In en, this message translates to:
  /// **'Previous note restored'**
  String get aiChangesUndone;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @reloadAiDraftHelp.
  ///
  /// In en, this message translates to:
  /// **'Reloading discards this AI draft and generates a new one from the latest saved entry. Copy this draft first if you want to keep it.'**
  String get reloadAiDraftHelp;

  /// No description provided for @aiReplaceMetadata.
  ///
  /// In en, this message translates to:
  /// **'Also replace the title and subtitle'**
  String get aiReplaceMetadata;

  /// No description provided for @aiApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get aiApply;

  /// No description provided for @aiDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get aiDiscard;

  /// No description provided for @aiRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Reload note and try again'**
  String get aiRegenerate;

  /// No description provided for @aiDraftConflict.
  ///
  /// In en, this message translates to:
  /// **'Could not save these changes. The note may have changed or been deleted. Reload before trying again; saved content has not been replaced.'**
  String get aiDraftConflict;

  /// No description provided for @originalTranscription.
  ///
  /// In en, this message translates to:
  /// **'Original transcription'**
  String get originalTranscription;

  /// No description provided for @restoreTranscription.
  ///
  /// In en, this message translates to:
  /// **'Restore original transcription'**
  String get restoreTranscription;

  /// No description provided for @restoreTranscriptionConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Replace the current note with the original transcription? Current edits will be replaced. The title, subtitle, and recording will be kept.'**
  String get restoreTranscriptionConfirmation;

  /// No description provided for @modelSetup.
  ///
  /// In en, this message translates to:
  /// **'Check model setup'**
  String get modelSetup;

  /// No description provided for @browseJournal.
  ///
  /// In en, this message translates to:
  /// **'Browse my existing journal'**
  String get browseJournal;

  /// No description provided for @embeddingModelMissing.
  ///
  /// In en, this message translates to:
  /// **'The offline search model is missing or damaged. Open model setup in Settings to download it. Text search and saved notes are still available.'**
  String get embeddingModelMissing;

  /// No description provided for @indexIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Search by meaning is incomplete while notes are pending or failed. Text search still covers your saved notes.'**
  String get indexIncomplete;

  /// No description provided for @indexStatus.
  ///
  /// In en, this message translates to:
  /// **'Indexed: {indexed} · Pending: {pending} · Failed: {failed}'**
  String indexStatus(int indexed, int pending, int failed);

  /// No description provided for @aiNoteTooLong.
  ///
  /// In en, this message translates to:
  /// **'This transcript is too long for offline formatting. Your recording and transcript are saved. Shorten the recording for a new note; no text was sent to a server.'**
  String get aiNoteTooLong;

  /// No description provided for @onboardingModelSize.
  ///
  /// In en, this message translates to:
  /// **'{size} MB download · multilingual · stored on this device'**
  String onboardingModelSize(String size);

  /// No description provided for @onboardingModelDownload.
  ///
  /// In en, this message translates to:
  /// **'Download model'**
  String get onboardingModelDownload;

  /// No description provided for @onboardingModelProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String onboardingModelProgress(int percent);

  /// No description provided for @onboardingModelVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying model…'**
  String get onboardingModelVerifying;

  /// No description provided for @onboardingEmbeddingSize.
  ///
  /// In en, this message translates to:
  /// **'{size} MB download · stored on this device'**
  String onboardingEmbeddingSize(String size);

  /// No description provided for @onboardingModelFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the model. Check your connection and free storage, then download again. An interrupted download can resume.'**
  String get onboardingModelFailed;

  /// No description provided for @onboardingUiLanguage.
  ///
  /// In en, this message translates to:
  /// **'This selects the audio language, not the interface language. The app interface is currently English.'**
  String get onboardingUiLanguage;

  /// No description provided for @onboardingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your settings or model readiness. Please retry.'**
  String get onboardingLoadFailed;

  /// No description provided for @onboardingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish setup. Your journal is safe. Please retry.'**
  String get onboardingSaveFailed;

  /// No description provided for @journalTitle.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get journalTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @recordButtonHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get recordButtonHint;

  /// No description provided for @stopRecordingHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to stop'**
  String get stopRecordingHint;

  /// No description provided for @emptyStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Your journal is empty'**
  String get emptyStateTitle;

  /// No description provided for @emptyStateMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to record your first note.'**
  String get emptyStateMessage;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @deleteConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get deleteConfirmationTitle;

  /// No description provided for @deleteConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteConfirmationMessage;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @audioLanguage.
  ///
  /// In en, this message translates to:
  /// **'Audio language'**
  String get audioLanguage;

  /// No description provided for @audioLanguageAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get audioLanguageAutomatic;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @reformat.
  ///
  /// In en, this message translates to:
  /// **'Reformat'**
  String get reformat;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @aiActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Organize with AI'**
  String get aiActionsTitle;

  /// No description provided for @aiPreparingModel.
  ///
  /// In en, this message translates to:
  /// **'Preparing the offline model…'**
  String get aiPreparingModel;

  /// No description provided for @aiModelCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check the offline formatting model. Your note is unchanged. Try again.'**
  String get aiModelCheckFailed;

  /// No description provided for @aiActionProcessing.
  ///
  /// In en, this message translates to:
  /// **'Transforming note…'**
  String get aiActionProcessing;

  /// No description provided for @aiActionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not transform note'**
  String get aiActionFailedTitle;

  /// No description provided for @aiActionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your current note was not changed. Try again?'**
  String get aiActionFailedMessage;

  /// No description provided for @aiActionOrganizedNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get aiActionOrganizedNoteTitle;

  /// No description provided for @aiActionOrganizedNoteDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a clear, well-structured note while preserving details and tone.'**
  String get aiActionOrganizedNoteDescription;

  /// No description provided for @aiActionJournalEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Journal style'**
  String get aiActionJournalEntryTitle;

  /// No description provided for @aiActionJournalEntryDescription.
  ///
  /// In en, this message translates to:
  /// **'Rewrite the current note as a personal narrative, without adding facts or reflections.'**
  String get aiActionJournalEntryDescription;

  /// No description provided for @aiActionKeyPointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Key points'**
  String get aiActionKeyPointsTitle;

  /// No description provided for @aiActionKeyPointsDescription.
  ///
  /// In en, this message translates to:
  /// **'Group ideas, tasks, and decisions into concise bullet points.'**
  String get aiActionKeyPointsDescription;

  /// No description provided for @aiActionFormalSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Formal summary'**
  String get aiActionFormalSummaryTitle;

  /// No description provided for @aiActionFormalSummaryDescription.
  ///
  /// In en, this message translates to:
  /// **'Create an objective, professional, structured record.'**
  String get aiActionFormalSummaryDescription;

  /// No description provided for @aiActionCasualRecapTitle.
  ///
  /// In en, this message translates to:
  /// **'Casual recap'**
  String get aiActionCasualRecapTitle;

  /// No description provided for @aiActionCasualRecapDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a light, direct, conversational recap.'**
  String get aiActionCasualRecapDescription;

  /// No description provided for @aiActionFaithfulTranscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean up wording'**
  String get aiActionFaithfulTranscriptionTitle;

  /// No description provided for @aiActionFaithfulTranscriptionDescription.
  ///
  /// In en, this message translates to:
  /// **'Clean up the current text into paragraphs, keeping its order and meaning. This does not retranscribe the recording.'**
  String get aiActionFaithfulTranscriptionDescription;

  /// No description provided for @originalRecording.
  ///
  /// In en, this message translates to:
  /// **'Original recording'**
  String get originalRecording;

  /// No description provided for @listenOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get listenOriginal;

  /// No description provided for @listenOriginalDuration.
  ///
  /// In en, this message translates to:
  /// **'Original · {duration}'**
  String listenOriginalDuration(String duration);

  /// No description provided for @playRecording.
  ///
  /// In en, this message translates to:
  /// **'Play recording'**
  String get playRecording;

  /// No description provided for @pauseRecording.
  ///
  /// In en, this message translates to:
  /// **'Pause recording'**
  String get pauseRecording;

  /// No description provided for @seekRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording position'**
  String get seekRecording;

  /// No description provided for @recordingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Original recording is unavailable. You can still read and edit your note.'**
  String get recordingUnavailable;

  /// No description provided for @recordingPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this recording. Your saved note is unchanged.'**
  String get recordingPlaybackFailed;

  /// No description provided for @durationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Duration unavailable'**
  String get durationUnknown;

  /// No description provided for @entryDetails.
  ///
  /// In en, this message translates to:
  /// **'Entry details'**
  String get entryDetails;

  /// No description provided for @currentEntry.
  ///
  /// In en, this message translates to:
  /// **'Saved entry'**
  String get currentEntry;

  /// No description provided for @yourEdits.
  ///
  /// In en, this message translates to:
  /// **'Your edits'**
  String get yourEdits;

  /// No description provided for @reloadReplacesDraft.
  ///
  /// In en, this message translates to:
  /// **'Reloading replaces this editing draft with the saved entry. Copy your edits first if you want to keep them.'**
  String get reloadReplacesDraft;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Save your changes?'**
  String get unsavedChanges;

  /// No description provided for @unsavedChangesHelp.
  ///
  /// In en, this message translates to:
  /// **'Your saved entry has not changed.'**
  String get unsavedChangesHelp;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @resumeDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume your edits?'**
  String get resumeDraftTitle;

  /// No description provided for @resumeDraftHelp.
  ///
  /// In en, this message translates to:
  /// **'There are unfinished edits saved on this device.'**
  String get resumeDraftHelp;

  /// No description provided for @resumeDraft.
  ///
  /// In en, this message translates to:
  /// **'Resume edits'**
  String get resumeDraft;

  /// No description provided for @draftRecoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your editing draft. Retry before editing so it is not overwritten.'**
  String get draftRecoveryFailed;

  /// No description provided for @discardRecoveryDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard recovery draft'**
  String get discardRecoveryDraft;

  /// No description provided for @discardRecoveryDraftHelp.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove these unfinished edits from this device? Your saved journal entry will not change.'**
  String get discardRecoveryDraftHelp;

  /// No description provided for @draftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not keep a recovery draft. Keep this screen open and save your changes before leaving.'**
  String get draftSaveFailed;

  /// No description provided for @draftChangedHelp.
  ///
  /// In en, this message translates to:
  /// **'The saved entry changed since these edits began. Compare or copy your edits before choosing a new starting point.'**
  String get draftChangedHelp;

  /// No description provided for @copyEdits.
  ///
  /// In en, this message translates to:
  /// **'Copy edits'**
  String get copyEdits;

  /// No description provided for @editsCopied.
  ///
  /// In en, this message translates to:
  /// **'Edits copied'**
  String get editsCopied;

  /// No description provided for @compareSaved.
  ///
  /// In en, this message translates to:
  /// **'Compare saved entry'**
  String get compareSaved;

  /// No description provided for @useLatestEntry.
  ///
  /// In en, this message translates to:
  /// **'Use saved entry as starting point'**
  String get useLatestEntry;

  /// No description provided for @entryChangedHelp.
  ///
  /// In en, this message translates to:
  /// **'This entry changed. Your draft is still here. Compare or copy it before reloading the saved entry.'**
  String get entryChangedHelp;

  /// No description provided for @entryDeletedHelp.
  ///
  /// In en, this message translates to:
  /// **'This entry was deleted. Your draft has not been applied. You can still copy it.'**
  String get entryDeletedHelp;

  /// No description provided for @entryBusyHelp.
  ///
  /// In en, this message translates to:
  /// **'Another operation is using this entry. Wait a moment, then retry.'**
  String get entryBusyHelp;

  /// No description provided for @entryStorageHelp.
  ///
  /// In en, this message translates to:
  /// **'Could not save to this device. Your draft is still here. Check available storage and retry.'**
  String get entryStorageHelp;

  /// No description provided for @entryChangedWithoutDraft.
  ///
  /// In en, this message translates to:
  /// **'This entry changed. Reload the saved entry before trying again. No changes were applied.'**
  String get entryChangedWithoutDraft;

  /// No description provided for @entryDeletedWithoutDraft.
  ///
  /// In en, this message translates to:
  /// **'This entry was deleted. No changes were applied.'**
  String get entryDeletedWithoutDraft;

  /// No description provided for @entryStorageWithoutDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not save to this device. No changes were applied. Check available storage and retry.'**
  String get entryStorageWithoutDraft;

  /// No description provided for @reloadEntry.
  ///
  /// In en, this message translates to:
  /// **'Reload entry'**
  String get reloadEntry;

  /// No description provided for @emptyEntry.
  ///
  /// In en, this message translates to:
  /// **'This note is empty. You can edit it or revisit the original transcription.'**
  String get emptyEntry;

  /// No description provided for @deletingEntry.
  ///
  /// In en, this message translates to:
  /// **'Deleting entry…'**
  String get deletingEntry;

  /// No description provided for @savingEntry.
  ///
  /// In en, this message translates to:
  /// **'Saving changes…'**
  String get savingEntry;

  /// No description provided for @transcriptionFailedHelp.
  ///
  /// In en, this message translates to:
  /// **'Transcription could not finish. Your available recording and words are kept here.'**
  String get transcriptionFailedHelp;

  /// No description provided for @entryNotFound.
  ///
  /// In en, this message translates to:
  /// **'Entry not found'**
  String get entryNotFound;

  /// No description provided for @failedToLoadEntry.
  ///
  /// In en, this message translates to:
  /// **'Failed to load entry'**
  String get failedToLoadEntry;

  /// No description provided for @failedToSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Your edits are still here. The saved note may have changed; copy your edits before reopening it.'**
  String get failedToSaveChanges;

  /// No description provided for @failedToDeleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete entry'**
  String get failedToDeleteEntry;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @processingFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed'**
  String get processingFailed;

  /// No description provided for @editEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editEntryTitle;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @subtitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get subtitleLabel;

  /// No description provided for @entryDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry date'**
  String get entryDateLabel;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get searchHint;

  /// No description provided for @entryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Entry deleted'**
  String get entryDeleted;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No entries match your search'**
  String get noSearchResults;

  /// No description provided for @preferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesTitle;

  /// No description provided for @processingSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing and search'**
  String get processingSearchTitle;

  /// No description provided for @processingSearchHelp.
  ///
  /// In en, this message translates to:
  /// **'Retry unfinished recordings or update search by meaning on this device. Large libraries may take time to index; keep the app open.'**
  String get processingSearchHelp;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @indexFailed.
  ///
  /// In en, this message translates to:
  /// **'Indexing could not finish. Notes are safe; check model setup, then retry.'**
  String get indexFailed;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the journal. Backups are limited to 100 MB.'**
  String get exportFailed;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import this backup. Existing notes were not changed.'**
  String get importFailed;

  /// No description provided for @aiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI processing could not complete. Please retry. Your saved content is unchanged.'**
  String get aiUnavailable;

  /// No description provided for @aiFormattingModelMissing.
  ///
  /// In en, this message translates to:
  /// **'This note needs a formatting model. Download and select one in Settings.'**
  String get aiFormattingModelMissing;

  /// No description provided for @aiNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'No speech was detected. Your recording is still saved.'**
  String get aiNoSpeech;

  /// No description provided for @recordingNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'No speech detected. Try recording again.'**
  String get recordingNoSpeech;

  /// No description provided for @aiIncompleteNote.
  ///
  /// In en, this message translates to:
  /// **'The local model did not finish formatting within its token limit. Your transcription is saved; retry.'**
  String get aiIncompleteNote;

  /// No description provided for @aiInvalidNote.
  ///
  /// In en, this message translates to:
  /// **'The local model returned an invalid note. Your transcription is saved; retry.'**
  String get aiInvalidNote;

  /// No description provided for @aiInvalidEmbedding.
  ///
  /// In en, this message translates to:
  /// **'The local model could not produce a valid search vector. Your notes are unchanged; retry or check model setup.'**
  String get aiInvalidEmbedding;

  /// No description provided for @aiQueryTooLong.
  ///
  /// In en, this message translates to:
  /// **'This query exceeds the offline search token or length limit. Try a shorter query.'**
  String get aiQueryTooLong;

  /// No description provided for @aiBusy.
  ///
  /// In en, this message translates to:
  /// **'This note is already being processed. Please wait.'**
  String get aiBusy;

  /// No description provided for @indexNotes.
  ///
  /// In en, this message translates to:
  /// **'Index pending notes'**
  String get indexNotes;

  /// No description provided for @rebuildIndex.
  ///
  /// In en, this message translates to:
  /// **'Rebuild search index'**
  String get rebuildIndex;

  /// No description provided for @rebuildIndexMessage.
  ///
  /// In en, this message translates to:
  /// **'This discards the derived search index and rebuilds it locally. Search by meaning will be incomplete until finished; notes and text search are unaffected. Continue?'**
  String get rebuildIndexMessage;

  /// No description provided for @indexComplete.
  ///
  /// In en, this message translates to:
  /// **'Search index is up to date'**
  String get indexComplete;

  /// No description provided for @retryRecordings.
  ///
  /// In en, this message translates to:
  /// **'Retry pending recordings'**
  String get retryRecordings;

  /// No description provided for @localData.
  ///
  /// In en, this message translates to:
  /// **'Local journal'**
  String get localData;

  /// No description provided for @localDataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'There is no cloud sync or automatic Android backup. Export regularly: uninstalling the app or losing this device can lose your journal. The database and audio files are not encrypted by the app; the optional app lock protects the interface only.'**
  String get localDataPrivacy;

  /// No description provided for @exportJournal.
  ///
  /// In en, this message translates to:
  /// **'Export journal'**
  String get exportJournal;

  /// No description provided for @importJournal.
  ///
  /// In en, this message translates to:
  /// **'Import journal'**
  String get importJournal;

  /// No description provided for @backupPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Backups contain readable notes and recordings, not AI models or the derived search index. Store them somewhere safe. Backup files are limited to 100 MB.'**
  String get backupPrivacy;

  /// No description provided for @importConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Notes with matching IDs will be replaced. The search index can be rebuilt afterwards. Import this backup?'**
  String get importConfirmation;

  /// No description provided for @backupExported.
  ///
  /// In en, this message translates to:
  /// **'Journal exported'**
  String get backupExported;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Journal imported'**
  String get backupImported;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open or save the backup file. Please retry.'**
  String get backupFailed;

  /// No description provided for @textSearch.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textSearch;

  /// No description provided for @semanticSearch.
  ///
  /// In en, this message translates to:
  /// **'Semantic'**
  String get semanticSearch;

  /// No description provided for @semanticSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what you are looking for'**
  String get semanticSearchHint;

  /// No description provided for @semanticSearchReady.
  ///
  /// In en, this message translates to:
  /// **'Tap Search to find entries by meaning.'**
  String get semanticSearchReady;

  /// No description provided for @searchSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get searchSourceTitle;

  /// No description provided for @searchSourceNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get searchSourceNote;

  /// No description provided for @searchSourceOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original transcription'**
  String get searchSourceOriginal;

  /// No description provided for @searchRelatedByMeaning.
  ///
  /// In en, this message translates to:
  /// **'Related by meaning'**
  String get searchRelatedByMeaning;

  /// No description provided for @searchExpandPassage.
  ///
  /// In en, this message translates to:
  /// **'Show matching passage'**
  String get searchExpandPassage;

  /// No description provided for @searchCollapsePassage.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get searchCollapsePassage;

  /// No description provided for @searchEntryChanged.
  ///
  /// In en, this message translates to:
  /// **'This entry has changed. Search again to refresh the matching passage.'**
  String get searchEntryChanged;

  /// No description provided for @searchUseWords.
  ///
  /// In en, this message translates to:
  /// **'Search by words'**
  String get searchUseWords;

  /// No description provided for @searchUnifiedFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Search your journal'**
  String get searchUnifiedFieldHint;

  /// No description provided for @searchUnifiedHint.
  ///
  /// In en, this message translates to:
  /// **'Search words, or describe a memory.'**
  String get searchUnifiedHint;

  /// No description provided for @searchClearQuery.
  ///
  /// In en, this message translates to:
  /// **'Clear search text'**
  String get searchClearQuery;

  /// No description provided for @searchFindingWords.
  ///
  /// In en, this message translates to:
  /// **'Finding matching words…'**
  String get searchFindingWords;

  /// No description provided for @searchFindingMeaning.
  ///
  /// In en, this message translates to:
  /// **'Finding related entries…'**
  String get searchFindingMeaning;

  /// No description provided for @searchFindRelated.
  ///
  /// In en, this message translates to:
  /// **'Find related entries'**
  String get searchFindRelated;

  /// No description provided for @searchWordsStillAvailable.
  ///
  /// In en, this message translates to:
  /// **'Word search remains available while search by meaning recovers.'**
  String get searchWordsStillAvailable;

  /// No description provided for @searchKeepWords.
  ///
  /// In en, this message translates to:
  /// **'Keep word results'**
  String get searchKeepWords;

  /// No description provided for @searchRefresh.
  ///
  /// In en, this message translates to:
  /// **'Results have changed · Refresh'**
  String get searchRefresh;

  /// No description provided for @searchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No entries shown} =1{1 entry shown} other{{count} entries shown}}'**
  String searchResultCount(int count);

  /// No description provided for @searchLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get searchLoadMore;

  /// No description provided for @searchLoadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more…'**
  String get searchLoadingMore;

  /// No description provided for @searchEndResults.
  ///
  /// In en, this message translates to:
  /// **'All available results are shown'**
  String get searchEndResults;

  /// No description provided for @searchEndWordResults.
  ///
  /// In en, this message translates to:
  /// **'All word matches are shown'**
  String get searchEndWordResults;

  /// No description provided for @searchEditQuery.
  ///
  /// In en, this message translates to:
  /// **'Edit search'**
  String get searchEditQuery;

  /// No description provided for @searchPreviousResults.
  ///
  /// In en, this message translates to:
  /// **'Showing the previous results until search succeeds.'**
  String get searchPreviousResults;

  /// No description provided for @searchWordsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Try fewer words, a name, or a word you remember using.'**
  String get searchWordsEmptyHint;

  /// No description provided for @searchMeaningEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Try describing the moment differently, or look for words you remember using.'**
  String get searchMeaningEmptyHint;

  /// No description provided for @semanticSearchPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Submit to search by meaning on this device. No notes or queries are sent to a server.'**
  String get semanticSearchPrivacy;

  /// No description provided for @offlineNotice.
  ///
  /// In en, this message translates to:
  /// **'Recording, notes and search work offline after model setup.'**
  String get offlineNotice;

  /// No description provided for @lockApp.
  ///
  /// In en, this message translates to:
  /// **'Lock app'**
  String get lockApp;

  /// No description provided for @lockAppEnableReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm your identity to enable app lock'**
  String get lockAppEnableReason;

  /// No description provided for @lockAppEnableFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not enable app lock'**
  String get lockAppEnableFailedTitle;

  /// No description provided for @lockAppEnableFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Biometric verification failed. App lock was not enabled.'**
  String get lockAppEnableFailedMessage;

  /// No description provided for @lockAppEnableFailedAction.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get lockAppEnableFailedAction;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Journal locked'**
  String get lockTitle;

  /// No description provided for @lockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity with your fingerprint or device credentials to unlock your journal.'**
  String get lockSubtitle;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock SmartNotes'**
  String get unlockReason;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
