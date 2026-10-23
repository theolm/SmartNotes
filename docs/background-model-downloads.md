# Background model installation

All three model services use `LocalModelDownload`. On Android/iOS it delegates
to `IPlatformModelDownloader`; desktop retains the Dart streaming implementation.
The injected adapter is shared by all model services. `ModelDownloadsStore` owns
MobX notification state and restores permission visibility without prompting;
widgets never access a platform service directly. Notification strings come from
ARB and travel with the durable request. The catalog, storage preflight, model
selection, and verified readiness stay in
Dart. The native installation job additionally verifies the catalog's exact size
and SHA-256 before atomic promotion so installation can finish without Flutter.
Dart validates the native post-promotion verification receipt against the current
artifact's stat and catalog metadata before reporting readiness. A missing or
stale receipt requires a full Dart check, deferred until after the first frame.

## Durable contract

- `start` attaches to existing work, resumes partial data, or starts unique work.
  Completed work is not restarted unless the caller explicitly requests repair.
- `status` returns typed, persisted queued/downloading/verifying/completed/
  cancelled/failed records, byte counts, errors, the transfer generation token,
  and an optional versioned verification receipt. The receipt identifies the
  model, folder, file name, expected SHA-256, final size, modification time in
  milliseconds, and generation token. Only a successful hash and final promotion
  can create it; `completed` alone is not proof for the readiness cache.
- `cancel` records cancellation before stopping platform work. Both the app and
  Android notification use this operation. Partial bytes/resume data are retained.
- Only one model installation may be active, across all model families. Catalog
  row queues remain UI-owned; unstarted queued selections do not survive process
  death. The active platform installation does.

Android uses unique WorkManager work, a connected-network constraint (including
cellular), a data-sync foreground service, and a low-importance notification
channel. A bounded streaming writer resumes `.part` files using Range; a server
returning HTTP 200 restarts the file instead of appending. Transient I/O failures
retry with backoff. Process death between promotion and completion is recovered
without another GET. Each attempt has a generation token; obsolete workers cannot
write, mutate state, or promote files after replacement. Cancellable OkHttp calls
are registered atomically before executing HTTP. Attaching uses KEEP; retrying a
cancelled/failed attempt uses REPLACE and distinct foreground-notification IDs.

iOS uses a non-discretionary background URLSession with launch events, native
resume data, and migration of existing Dart `.part` files through Range. Transfer
completion starts streaming verification under a background assertion. A
persisted BGProcessingTask request finishes/retries verification if that window
expires or the OS terminates the process. Background processing is scheduled at
the OS's discretion, so a large model may remain “verifying” until iOS grants time
or the user opens the app. Completion notifications mean **verified installation**,
not merely completed network traffic. Model artifacts are excluded from backup.
Rejected resume data is discarded before a bounded fresh/Range fallback. Legacy
Range responses are staged as `.segment` files; merging and hashing share the
background budget, with the partial length checkpoint preventing duplicate
appends after interruption. Preflight reserves the temporary merge-copy space,
including when native resume data belongs to a legacy Range request.

Onboarding/settings reattach to durable work on load/resume. Leaving setup no
longer cancels installation. Reopening setup in the same process joins the
existing embedding installation and receives progress without a second request.

## Platform limits

- iOS user force-quit cancels background URLSession transfers. Reopen SmartNotes
  to resume; if iOS discarded its resume data, the transfer must restart. Normal
  suspension and OS termination are different and are supported.
- iOS shows start and terminal local notifications, not continuously updated
  progress. BGProcessing timing cannot be guaranteed by the application.
- Android force-stop prevents work until the app is opened again; ordinary
  process death is recovered by WorkManager. OS foreground-service limits and
  vendor battery restrictions still apply.
- Notification denial never prevents the transfer. Android still exposes the
  foreground service in its system task manager, but not the notification drawer.
  The app explains that progress must be checked inside SmartNotes.
- macOS still requires the foreground Dart process.

## Automated checks

```sh
cd app
flutter analyze
flutter test
env ORG_GRADLE_PROJECT_smartnotesApplicationId=dev.theolm.smartnotes.downloadtest \
  flutter test integration_test/model_download_platform_test.dart -d DEVICE_ID
env ORG_GRADLE_PROJECT_smartnotesApplicationId=dev.theolm.smartnotes.downloadtest \
  flutter test integration_test/model_download_wiring_test.dart -d DEVICE_ID
```

