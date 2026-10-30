# SmartNotes Architecture

This document defines the architecture that all SmartNotes code must follow. It is the source of truth for packages, layering, dependency injection, MobX state, navigation, persistence, local AI, presentation, testing, and code generation. New code must follow these rules. When existing code differs, converge on this document as part of the change instead of introducing another pattern.

## 1. Product constraints

- Android, iOS, and macOS are supported. Flutter web is not supported.
- The app is local-first. Journal entries, recordings, transcriptions, settings, and search data stay on the device.
- There is no account, backend, cloud sync, remote AI, analytics, telemetry, advertising, or API key.
- Network access is limited to downloading pinned model files, checking public
  GitHub releases, and downloading explicitly accepted app updates. Update checks
  send no journal content, identifiers, analytics, or credentials; GitHub receives
  ordinary connection metadata such as the IP address.
- The journal and original recordings are authoritative. Search indexes, chunks, and embeddings are derived and disposable.
- AI is optional except where setup explicitly requires a model. A missing formatting model never blocks recording, transcription, reading, text search, or backups.
- The app does not encrypt the database or recordings. App lock protects the interface only.

## 2. Stack

| Concern | Package | Use |
| --- | --- | --- |
| UI | Flutter, Material 3 | Android, iOS, and macOS UI |
| State | `mobx`, `flutter_mobx`, `mobx_codegen` | Observable stores and generated `.g.dart` files |
| Dependency injection | `get_it`, `injectable`, `injectable_generator` | Service locator and generated registration |
| Navigation | `auto_route`, `auto_route_generator` | Typed routes and generated route classes |
| Models | `freezed`, `freezed_annotation`, `json_serializable`, `json_annotation` | Immutable models, unions, JSON |
| Persistence | `sqlite3`, `sqlite3_vec`, `shared_preferences` | Journal, full-text search, vector search, settings |
| Speech | `whisper_ggml` | On-device Whisper inference |
| Formatting and embeddings | `llamadart`, `llamadart_llama_cpp_flutter` | On-device Qwen inference through llama.cpp |
| Audio | `record`, `just_audio`, `audio_session`, `ffmpeg_kit_flutter_new_min` | Capture, playback, decoding |
| Files | `file_picker`, `path_provider`, `archive`, `crypto`, `uuid` | Imports, backups, hashing, IDs |
| Authentication | `local_auth` | Optional biometric or device-credential lock |
| Presentation utilities | `flutter_markdown_plus`, `markdown`, `flutter_slidable`, `intl`, `diacritic`, `logger` | Markdown, lists, formatting, logging |
| HTTP | `http` | Model downloads, public GitHub releases, and update checksums |
| App updates | `package_info_plus`, `pub_semver`, `url_launcher` | Installed version, semantic comparison, external release links |
| Tests | `flutter_test`, `integration_test`, `mocktail`, `flutter_lints` | Unit, widget, and integration tests |

Pinned native dependencies must remain pinned unless a deliberate upgrade is validated across Android, iOS, and macOS. Do not add a second state-management, dependency-injection, routing, or database package.

### Android build toolchain

The app compiles against API 37 with AGP 9.4.1 and Gradle 9.8.2. Keep `minSdk`
at 24 and `targetSdk` tied to Flutter's default; raising `compileSdk` alone must
not opt users into new target-SDK runtime behavior. This compile SDK prepares
the app for dependencies requiring API 37 without changing their versions here.

Kotlin remains at 2.4.21, the latest stable release checked for this upgrade.
Its published fully supported range ends at AGP 9.3.1 and Gradle 9.7.0.
Successful project builds outside that range are project-specific validation,
not a claim of upstream full support. Do not introduce prerelease Kotlin or
suppress compatibility checks to hide this gap. Validate optimized Android
builds and isolated device tests when changing this combination.

## 3. Project layout

```text
app/
  lib/
    main.dart
    application/              # App-wide orchestration
      journal_lifecycle.dart
    core/
      di/                     # get_it + injectable setup
      l10n/                   # ARB and generated localizations
      routes/                 # auto_route definitions and guards
      theme/                  # tokens, theme, system bars, insets
      utils/                  # shared logging and helpers
    data/
      datasources/local/      # SQLite, files, settings
      services/               # AI, downloads, search, archives, auth
    domain/
      entities/               # Immutable models, enums, failures
      services/               # Interfaces
      use_cases/              # Cross-service workflows
    presentation/
      app_store.dart          # App lock and onboarding state
      screens/<feature>/      # Screen + feature store
      stores/                 # Shared stores
      widgets/                # Reusable widgets
  test/                       # Unit and widget tests, mirroring lib/
  integration_test/           # Opt-in platform and real-model tests
  tool/                       # Development probes and reference tools
```

