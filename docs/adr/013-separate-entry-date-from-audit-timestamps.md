# ADR-013: Separate Entry Date from Audit Timestamps

## Status

Accepted

## Context

Issue #34 asks for the ability to change the date of a journal entry from the edit screen. The `JournalEntry` entity currently carries two timestamp fields:

- `createdAt` — the instant the entry was originally persisted.
- `updatedAt` — the instant the entry was last modified.

Both fields are used for both audit and presentation/ordering concerns. If we let the user edit `createdAt` to move an entry in the timeline, we lose the original creation timestamp forever. If we keep using `createdAt` for ordering, we cannot satisfy the requirement of reordering entries after a date change.

## Decision

Introduce a new field `entryDate` on `JournalEntry`. It represents the user-facing date and time of the entry and is used for timeline ordering and grouping. `createdAt` and `updatedAt` remain immutable audit timestamps:

- `createdAt` is set once at entry creation and never changes.
- `updatedAt` is updated automatically on every save.
- `entryDate` is initialised to `createdAt` at creation but can be edited by the user.

Timeline ordering and day grouping are driven by `entryDate`, not `createdAt`.

## Consequences

- The domain model distinguishes between **when the entry happened** (`entryDate`) and **when it was recorded** (`createdAt`).
- `effectiveEntryDate` falls back to `createdAt` when `entryDate` is absent; no backfill write is required. ADR-019 introduced the current local version without a legacy-user migration.
- The timeline reflects user-edited dates immediately because `watchAll` emits sorted by `entryDate`.
- The former Hive field index is historical and no longer constrains the model. SQLite stores entry JSON and a UTC ordering key derived from the effective entry date.
