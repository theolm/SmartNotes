---
status: accepted
---

# Offer a verified formatting-model catalog with optional setup and explicit selection

On-device note formatting shipped with a single fixed Qwen3-1.7B Q4_K_M
artifact. The magic wand could only discover a missing model after an action
failed, and the failure path showed a download sheet instead of the model
management surface. Low-memory devices had no lighter option, and the app had no
persisted notion of which formatting model the journaler intended to use.

## Decision

Maintain a pinned formatting-model catalog with two Qwen3 tiers:

| Tier | Model | Artifact | Download |
| --- | --- | --- | ---: |
| Light | Qwen3 0.6B | Q8_0 | 639.4 MB |
| Balanced | Qwen3 1.7B | Q4_K_M | 1.11 GB |

Both artifacts are multilingual, Apache-2.0, pinned by revision, size, and
SHA-256, and run through the existing CPU-only `llamadart` / llama.cpp path. No
new runtime, cloud fallback, remote catalog, or automatic download is added.

The model is optional. Onboarding gains a skippable formatting step between
speech and embedding; completion still requires only the active speech model and
the embedding model. Settings gains a "Formatting models" screen that uses the
same compact rows, recommendation, progress, cancellation, resume, delete, and
activation states as the transcription catalog. The old formatting bottom sheet
is removed.

Selection is explicit. The first downloaded model becomes active when no active
model is ready; a later download does not switch it. Tapping an installed row
switches the active model. The active model cannot be deleted until another model
is selected. The active model ID is persisted in shared preferences. There are no
existing users, so no migration or legacy fallback is written.

Recommendation is a conservative device-memory estimate: unknown or low-memory
profiles, 32-bit processes, and devices below 6 GiB reported RAM favor the light
model; 64-bit devices with at least 6 GiB favor the balanced model. It never
downloads or activates a model and is not a performance guarantee.

AI organization checks for a ready active formatting model before enabling its
actions. ADR-023 moves that check inside the action sheet so a large hash never
delays the sheet itself; when none is ready, the sheet shows a direct path to the
formatting-model screen. Returning after installing and selecting a model shows
the actions again but does not auto-run one. A model that disappears or corrupts
during generation maps to a formatting-specific failure and the same Settings
path, not the embedding-model message.

## Consequences

Formatting remains disposable and optional: a missing model never blocks
recording, transcription, reading, search, setup completion, or backups. The app
carries two pinned artifacts and more storage-management surface, but gives
low-memory devices a viable option and gives every journaler an explicit choice.
The light tier can be less faithful on long or complex notes; its capability copy
states that limitation. The balanced tier remains the default recommendation for
capable devices.

Before the light tier is shipped as selectable, run the fidelity gate on named
devices and a PT-BR/PT-PT/EN corpus: schema validity, factual preservation,
negation and uncertainty, no translation, title/subtitle faithfulness, no
truncation, completion time, and peak memory. If the light model invents facts,
drops negations, or translates, do not ship it; keep the catalog at 1.7B and
record the result. Tune the 6 GiB threshold and capability copy from the
measurements.

This decision follows the existing speech-catalog pattern and leaves the shared
local-model installation contract to issue #78. It does not change the embedding
catalog or semantic-search policy (#87).
