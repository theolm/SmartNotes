---
status: accepted
---

# Offer a verified local speech-model catalog with explicit active selection

Whisper base Q8_0 multilingual transcription is usable for English but its
Portuguese quality is insufficient. Device capability and language needs vary
widely, and the native binding is CPU-only. A single mandatory model cannot
serve a low-memory phone, an English-only journaler, and a user who accepts
slower processing for better Portuguese recognition.

## Decision

Maintain six pinned whisper.cpp artifacts: Base Q8_0, Small.en Q8_0,
Medium.en Q5_0, Small Q5_1, Large-v3-turbo Q5_0, and Large-v3 Q5_0. Any subset
may be installed, but exactly one verified model is active for a transcription
job. English-only weights may be downloaded by anyone but can be active only
for explicit English; automatic detection and every other supported language
require multilingual weights. The active model and audio language are persisted
together.

Make the active choice explicit. A recommendation may change when language or
hardware changes, but it never replaces a user's valid active model. The initial
recommendation policy filters by audio language, then uses conservative local
device capabilities. Unknown or low-memory profiles favor Base. Qualified
64-bit profiles favor Small.en for English and Small for other languages.
Larger-model recommendation requires a measured SoC qualification; available RAM
alone never establishes CPU speed. Full Large-v3 remains an explicit advanced
choice.

Selecting and downloading weights is separate from activating them. Onboarding
and Settings use compact model rows with exact sizes, language coverage,
benefits, and processing-cost warnings. Each row has a download action, a
cancellable progress spinner, and a delete action once installed. Tapping an
installed compatible row activates it; the active row is outlined in place and
the list order stays stable. Download requests queue sequentially, and
the first compatible download becomes active when no compatible model is active
yet. Existing installations keep a verified Base model active without another
download. Removing the active model or the last compatible model requires an
explicit replacement. Native inference, activation, and deletion share the
inference queue so a job holds a stable model/path/language until native disposal.

Apply CPU-only inference with the pinned binding; no GPU/NPU backend, cloud
fallback, or silent model switch is introduced. Model files remain outside
journal exports and are verified against pinned revisions, sizes, and SHA-256
hashes. Android excludes all app data from backup/transfer; iOS explicitly
excludes model files from iCloud Backup. macOS system-backup inclusion remains
user-managed.

## Consequences

Users gain quality and language choices without a per-device model build, at the
cost of a larger catalog, storage management, and verification of each artifact.
All six files are optional except one active model; setup requires a compatible
default and the embedding model. The recommendation is an estimate, not a
performance guarantee. Automatic language detection is slower than an explicit
language, and large models can be impractical on phone CPUs even when storage is
available. Policy thresholds and any qualified SoC profiles require device
measurements before they are broadened. Preserve the OpenAI Whisper notices and
audit distribution licenses when adding future artifacts.
