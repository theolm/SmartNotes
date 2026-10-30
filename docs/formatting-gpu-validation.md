# Formatting GPU validation

## Status

The formatting GPU path is implemented: a device-and-model-qualified Metal
profile ships for Apple M5 with Qwen3 1.7B Q4_K_M organization requests, behind
an off-by-default beta setting. Android Vulkan is packaged and wired but has no
qualified profile, so Android keeps the CPU until a device measurement is
recorded here. Embeddings remain CPU-only.

CPU remains the default on every platform and is always packaged.

## Baseline

Before this work: `flutter analyze` clean and 750 Flutter tests passing.

Instrumentation: opt-in `--dart-define=INFERENCE_TRACE=true` logs stage
boundaries, elapsed time, process RSS and peak RSS, model and backend identity.
It never logs note text, prompts, audio, file paths or provider errors.

## macOS Metal measurement (2026-10-30)

Machine: Apple M5, 24 GiB physical memory, macOS 26.5.2 (build 25F84).
Runtime: `llamadart` 0.11.1, `llamadart_llama_cpp_flutter` 0.0.21, native
`v0.5.0-2`. Model: Qwen3 1.7B Q4_K_M, SHA-256
`b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897`.

Isolated probe (`app/tool/formatting_gpu_probe.dart`) built with the
`dev.theolm.smartnotes.formattingprobe` bundle identifier and no journal
initialization. The measured sequence used the shipped
`FormattingBackendPolicy.qualifiedProfiles` (not a diagnostic override), one
warm-up and five measured organization requests on a synthetic Portuguese
passage, alternating CPU and Metal. One session per request; load, tokenization,
generation and disposal included.

| Run | Backend | Total | Load | Generate | Output tokens | Generate tok/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| warm-up | CPU | 9.71 s | 1.28 s | 8.29 s | 173 | 20.9 |
| warm-up | Metal | 4.52 s | 0.22 s | 4.27 s | 164 | 38.4 |
| 1 | Metal | 4.17 s | 0.17 s | 3.98 s | 164 | 41.2 |
| 1 | CPU | 7.53 s | 0.73 s | 6.77 s | 158 | 23.3 |
| 2 | CPU | 7.72 s | 0.65 s | 7.04 s | 165 | 23.5 |
| 2 | Metal | 3.89 s | 0.17 s | 3.70 s | 163 | 44.1 |
| 3 | Metal | 3.92 s | 0.18 s | 3.72 s | 165 | 44.3 |
| 3 | CPU | 10.24 s | 0.67 s | 9.40 s | 173 | 18.4 |
| 4 | CPU | 31.87 s | 3.46 s | 28.26 s | 173 | 6.1 |
| 4 | Metal | 12.72 s | 0.81 s | 11.83 s | 165 | 14.0 |
| 5 | Metal | 12.68 s | 0.73 s | 11.86 s | 164 | 13.8 |

Runs 1-3 were on an unthrottled machine; runs 4-5 were visibly thermally
throttled after several minutes of sustained inference and builds. Both backends
degrade together, so the ratio is the stable finding: Metal generated 1.8-2.4x
faster (44 vs 23 tok/s unthrottled), and the unthrottled median total was 3.92 s
versus 7.72 s CPU (about 49% less). Across all five measured pairs the medians
were 4.17 s Metal and 10.24 s CPU (about 59% less). Run-to-run absolute times
must not be compared across sessions without the same thermal state.

`resolvedGpuLayers: 999` and backend `Metal` were reported for every GPU
request; CPU sessions reported `CPU` and `0`. All requests returned structurally
valid JSON through the production service, including preview construction, and
no request fell back.

The first Metal load ever for this bundle identifier took 15.7 s because the
slower JIT shader compilation ran once; later process launches loaded in
0.17-0.22 s. The first organization request after a fresh install therefore
pays a large one-time GPU cost even though later requests do not.

