---
status: accepted
---

# Save transcriptions before optional AI organization

On-device formatting adds latency and may flatten a personal journaler's voice.
Complete entries after transcription instead of automatically applying a template.
Keep the original recording and transcription, make the formatting model optional,
and generate drafts from the current saved body so user corrections are not lost.
Only explicit acceptance persists a draft; title/subtitle replacement is a separate
opt-in. Apply, restore, and manual edits use expected-entry checks to reject stale
writes after concurrent edits, imports, or deletion. There is no full revision
history: restoring the original does not recover every previous manual edit.

Retain the nullable `formattedNote` field for accepted edits/transformations and
use transcription only when that field is null, not when an edited body is empty.
This preserves old notes and backups without a journal schema rename. Render an
untouched transcription literally, not as Markdown.

Initial metadata is an exception to explicit draft acceptance: after preserving
the transcription, a selected, ready local formatting model generates only a
title and subtitle in the transcription's language. It never rewrites the body
or replaces existing metadata, including intentionally empty fields. Missing
models and generation failures do not prevent completion. Recovery may fill
missing metadata from the retained transcription without transcribing again.

Index the title, current body, and original transcription in one chunked semantic
index, omitting empty parts and exact trimmed body/original duplicates. Keeping the
original preserves details omitted by summaries, at the cost of indexing similar
passages after a rewrite. Change the pipeline identity and recompute persisted
source hashes transactionally when this representation changes; vectors remain
disposable. Preview generation never changes the index.

This supersedes automatic-formatting and mandatory-formatting-model assumptions.
ADR-025 refines pipeline hash migration into resumable batches, retaining atomic
derived-index invalidation and excluding un-repaired entries from indexing.
It retains ADR-019's authority of journal/audio data and derived-index policy;
the current implementation is offline.
