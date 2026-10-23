## Architecture and design

- `docs/architecture.md` — required architecture: layering, dependency injection, MobX stores, navigation, persistence, local AI, presentation, testing, and code generation. Read it before changing code and follow it for new work.
- Do not create ADRs or files under `docs/adr/`. Record architecture decisions directly in `docs/architecture.md`.
- `docs/DESIGN.md` — visual design system: color tokens, typography, spacing, shapes, components, motion, and dark mode. Read it before changing UI.
- `docs/agents/navigation.md` — auto_route conventions and examples for adding screens and navigating.
- `PRODUCT.md` — strategic context: product register, platform, users, positioning, and design principles.
- `CONTEXT.md` — domain vocabulary and ubiquitous language.

## Agent skills

### Issue tracker

Issues live in GitHub Issues at `theolm/SmartNotes`; use the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default canonical labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: read `CONTEXT.md` and `docs/architecture.md` at the repo root. See `docs/agents/domain.md`.