Group files by feature, not by layer, inside `presentation/screens`. Keep one screen and one store per feature folder when the store is screen-scoped. Put shared widgets in `presentation/widgets` and shared stores in `presentation/stores`.

## 4. Layering and dependency rules

- `domain/` is pure Dart. It must not import Flutter, `data/`, `presentation/`, `application/`, or platform packages.
- `data/` implements domain interfaces and may use Flutter, platform channels, SQLite, HTTP, and native AI packages.
- `application/` coordinates long-lived work such as recovery and background indexing. It depends on domain interfaces and small platform-facing adapters; it must not depend on widgets or on concrete persistence or AI implementations.
- `presentation/` depends on domain models, domain interfaces, use cases, and application coordinators. It must not depend on concrete data implementations.
- `core/` provides shared infrastructure. It must not contain feature business logic.
- `main.dart` is the composition root. It wires dependencies, initializes app-level state, and starts the UI.
- Widgets render state and forward user intent to stores. Widgets must not call data services directly, run SQL, manage model downloads, or contain business rules.
- Stores own presentation state and orchestrate calls to domain services and use cases. They never build widgets.
- Use cases coordinate more than one service or enforce an application rule. Keep single-service operations in that service.
- No circular dependencies. Dependencies point inward: presentation → application/domain; application → domain and platform-facing adapters; data → domain; domain → nothing.
- All SQL writes go through `LocalDatabase`. A read-only SQLite snapshot may be opened for backup export; no other code opens the database directly.

## 5. Dependency injection

Use `get_it` as the container and `injectable` for registration.

- `lib/core/di/injection.dart` exposes `getIt` and `configureDependencies()`.
- `lib/core/di/injection.config.dart` is generated. Never edit it.
- `lib/core/di/register_module.dart` registers third-party types such as `AudioRecorder`, `http.Client`, `LocalAuthentication`, and `SharedPreferences`.
- Feature services are registered as lazy singletons behind an interface:
  `@LazySingleton(as: IJournalEntryService)`. Infrastructure objects without a
  domain interface, such as the database, inference queue, and lifecycle
  coordinator, may be concrete lazy singletons.
- App-wide stateful objects are `@singleton` or `@lazySingleton`.
- Screen-scoped stores are `@injectable` and receive their dependencies through the constructor.
- Async initialization uses `@preResolve` only for dependencies that must exist before the first frame.
- Use constructor injection. Do not resolve dependencies inside domain classes, stores, or widgets with `getIt`. Framework entry points such as the composition root, route guards, and constructors with testable overrides may use it.
- Dispose resources with `@disposeMethod` or the generator's dispose callback. Cancel streams, timers, and subscriptions.

Example service registration:

```dart
@LazySingleton(as: IJournalEntryService)
class SqliteJournalEntryService implements IJournalEntryService {
  SqliteJournalEntryService(this._database);

  final LocalDatabase _database;
  // ...
}
```

Example store registration:

```dart
@injectable
class EntryEditStore = _EntryEditStore with _$EntryEditStore;
```

## 6. MobX state

All application and feature state is exposed through MobX stores. Domain models stay immutable; do not decorate them with MobX annotations.

### Store shape

```dart
@singleton
class HomeStore = _HomeStore with _$HomeStore;

abstract class _HomeStore with Store {
  _HomeStore(this._journal, this._lifecycle);

  final IJournalEntryService _journal;
  final JournalLifecycle _lifecycle;

  @observable
  bool isLoading = true;

  @observable
  String? errorCode;

  @observable
  ObservableList<JournalEntry> entries = ObservableList();

  @computed
  bool get isEmpty => !isLoading && entries.isEmpty;

  @action
  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    errorCode = null;
    try {
      final snapshot = await _journal.watchAll().first;
      runInAction(() => entries.replaceAll(snapshot));
    } catch (_) {
      runInAction(() => errorCode = 'loadFailed');
    } finally {
      runInAction(() => isLoading = false);
    }
  }
}
```

Rules:

- Mark stored state `@observable`; keep fields private when they are implementation details.
- Derive view state with `@computed` instead of duplicating it in widgets.
- Mutate state in `@action` methods. Use `runInAction` for mutations after an `await`.
- Guard reentrant async actions with a busy flag. Return a result when the caller must know whether the action succeeded.
- Store a stable failure code, not a localized message. Presentation maps codes to localized text.
- Expose streams through stores; do not expose raw service streams to widgets.
- Cancel stream subscriptions, timers, and reactions in `dispose` or `@disposeMethod`.
- Use `Observer` around the smallest widget subtree that reads observables. Do not wrap whole screens when a smaller region is enough.
- A widget may keep ephemeral local UI state (scroll position, text controller, expansion) in a `StatefulWidget`. App state belongs in a store.
- App-wide stores are `AppStore`, `HomeStore`, the settings stores, and the shared model stores. `HomeStore` is app-wide because the home route owns the shared journal feed. Screen-scoped stores (`EntryDetailStore`, `EntryEditStore`, `OnboardingStore`) are injected into their screen.
- Stores may depend on other stores only when the dependency is part of the same feature; otherwise depend on a service or use case.

