# SmartNotes architecture

## Current boundaries

The Flutter application in `app/` is the only runtime. There is no Firebase
Authentication, Firestore, Cloud Functions, account model, or backend package.
ADR-019 records the local SQLite journal and derived-index decisions; ADRs
020–022 and this document describe the current local AI implementation.

- **Domain:** immutable Freezed entities and service interfaces.
- **Data:** local SQLite/file/model-download implementations and native AI adapters.
- **Application:** `JournalLifecycle` owns recovery and automatic pending indexing.
- **Presentation:** MobX stores consumed by Material widgets.
- **DI:** get_it + injectable; navigation uses auto_route.

Keep service interfaces in `lib/domain/services`, implementations in
`lib/data`, and services consumed by stores rather than widgets. Preserve
MobX, get_it/injectable, immutable models, and token-based themes. Grouped
public folders use barrel exports. Generate models/stores/DI/routes using
build_runner; do not edit generated output manually. UI copy lives in ARB
localizations. Design context is in `PRODUCT.md` and `app/DESIGN.md`.

## Persistence and retrieval

`LocalDatabase` owns one SQLite connection on a long-lived worker isolate.
It serializes commands, enables WAL/foreign keys, and versions the schema
using `PRAGMA user_version`. Entries keep their complete JSON plus a UTC
ordering key and source hash. FTS5 mirrors searchable content. `vec0` stores
512-dimensional cosine embeddings linked through chunk IDs to entries.

Note, FTS, and index invalidation writes are transactional. AI updates compare
their expected snapshot before saving, so edits or imports cannot be silently
overwritten by a late response. Stream revisions discard stale snapshots.
A content edit
invalidates vectors; date-only edits do not. A deleted note cannot be
resurrected by a late processing update. Index responses include a source
hash so stale responses for edited/deleted notes are discarded. Model,
dimensions, and indexed source hash are recorded separately from notes.
Changing vector dimensions/model requires a schema/index migration and
re-embedding, not comparing incompatible representations.

Schema v2 stores the active embedding pipeline identity and generation. A new
identity transactionally clears only derived vectors/chunks/index markers.
Late writes must match both generation and source hash. Pipeline identity
includes artifact hash, runtime, pooling, query prompt, dimension and chunking
policy; equal dimensions alone do not make vector spaces compatible.

Indexing chunks source text into overlapping tokenizer-bounded segments. Embeddings
are derived data, excluded from backups, and regenerated on request. Query
embeddings have a bounded in-memory cache. The engine performs exact native
KNN, not HNSW/ANN. Both search modes are offline; semantic queries are explicit
on-device submissions. Pending/failed counts expose incomplete results. Search result ID filtering ensures removed notes are not
shown from an earlier result set.

Audio is stored under the documents audio directory. Database references for
app-owned recordings are relative and resolved by the persistence adapter.
Settings remain in shared_preferences. First-run onboarding explains recording
and privacy, asks for audio language, requires speech and embedding model
downloads, and offers an optional formatting-model step between them. Completion
is persisted only after the active speech model and embedding model are verified;
formatting is never a completion condition. The route guard checks the optional
local lock first, then onboarding readiness. Previously completed installations
jump to the first missing required model and may browse existing notes while
setup remains incomplete; repair mode skips the optional formatting step.
Android automatic backup/transfer rules exclude all app data and credentials.
On iOS, each downloaded model directory and verified model file is marked
excluded from iCloud Backup. macOS has no iCloud container or app-managed
backup exclusion; user-managed system backups can include Application Support.
macOS uses the same interface set: the `record`/`file_picker`/`local_auth`
plugins and the bundled sqlite-vec asset have desktop implementations. The
macOS build is unsigned (ad-hoc). No credential adapter or API-key UI remains.
Deletion-only startup cleanup removes the former preference and mobile secure
entry independently, retrying unavailable stores on later launches. The secure
storage plugin remains solely for that migration; HTTP remains for downloads.

## AI and recovery

Onboarding requires one verified, language-compatible active Whisper model and
Qwen3-Embedding-0.6B Q8_0 before completion. Speech setup supports any subset of
six pinned artifacts; tapping an installed compatible row selects the active
model. Formatting is optional: the catalog offers Qwen3 0.6B Q8 and 1.7B Q4_K_M,
and the active model is explicit. Downloads support progress,
cancellation, partial resume, and SHA-256 validation before atomic publication.
A missing/corrupt active speech model or required embedding model requires
repair; an absent optional speech or formatting model does not.
Model artifacts live separately from journal data and are not in journal exports.
Android excludes them with all app data; iOS explicitly excludes them from
iCloud Backup. See the backup limitations below for macOS.

`ISpeechModelService` owns catalog readiness, per-artifact download workers,
active selection, and deletion. Download requests are queued sequentially; files
are not loaded into inference memory. Model/language configuration is one JSON
preference write, with legacy Base and audio-language fallbacks. Activating and
deleting weights use the shared inference queue, so a job snapshots a stable
model/path/language and releases native memory before files can be removed.
Settings and onboarding share `SpeechModelsStore` and the compact model-row list;
the active row is outlined in place and the list order stays stable.

