# SmartNotes

SmartNotes is an open-source, local-first voice journal for Android, iOS, and macOS. Tap record, speak, and keep a private journal on your device. On-device AI can transcribe your voice, organize a note, and search by meaning. There is no account, cloud sync, backend, or telemetry.

The app is early-stage (`0.1.x`). The interface is currently English; the language used for transcription is selected separately.

## Download

### Android · Obtainium

[Obtainium](https://obtainium.imranr.dev/) installs SmartNotes directly from GitHub Releases and checks for new versions, so you do not have to download each update manually.

[<img src="docs/assets/badge_obtainium.png" alt="Get it on Obtainium" height="72">](https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/theolm/SmartNotes)

1. Install Obtainium from its [official releases](https://github.com/ImranR98/Obtainium/releases/latest).
2. On your Android device, tap the badge above and confirm adding SmartNotes in Obtainium.
3. Enable automatic APK filtering by architecture in the app's Obtainium settings, then install SmartNotes. Releases provide separate APKs for `arm64-v8a`, `armeabi-v7a`, and `x86_64`.
4. Configure background update checks and automatic downloads in Obtainium as desired. Downloads and installations depend on your settings and Android permissions; installation may still require confirmation.

For manual setup, open Obtainium → **Add App** and paste `https://github.com/theolm/SmartNotes`. The badge's redirect page also provides guidance if Obtainium is not installed.

Prefer a direct download? Get the APK from [GitHub Releases](https://github.com/theolm/SmartNotes/releases/latest). Choose `arm64-v8a` for most modern phones, `armeabi-v7a` for older 32-bit phones, or `x86_64` for x86 devices and emulators.

Obtainium is Android-only.

<!-- Official Obtainium badge, hosted locally as recommended: https://wiki.obtainium.imranr.dev/deep_links/#badging-your-project -->

### macOS

Requires macOS 14 or newer. The universal DMG supports both Apple Silicon and Intel Macs.

1. Download `SmartNotes-<version>-macos-universal.dmg` from [GitHub Releases](https://github.com/theolm/SmartNotes/releases/latest).
2. Open the DMG and drag **SmartNotes** into **Applications**.
3. Eject the disk image and open SmartNotes from Applications.
4. The app is ad-hoc signed and **not notarized**, so macOS may block the first launch. After attempting to open it, go to **System Settings → Privacy & Security → Open Anyway** and confirm. On macOS 14, you can also right-click the app and choose **Open**.
5. Allow microphone access when prompted to record voice notes.

Only approve the app if you downloaded it from this repository's releases and trust the source. See [the release guide](docs/release.md#macos-builds) for signing details.

### iOS · Build from source

Requires iOS 16.4 or newer and a Mac with Xcode, CocoaPods, and Flutter installed. The release workflow does **not** currently publish an iOS IPA; installation requires building and signing the app yourself.

1. Download or clone this repository, then follow [Build and run](#build-and-run) through the code-generation steps in the `app/` directory.
2. Connect your iPhone to the Mac and enable **Developer Mode** on the phone if prompted.
3. Open `app/ios/Runner.xcworkspace` in Xcode. Select the **Runner** target, then choose your development team under **Signing & Capabilities**. Use a bundle identifier available to your team if required.
4. Select your iPhone as the run destination and click **Run**. Complete any device pairing or developer-trust prompts, then allow microphone access when prompted by SmartNotes.

An Apple ID and valid development signing are required. Free Personal Team installations expire and must be rebuilt periodically; this is not an automatic-update distribution channel.

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
- Internet access downloads model files, checks public GitHub releases at app startup, and downloads app updates only after confirmation. No journal content is transmitted. Transcription, formatting, search, and reading work offline.
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

Official builds are produced by GitHub Actions from `v*` tags. Android releases are
signed with the CI keystore; macOS releases are ad-hoc signed and not notarized, so
the first launch requires approval in System Settings. See
[`docs/release.md`](docs/release.md) for the release process and signing setup.

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