## 7. Navigation

Use `auto_route` exclusively.

- The router is `AppRouter` in `lib/core/routes/app_route.dart`, annotated with `@AutoRouterConfig()`.
- Screens are annotated with `@RoutePage()`.
- Add each screen to `AppRouter.routes`.
- Generated routes live in `app_route.gr.dart`; never edit that file.
- Use `context.pushRoute(...)`, `context.replaceRoute(...)`, and `context.maybePop()`. Do not use raw `Navigator.push` with `MaterialPageRoute`.
- Journal routes are protected by `LocalLockGuard`. The guard checks the optional local lock first, then onboarding completion. Unlocking redirects to the lock screen; incomplete onboarding redirects to onboarding.
- When adding a route, run the route generator and verify the guard is applied where journal data is reachable.

```dart
@RoutePage()
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({super.key, required this.entryId});

  final String entryId;
  // ...
}
```

```dart
AutoRoute(page: EntryDetailRoute.page, guards: [LocalLockGuard()]),
```

## 8. Domain models

- Domain entities are immutable. Prefer Freezed for entities, value objects, and unions.
- Use `json_serializable` for models stored in SQLite or exported in backups.
- Keep storage annotations out of domain models; serialization annotations are acceptable when JSON is part of the domain contract.
- Use `copyWith`, value equality, and explicit constructors. Do not mutate fields after construction.
- Use enums for finite states such as entry status and AI action. Use typed failure classes for errors (`AiFailure`, `EntryWriteFailure`, `ModelDownloadCancelled`).
- `JournalEntry` carries immutable audit timestamps (`createdAt`, `updatedAt`) and a user-editable `entryDate`. Ordering and grouping use `effectiveEntryDate`, which falls back to `createdAt` when `entryDate` is absent.
- `JournalEntry.body` returns the accepted formatted note when present; otherwise it returns the original transcription. An intentionally empty formatted note must not reveal the original transcription.
- Writes that can race with edits, imports, or deletion must compare an expected snapshot and reject stale updates.
- Typed capture uses the first saved body as `transcription`, leaves `audioPath`
  and `formattedNote` null, and starts completed. `createTyped` writes the whole
  entry and search text atomically without calling audio or model services.
  A reserved capture ID survives recovery; creation rejects an existing ID
  atomically rather than overwriting an imported or concurrently edited entry.
- Do not put Flutter widgets, platform channels, or database objects in domain entities.

## 9. Persistence and search

`LocalDatabase` is the only component that opens the journal database for writes. It owns one long-lived SQLite connection on a worker isolate. No SQL runs on the UI isolate.

- Enable WAL, foreign keys, and a busy timeout. Version the schema with `PRAGMA user_version`.
- Store each entry as complete JSON plus a UTC ordering key and source hash.
- Mirror searchable text in FTS5.
- Store cosine embeddings in a `vec0` table linked to chunks and entries. Its
  dimension follows the active embedding profile (currently 512; the E5 profile
  uses 384 when validated). Never pad incompatible representations.
- Record the active embedding pipeline identity and generation separately from notes. A new identity clears only derived data.
- Store failed index sources against their source hash. Retry them only on an explicit user action.
- Stage imports in batches of 25 and publish them atomically on a separate WAL connection. Readers continue to see the previous committed journal until publication completes.
- Export from an independent read-only WAL snapshot. Stream already-compressed audio into a disk-backed ZIP and avoid retaining all audio in memory.
- Keep one application writer. Do not open multiple write connections to the same database.
- Resolve app-owned audio paths relative to the documents `audio/` directory. Delete an entry's audio only after the entry deletion succeeds.
- Store settings in `shared_preferences`. Keep model artifacts under the application support directory, outside the journal database and journal exports.
- Use `watchAll` for the shared journal feed, ID-scoped changes for ordinary writes, and full reconciliation after import. Discard stale snapshots by revision.
- Invalidate vectors on content changes, not on date-only changes. A deleted entry must not be resurrected by a late processing update.
- Changing the embedding model, dimensions, pooling, prompt, chunking, or quantization requires a new pipeline identity and re-embedding. Never compare vectors from different identities.
- Schema version 3 stores the selected embedding model in `embedding_selection`.
  This is the durable authority, not a second preference in shared_preferences:
  selection, pipeline identity, generation, and vector-table recreation commit
  atomically on the database worker. Existing installations retain Qwen and its
  pipeline identity. Restart resumes pending work without reverting selection.