`IFormattingModelService` mirrors the speech catalog surface: pinned readiness
and hashes, per-model download workers, explicit activation, active-model
deletion protection, and a persisted model ID. `FormattingModelsStore` and
`FormattingModelCatalog` are shared by the optional onboarding step and
Settings. The recommendation uses the same local device profile as speech but
has only light and balanced tiers. AI organization opens the action sheet
immediately and checks readiness inside it, showing preparing, actions-ready, or
a model-needed state with a direct path to the formatting-model screen. The
formatting service maps a missing artifact to a formatting-specific failure,
never the embedding-model message. Activation and removal share the inference
queue. See [ADR-022](adr/022-selectable-formatting-model-catalog.md) and
[ADR-023](adr/023-keep-model-verification-off-the-interaction-path.md).

Recommendations use a pure language-filtered hardware policy and a small local
platform channel for physical RAM, low-memory status, ABI/CPU information, and
separate free-storage checks. Policy v1 is intentionally conservative: unknown
profiles favor Base, qualified 64-bit/memory profiles favor Small or Small.en,
and high-end recommendations require measured SoC qualification. No GPU/NPU,
remote device profiling, benchmark requirement, or silent active-model switching.
See [ADR-021](adr/021-local-speech-model-catalog.md).

Recording no longer checks for an API key. `ITranscriptionService` runs only
local whisper.cpp via the pinned MIT `whisper_ggml` binding on Android/iOS/macOS;
`INoteProcessingService` delegates transcription locally and formats text with
Qwen via llama.cpp (`llamadart` 0.11.1). Local Qwen embeddings reuse that runtime.
ADR-019 records the journal storage choice; ADRs 020–022 record the local AI
choices. There is no cloud adapter, credential requirement, or online fallback.

The original recording is retained and decoded at normal speed to 16 kHz mono
PCM, with unique owned temporary files and cleanup on success/failure. Inference
is serialized across entries, runs in worker isolates, and frees model memory
after each request. Automatic language detection remains the default, with an
explicit language override. The Apple binding rejects `auto`, so a direct
whisper.cpp language-detection pre-pass uses at most the first 30 seconds and
frees its context before transcription loads another; Android uses native auto.
English-only weights require explicit English and bypass language detection.
Transcription is persisted before local formatting. All three AI services share one
inference queue. Whisper frees its context before releasing the lease; Qwen
loads a fresh session and awaits native disposal before the next job starts.
Native inference runs outside the UI isolate, CPU-only with four threads.
Qwen uses non-thinking generation, a strict three-field JSON schema, and the
selected one of six presentation styles. The exact source stays separate from
generated content. Its 4,096-token context includes the fully templated input,
1,536 reserved output tokens and 64 safety tokens. Oversized input is rejected,
never silently truncated. Incomplete or malformed output is not saved.
Failures retain the recording and transcription; retry reuses that text instead
of transcribing again. Valid JSON does not guarantee factual fidelity; physical
device performance and broader multilingual quality still need evaluation.
Entry processing status survives app restart. `main` starts the singleton
`JournalLifecycle` after dependency/settings initialization, without awaiting
background work or depending on any screen. Its orchestration path is:

- Subscribe to embedding readiness changes before watching journal entries.
- On the first journal snapshot, recover only interrupted `processing` entries,
  sequentially and once per application lifetime. Failed recordings remain manual.
- On every journal snapshot (including edits/imports), request pending indexing.
- After a verified embedding download/repair, request pending indexing even if
  no entry changed and Settings was never opened. Each pass checks readiness;
  absent weights leave derived work pending.

Index triggers coalesce into one drain, retaining a follow-up pass for changes
received during indexing. Background errors are logged, never block the UI, and
never enable retries of failed index sources. Explicit Settings commands still
retry failed sources or rebuild through `IEntrySearchService`, which serializes
indexing. Capture, startup recovery, and explicit recording retries share
`JournalLifecycle.processEntry` and its per-entry in-flight guard; the existing
use-case exclusivity and single native inference queue remain unchanged. Recovery
failures retain original audio/transcription and persist an error status, except
when another use-case job reports `busy`.

Home only renders journal snapshots and issues user commands. Settings loading
only observes readiness/index status; its recording-retry command reads current
storage through the coordinator instead of a Home snapshot. DI disposal cancels
the coordinator's subscriptions and drains in-flight work. Work is in-process,
not an OS background scheduler. The screen-owned recovery described historically
in ADR-012 is replaced by this application boundary (issue #81).

Embedding input is raw text, never a chat template: queries alone have the
retrieval instruction. Validate Qwen architecture and LAST pooling metadata,
require 1024 native dimensions, slice to 512 and normalize. Real tokenizer
counts bound chunks to 384 tokens with up to 64-token overlap in a 1024-token
context. Oversized queries fail explicitly. Indexing yields after four chunks,
disposing the model before interactive STT/formatting/search can take the lease.
Bounded queue fairness prevents backlog starvation. Failed notes do not block
other entries; missing weights leave entries pending until model repair.
Embedding failures do not change successful note status or block text search.

## Backup and limitations

ZIP backup version 1 stores a journal manifest and available original audio.
Import validates the manifest and audio references before writing, generates
safe local filenames, and commits entry records atomically. Matching IDs are
replaced. Failed database imports clean up newly written audio files. ZIP
paths are never extracted verbatim. Backup limits bound compressed and
expanded size; compression/decompression runs outside the UI isolate.

No app-level encryption, cloud sync, background OS scheduler, or account
management is provided. Processing runs while the app is alive and resumes
interrupted work at startup. Repeated import can leave superseded audio files
on disk; file maintenance is a future improvement. Failed indexing is recorded
against its source hash and excluded from automatic processing; the Settings
retry action includes those failures. Benchmarks and multilingual retrieval
quality still need representative-device/content evaluation.
