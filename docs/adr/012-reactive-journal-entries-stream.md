# ADR-012: Reactive Journal Entries via Stream

## Status

Accepted

## Context

`HomeScreen` previously loaded journal entries only once during `initState()`. After a user modified an entry on `EntryDetailScreen` — by deleting, editing, retrying, or reformatting — the timeline on `HomeScreen` still showed stale data until the next full rebuild.

Issue #32 originally proposed solving this with `auto_route`'s `RouteAware.onResume()` lifecycle hook, calling `HomeStore.loadEntries()` every time the screen regained visibility. That approach is simple and localized, but it is pull-based: the UI must remember to ask for fresh data on every navigation boundary.

## Decision

Expose journal entries as a reactive `Stream<List<JournalEntry>>` from `IJournalEntryService.watchAll()` and subscribe to it in `HomeStore`.

`HomeStore` no longer pulls data via `loadEntries()`. Instead, it subscribes to `watchAll()` once at construction and updates its `entries` observable whenever the underlying storage changes. The local SQLite service emits a new sorted list on create, update, delete, or import. Stream revisions prevent an older asynchronous snapshot from replacing a newer one. This preserves the reactive contract after the storage replacement in ADR-019.

## Consequences

ADR-025 refines this implementation: `watchAll()` now shares a replayed feed,
ordinary writes use ID-scoped reads, and imports request full reconciliation.
The reactive contract and revision/concurrency guarantees remain unchanged.

- `IJournalEntryService.getAll()` was removed. All consumers must use `watchAll()`.
- `HomeStore.loadEntries()` was removed. The timeline updates automatically from journal mutations.
- `HomeScreen.initState()` now only calls `HomeStore.resumePendingProcessing()`, since entries are already populated by the stream.
- `HomeStore` gained a `dispose()` method to cancel its stream subscription, even though the store is an application singleton.
- Tests now stub `watchAll()` with a controllable `StreamController` or `Stream.value`.
- This pattern can later be extended with `watchById(id)` for `EntryDetailScreen` if detail-level reactivity becomes necessary.
- A stream-based approach adds a small amount of lifetime complexity (subscription management) but eliminates an entire class of stale-data bugs across the home timeline.

## Alternatives Considered

- **RouteAware `onResume()` hook**: Simpler to implement for issue #32 specifically, but leaves other mutation paths (e.g., background processing finishing, future features) requiring manual refreshes. Chosen against because it is reactive only at navigation boundaries, not at the data source.
- **Modification-tracking flag**: Explicitly rejected in issue #32 as overly complex and error-prone.

## Related

- Issue #32: Auto-refresh journal entries when returning to HomeScreen
- ADR-001: Use MobX for UI State Management
- [ADR-019: Local-first SQLite journal](019-local-first-sqlite-journal.md)