- Every effective model switch clears semantic derived data and failed-source
  markers, but never entries, recordings, or FTS. Selecting the current model is
  idempotent. In-flight queries and writes carry an expected generation; the
  database rejects stale work even when two models have the same dimensions.

Search:

- Text search uses FTS5 and returns ranked results across all entry dates.
- Semantic search embeds the query on device, runs exact KNN, filters chunks beyond the calibrated distance cutoff, groups by entry, and returns ranked entries.
- Keep a bounded in-memory query-vector cache. Include pipeline identity and index generation in the cache key.
- Semantic queries are explicit submissions; do not run them on every keystroke.
- Pending and failed index counts must be visible when results are incomplete. Fall back to text search when the model is missing or corrupt.
- When an entry is deleted or edited during a search, resolve results against current entries and never show a removed entry from an older result set.

## 10. Local AI

### Model catalogs

Every model is a pinned artifact with an ID, file name, download URL, byte size, and SHA-256. Catalogs are typed domain entities.

- Speech: six Whisper artifacts, including English-only and multilingual options.
- Formatting: Qwen3 0.6B Q8 (light), Qwen3 1.7B Q4_K_M (balanced),
  Qwen3-4B-Instruct-2507 Q4_K_M and Gemma 3 4B IT Q4_K_M (larger optional
  choices). The conservative recommendation remains on the existing small
  models; 4B options do not imply a measured quality or speed guarantee.
  Gemma downloads require explicit acceptance of the bundled Gemma terms.
- Embeddings: Qwen3-Embedding 0.6B Q8 and EmbeddingGemma 300M Q8. The pinned
  EmbeddingGemma 2 and multilingual-e5-small candidates are visible but cannot be
  downloaded or activated until runtime and retrieval validation passes. An
  unvalidated model has no calibrated cutoff. See `embedding-calibration.md`.

Never download from an unpinned `main` revision. Never switch the active model silently. The active model and the audio language are explicit, persisted choices. An English-only speech model can be active only for explicit English.

### Installation and verification

- `LocalModelDownload` owns progress, cancellation, resume, storage preflight, atomic promotion, and SHA-256 validation.
- Android and iOS delegate to the platform downloader; desktop uses the Dart streaming path.
- `ModelVerification` persists a versioned receipt containing model ID, file name, digest, size, and modification time. Reuse a receipt only when the stat and catalog metadata match.
- Verify the full artifact after an interrupted download or a changed file. A cached stat match avoids rehashing readable, unchanged files.
- Model artifacts are excluded from journal exports and from platform backups as supported by each OS.
- Downloading a model never selects it. Activation verifies the candidate and
  runs a small inference preflight under the inference queue before replacing
  the index. Failed preflight leaves the previous model/index untouched. Active
  models cannot be removed. Gemma 300M downloads require explicit acceptance of
  its bundled Terms of Use and incorporated use restrictions.

### Inference

- `LocalInferenceQueue` serializes all native inference. One job at a time.
- Foreground work (capture, transcription, formatting, user-submitted search) precedes background indexing. Run at most eight foreground jobs before yielding to background work.
- Jobs must release native memory before releasing the queue lease. A cancelled queued job is skipped before acquiring native resources; a running job must check cancellation at safe boundaries.
- Run native inference off the UI isolate. CPU-only inference is the default.
  Llama.cpp sessions use four threads and stay CPU-only. The single exception is
  the optional Android speech Vulkan backend described below; never extend it to
  embeddings or formatting without a separate validated decision.
- On Apple, keep Whisper's GGML/GGUF and quantization implementation symbols
  private using the Podfile linker exclusion list in
  `app/native/whisper_private_symbols.txt`. Otherwise its different GGML version
  can interpose llama.cpp CPU symbols and abort inference. Preserve the public
  `whisper_*` API used by language detection. Changes require native process
  restart and speech/embedding regression tests, not hot reload alone.

Speech:

- Before creating a captured entry, inspect the entire recording for confirmed
  silence using a conservative peak threshold below -60 dBFS. Discard only the
  capture-owned silent file and show a localized snackbar without scheduling
  transcription. Inconclusive or failed analysis preserves the recording and
  follows normal processing; volume is not a speech-versus-noise classifier.
- Reject empty transcripts and Whisper non-speech markers such as `[BLANK_AUDIO]`
  before persisting transcription text. If discovered after an entry was saved,
  keep its original recording and normal retryable error behavior.
- Use `whisper_ggml`. Decode audio to 16 kHz mono PCM at original speed.
- Select the model by explicit file path, not only by enum. Keep the model loaded only for one job.
- Automatic language detection is the default. On Apple platforms, run the app-owned whisper.cpp language-detection pre-pass on at most the first 30 seconds, then free that context before loading the transcription model. Android may use native `auto`.
- English-only models require explicit English and bypass language detection.
- `LocalTranscriptionService.transcribeMeasured` exposes opt-in monotonic stage
  timings without persisting or logging transcript content or paths. Its Whisper
  request timing includes the plugin's own conversion, loading, inference, and
  disposal; it is not an encoder-only metric. Reports also include the backend
  that produced the accepted transcript and whether a CPU fallback happened.
  Qualification evidence and reproduction instructions live in
  `whisper-vulkan-validation.md`.

