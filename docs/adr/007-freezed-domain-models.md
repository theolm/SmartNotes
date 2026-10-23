# ADR-007: Use Immutable Domain Models

## Status

Accepted

## Context

Domain models need immutability, deep `copyWith`, and predictable equality. Hand-writing boilerplate is error-prone. Freezed is the project's preferred generator for these cases. Persisted journal entries use `json_serializable` together with Freezed for SQLite JSON records and portable backups.

## Decision

Use immutable domain models throughout the app. Prefer **Freezed** for value objects and unions, with generated JSON serialization where needed. Storage engine details belong in the data layer, not in domain annotations.

## Consequences

- Models are immutable by default.
- Journal entries use Freezed with `json_serializable` for JSON mapping.
- No Hive adapters or Firestore mappers are generated. SQLite replaced the former storage implementation in [ADR-019](019-local-first-sqlite-journal.md).
- Run `build_runner` after any model change.
- Do not hand-write generated `*.g.dart` or `*.freezed.dart` files.
