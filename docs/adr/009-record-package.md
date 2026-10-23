# ADR-009: Use record Package for Audio Capture

## Status

Accepted

## Context

Users capture audio by holding a button (WhatsApp-style). We need a cross-platform audio recorder with Flutter bindings that handles permissions, recording state, and file output.

## Decision

Use the **`record`** package (version `^7.1.0`) for audio recording.

## Consequences

- Audio is recorded to `.m4a` (AAC) in the app's documents directory.
- The service exposes recording state via a stream and returns the file path after `stop()`.
- Native microphone permissions must be declared in `AndroidManifest.xml` and `Info.plist`.
- The recording service is hidden behind `IAudioRecordingService` for testability and future swaps.
