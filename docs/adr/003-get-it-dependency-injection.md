# ADR-003: Use get_it for Dependency Injection

## Status

Accepted

## Context

The app needs a simple, compile-time-safe service locator to wire services and stores without framework lock-in.

## Decision

Use **get_it** as the dependency injection container.

## Consequences

- `lib/core/di/injection.dart` exports a global `getIt` and a `configureDependencies()` function.
- `lib/core/di/register_module.dart` registers third-party types (e.g. `AudioRecorder`) as injectable modules.
- Services are registered as lazy singletons behind interfaces.
- Stores are registered as lazy singletons.
- get_it may not be replaced by another DI package.