#### Android speech Vulkan exception

This is the only approved GPU exception. It is speech-only, Android-only, and
must degrade to CPU without user data loss.

- The app depends on the public `theolm/whisper_ggml` fork, pinned to an
  immutable commit on `smartnotes/vulkan` (never a branch name). It ships the
  unchanged API 24 CPU library for all ABIs plus a separate
  `libwhisper_vulkan.so` for `arm64-v8a`, built against the API 28 Vulkan stub.
  The CPU library must never resolve Vulkan 1.1 symbols.
- Eligibility requires Android, arm64, API 28+, Vulkan 1.1 hardware support, a
  successful native capability probe, the user preference enabled, and a closed
  crash circuit.
- `SpeechBackendPolicy` is pure and versioned. Small Q5_1 and Turbo Q5_0 may use
  the GPU at any duration; Base Q8 only at or above the measured cutoff. English
  variants and Large remain CPU until measured.
- A recoverable GPU failure may retry exactly once on the CPU with the same
  converted WAV and queue lease. Cancellation, invalid audio, missing/corrupt
  models, and no-speech failures are never retried as backend failures.
- Before native GPU work, write a minimal synchronous marker (model identity and
  runtime identity only). Clear it after handled success or failure. An
  uncleared marker on startup disables the GPU before journal recovery, and the
  circuit stays open until the user explicitly retries or a new runtime identity
  is shipped.
- The Transcription settings screen exposes a single beta toggle and a retry
  action. Settings must never show a GPU as active when the effective backend is
  CPU.
- Do not compare GPU and CPU transcripts automatically in production. Quality is
  a release gate measured with approved public fixtures, not a runtime heuristic.

Formatting:

- Use `llamadart` with each GGUF's embedded chat template and thinking disabled.
  Qwen3-4B-Instruct-2507 is non-thinking-only. Gemma uses its own template and
  text-only inference; do not download or load a vision projector.
- The context budget is 4,096 tokens: 1,536 reserved output tokens and 64 safety tokens. Reject oversized input; never silently truncate or summarize.
- Return JSON with exactly the required string fields. Reject malformed, incomplete, or empty output.
- Generate an unsaved preview first. Persist only after explicit acceptance. Preserve the recording, original transcription, entry date, and creation timestamp.
- A missing or corrupt formatting model maps to a formatting-specific failure, not the embedding-model message.
- Keep the action enum, prompt mapping, localization, and action sheet in sync.
- Explicit formatting previews run through `IFormattingFeedbackService`, backed
  by the shared native processing notification and timeline feedback. Show
  preparing/running phases with the selected formatting model, then finalize
  and dismiss on success or failure without saving or changing entry status.
  Feedback jobs have independent identities: overlapping capture and formatting
  cannot update or dismiss each other's status, and the latest remaining job is
  restored when the visible job ends. Notification permission/plugin failures
  never fail inference. This reuses the transcription notification mechanism;
  it does not make Dart inference a durable OS worker.
- Formatting prompts specify each preset without sample output: English examples
  can bias small models toward translation, and shared list examples can bias
  presentation. The source alone determines output language, including mixed
  passages, never the English instructions, app locale or preset name. Key points
  selects and shortens source phrases without translating them.
  Journal, formal-summary and casual-recap presets
  require connected prose even when the current note is a list. Faithful
  transcription preserves wording, order and existing lists with grammar and
  punctuation fixes only; it is not a summary or a restoration of original text.

Embeddings:

- Use raw text, not a chat template. Each typed `EmbeddingModel` defines
  architecture, pooling, native/stored dimensions, prefixes, context, and cutoff.
- Qwen uses LAST pooling, 1,024 native dimensions sliced to 512, then L2
  normalization. Only queries receive its retrieval instruction.
- Gemma 300M uses MEAN pooling and the verified projection layers, 768 native
  dimensions sliced to 512, then L2 normalization. Queries use
  `task: search result | query: `; passages use `title: none | text: `.
- Chunk documents with real tokenizer counts including document prefixes:
  384 tokens per chunk, up to 64 tokens of overlap. Context is profile-specific
  (1,024 for current Qwen/Gemma profiles, 512 for the gated E5 candidate).
