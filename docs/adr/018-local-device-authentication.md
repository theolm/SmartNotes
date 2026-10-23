# ADR-018: Optional Local Device Authentication

## Status

Accepted, with account/session behavior superseded by
[ADR-019](019-local-first-sqlite-journal.md).

## Context

A personal journal should optionally require local verification before
showing entries on an unlocked device. The original decision protected
restored Firebase sessions; the current app has no accounts or sign-in.
The protection now applies to the single local journal at app startup.

## Decision

Keep an optional **Lock app** setting in shared_preferences, default **off**.
When enabled, `AppStore` starts locked and `LocalLockGuard` redirects journal
routes to `LockRoute` until local verification succeeds.

- Use `local_auth` behind `ILocalAuthService`.
- Allow biometrics and device credentials (PIN/pattern/passcode) with
  `biometricOnly: false`.
- Show the setting only when the device supports local authentication.
- Require successful local verification before enabling the setting. A
  cancelled or failed prompt leaves it disabled.
- Apply setting changes on the next launch; do not re-lock the running app.
- Failed or cancelled unlock attempts keep the journal locked and offer retry.
  There is no sign-out escape hatch, account session, or login bypass.

## Consequences

- `AppStore` depends on `ILocalAuthService` and `ISettingsService`, not an
  account authentication service.
- Android uses `FlutterFragmentActivity` and biometric permission; iOS
  declares `NSFaceIDUsageDescription`. macOS support follows the pinned
  `local_auth` release and requires an available device-credential mechanism.
- Store, service, guard, and widget tests cover local startup and unlocking.
- App lock gates UI access only; it does not encrypt SQLite, recordings, or
  exported backups.
- Losing the device's authentication capability after enabling app lock can
  prevent unlocking. Configure supported credentials when testing emulators;
  there is no automatic insecure bypass.
