# auto_route Navigation Guide

This project uses `auto_route` for type-safe, generated navigation. The router is set up and ready; this guide tells agents how to add new screens, push routes, and regenerate the router code.

## Router setup

| File | Purpose |
|---|---|
| `lib/core/routes/app_route.dart` | Router definition (`@AutoRouterConfig()`) |
| `lib/core/routes/app_route.gr.dart` | Generated route classes — DO NOT EDIT |
| `lib/main.dart` | Top-level `final appRouter = AppRouter()` + `MaterialApp.router(routerConfig: appRouter.config())` |

## Adding a new screen

1. **Annotate** the screen widget with `@RoutePage()`.
   ```dart
   @RoutePage()
   class MyScreen extends StatelessWidget { ... }
   ```

2. **Register** the screen in `app_route.dart`:
   ```dart
   @AutoRouterConfig()
   class AppRouter extends RootStackRouter {
     @override
     List<AutoRoute> get routes => [
       AutoRoute(page: HomeRoute.page, initial: true),
       AutoRoute(page: MyRoute.page),          // <-- add here
     ];
   }
   ```

3. **Run the generator**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. The generated `MyRoute` class (inside `app_route.gr.dart`) is now available to use in navigation.

## Passing parameters

```dart
// Screen
@RoutePage()
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({required this.entryId});

  final String entryId;
  // build() ...
}

// Router registration
AutoRoute(page: EntryDetailRoute.page),
```

The generator automatically creates `EntryDetailRoute` with `entryId` as a required constructor parameter.

## Navigating

```dart
import 'package:auto_route/auto_route.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';

// Push a named route
context.pushRoute(EntryDetailRoute(entryId: entry.id));

// Replace current route (e.g. after unlocking the local journal)
context.replaceRoute(HomeRoute());

// Pop back
context.maybePop();
```

> **IMPORTANT**: Always use `import 'package:auto_route/auto_route.dart'` to get `pushRoute` extensions on `BuildContext`. Never use `Navigator.push` with `MaterialPageRoute`.

## Dependency constraints

Use `app/pubspec.yaml` and `app/pubspec.lock` as the source of truth for
dependency constraints and resolved versions. Before upgrading generators,
resolve compatible analyzer constraints and rerun generation, analysis, and
tests. The former Hive generator constraint is obsolete.

Journal routes use `LocalLockGuard` for the optional on-device app lock.
There are no login, profile, or account-password routes.

## Generated file

`app_route.gr.dart` is generated. Run the build_runner command after any change to `app_route.dart` or any `@RoutePage()` annotation.

## ADR reference

See `docs/adr/006-plain-material-navigation.md` for the full architectural decision record.