The device smoke suite uses a 1.5 KB pinned public license in `download_test`,
not journal data or actual model folders. It checks native completion, attaching
twice, migrating partial bytes, invalid resume-data recovery, corrupt-file repair,
integrity rejection, cancellation, and immediate cancel/restart. The wiring suite
exercises the real production DI graph, catalog restoration, and disposal. It does
not request notification permission: successful transfers also exercise the
ungranted-notification case on a fresh install. On iOS run this in a dedicated
simulator or a separately signed test bundle, never over an existing journal.

## Physical-device lifecycle matrix

Use the isolated probe rather than the user's production install. It downloads
the Base Q8 catalog artifact into `download_probe`, not `speech_models`, and has
no journal initialization. It automatically attaches/resumes on every launch.

```sh
cd app
flutter build apk --debug -t tool/model_download_probe.dart \
  -PsmartnotesApplicationId=dev.theolm.smartnotes.downloadtest
adb -s DEVICE_ID install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s DEVICE_ID shell am start \
  -n dev.theolm.smartnotes.downloadtest/dev.theolm.smartnotes.MainActivity
```

Run each scenario from a clean **test** install/model; never clear the production
package. On iOS build the same Dart entry point with a separate bundle ID using
Xcode and use a physical device for suspension/BGProcessing validation.

| Scenario | Expected result |
| --- | --- |
| Start, Home, wait | Native transfer and verification complete; terminal notification; ready on reopen |
| Start, lock screen, wait | Same, without keeping Flutter awake |
| Android: kill the test UID with `run-as PACKAGE kill -9 PID` | WorkManager recovers; reopening attaches to the same model and retained `.part` bytes |
| Android: force-stop test package, reopen | No work while force-stopped; reopen resumes retained bytes, not a parallel GET |
| iOS: terminate through debugger/system, reopen | Existing URLSession task or resume data is reconciled, no duplicate task |
| iOS: swipe away app | Transfer stops (documented OS limitation); reopen offers resume/restart |
| Cancel in Android notification | State cancelled, bytes stop growing, ongoing notification disappears; resume retains bytes |
| Cancel in app | Same terminal state; iOS waits for resume-data capture before returning |
| Deny notification permission | Transfer/verification succeed; app shows visibility explanation |
| Drop network, restore | Android retry / iOS system behavior or resumable failure; no unverified ready state |
| Expire iOS verification assertion | Remains verifying; BGProcessing or app relaunch completes validation before readiness |

Inspect `model_downloads.xml` in the Android test package's shared preferences
and `.part` length before/after process death. The unique WorkManager name is
`model:background-download-probe`. Compare server Range logs when using an
equivalent controlled HTTPS fixture to prove no overlapping network requests.
For iOS use Instruments/network logs and BGTaskScheduler debugger simulation in
addition to an untethered physical-device run; a simulator alone cannot establish
real suspension/locking behavior.

## Validation recorded on 2026-10-19

- Flutter analysis: clean; unit/widget suite after review: 389 passing tests.
- Android 16 physical device: all four native smoke scenarios passed; the
  isolated 81,768,585-byte Base Q8 probe completed after Home/process kill and
  relaunch, with native verified completion persisted. The notification cancel
  receiver was exercised under the test UID; state became cancelled and the
  partial artifact was retained.
- iOS 26.5 dedicated simulator: all four native smoke scenarios passed; native
  simulator builds passed.
- Review regressions extend the native suite to completion, Range migration,
  invalid resume data, repair, integrity failure, cancellation, and immediate
  cancel/restart; a separate suite exercises production DI and disposal. All
  eight checks passed on both the isolated Android emulator and iOS simulator.
- The production app started and hot-restarted in the dedicated iOS simulator
  without runtime errors after the architecture changes.
- Still requires physical-device sign-off: locked-screen runs, iOS suspension/
  OS relaunch, start/terminal notification presentation, and verification-window
  expiration/BGProcessing delivery. The simulator is not evidence for those.
