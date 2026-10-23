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
