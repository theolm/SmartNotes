# SmartNotes Architecture

This document defines the architecture that all SmartNotes code must follow. It is the source of truth for packages, layering, dependency injection, MobX state, navigation, persistence, local AI, presentation, testing, and code generation. New code must follow these rules. When existing code differs, converge on this document as part of the change instead of introducing another pattern.

## 1. Product constraints

- Android, iOS, and macOS are supported. Flutter web is not supported.
- The app is local-first. Journal entries, recordings, transcriptions, settings, and search data stay on the device.
- There is no account, backend, cloud sync, remote AI, analytics, telemetry, advertising, or API key.
- Network access is limited to downloading pinned model files.
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
| HTTP | `http` | Model downloads only |
| Tests | `flutter_test`, `integration_test`, `mocktail`, `flutter_lints` | Unit, widget, and integration tests |

Pinned native dependencies must remain pinned unless a deliberate upgrade is validated across Android, iOS, and macOS. Do not add a second state-management, dependency-injection, routing, or database package.

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
- Store 512-dimensional cosine embeddings in a `vec0` table linked to chunks and entries.
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
- Formatting: two Qwen3 artifacts, one light and one balanced.
- Embeddings: Qwen3-Embedding 0.6B Q8.

Never download from an unpinned `main` revision. Never switch the active model silently. The active model and the audio language are explicit, persisted choices. An English-only speech model can be active only for explicit English.

### Installation and verification

- `LocalModelDownload` owns progress, cancellation, resume, storage preflight, atomic promotion, and SHA-256 validation.
- Android and iOS delegate to the platform downloader; desktop uses the Dart streaming path.
- `ModelVerification` persists a versioned receipt containing model ID, file name, digest, size, and modification time. Reuse a receipt only when the stat and catalog metadata match.
- Verify the full artifact after an interrupted download or a changed file. A cached stat match avoids rehashing readable, unchanged files.
- Model artifacts are excluded from journal exports and from platform backups as supported by each OS.

### Inference

- `LocalInferenceQueue` serializes all native inference. One job at a time.
- Foreground work (capture, transcription, formatting, user-submitted search) precedes background indexing. Run at most eight foreground jobs before yielding to background work.
- Jobs must release native memory before releasing the queue lease. A cancelled queued job is skipped before acquiring native resources; a running job must check cancellation at safe boundaries.
- Run native inference off the UI isolate. Use CPU-only inference. Llama.cpp sessions use four threads; the speech binding stays on its CPU path. Do not add a GPU/NPU backend without deliberate validation.

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

Formatting:

- Use `llamadart` with the Qwen chat template and thinking disabled.
- The context budget is 4,096 tokens: 1,536 reserved output tokens and 64 safety tokens. Reject oversized input; never silently truncate or summarize.
- Return JSON with exactly the required string fields. Reject malformed, incomplete, or empty output.
- Generate an unsaved preview first. Persist only after explicit acceptance. Preserve the recording, original transcription, entry date, and creation timestamp.
- A missing or corrupt formatting model maps to a formatting-specific failure, not the embedding-model message.
- Keep the action enum, prompt mapping, localization, and action sheet in sync.

Embeddings:

- Use raw text, not a chat template. Queries alone receive the retrieval instruction.
- Use Qwen3-Embedding with last-token pooling. Validate 1,024 native dimensions, slice to 512, then L2-normalize.
- Chunk documents with real tokenizer counts: 384 tokens per chunk, up to 64 tokens of overlap, within a 1,024-token context.
- Index title, current note, and original transcription, omitting empty parts and exact trimmed duplicates.
- Index in bounded batches, releasing the native session after four chunks so interactive work can take the queue.
- Use the calibrated absolute distance cutoff for semantic matches. Do not make the cutoff relative to the best hit.
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

## 12. Presentation

- One screen file and one store file per feature when the store is screen-scoped.
- Screens are thin: build layout, bind stores with `Observer`, and forward intent.
- Use shared widgets for model catalogs, download rows, entry content, players, and common controls.
- Use Material 3 and the theme layer (`lib/core/theme`) for colors, typography, spacing, shapes, system bars, and insets. Do not hardcode colors, font families, or arbitrary sizes in widgets.
- Use bundled Archivo for UI text and Archivo Black for display headings. Widgets select `TextTheme` roles.
- All user-facing text must live in `lib/core/l10n/app_en.arb` and be accessed through `AppLocalizations`. Do not display raw store messages; map stable failure codes through a presentation mapper.
- Use 48dp minimum touch targets, safe-area insets, bounded reading columns, and reduced-motion handling.
- Use `ThemeMode.system` for light and dark themes. Visual hierarchy relies on whitespace and tonal surfaces; elevation and shadows remain at zero.
- Keep model download rows consistent between onboarding and settings: name, size, progress, cancel, resume, retry, verify, delete, and active state.
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