- Index title, current note, and original transcription, omitting empty parts and exact trimmed duplicates.
- Index in bounded batches, releasing the native session after four chunks so interactive work can take the queue.
- Fetch pending entries in batches of 25, construct indexing source text off the
  UI isolate, hash expected index sources on the database worker, and expand
  Unicode only in bounded windows. Model checks, downloads, verification,
  switching, and reindexing must never display a blocking progress dialog or
  disable journal navigation, capture, reading, editing, or FTS. Throttle model
  progress notifications to at most ten per second plus terminal updates.
- Use the calibrated absolute distance cutoff for semantic matches. Do not make the cutoff relative to the best hit.
- Calibrate each pinned model/representation independently on the training
  split. Keep holdout queries out of threshold selection; report both absent-topic
  false positives and relevant-note recall. A cutoff-policy-only change does
  not require generating new embeddings.
- An embedding failure must not change a successful entry's status or block text search.

### Application orchestration

`JournalLifecycle` owns recovery and automatic indexing. It is started once after the first frame and never depends on a screen.

- Subscribe to embedding readiness changes before watching journal entries.
- On the first journal snapshot, recover interrupted `processing` entries sequentially, once per application lifetime. Leave failed entries for explicit retry.
- On every journal snapshot, request pending indexing.
- After a verified embedding download or repair, request pending indexing even when no entry changed.
- Coalesce index triggers into one drain with a follow-up pass for changes received during indexing.
- Log background failures without blocking the UI. Never retry failed index sources automatically; only an explicit user action retries them.
- Share one `processEntry` path for capture, startup recovery, and explicit recording retries. Keep a per-entry in-flight guard.
- On failure, retain the original audio and transcription, persist an error status, and do not overwrite a concurrent edit.

## 11. Application lifecycle

`main` follows this order:

1. Initialize Flutter bindings and register bundled model licenses.
2. Configure edge-to-edge system UI.
3. Call `configureDependencies()`.
4. Initialize `AppStore` from local settings. This reads the lock flag and onboarding completion only; it must not read model files.
5. Load `SettingsStore`; a failure must not block the first frame.
6. Call `runApp`.
7. In the first post-frame callback, allow deferred model verification, start processing feedback, check model readiness, and start `JournalLifecycle`.

Model checks and journal recovery must never delay route protection or the first frame. Route protection uses the persisted lock and onboarding flags, not model availability.

### App updates

- `IAppUpdateService` separates release/version/platform operations from presentation.
  `GithubAppUpdateService` queries the public `theolm/SmartNotes/releases/latest`
  endpoint without credentials, with a timeout and persisted rate-limit backoff.
- `AppUpdateStore` owns shared MobX state, one startup check per process, manual
  checks, and platform download reconciliation. Resume does not query releases.
  Automatic failures are silent; manual failures have localized feedback.
- Compare semantic versions without build metadata. Only a strictly newer stable
  release is offered. Manual checks bypass ignored/deferred prompts but never
  server backoff. Later defers that version for three days; Ignore suppresses it.
- `AppUpdateHost` offers updates only when resumed, unlocked, onboarded, outside
  editing/recording/processing, and without a root popup. It never delays startup.
- Android uses a separate WorkManager worker, state journal, notification channel,
  and app-private file directory; it does not reuse model download identities or
  select models. Downloads require an explicit size-labelled confirmation and may
  use any connected network. Partial downloads use HTTP Range when supported.
- Before publishing a ready APK and again before installation, check its length,
  SHA-256 from the same release's `SHA256SUMS.txt`, package identifier, version,
  increasing versionCode, and exact installed signer set. The Android installer
  independently verifies the APK signature. Missing metadata/assets fall back to
  the release page. Checksums are integrity checks, not an independent trust root.
- Installation always requires a user action and Android confirmation. Unknown
  sources authorization is requested only at installation time; returning from
  settings requires another Install tap. A non-exported FileProvider grants read
  access only to the private update folder. Updates are excluded from backups
  by the application's existing disabled platform-backup policy.
- Notifications open the update settings after safe navigation becomes possible.
  Update files are deleted after successful installation or replacement. OS
  scheduling and force-stop restrictions apply; background work is not guaranteed.
- Other platforms only open the release page. This is not iOS app distribution.

## 12. Presentation

- One screen file and one store file per feature when the store is screen-scoped.
- Screens are thin: build layout, bind stores with `Observer`, and forward intent.
- Use shared widgets for model catalogs, download rows, entry content, players, and common controls.
- Model settings screens use `ModelSettingsPage` for shared chrome and insets.
  Speech, formatting and embedding catalogs use `ModelCatalogTile` and
  `ModelCatalogActionButton`; family-specific policy stays in their catalogs
  and stores. Embedding row selection confirms index rebuilding, and its
  information dialog retains explicit verification without blocking progress.
