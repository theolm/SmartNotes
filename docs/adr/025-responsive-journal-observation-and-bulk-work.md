---
status: accepted
---

# Keep journal observation and bulk work off interaction paths

Issue #95 exposed two independent full-journal subscriptions and a single SQLite
worker monopolized by import and pipeline hash maintenance. Share one replayed
journal feed across Home and application lifecycle work. Read the initial snapshot
once, apply subsequent ID-scoped changes, and reconcile after import. Detail keeps
its targeted subscription; reactive updates and expected-entry checks remain the
authority, not screen snapshots.

Stage imported JSON and source hashes in batches of 25, yielding between batches.
Publish the prepared rows and FTS/vector invalidations atomically on a separate
WAL connection/isolate. Interactive reads continue against the old committed
journal until publication completes. Competing writes wait cooperatively outside
SQLite, then validate expected entries against the committed result. The final
transaction is deliberate: per-batch publication would expose partial restores,
invalidate concurrency checks at multiple boundaries, and make rollback unsafe.
Interrupted staging is discarded on the next open; existing entries never depend
on staging. The application owns a single journal writer; independently opening
multiple application writers against the same file is not supported.

On a pipeline change, atomically invalidate derived vectors and persist IDs needing
new source hashes, then repair hashes in resumable short transactions after the
database becomes readable. Entries awaiting repair cannot be selected for semantic
indexing. New writes repair their own hash and remove their marker. Completion
requests background indexing; an interruption resumes from the remaining markers.
This supersedes ADR-020's requirement to recompute every hash inside the pipeline
invalidation transaction, without weakening representation compatibility. Home
shows maintenance progress without disabling reading or capture.

Export uses an independent read-only WAL snapshot. Page raw rows and serialize the
manifest inside the export isolate; stream already-compressed M4A recordings into
a disk-backed ZIP without recompressing or retaining all audio. Import streams
recordings out of the archive rather than caching all expanded audio. The version-1
manifest, size limits, relative audio references, and restore-by-ID semantics stay
unchanged. The current picker interface still requires the completed ZIP bytes
(at most 100 MB) in memory; this is not a zero-copy/file-only backup API.

Text input is debounced for 250 ms. Superseded work is invalidated before worker
execution where possible and ignored before entity decoding/publication; an FTS
statement already executing is not forcibly interrupted. Index-status observers
coalesce changes and retain a final trailing refresh. Long Markdown documents
parse in an isolate and retain their AST/rendered children for the mounted view;
theme changes rebuild rendering, while width/text-scale changes relayout it.
Neither parsed text nor drafts become a persistent cache or part of backups.
