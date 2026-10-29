# Release process

Releases are built and published by [`.github/workflows/release.yml`](../.github/workflows/release.yml).
The workflow runs when a semver tag is pushed and produces:

| Artifact | Platform |
|---|---|
| `SmartNotes-<version>-android-arm64-v8a.apk` | Almost all modern phones; recommended download |
| `SmartNotes-<version>-android-armeabi-v7a.apk` | Older 32-bit phones |
| `SmartNotes-<version>-android-x86_64.apk` | Emulators and x86 Chromebooks |
| `SmartNotes-<version>-macos-universal.dmg` | Universal macOS app (Apple Silicon and Intel) |
| `SHA256SUMS.txt` | SHA-256 checksums for all assets |

Android APKs are split per ABI to keep each download small. The release is only
created after all build jobs succeed.

The arm64 APK also contains the optional `libwhisper_vulkan.so` for the beta GPU
speech path (about 32 MB uncompressed). The other ABI APKs stay CPU-only. Verify
that the Vulkan library is present only in the arm64 APK, that both libraries
declare 16 KB page alignment, and that the size increase is reported in the
release notes before publishing.

## In-app update contract

The app queries the public GitHub `releases/latest` endpoint once per process
startup and on explicit manual checks. Publish stable semantic-version tags;
drafts and prereleases are not update candidates. Version build metadata is not
used to decide whether a release is newer.

For Android's integrated updater, preserve the exact asset names above and
publish `SHA256SUMS.txt` with one standard sha256sum entry per asset. The app
selects the ABI matching its running process. APKs must retain the production
application ID and signing certificate, match the release version, and have a
strictly increasing versionCode. Missing compatible APK/checksum assets fall
back to opening the release page. Do not replace already published assets with
different binaries: clients may already have downloaded their checksums.

Downloads use a separate WorkManager job and app-private files, with progress,
cancellation, bounded network retries, and partial-file resume. Installation
requires the user's Install action, unknown-source authorization where required,
and confirmation in Android's installer. iOS and desktop open the release page
only. GitHub distributions must remain separate from any future Play Store build
that cannot use this APK installation permission/flow.

Before release, test two consecutively versioned, identically signed APKs on a
device: background download, process restart, cancellation, offline recovery,
low storage, notifications denied, unknown-source permission denied/granted,
installer cancellation, wrong checksum/package/signer, and preservation of the
journal and downloaded models after successful installation. Never uninstall a
user's journal to test updates. Use an isolated test application ID and a native
test harness with matching APK/checksum fixtures; the production downloader
intentionally accepts only this repository's GitHub release URLs.

## CI validation

PR checks and release builds use Flutter 3.47.8, pinned to its full Git revision
in `app/tool/ci/setup_flutter.sh`. Update the version and revision together when
deliberately upgrading the SDK.

The required `pr-checks` job runs code generation, analysis, Flutter tests, and
an ARM64 Android release build. It uses a disposable signing key and a separate
application ID (`dev.theolm.smartnotes.ci`), never the production signing secrets.
CI APKs are not published. This build covers native compilation and R8, but does
not replace the device startup and model download checks described below.

## Cutting a release

1. Update `version:` in `app/pubspec.yaml` to the release version. The build suffix
   (`+1`) is ignored by the workflow.
2. Commit the change on `main` and let the PR checks pass.
3. Create and push an annotated tag:

   ```sh
   git tag -a v0.2.0 -m "SmartNotes 0.2.0"
   git push origin v0.2.0
   ```

The workflow validates that:

- the tag matches `vMAJOR.MINOR.PATCH` or `vMAJOR.MINOR.PATCH-suffix`;
- the `pubspec.yaml` version matches the tag. Prerelease tags only need the same
  base version (for example `v0.2.0-rc.1` with `0.2.0`);
- the tagged commit is on `main`.

A tag with a suffix (for example `v0.2.0-rc.1`) is published as a prerelease.
Release descriptions are generated from merged changes since the previous tag.

## Re-running a release

Use **Actions → Release → Run workflow** and provide an existing tag. Re-running
uploads the artifacts again with `--clobber`, so it does not create duplicate assets.

## Version numbers

