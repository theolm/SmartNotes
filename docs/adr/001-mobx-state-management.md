# ADR-001: Use MobX for UI State Management

## Status

Accepted

## Context

SmartNotes needs a reactive state-management solution for its Flutter UI. The team wanted a lightweight, observable pattern with strong code-generation support and minimal boilerplate.

## Decision

Use **MobX** with `flutter_mobx` and `mobx_codegen` for all UI state.

## Consequences

- Stores expose `@observable`, `@computed`, and `@action`.
- Widgets remain `StatelessWidget` unless local UI state requires otherwise.
- `*.g.dart` files are generated via `build_runner` and must not be hand-written.
- Alternative state-management packages are not permitted.
