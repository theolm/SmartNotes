# ADR-005: Token-Based Theming

## Status

Accepted

## Context

The app targets Material 3 and needs a consistent, maintainable design system that supports light and dark modes.

## Decision

Use token-based theming under `lib/core/theme/`. The concrete values and component rules are documented in `app/DESIGN.md`.

## Consequences

- `AppColors` defines color tokens for light, dark, and semantic uses.
- `AppTypography` builds a `TextTheme` using Google Fonts.
- `AppSpacing` and `AppRadius` provide layout and shape constants.
- `AppTheme.light` and `AppTheme.dark` produce full `ThemeData` objects.
- All UI uses theme tokens rather than hard-coded values.
- Any design refinements are recorded in `app/DESIGN.md` and reflected through the tokens.
