# SmartNotes

A local-first Flutter voice journal for Android, iOS, and macOS. Tap to record, tap to stop;
your recording is saved on the device and AI can turn it into a structured
Markdown note. No account, Firebase, app backend, or cloud synchronization.

## Features

- Local SQLite journal and original audio files.
- Six selectable offline Whisper models through whisper.cpp, including English-only and multilingual options.
- Device-aware speech-model recommendations constrained by the chosen audio language.
- Offline selectable note formatting with Qwen3 0.6B Q8 or 1.7B Q4_K_M and six presentation styles.
- Device-aware formatting-model recommendations, explicit active selection, and optional onboarding.
- Offline full-text search with SQLite FTS5.
- Offline semantic retrieval with **sqlite-vec**, using Qwen3-Embedding-0.6B
  Q8_0, last-token pooling and normalized 512-dimensional Matryoshka vectors.
- Timeline, Markdown viewing/editing, recoverable processing, and optional
  biometric/device-credential app lock.
- ZIP export/import of notes and available recordings, excluding models and vectors.
- System-aware light/dark themes and audio-language selection.

## Getting started

On first launch, onboarding explains the app, asks for your audio language,
lets you select any number of Whisper speech models and one compatible default,
then offers an optional formatting model, and requires Qwen3-Embedding-0.6B Q8_0
(639.2 MB) for search by meaning. The formatting step can be skipped; a
formatting model is only needed for AI organization and can be installed later
in Settings. Download progress, cancellation, resumable partial files, and SHA-256
verification are supported. No account, API key, or paid AI service is needed.
Setup completion is saved locally; a missing/corrupt active speech model or
required embedding model requires repair, while optional speech and formatting
models may be absent.
The interface is currently English; the language choice controls transcription.

Open Settings from the journal toolbar to change the language, repair model
setup, manage transcription or formatting models, or inspect indexing progress.
Existing installations install only missing models and may browse saved notes
while setup is incomplete. Obsolete API-key preferences and mobile secure-store
entries are deleted independently at startup; unavailable stores are retried
next launch. No credential is read or used.

After installing models, transcription, formatting and both search modes work
without internet. Failures retain original audio and transcription for retry.
Completed notes are indexed gradually in the background. **Index pending notes**
retries failures; **Rebuild search index** regenerates all vectors locally.
The old OpenAI vector space is invalidated transactionally, even though both
spaces have 512 dimensions. Notes, recordings, transcriptions, dates and text
search remain intact. Incomplete semantic search is disclosed in the UI.
Semantic queries run only on explicit submission, not on each keystroke.

## Privacy and backups

AI processing is offline after model installation. There is no cloud sync or automatic
Android backup. Export regularly: uninstalling the app, clearing its data,
or losing the device can lose the journal. Android backup/data transfer is
excluded by the app's backup rules. On iOS, downloaded model directories and
verified model files are explicitly excluded from iCloud Backup. The macOS app
uses Application Support and has no iCloud container; Time Machine and other
user-managed macOS backups may still contain downloaded models.

The database and recordings are **not encrypted by the app**. App lock protects
the interface only. Local AI does not encrypt the journal or its exports.
The only production HTTP operations download pinned model files; recordings,
notes and queries are not uploaded and there is no cloud fallback.

Exports are readable ZIP archives containing notes and available audio, not
models or vectors. Keep them safe. Archives are limited to 100 MB compressed and
500 MB expanded. Import replaces matching note IDs; imported incomplete
recordings are marked retryable. Reindex restored notes when needed.

## Development

From `app/`, using a Flutter release supporting Dart 3.12 or newer:

