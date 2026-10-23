---
status: accepted
---

# Use SQLite, FTS5, and sqlite-vec as the local journal store

SmartNotes is a single-device, local-first journal. The journal database and
original recordings are authoritative; search indexes and embeddings are derived
and disposable. The app has no account model, cloud backend, or synchronization,
so entries, settings, and search data must persist without network access.

## Decision

Use one local SQLite database with WAL, foreign keys, and `PRAGMA user_version`
for schema versioning. Store each entry's complete JSON plus a UTC ordering key
and source hash, and mirror searchable content in FTS5. Use upstream
`sqlite-vec` through the pinned `sqlite3_vec` binding for 512-dimensional cosine
KNN, linked through chunk IDs to entries. Keep original recordings under the
documents audio directory with relative references. Keep device settings in
`shared_preferences`.

Journal records and original audio are authoritative. Vectors, chunks, and
search hashes are derived, invalidated on content changes, and rebuildable.
Schema v2 records the active embedding pipeline identity and generation; a new
identity clears only derived data. Both search modes work offline after model
installation, and the semantic index is excluded from backups.

## Consequences

- The app has one local journal and no account, cloud sync, or backend.
- Text search remains available without AI models; semantic search requires the
  embedding model.
- Derived data can be rebuilt without touching journal entries or audio.
- The SQLite worker isolate serializes writes; imports and exports use a
  separate read-only WAL snapshot.
- Schema and pipeline changes require versioned migrations, not comparisons
  between incompatible representations.

## Related

- [architecture.md](../architecture.md)
- ADR-020, ADR-021, ADR-022, ADR-024, ADR-025
