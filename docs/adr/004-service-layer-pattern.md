# ADR-004: Service Layer Pattern

## Status

Accepted

## Context

To keep business logic testable and decoupled from UI, the app needs a clear boundary between data operations and state management.

## Decision

Use interface + implementation pairs for every service.

## Consequences

- Interfaces (contracts) live in `lib/domain/services/`.
- Implementations live in `lib/data/services/` and `lib/data/datasources/local/`.
- Local persistence and local AI adapters live in `lib/data/services/` and
  `lib/data/datasources/local/`. Provider-specific details remain internal to
  data implementations; the current app has no remote AI adapter.
- Services are consumed only by stores, never directly by widgets.
- Remote, platform, and local services each get their own interface + implementation.
- This pattern must be preserved across the codebase.