Memory: the GPU-only sequence peaked at 2.05 GiB process RSS; the interleaved
CPU sequence peaked at 3.29 GiB. Disposal returned RSS to roughly 0.47-0.57 GiB
after every request. Peak RSS is process-wide and retained after disposal, so it
is not a per-request allocation figure.

## Package checks

Android debug packaging now bundles `libggml-vulkan.so` (26.4 MB) for
`arm64-v8a` only, alongside the unchanged CPU libraries. `llvm-readelf` reports
`0x4000` (16 KB) LOAD alignment for that library. A host-side arm64-only build
was also exercised through the isolated probe. Before any Android profile is
qualified, confirm API 24-27 and non-`arm64-v8a` startup still selects CPU and
does not crash while enumerating the bundled Vulkan module; if that fails,
remove `vulkan` from the Android bundle until it is fixed.

## What this does not establish

- One machine, one model artifact, one preset, one synthetic source. No
  Portuguese/Spanish/French/mixed-language semantic review, no long-note
  boundary, no 0.6B or 4B artifacts.
- The source language and facts were not scored against a reference. JSON
  validity is not semantic fidelity.
- No thermal throttling, low-memory, process-kill or interruption test on
  physical iOS. No iOS or macOS hardware other than the M5 above.
- Android Vulkan for formatting is unmeasured. Known upstream limits apply:
  Android Vulkan llama.cpp is experimental and device-dependent, and the pinned
  0.11.1 mitigates only text-prefill micro-batching for one wrong-output mode.
- Metadata-only (title/subtitle) requests are not qualified; they remain CPU.

## Reproduction

Android (isolated package, model pushed to `/data/local/tmp`):

```sh
cd app
adb push <Qwen3-1.7B-Q4_K_M.gguf> /data/local/tmp/smartnotes-formatting-Qwen3-1.7B-Q4_K_M.gguf
ORG_GRADLE_PROJECT_smartnotesApplicationId=dev.theolm.smartnotes.formattingprobe \
  flutter build apk --debug --target-platform android-arm64 \
  -t tool/formatting_gpu_probe.dart \
  --dart-define=FORMATTING_MODEL_PATH=/data/local/tmp/smartnotes-formatting-Qwen3-1.7B-Q4_K_M.gguf \
  --dart-define=FORMATTING_REPETITIONS=5 --dart-define=INFERENCE_TRACE=true
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Verify the package identity before installing with `aapt dump badging`.

macOS: build the probe target with the isolated bundle identifier, then run the
binary directly and read `FORMATTING_PROBE` lines. The probe verifies file size
and SHA-256 against the catalog before loading, never touches the journal, and
writes only synthetic results to a temporary directory.

Regression on the real preset suite against a qualified backend:

```sh
flutter test integration_test/local_formatting_platform_test.dart -d macos \
  --dart-define=FORMATTING_MODEL_PATH=<path to GGUF> \
  --dart-define=FORMATTING_MODEL_ID=qwen3-1.7b-q4_k_m \
  --dart-define=FORMATTING_BACKEND=gpu
```

`FORMATTING_BACKEND=cpu` is the paired reference.

## Adding a profile

1. Run the probe on the exact hardware and artifact, alternating CPU and GPU.
2. Require at least 20% lower median total latency, no consistent tail
   regression, structurally valid output for every preset, no crash, and
   documented memory headroom.
3. Review semantic fidelity for the supported languages with approved fixtures.
4. Add the profile to `FormattingBackendPolicy.qualifiedProfiles` and this
   document, including the date, OS build, driver, medians and limits.
5. Update `FormattingBackendPolicy.runtime` when the runtime changes; an
   interrupted marker stays closed until the user retries or a new runtime
   identity ships.

## Rollback

Turn off GPU acceleration in AI organization settings. That immediately returns
every request to CPU without touching models, notes or the speech preference.
Removing a profile from `qualifiedProfiles` disables it for new requests on the
next release. The circuit marker can be cleared with Retry only when no job is
active.
