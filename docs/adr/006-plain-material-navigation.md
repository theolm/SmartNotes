# ADR-006: Type-Safe Navigation with auto_route

## Status

Supersedes: previously "Plain MaterialApp Navigation" (Jun 2026)

## Context

The app needs type-safe, generated routing as more screens are added (Home, Entry Detail, Settings). Manual `Navigator.push` with `MaterialPageRoute` becomes error-prone and verbose as the route count grows. Auto-route provides compile-time safety, standardised transitions, and automatic route registration via code generation.

## Decision

Use `auto_route` (v11.1) with `auto_route_generator` (v10.5) for all navigation.

- `MaterialApp.router` replaces `MaterialApp`.
- The router is defined in `lib/core/routes/app_route.dart` using `@AutoRouterConfig()`.
- Each screen gets a `@RoutePage()` annotation.
- Generated route classes live in `app_route.gr.dart` and are imported by the router definition.
- The router instance is created as a top-level `final appRouter = AppRouter()` in `main.dart` and passed via `routerConfig: appRouter.config()`.

### Version pinning

The following version constraints are required due to transitive `analyzer` compatibility:

```yaml
dependencies:
  auto_route: ^11.1.0

dev_dependencies:
  auto_route_generator: ^10.5.0
  mobx_codegen: ^2.7.7
```

The current resolved `analyzer` version is 10.x. Hive and its generator have
been removed. Verify compatible constraints across the active generators
before upgrading; `app/pubspec.yaml` and `app/pubspec.lock` are authoritative.

## Consequences

- All navigation goes through auto_route — no raw `Navigator.push` / `MaterialPageRoute` calls.
- New screens must:
  1. Add `@RoutePage()` annotation.
  2. Register the route in `AppRouter.routes`.
  3. Run `dart run build_runner build` to regenerate `app_route.gr.dart`.
- Routes are type-safe: parameters are passed via `PageRouteInfo` subclasses.
- Follow-up issues (#5, #7) can now push routes via `context.pushRoute(EntryDetailRoute(entryId: id))`.
- The auto_route generator uses `lean_builder` for incremental builds (fast rebuilds).
- Adding a new screen requires no manual route registration plumbing beyond the two steps above.
- ADR-006 RENUMBER NOTE: This ADR originally described plain MaterialApp navigation. It was updated in-place when auto_route was introduced; the number 006 is retained to avoid renumbering downstream references.