```sh
flutter pub get
dart run build_runner build
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

SQLite and sqlite-vec compile/bundle through Dart native build hooks. A native
C toolchain is needed for tests/builds; Android builds also need the SDK/NDK;
Apple builds need Xcode and CocoaPods (Whisper currently uses CocoaPods,
alongside Swift Package Manager plugins, including FFmpeg). Minimum targets are Android API 24,
iOS 16.4, and macOS 14.0; Android uses NDK 29.0.13113456.
macOS asks for microphone permission at first recording.
`sqlite3_vec` is pinned to 0.1.2 and bundles upstream sqlite-vec 0.1.9. It is a
community MIT binding to sqlite-vec, **not** SQLiteAI's `sqlite_vector` package.
Flutter web is not supported by this native persistence implementation.

The engine is pinned to `whisper_ggml` 2.7.1 / whisper.cpp 1.9.1. We pass our
verified selected model path explicitly; the plugin's automatic download is not used.
FFmpeg is overridden to 3.6.7 for native arm64 iOS simulator support; its consumed
Dart API is smoke-tested against this Whisper binding. Resolve/build Apple targets
sequentially on a fresh machine to avoid racing SwiftPM's shared artifact cache.
Its Apple file wrapper rejects `auto`, so an app-owned C API detection pre-pass
selects the language before transcription on iOS/macOS. This loads the model
twice sequentially, never simultaneously; choosing a language skips the extra
pass. Android accepts `auto` directly. All inference remains in worker isolates.
Recordings are decoded to 16 kHz mono PCM at their original speed, not accelerated.
See `integration_test/local_stt_platform_test.dart` for an opt-in real-model
smoke test using `STT_MODEL_PATH`, `STT_AUDIO_PATH` (upstream JFK sample), and
optional `STT_PORTUGUESE_AUDIO_PATH` (Portuguese speech containing "nota" and
"projeto") Dart defines. Model files are not bundled into the app/test suite.

### Speech model catalog

Onboarding lists compact model rows with sizes, language coverage, benefits, and
processing-cost warnings. A row offers download while unavailable, a cancellable
spinner while queued or transferring, and delete once installed (the active model
must be replaced first). Tapping an installed compatible row makes it active in
place and outlines it; the list order stays stable, and the Active model label
eases in with a short height/fade transition. Settings → Transcription models
uses the same rows for later downloads, activation, and removal. All six can be
installed, but inference loads only one at a time. The active model and audio language are persisted
together; English-only models cannot be active for another language or automatic
detection. Existing verified Base installations remain active without another
download.

| Model | Artifact | Download |
| --- | --- | ---: |
| Base | Q8_0 | 81.8 MB |
| Small.en (English only) | Q8_0 | 264.5 MB |
| Medium.en (English only) | Q5_0 | 539.2 MB |
| Small | Q5_1 | 190.1 MB |
| Large-v3-turbo | Q5_0 | 574.0 MB |
| Large-v3 | Q5_0 | 1.08 GB |

Hardware recommendations are conservative **estimates**, not benchmarks or RAM
requirements. Policy v1 uses local physical RAM, low-memory status, process ABI,
and available CPU information. Unknown/low-memory profiles favor Base; 64-bit
profiles with at least 6 GiB reported physical RAM favor Small.en for English
or Small for other supported languages/automatic detection. Large-model automatic
recommendation requires a measured, qualified SoC profile; that list initially
remains empty. More RAM alone never certifies CPU speed. All models remain
available for manual selection. Whisper currently runs on CPU (Accelerate on
Apple), not smartphone GPU/NPU. Download size is not process memory usage.

### Formatting model catalog

Formatting is optional and separate from transcription. Onboarding includes a
skippable formatting step; Settings → Formatting models uses the same compact
rows for later installation. A row offers download, cancellation, resume,
retry, delete, and explicit activation. The first downloaded model becomes
active when none is active; a second download does not switch the active model.
The active model cannot be deleted until another model is selected. Missing or
corrupt formatting weights only block AI organization, never recording,
transcription, reading, search, or backups.

| Model | Artifact | Download | Position |
| --- | --- | ---: | --- |
| Qwen3 0.6B | Q8_0 | 639.4 MB | Light; lower-memory devices |
| Qwen3 1.7B | Q4_K_M | 1.11 GB | Balanced; recommended for most devices |

The recommendation is a conservative device-memory estimate, not a benchmark.
Unknown or low-memory profiles favor 0.6B; 64-bit devices with at least 6 GiB
reported physical RAM favor 1.7B. The recommendation never downloads or switches
a model. Both artifacts are pinned, multilingual, SHA-256 verified, and run
CPU-only through the existing llama.cpp path. The 0.6B tier is released only
after passing the fidelity gate described in ADR-022; its capability copy states
that it may omit details on long or complex notes.

When the magic wand is tapped without a ready active formatting model, the app
explains the model requirement and offers a direct path to Settings. Returning
after installing and selecting a model opens the AI action list; no action runs
automatically.

### Safe Android device tests

Flutter integration tests can uninstall their package and erase its data.
**Never run device tests against a journal installation.** Android supports an
isolated package override, without changing the production identifier:

```sh
python3 -m http.server 8766 --bind 127.0.0.1 --directory FIXTURE_ROOT
adb reverse tcp:8766 tcp:8766
ORG_GRADLE_PROJECT_smartnotesApplicationId=dev.theolm.smartnotes.validation \
  flutter test integration_test/whisper_catalog_platform_test.dart \
  -d DEVICE_ID --no-uninstall \
  --dart-define=STT_FIXTURE_URL=http://127.0.0.1:8766
```

`FIXTURE_ROOT` contains `speech_models/` with the six pinned artifacts, plus
`jfk.wav` and `portuguese.aiff` containing Portuguese speech with "nota" and
"projeto". Fixtures are streamed into a unique test directory before offline
inference. On desktop, `STT_CATALOG_ROOT` can point directly at the same
directory. The suite does not initialize journal DI. Use a separate macOS/iOS
test installation too; `--no-uninstall` alone does not isolate application data.
See `docs/native-dependencies.md` for validation status.

Platform-specific build and run:

```sh
flutter run -d macos                      # desktop
flutter build macos --release             # build/macos/Build/Products/Release/SmartNotes.app
flutter test integration_test -d macos    # platform checks; model tests opt in via Dart defines
```

The macOS target builds without an Apple account using ad-hoc signing.
To harden a distributed build, sign the app with an Apple Development team,
restore the sandbox capability in
`app/macos/Runner/*.entitlements` (app sandbox, audio input, user-selected
files, and network client), and set
`DEVELOPMENT_TEAM` in `app/macos/Runner/Configs/AppInfo.xcconfig`.

Release signing currently uses `app/android/keystore/key.properties` or the
`ALIAS`/`PASS` environment variables. Supply your own signing credentials for
distribution; never publish credentials or local environment files.

For macOS release distribution, archive/sign/notarize the generated
`build/macos/Build/Products/Release/SmartNotes.app` with your Apple Developer
identity.

See [domain vocabulary](CONTEXT.md), [architecture](docs/architecture.md),
[ADRs](docs/adr/), and [native dependency notices](docs/native-dependencies.md).

## License

MIT. See [LICENSE](LICENSE).