- Use Material 3 and the theme layer (`lib/core/theme`) for colors, typography, spacing, shapes, system bars, and insets. Do not hardcode colors, font families, or arbitrary sizes in widgets.
- Use bundled Archivo for UI text and Archivo Black for display headings. Widgets select `TextTheme` roles.
- All user-facing text must live in `lib/core/l10n/app_en.arb` and be accessed through `AppLocalizations`. Do not display raw store messages; map stable failure codes through a presentation mapper.
- Use 48dp minimum touch targets, safe-area insets, bounded reading columns, and reduced-motion handling.
- Use `ThemeMode.system` for light and dark themes. Visual hierarchy relies on whitespace and tonal surfaces; elevation and shadows remain at zero.
- Keep model download rows consistent between onboarding and settings: name, size, progress, cancel, resume, retry, verify, delete, and active state.
- Embedding downloads and explicit model selection live on the guarded
  `EmbeddingModelsRoute`, reached from Settings → Search model. Settings names
  the persisted active model and readiness, never an assumed default while
  loading. The shared catalog highlights the active selection and collapses
  unavailable candidates. Search by meaning settings contain only explanations,
  index progress/repair and, when needed, a direct model-management link.
- For destructive or irreversible actions, confirm first and keep the saved state unchanged on failure.
- Use `auto_route` transitions. Do not introduce a second navigation system.
- Keep the capture action dominant. UI chrome must not compete with the journal content.

### Adaptive journal workspace

- `HomeRoute` hosts `JournalWorkspaceScreen`, a persistent journal feed and a
  nested `AutoRouter`. Its initial child is `JournalEmptyRoute`; detail and edit
  routes are children of this same workspace and retain `LocalLockGuard`.
- `JournalCapture` belongs above both content panes, not inside the feed. It
  binds the shared `HomeStore` once; the feed reports its ephemeral search mode
  to the workspace without owning capture UI. Its recording scrim blocks touch,
  focus, and semantics across the entire workspace. Stop remains available even
  when folding hides the feed. Content panes own keyboard avoidance; the outer
  capture scaffold does not resize them a second time. FAB geometry respects
  keyboard insets and the unobstructed region resolved by `AppPaneLayout`.
- The child route is the source of truth for the open entry. Do not maintain a
  second selected-entry observable or mutate the route stack on a size change.
  Selecting another entry replaces the detail route rather than accumulating
  a history of sidebar selections. Back returns to the journal.
- `AppPaneLayout` in the theme layer resolves immutable geometry from local
  constraints, text scaling, safe insets, keyboard occlusion, directionality,
  and Android display features. It does not inspect hardware names, device
  categories, platform, or orientation. Width minimums describe usable content;
  they are not device classifications.
- `AdaptivePanes` keeps both children in stable element positions. Resize,
  fold/unfold, keyboard changes, and editor expansion change geometry and
  visibility, never navigator or editor ownership. Hidden panes exclude focus,
  semantics, and animation tickers. Each pane receives local MediaQuery geometry
  and insets. Keep screen-level controllers and feature stores alive for their
  route/session; do not promote them to global singletons to survive resize.
- The existing editor's recovery draft remains a failure-recovery mechanism,
  not a way to transfer an editor between separate compact and wide widgets.
  Text, selection, focus, search, and scroll have live session ownership.
- `EntryEditRoute` also hosts new typed captures without a saved entry ID.
  The route, not a selected saved ID, determines whether the editor pane is
  visible. Optional initial metadata remains draft data until a nonblank body
  is saved. New-capture recovery has no saved source snapshot and uses a separate
  draft key plus a reserved entry ID. Recovery checks for an already committed
  entry before offering Resume/Discard, closing the commit/cleanup crash window.
  Existing entry draft JSON remains compatible. The first save opens detail;
  subsequent editing retains concurrency-checked metadata review.
- `JournalNavigationSession` is a workspace-owned presentation handshake for
  leaving the editor. Sidebar and notification entry selection await the same
  Save/Discard/Keep editing flow, including metadata review and write failure.
  `AppRouter.openJournalEntry` forwards notification requests to that action
  when a workspace is mounted; cold navigation constructs guarded nested routes.
- Respect separating hinges and half-open folds. A flat, non-occluding crease
  does not force a split. If two usable regions cannot fit, use an unobstructed
  single region. No custom tabletop workflow or device-specific package is
  required. Use SDK layout primitives instead of a second layout framework.
- The first implementation adds no custom keyboard shortcuts, multi-window
  documents, or user-resizable pane dividers. Standard keyboard focus and
  pointer interaction remain supported.

## 13. Testing

