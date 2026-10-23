# ADR-010: English UI with Flutter l10n

## Status

Accepted

## Context

SmartNotes will support multiple languages in the future, but the MVP needs a single UI language to start with.

## Decision

Use **English** as the primary app language and implement localization with Flutter's built-in l10n support (`flutter_localizations` + ARB files).

## Consequences

- All user-facing strings live in `lib/core/l10n/app_en.arb`.
- The app uses `MaterialApp.localizationsDelegates` and `supportedLocales`.
- Adding new languages later only requires new ARB files.
- Audio language is a separate setting from UI language.
