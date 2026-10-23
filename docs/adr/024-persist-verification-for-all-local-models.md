---
status: accepted
---

# Persist verification for every local model, after the first frame

Speech and embedding weights previously rehashed on every cold process before
`runApp`, while formatting retained only one verified artifact. Extend ADR-023's
stat-cache trade-off to all model families through one verification module and
independent, versioned preference keys per folder/model ID. Records match model
ID, folder, file name, catalog digest, size, and modification time in milliseconds.
Successful verification remains usable in memory when preferences are unavailable.
The matching legacy formatting signature migrates without reading model contents.

## Startup and readiness

Completed onboarding is a saved user decision, not the current availability of
replaceable weights. Initialize route/app-lock protection without model I/O, render
the first frame, then release the production hash gate and start model checks and
journal recovery/indexing. Legacy models verify once in the background; navigation,
reading, text search, and archive actions stay available. First setup and inference
still require verified models. Settings distinguishes checking, missing/corrupt,
and failed checks, with retry and model setup/repair paths. Full checks join an
existing model job and share a bounded, serial hashing queue off the UI isolate.

## Download completion

The Dart path hashes `.part`, promotes it, and records the final artifact without
rehashing. Android/iOS persist a versioned receipt only after their full catalog
hash and successful promotion. Dart imports that receipt only when its transfer
generation, identity, expected digest, and final stat match. Old/stale completion
records fall back to full verification rather than certifying arbitrary files.
Receipt timestamps use integer milliseconds on both sides of the channel.

## Consequences

Normal cold launches and A → B → A switches perform stat probes, not artifact
reads. Speech deletion uses compatibility metadata and file presence/size, not
integrity checks of unrelated models. That presence check never authorizes inference.

Retain full streaming SHA-256; no prefix/suffix hash or digest-algorithm migration.
Content changes preserving both size and millisecond mtime can escape this cache:
it detects accidental storage changes, not adversarial tampering. Catalog changes,
ordinary rewrites, removal, or mismatching receipts invalidate trust. A model-load
failure remains recoverable through existing retry/setup paths and never changes
saved journal text. Model diagnostics expose counters, not artifact contents or
private journal/audio paths.
