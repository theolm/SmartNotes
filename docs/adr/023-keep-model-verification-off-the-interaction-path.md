---
status: accepted
---

# Keep formatting-model verification off the interaction path

## Context

Opening AI actions awaited a full readiness check before showing the action
sheet. On a cold process, that check hashes the entire active artifact: 639 MB
for the light model or 1.11 GB for the balanced model. The result was a wand that
could take seconds to respond, especially on the first tap after launch or after
the weights changed. Hashing is still necessary after an interruption or a
partial download, but repeating it on every launch added no safety.

## Decision

Open the AI action sheet immediately. Check readiness inside the sheet and show
one of three compact states: preparing, actions ready, or the existing
formatting-model-needed path with Settings and Not now. A check failure offers
Retry. The sheet no longer waits for the model before appearing, and a slow hash
never blocks navigation or reading.

Persist the last successful full verification as a local signature containing
the model ID, file size, modification time, and the catalog's expected SHA-256.
On later launches, `isReady` compares the signature with a stat-only probe. A
match reuses verification; any difference, including a missing file, size
change, modification-time change, model-ID change, or digest change, forces a
full hash again. The cache is written only after the hash succeeds and is
best-effort: a preferences failure only costs time.

The existing missing-model and disappeared-model paths remain. Generation still
requires a ready active model; an optional AI failure never changes saved text
or makes the entry incomplete.

## Consequences

The first interaction after installing or updating a model still pays for one
full integrity check, but the sheet appears immediately and every later launch
uses a stat-only check. Repeating an unchanged hash on launch is avoided without
weakening the first verification. A content change that preserves both file size
and modification time would not invalidate the local signature; that is the
accepted local-storage trade-off, and any ordinary re-download or file rewrite
changes the modification time. The signature is not a security boundary and does
not encrypt weights. This supersedes ADR-022's statement that the app must finish
checking for a ready model before opening the action list; the model-needed
outcome is now shown inside that sheet.