- Put unit and widget tests in `app/test/`, mirroring `lib/` paths.
- Put platform and real-model tests in `app/integration_test/`.
- Use `mocktail` for interfaces and small fakes for streams and platform channels.
- Test stores by calling actions and asserting observables, computed values, and emitted states.
- Test services at their interface boundary. Test persistence migrations against a temporary database.
- Do not download real models in unit tests. Use small fixtures and injected clients.
- Real-model and device tests are opt-in. Use a separate application ID or test install; device tests may uninstall the app and erase data.
- `integration_test/local_formatting_platform_test.dart` accepts
  `FORMATTING_MODEL_PATH` and `FORMATTING_MODEL_ID` to exercise any pinned
  formatting artifact offline (metadata and every preset). Accept the model's
  license before obtaining it; the test never downloads weights. Catalog/unit
  coverage is not evidence of native compatibility, fidelity or acceptable
  latency: validate the new 4B artifacts on target platforms separately.
- Formatting regression coverage checks preset-specific, example-free prompts,
  unchanged-source previews and explicitly accepted chains. The opt-in native
  test asserts prose versus bullets, faithful wording and existing source lists,
  source-language preservation, and a key-points-to-journal transformation.
  Key-points language fixtures explicitly cover Portuguese, Spanish, French and
  mixed Portuguese/English, including negation, uncertainty, quantities and days.
  Structural assertions are not a semantic-fidelity guarantee; review real-model
  outputs separately before claiming quality across all supported artifacts.
- Native macOS integration coverage for adaptive entry selection lives in
  `integration_test/adaptive_journal_platform_test.dart`. It opens only a generated
  temporary journal, runs the actual SQLite worker and nested routes, and never
  initializes the user's journal or model services. It also exercises typed
  capture through metadata, the shared editor, and completed audio-free storage.
- Stop a live macOS debug app before rebuilding its native assets with another
  build or native integration test. Relaunch the process afterwards; do not hot
  reload the old process against replaced native frameworks. Native SQLite
  connections and prepared statements cannot be transferred between separately
  loaded copies of the SQLite library. A hot restart is not a substitute for a
  process restart after a native rebuild.
- Run `flutter analyze` and `flutter test` before every change. Add tests for behavior changes, failure paths, and concurrency guards.

## 14. Code generation

Run generation after changing models, stores, DI, routes, or localization:

```sh
cd app
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

Generated files include `*.freezed.dart`, `*.g.dart`, `injection.config.dart`, `app_route.gr.dart`, and localization output. Generated files are checked in but must never be edited manually. Re-run the generator after changing the source annotation or ARB file.

## 15. Error handling

- Use typed failures, not raw exceptions, at service boundaries.
- Stores must expose stable failure codes. Presentation maps codes to localized messages.
- Never log journal text, recordings, queries, embeddings, filesystem paths, or credentials.
- Expected-entry checks protect writes against edits, imports, and deletion. A stale operation must fail cleanly, not overwrite newer data.
- Do not silently truncate input, skip model verification, switch models, or fall back to a cloud service.
- If a model is missing or corrupt, leave saved data intact and offer a repair path.
- Background failures are logged without blocking the UI and are retried only through explicit user actions.

## 16. Privacy and security

- Keep all journal content on the device. Do not add a backend, account, sync, analytics, crash-reporting service, or remote AI call.
- Do not add an API-key flow or credential storage. Model downloads use public, pinned URLs.
- Verify model artifacts with SHA-256 before use. Do not trust a download merely because it completed.
- App lock is a UI gate. It does not encrypt the database, recordings, or exports.
- Android backup and data transfer are disabled. iOS excludes model files from iCloud Backup. macOS backups are user-managed.
- Journal exports are readable ZIP files. Validate archive paths and sizes before writing; never extract archive paths verbatim.
- Keep model artifacts and derived search data out of journal exports.
- Treat model weights, prompts, and downloaded files as replaceable data, not journal data.

## 17. Conventions

- Use `snake_case.dart` files, `PascalCase` types, and `camelCase` members.
- Name interfaces `I...`, services `...Service`, stores `...Store`, screens `...Screen`, repositories `...Repository`, and use cases `...UseCase`.
- Keep imports package-qualified (`package:smartnotes/...`) across layers.
- Keep files focused. Extract a widget when a build method grows or when the same composition is reused.
- Comments explain intent, constraints, and non-obvious decisions, not syntax.
- Prefer the existing stack. Do not add a new state, DI, routing, database, or AI runtime package without a concrete need and platform validation.
- Keep the dependency graph acyclic. Run `flutter analyze` after moving code between layers.
- Preserve generated code and run generators instead of editing output.

## 18. Change checklist

1. Define or extend the domain entity, enum, failure, or service interface.
2. Implement the behavior in `data/` or in a use case; keep SQL in `LocalDatabase`.
3. Register the implementation with `injectable` and the correct lifetime.
4. Add or extend a MobX store. Use observables, computed values, actions, and stable failure codes.
5. Build the screen with `Observer`, theme tokens, localized strings, and accessibility defaults.
6. Add or update unit, widget, and integration tests.
7. Run code generation, `flutter analyze`, and `flutter test`.
8. Verify that no journal content, path, or credential reached logs, errors, or backups.
