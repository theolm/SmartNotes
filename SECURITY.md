# Security Policy

## Supported versions

Security fixes are applied to the latest `main` and the current `0.1.x` release
line.

## Reporting a vulnerability

Do not open a public issue for a security vulnerability.

- Preferred: GitHub private vulnerability reporting:
  https://github.com/theolm/SmartNotes/security/advisories/new
- Otherwise: email `me@theolm.dev`.

Include the affected version or commit, steps to reproduce, impact, and any
relevant logs. Remove journal content, recordings, filesystem paths, and
credentials before sending.

## Scope

This is a local-first app. Reports of interest include:

- exposure of journal text, recordings, embeddings, or credentials
- app-lock or local-authentication bypass
- path traversal or unsafe archive/import handling
- model download integrity or verification bypass
- unsafe native code or dependency behavior

Please do not include personal journal content in a report.
