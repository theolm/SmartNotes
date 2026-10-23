# SmartNotes

SmartNotes is an open-source, local-first voice journal for Android, iOS, and macOS. Tap record, speak, and keep a private journal on your device. On-device AI can transcribe your voice, organize a note, and search by meaning. There is no account, cloud sync, backend, or telemetry.

The app is early-stage (`0.1.x`). The interface is currently English; the language used for transcription is selected separately.

## Features

- One-tap voice capture; the original recording is kept for playback and retry.
- Offline transcription with six selectable Whisper models, including English-only and multilingual options.
- Optional on-device note organization with Qwen3 0.6B or 1.7B and four presentation presets: Organize, Journal style, Key points, and Clean up wording.
- Offline full-text search and offline search by meaning.
- Timeline, Markdown preview and editing, recoverable processing, and retry.
- Optional biometric or device-credential app lock.
- ZIP export and import of notes and available recordings.
- Light and dark themes, with a selectable audio language.
- Android, iOS, and macOS.

## Privacy

- Notes, recordings, transcriptions, and search data stay on the device.
- There is no account, analytics, telemetry, advertising, cloud AI, or API key.
- The internet is used only to download model files. After setup, transcription, formatting, search, and reading work offline.
- The journal database and recordings are not encrypted by the app. App lock protects the interface, not the files.
- Exported backups are readable ZIP archives. Store them safely.
- Uninstalling the app or clearing its data deletes the journal. Export backups regularly.
- Android backup and data transfer are disabled. iOS excludes downloaded model files from iCloud Backup. On macOS, system backups are user-managed.
- Downloaded models are excluded from journal exports.

## Models

Models are downloaded on first use; they are not bundled with the app. Downloads require internet, can be cancelled and resumed, and are verified with SHA-256 before use. All models run on the device.

### Speech models

| Model | Download | Notes |
| --- | ---: | --- |
| Base | 81.8 MB | Multilingual; smallest and fastest. |
| Small.en | 264.5 MB | English-only. |
| Medium.en | 539.2 MB | English-only; higher quality, slower. |
| Small | 190.1 MB | Multilingual; balanced. |
| Large-v3-turbo | 574.0 MB | Multilingual; high quality, slower. |
| Large-v3 | 1.08 GB | Multilingual; maximum quality, slowest. |

### Formatting models

| Model | Download | Notes |
| --- | ---: | --- |
| Qwen3 0.6B Q8 | 639.4 MB | Lower-memory devices; may omit details on long or complex notes. |
| Qwen3 1.7B Q4_K_M | 1.11 GB | Recommended for most devices. |

Formatting is optional. A missing formatting model never blocks recording, transcription, reading, text search, or backups.

### Search model

Qwen3-Embedding 0.6B Q8 (639.2 MB) is downloaded during onboarding and used for on-device semantic search. Text search does not depend on the embedding model.

## Requirements

- Flutter stable with Dart 3.12 or newer.
- Android: SDK and NDK `29.0.13113456`, API 24 or newer.
- iOS: Xcode, CocoaPods, iOS 16.4 or newer.
- macOS: Xcode, macOS 14 or newer.
- A native C toolchain for the SQLite and sqlite-vec build hooks.

## Build and run

From the `app/` directory:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter run
```

Choose a target explicitly when needed:

```sh
flutter run -d macos
flutter run -d <device-id>
```

Build release artifacts:

```sh
flutter build apk
flutter build ios
flutter build macos
```

Release signing is not included. Supply your own Android keystore and Apple signing identity.

## Tests

```sh
cd app
flutter analyze
flutter test
```

Integration tests are opt-in and may uninstall the app on a device. Never run them against a journal installation; use a separate test package or test install.

```sh
flutter test integration_test -d <device-id>
```

Some model tests require local model paths passed as Dart defines. See the test files for the required variables.

## Open source

SmartNotes is MIT-licensed and independent. Issues and pull requests are welcome.

Before submitting a change:

- Run `flutter analyze` and `flutter test`.
- Add or update tests for behavior changes.
- Keep changes focused and avoid unrelated refactors.
- Read `docs/architecture.md` before changing code and `docs/DESIGN.md` before changing UI.
- Report security issues privately as described in `SECURITY.md`.

Bundled model license notices are included under `app/assets/licenses/`.

SmartNotes is not affiliated with OpenAI, Alibaba Cloud, or the authors of the models it downloads.

## Acknowledgements

SmartNotes builds on Whisper and whisper.cpp, Qwen3 and Qwen3-Embedding, llama.cpp and llamadart, sqlite-vec, FFmpeg, Flutter, and the Archivo typeface.

## License

MIT. See `LICENSE`.
