// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;
import 'package:local_auth/local_auth.dart' as _i152;
import 'package:record/record.dart' as _i1039;
import 'package:shared_preferences/shared_preferences.dart' as _i460;
import 'package:smartnotes/application/journal_lifecycle.dart' as _i108;
import 'package:smartnotes/core/di/register_module.dart' as _i357;
import 'package:smartnotes/data/datasources/local/file_storage_service.dart'
    as _i734;
import 'package:smartnotes/data/datasources/local/local_database.dart' as _i877;
import 'package:smartnotes/data/datasources/local/shared_preferences_settings_service.dart'
    as _i191;
import 'package:smartnotes/data/datasources/local/sqlite_journal_entry_service.dart'
    as _i423;
import 'package:smartnotes/data/services/audio_recording_service.dart' as _i391;
import 'package:smartnotes/data/services/device_profile_service.dart' as _i406;
import 'package:smartnotes/data/services/embedding_model_service.dart'
    as _i1059;
import 'package:smartnotes/data/services/formatting_model_service.dart'
    as _i241;
import 'package:smartnotes/data/services/journal_archive_service.dart' as _i474;
import 'package:smartnotes/data/services/local_auth_service.dart' as _i561;
import 'package:smartnotes/data/services/local_embedding_service.dart' as _i461;
import 'package:smartnotes/data/services/local_entry_draft_repository.dart'
    as _i1055;
import 'package:smartnotes/data/services/local_entry_search_service.dart'
    as _i10;
import 'package:smartnotes/data/services/local_inference_queue.dart' as _i935;
import 'package:smartnotes/data/services/local_note_processing_service.dart'
    as _i897;
import 'package:smartnotes/data/services/local_recording_metadata.dart'
    as _i564;
import 'package:smartnotes/data/services/local_recording_playback.dart'
    as _i240;
import 'package:smartnotes/data/services/local_transcription_service.dart'
    as _i1008;
import 'package:smartnotes/data/services/model_verification.dart' as _i537;
import 'package:smartnotes/data/services/platform_model_downloader.dart'
    as _i203;
import 'package:smartnotes/data/services/processing_feedback_service.dart'
    as _i751;
import 'package:smartnotes/data/services/recording_signal_detector.dart'
    as _i375;
import 'package:smartnotes/data/services/speech_model_service.dart' as _i123;
import 'package:smartnotes/domain/services/i_audio_recording_service.dart'
    as _i1071;
import 'package:smartnotes/domain/services/i_embedding_model_service.dart'
    as _i872;
import 'package:smartnotes/domain/services/i_embedding_service.dart' as _i613;
import 'package:smartnotes/domain/services/i_entry_draft_repository.dart'
    as _i422;
import 'package:smartnotes/domain/services/i_entry_search_service.dart'
    as _i158;
import 'package:smartnotes/domain/services/i_file_storage_service.dart'
    as _i269;
import 'package:smartnotes/domain/services/i_formatting_model_service.dart'
    as _i984;
import 'package:smartnotes/domain/services/i_journal_archive_service.dart'
    as _i212;
import 'package:smartnotes/domain/services/i_journal_entry_service.dart'
    as _i112;
import 'package:smartnotes/domain/services/i_local_auth_service.dart' as _i822;
import 'package:smartnotes/domain/services/i_note_processing_service.dart'
    as _i139;
import 'package:smartnotes/domain/services/i_platform_model_downloader.dart'
    as _i13;
import 'package:smartnotes/domain/services/i_recording_metadata.dart' as _i991;
import 'package:smartnotes/domain/services/i_recording_playback.dart' as _i1041;
import 'package:smartnotes/domain/services/i_settings_service.dart' as _i791;
import 'package:smartnotes/domain/services/i_speech_model_service.dart'
    as _i824;
import 'package:smartnotes/domain/services/i_transcription_service.dart'
    as _i164;
import 'package:smartnotes/domain/use_cases/process_audio_note.dart' as _i926;
import 'package:smartnotes/presentation/app_store.dart' as _i634;
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_store.dart'
    as _i207;
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_store.dart'
    as _i711;
import 'package:smartnotes/presentation/screens/home/home_store.dart' as _i635;
import 'package:smartnotes/presentation/screens/onboarding/onboarding_store.dart'
    as _i588;
import 'package:smartnotes/presentation/screens/settings/embedding_models_store.dart'
    as _i739;
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart'
    as _i153;
import 'package:smartnotes/presentation/screens/settings/local_data_store.dart'
    as _i304;
import 'package:smartnotes/presentation/screens/settings/settings_store.dart'
    as _i633;
import 'package:smartnotes/presentation/screens/settings/speech_models_store.dart'
    as _i462;
import 'package:smartnotes/presentation/stores/model_downloads_store.dart'
    as _i934;