- `versionName` / `CFBundleShortVersionString`: tag version. macOS drops the
  prerelease suffix, since Apple expects `MAJOR.MINOR.PATCH`.
- `versionCode` / `CFBundleVersion`: `github.run_number`, which increases on every
  workflow run.

## Required secrets (Android)

The Android release is signed with a release keystore. Create one once and keep it
safe; losing it means existing installations cannot be updated.

```sh
keytool -genkeypair -v \
  -keystore smartnotes-release.jks \
  -alias smartnotes \
  -keyalg RSA -keysize 4096 -validity 10000
```

Add the secrets to the repository:

```sh
base64 < smartnotes-release.jks | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_PASSWORD
gh secret set ANDROID_KEY_ALIAS
```

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64 of the `.jks` file |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | Key alias |

The workflow fails with a clear error if any of these are missing.

The build expects the keystore at `app/android/keystore/keystore.jks` and reads the
password from the environment. Locally, you can still use `ALIAS`/`PASS` or
`app/android/keystore/key.properties` as before.

## macOS builds

The DMG is **ad-hoc signed only** by Xcode/Flutter and is **not notarized**.
No Apple account or macOS secret is required for this workflow. macOS Gatekeeper
blocks the first launch:

- macOS 15 and later: try to open SmartNotes, then go to
  **System Settings → Privacy & Security** and click **Open Anyway**.
- Alternatively, remove the quarantine flag:

  ```sh
  xattr -dr com.apple.quarantine /Applications/SmartNotes.app
  ```

- macOS 14 also supports right-click → **Open**.

The release notes include these instructions and the checksum verification command.

### Enabling signing and notarization later

This requires an Apple Developer Program membership. When you are ready:

1. Add the Developer ID Application certificate as a base64 `.p12` secret and a
   temporary keychain password.
2. Add App Store Connect API key secrets (`.p8`, key ID, issuer ID).
3. Add a certificate import step to the `macos` job in `release.yml` and set
   `MACOS_SIGNING_IDENTITY`.
4. Uncomment the signing/notarization blocks in
   [`app/tool/release/package_macos.sh`](../app/tool/release/package_macos.sh).

The script already contains the `codesign`, `notarytool` and `stapler` commands.

## Testing a release without publishing

Push a prerelease tag:

```sh
git tag -a v0.2.0-rc.1 -m "SmartNotes 0.2.0-rc.1"
git push origin v0.2.0-rc.1
```

Then verify:

- the DMG contains both architectures
  (`lipo -info SmartNotes.app/Contents/MacOS/SmartNotes`);
- each APK signature with `apksigner verify --print-certs`;
- Gatekeeper behavior on a Mac;
- `SHA256SUMS.txt` against the downloaded files.

### Android release startup regression check

Test an optimized release build on a device before promoting a prerelease. Debug
builds do not exercise R8 and cannot detect reflection-related startup failures.
Use a separate application ID to preserve the installed journal:

```sh
# Run from app/ with the release signing environment variables configured.
ORG_GRADLE_PROJECT_smartnotesApplicationId=dev.theolm.smartnotes.startuptest \
  flutter build apk --release --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -W -n \
  dev.theolm.smartnotes.startuptest/dev.theolm.smartnotes.MainActivity
adb shell pidof dev.theolm.smartnotes.startuptest
adb logcat -b crash -d
```

Verify that onboarding is visible, the process stays alive, and no new crash is
reported for the test package. Check the crash timestamps: logcat can include old
failures. Repeat after force-stopping the test package to cover cold starts.

`app/android/app/proguard-rules.pro` preserves the generated WorkManager database
constructor that Room invokes through reflection. Removing it causes a
`WorkDatabase_Impl.<init>` startup crash in optimized builds before Flutter starts.

## Limitations

- Flutter release builds for macOS are universal by default (Apple Silicon and
  Intel), so a single DMG is published. The workflow verifies both slices and
  fails if they are missing.
- The macOS build runs on an Apple Silicon runner and compiles native dependencies
  (`llama.cpp`, Whisper, FFmpeg), so it takes substantially longer than the
  Android build.
- The workflow installs NDK `29.0.13113456` because the runner image ships a
  different version.
- If Flutter switches macOS to arm64-only by default, the universal verification
  step will fail until the build is adapted.