// initializes the registration of main-scope dependencies inside of GetIt
Future<_i174.GetIt> $initGetIt(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) async {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final registerModule = _$RegisterModule();
  await gh.factoryAsync<_i460.SharedPreferences>(
    () => registerModule.prefs,
    preResolve: true,
  );
  gh.singleton<_i1039.AudioRecorder>(() => registerModule.audioRecorder);
  gh.singleton<_i519.Client>(() => registerModule.httpClient);
  gh.singleton<_i152.LocalAuthentication>(
    () => registerModule.localAuthentication,
  );
  gh.singleton<_i877.LocalDatabase>(() => _i877.LocalDatabase());
  gh.lazySingleton<_i406.DeviceProfileService>(
    () => _i406.DeviceProfileService(),
  );
  gh.lazySingleton<_i935.LocalInferenceQueue>(
    () => _i935.LocalInferenceQueue(),
  );
  gh.lazySingleton<_i751.ProcessingFeedbackService>(
    () => _i751.ProcessingFeedbackService(),
  );
  gh.lazySingleton<_i375.RecordingSignalDetector>(
    () => _i375.RecordingSignalDetector(),
  );
  gh.factory<_i269.IFileStorageService>(() => _i734.FileStorageService());
  gh.lazySingleton<_i422.IEntryDraftRepository>(
    () => _i1055.LocalEntryDraftRepository(),
  );
  gh.lazySingleton<_i991.IRecordingMetadata>(
    () => _i564.LocalRecordingMetadata(),
  );
  gh.factory<_i1041.IRecordingPlayback>(() => _i240.LocalRecordingPlayback());
  gh.lazySingleton<_i13.IPlatformModelDownloader>(
    () => _i203.PlatformModelDownloader(),
    dispose: _i203.disposePlatformModelDownloader,
  );
  gh.lazySingleton<_i537.ModelVerificationStore>(
    () => _i537.ModelVerificationStore(gh<_i460.SharedPreferences>()),
  );
  gh.factory<_i1071.IAudioRecordingService>(
    () => _i391.AudioRecordingService(
      gh<_i1039.AudioRecorder>(),
      gh<_i375.RecordingSignalDetector>(),
    ),
  );
  gh.lazySingleton<_i934.ModelDownloadsStore>(
    () => _i934.ModelDownloadsStore(gh<_i13.IPlatformModelDownloader>()),
    dispose: _i934.disposeModelDownloadsStore,
  );
  gh.lazySingleton<_i112.IJournalEntryService>(
    () => _i423.SqliteJournalEntryService(
      gh<_i877.LocalDatabase>(),
      gh<_i269.IFileStorageService>(),
      gh<_i422.IEntryDraftRepository>(),
    ),
  );
  gh.factory<_i791.ISettingsService>(
    () => _i191.SharedPreferencesSettingsService(gh<_i460.SharedPreferences>()),
  );
  gh.factory<_i822.ILocalAuthService>(
    () => _i561.LocalAuthService(gh<_i152.LocalAuthentication>()),
  );
  gh.lazySingleton<_i984.IFormattingModelService>(
    () => _i241.FormattingModelService(
      gh<_i519.Client>(),
      gh<_i791.ISettingsService>(),
      gh<_i935.LocalInferenceQueue>(),
      gh<_i406.DeviceProfileService>(),
      gh<_i13.IPlatformModelDownloader>(),
      gh<_i537.ModelVerificationStore>(),
    ),
  );
  gh.lazySingleton<_i872.IEmbeddingModelService>(
    () => _i1059.EmbeddingModelService(
      gh<_i519.Client>(),
      gh<_i13.IPlatformModelDownloader>(),
      gh<_i406.DeviceProfileService>(),
      gh<_i537.ModelVerificationStore>(),
      gh<_i877.LocalDatabase>(),
      gh<_i935.LocalInferenceQueue>(),
    ),
    dispose: _i1059.disposeEmbeddingModelService,
  );
  gh.lazySingleton<_i613.IEmbeddingService>(
    () => _i461.LocalEmbeddingService(
      gh<_i872.IEmbeddingModelService>(),
      gh<_i935.LocalInferenceQueue>(),
    ),
  );
  gh.lazySingleton<_i212.IJournalArchiveService>(
    () => _i474.JournalArchiveService(
      gh<_i877.LocalDatabase>(),
      gh<_i269.IFileStorageService>(),
    ),
  );
  gh.lazySingleton<_i824.ISpeechModelService>(
    () => _i123.SpeechModelService(
      gh<_i519.Client>(),
      gh<_i791.ISettingsService>(),
      gh<_i935.LocalInferenceQueue>(),
      gh<_i406.DeviceProfileService>(),
      gh<_i13.IPlatformModelDownloader>(),
      gh<_i537.ModelVerificationStore>(),
    ),
  );
  gh.lazySingleton<_i158.IEntrySearchService>(
    () => _i10.LocalEntrySearchService(
      gh<_i877.LocalDatabase>(),
      gh<_i613.IEmbeddingService>(),
    ),
  );
  gh.singleton<_i153.FormattingModelsStore>(
    () => _i153.FormattingModelsStore(
      gh<_i984.IFormattingModelService>(),
      gh<_i406.DeviceProfileService>(),
      downloads: gh<_i934.ModelDownloadsStore>(),
    ),
  );
  gh.lazySingleton<_i164.ITranscriptionService>(
    () => _i1008.LocalTranscriptionService(
      gh<_i824.ISpeechModelService>(),
      gh<_i791.ISettingsService>(),
      gh<_i935.LocalInferenceQueue>(),
    ),
  );
  gh.factory<_i711.EntryEditStore>(
    () => _i711.EntryEditStore(
      gh<_i112.IJournalEntryService>(),
      gh<_i422.IEntryDraftRepository>(),
    ),
  );
  gh.lazySingleton<_i139.INoteProcessingService>(
    () => _i897.LocalNoteProcessingService(
      gh<_i984.IFormattingModelService>(),
      gh<_i164.ITranscriptionService>(),
      gh<_i935.LocalInferenceQueue>(),
    ),
  );
  gh.singleton<_i633.SettingsStore>(
    () => _i633.SettingsStore(
      gh<_i791.ISettingsService>(),
      gh<_i822.ILocalAuthService>(),
      gh<_i824.ISpeechModelService>(),
    ),
  );
  gh.singleton<_i739.EmbeddingModelsStore>(
    () => _i739.EmbeddingModelsStore(
      gh<_i872.IEmbeddingModelService>(),
      gh<_i934.ModelDownloadsStore>(),
    ),
  );
  gh.singleton<_i634.AppStore>(
    () => _i634.AppStore(
      gh<_i822.ILocalAuthService>(),
      gh<_i791.ISettingsService>(),
      gh<_i824.ISpeechModelService>(),
      gh<_i872.IEmbeddingModelService>(),
    ),
  );
  gh.singleton<_i462.SpeechModelsStore>(
    () => _i462.SpeechModelsStore(
      gh<_i824.ISpeechModelService>(),
      gh<_i406.DeviceProfileService>(),
      downloads: gh<_i934.ModelDownloadsStore>(),
    ),
  );
  gh.lazySingleton<_i926.ProcessAudioNoteUseCase>(
    () => _i926.ProcessAudioNoteUseCase(
      gh<_i139.INoteProcessingService>(),
      gh<_i112.IJournalEntryService>(),
    ),
  );
  gh.factory<_i207.EntryDetailStore>(
    () => _i207.EntryDetailStore(
      gh<_i112.IJournalEntryService>(),
      gh<_i926.ProcessAudioNoteUseCase>(),
      gh<_i984.IFormattingModelService>(),
    ),
  );
  gh.factory<_i588.OnboardingStore>(
    () => _i588.OnboardingStore(
      gh<_i633.SettingsStore>(),
      gh<_i634.AppStore>(),
      gh<_i872.IEmbeddingModelService>(),
      gh<_i462.SpeechModelsStore>(),
      gh<_i153.FormattingModelsStore>(),
      downloads: gh<_i934.ModelDownloadsStore>(),
      processingFeedback: gh<_i751.ProcessingFeedbackService>(),
      embeddings: gh<_i739.EmbeddingModelsStore>(),
    ),
  );
  gh.lazySingleton<_i108.JournalLifecycle>(
    () => _i108.JournalLifecycle(
      gh<_i112.IJournalEntryService>(),
      gh<_i926.ProcessAudioNoteUseCase>(),
      gh<_i158.IEntrySearchService>(),
      gh<_i872.IEmbeddingModelService>(),
      feedback: gh<_i751.ProcessingFeedbackService>(),
      speechModels: gh<_i824.ISpeechModelService>(),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.singleton<_i635.HomeStore>(
    () => _i635.HomeStore(
      gh<_i112.IJournalEntryService>(),
      gh<_i1071.IAudioRecordingService>(),
      gh<_i108.JournalLifecycle>(),
      gh<_i158.IEntrySearchService>(),
      processingFeedback: gh<_i751.ProcessingFeedbackService>(),
    ),
  );
  gh.singleton<_i304.LocalDataStore>(
    () => _i304.LocalDataStore(
      gh<_i158.IEntrySearchService>(),
      gh<_i212.IJournalArchiveService>(),
      gh<_i872.IEmbeddingModelService>(),
      gh<_i108.JournalLifecycle>(),
    ),
  );
  return getIt;
}

class _$RegisterModule extends _i357.RegisterModule {}
