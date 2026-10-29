# Android Whisper acceleration validation

## Status

The Android beta GPU path is implemented behind a settings toggle and a CPU
fallback, but it is not release-qualified. S24/Exynos measurements and PT-BR
screening are recorded below; other device families, memory, thermal, lifecycle,
and physical crash recovery remain open. The app still ships the CPU library on
every platform and ABI, and Apple builds and llama.cpp configuration are
unchanged.

The baseline before this work was clean: `flutter analyze` reported no issues,
and all 700 Flutter tests passed.

Implementation checks: 732 Flutter tests (including production dependency
injection and crash/storage-recovery cases), 24 host-side probe tests, 16 fork
unit tests, and a C++ boundary regression test passed; analysis and diff
whitespace checks were clean. An isolated debug and release APK built with a
disposable test signing key, and the debug install was exercised through the real
app service and reported `backend: vulkan`. A debug APK also built from the
git-pinned fork commit, containing the Vulkan library only under `arm64-v8a` with
16 KB page alignment.

## App diagnostics and repeat runs (2026-10-29)

- Opt-in `--dart-define=INFERENCE_TRACE=true` logs stage boundaries, elapsed
  time, backend/model identity, process RSS and peak RSS. It is off by default.
  The trace helper does not log source text, audio, file paths or provider error
  messages. Logs remain local to the development device/host.
- A user-reported app termination was recorded by Android as `LOW_MEMORY`,
  with approximately 1.4 GB RSS. No native crash stack was captured. The GPU
  marker had been completed about 14 seconds before termination; this does not
  establish which later operation caused the memory pressure.
- Two subsequent user-operated runs completed with Small Q5_1 and confirmed
  `backend: vulkan`, without CPU fallback. Approximate converted-audio durations
  were 63.6 and 122.1 seconds; native request times were 9.8 and 14.8 seconds.
- In these runs, automatic title/subtitle generation loaded Gemma 3 4B IT
  Q4_K_M after speech completed. Process peak RSS reached approximately 4.0 GB
  during formatting-model loading. Formatting disposal completed before
  EmbeddingGemma indexing; RSS returned to approximately 256 MB after the final
  embedding disposal. This suggests formatting memory pressure as a suspect,
  not a proven cause of the previous termination or evidence of a crash fix.
- These are functional observations, not a transcript-quality benchmark. The
  recordings and generated text were not collected as benchmark fixtures.
- A later isolated benchmark attempt did not complete and was cancelled. Its
  APK had the production application ID, not the intended isolated ID. Do not
  count it as isolated validation or infer a native crash from that test output.
  Verify the built APK identity before every future benchmark install.

## Initial physical-device evidence (2026-10-27)

Device: Samsung Galaxy S24 (SM-S921B), Android 16, Exynos 2400, stock Samsung
Xclipse 940 driver. Vulkan reported vendor ID 5197, device ID 39846400, driver
version 100663830, and API version 4206871. No replacement driver was installed.

Workload: pinned Base Q8 catalog artifact, public 11-second JFK WAV from the
pinned upstream source, explicit English, six CPU threads, default context flash
attention enabled for both backends. Audio SHA-256:
`59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e`.

After excluding one warm-up per backend, three measured runs produced:

| Metric | CPU | Vulkan |
| --- | ---: | ---: |
| Median native total (load, PCM read, inference, disposal) | 1,949.95 ms | 10,200.95 ms |
| Median encoder timing reported by Whisper | 1,016.13 ms | 8,737.12 ms |

Vulkan was approximately **5.23 times slower** on this configuration/workload.
All eight fixture transcripts had the same SHA-256, but equality on one clip is
not a reference-based quality evaluation. Backend initialization was confirmed;
individual GPU operation placement was not profiled. This is not an in-app
latency measurement and does not establish results for other GPU families,
quantizations, models, recordings, or driver/toolchain versions.

**Decision for this 11-second clip:** keep Base Q8 on CPU for this configuration. Availability alone is
not sufficient qualification. The native feasibility gate has not justified a
production GPU integration.

The larger existing multilingual Small Q5_1 artifact was then tested with the
same fixture and options, again excluding one warm-up and using three measured
runs per backend:

| Metric | CPU | Vulkan |
| --- | ---: | ---: |
| Median native total | 6,458.54 ms | 32,475.49 ms |
| Median encoder timing | 4,853.09 ms | 30,110.07 ms |

Vulkan remained approximately **5.03 times slower**. All eight Small fixture
transcripts were identical by SHA-256. The negative result is therefore not
limited to Base Q8, but still cannot be extrapolated to all Android hardware or
all models. No performance qualification was granted for either tested model.

### Follow-up investigation

The user requested additional investigation on this S24 before deciding whether
to proceed. The probe now supports capability inspection, explicit Flash
Attention selection, allowlisted backend options, and GPU timestamp profiling.
These are diagnostic controls only; none changes application behavior.

Findings so far:

- The stock driver exposes FP16/INT8 features and the integer-dot-product
  extension, but not `VK_KHR_cooperative_matrix`. An advertised extension is not
  proof that its accelerated feature/property bits satisfy ggml's requirements.
  Inspection confirmed `shaderIntegerDotProduct=true` but
  `integerDotProduct4x8BitPackedSignedAccelerated=false`. The pinned ggml backend
  requires both for its integer-dot-product path, so a newer shader compiler
  alone cannot activate that optimization on this driver.
- The NDK's bundled `glslc` identifies as shaderc 2022.3 and cannot compile the
  modern integer-dot-product shader path. A separate shaderc 2026.4 compiler was
  downloaded from a checksum-pinned macOS arm64 Homebrew bottle, extracted only
  under the experiment's scratch directory. Nothing was installed system-wide.
- Rebuilding with shaderc 2026.4 successfully enabled the shader compilation
  checks, but the first measured Base Q8 GPU run still took 9,875 ms versus
  1,756 ms for CPU. This was a screening run, not a three-run qualification.
- Disabling Flash Attention with the NDK compiler reduced a measured GPU run to
  8,099 ms (CPU with the same setting: 2,405 ms), still slower than default CPU.
- GPU timestamp profiling confirmed actual GPU matrix multiplication and
  attention execution. In one diagnostic run, the captured aggregates included
  about 5.70 seconds of matrix multiplication and 2.13 seconds of Flash
  Attention. Profiling changes scheduling and is not a qualification workload.

Single-variable screening with the modern compiler (one warm-up, one measured
run, Base Q8 and the same public clip) gave these GPU native totals:

| Vulkan configuration | Measured native total |
| --- | ---: |
| Defaults | 9,875 ms |
| Flash Attention disabled | 8,077 ms |
| Prefer host memory only | 9,642 ms |
| Async disabled only | 10,172 ms |
| FP16 arithmetic disabled only | 4,665 ms |
| FP16 and Flash Attention disabled | 2,472 ms |
| FP16 and Flash Attention disabled, prefer host memory | 2,078 ms |

The best screening combination substantially reduced Vulkan latency, but did
not beat the default CPU reference. These settings do not change model weights.
They also do not guarantee every operation remains on GPU; offload policy must
still be inspected. The next confirmation comparison preserves default CPU
Flash Attention while applying `--vulkan-flash-attention off` only to Vulkan,
so an artificially slowed CPU reference cannot make GPU look favorable.

### Confirmed tuned results

The best combination was subsequently compared against **unchanged CPU defaults**
with one warm-up and three measured runs per backend. Only Vulkan disabled Flash
Attention and FP16 arithmetic and preferred host memory. The model artifacts,
language, thread count, audio, source revision, and driver were unchanged.

| Existing catalog model | CPU median | Tuned Vulkan median | Native result |
| --- | ---: | ---: | --- |
| Base Q8 | 2,067.83 ms | 2,140.24 ms | 3.5% slower; keep CPU |
| Small Q5_1 | 6,281.41 ms | 3,543.48 ms | 43.6% less time; performance candidate |

The tuned Small result was reproduced with the **original NDK shader compiler**:
approximately 3,579 ms in one measured GPU run (CPU in that pair: 6,844 ms). A separate
reference-scored NDK run again measured approximately 3.55 seconds on GPU. The
new shader compiler is therefore not required for the observed benefit. The
gain comes from the backend/attention/memory configuration on this tested driver,
not from replacing Whisper, model weights, or the device driver.

Small's raw transcript hashes differed between default CPU and tuned Vulkan.
A follow-up comparison against `app/tool/fixtures/jfk_reference.txt` confirmed
identical normalized words and **0 WER** on all four reference-scored CPU/GPU
runs. Differences in raw formatting/casing/punctuation are not byte-identical
fidelity. This is one short English clip, not a multilingual quality sign-off.

An additional tuned Small diagnostic with the NDK compiler measured GPU timestamp
aggregates including 1.47 seconds of matrix multiplication and 0.64 seconds of
matrix-vector operations. Thus the tuned path performs actual GPU work, not
merely successful GPU initialization. Those profiled runs are excluded from the
unprofiled latency comparison.

**Outcome for the 11-second workload:** a shared Vulkan backend with
per-configuration options is feasible on this stock S24 and beneficial for Small
Q5_1, but not Base Q8 at that duration.
Do not enable it universally or infer benefits for untested workloads, Large,
other drivers, or other devices. Turbo follow-up evidence is below.
Production activation is implemented behind the beta policy described below, but
no release qualification has been granted yet. The rollback for an unqualified
release is a CPU default with the toggle available as opt-in. Remaining gates are
optional-backend packaging on other device families, guarded fallback across
drivers, app-level timing, PT-BR/long/noisy quality on more devices, memory,
cancellation, and lifecycle validation.

### Duration scaling and Turbo follow-up

The user requested a longer Base workload and Turbo measurements. A controlled
132-second fixture was generated by repeating the pinned 11-second public JFK
clip twelve times, with a correspondingly repeated reference. This is a
**duration-scaling experiment, not a natural conversation or diverse long-form
quality evaluation**. No journal recordings are used. The generator writes a
manifest with source/output/reference hashes, repetition count, and explicit
synthetic-fixture labeling:

```sh
python3 app/tool/whisper_vulkan_probe.py --work "$PROBE_WORK" loop-fixture --repetitions 12
python3 app/tool/whisper_vulkan_probe.py --work "$PROBE_WORK" fetch-model --model turbo
```

Turbo uses the existing catalog's pinned `ggml-large-v3-turbo-q5_0.bin` artifact,
not a new model or quantization. All follow-up experiments use the original NDK
compiler and the same stock driver. CPU settings remain unchanged; Vulkan alone
disables FP16 arithmetic and Flash Attention and prefers host memory.

For **Base Q8 with 132 seconds**, one warm-up and three measured runs per backend
produced a CPU median of **16,845.27 ms** and Vulkan median of **7,049.01 ms**:
**58.2% less native elapsed time**. Every CPU/GPU result had identical text and
0 WER against the loop reference. The three measured GPU totals were approximately
7.06, 7.02, and 7.05 seconds.

Model-file loading was only about 90 ms on CPU versus 97 ms on Vulkan in this
experiment; the difference was primarily inside inference, not file loading.
Whisper's reported `encode_ms` is a **mean per encoder call**, not the sum across
all windows. Its measured means were approximately 1,014 ms on CPU and 504 ms on
Vulkan. Do not sum that field with wall-clock totals or interpret it as total
encoder time for a long recording.

This supersedes any blanket recommendation that Base must always use CPU:
qualification must consider **duration/workload as well as device, driver,
model, quantization, and backend settings**. Two durations do not establish a
safe switching threshold.

The completed follow-up suite produced the following native elapsed times using
the same original NDK build and settings. Values are medians of three measured
runs per backend after one warm-up, except Turbo long, which has only one measured
run per backend after warm-up:

| Model | Audio | CPU | Tuned Vulkan | Latency change | Reference WER CPU / GPU |
| --- | ---: | ---: | ---: | ---: | ---: |
| Base Q8 | 11 s | 1.814 s | 2.064 s | 13.8% slower | 0% / 0% |
| Base Q8 | 132 s loop | 16.845 s | 7.049 s | 58.2% less time | 0% / 0% |
| Turbo Q5_0 | 11 s | 28.777 s | 10.223 s | 64.5% less time | 0% / 0% |
| Turbo Q5_0 | 132 s loop | 293.954 s | 72.893 s | 75.2% less time | 0% / 8.33% |

Base short remains unfavorable, although the exact percentage varies between
suites. Turbo short measured GPU totals of 10.344, 10.223, and 10.206 seconds;
CPU totals were 28.186, 28.909, and 28.777 seconds. All short Turbo transcripts
were byte-identical across backends and had 0 WER.

**Turbo long is not accuracy-qualified.** Both GPU warm-up and measured runs had
8.33% WER against the repeated reference, while both CPU runs had 0 WER. Normalized
word hashes differed, so this is not merely punctuation. The natural-audio control
below did not reproduce this regression, so repetition is the leading explanation
for that fixture; the mechanism remains unidentified and the loop must not be used
as a quality benchmark. Investigate with natural PT-BR/long/noisy speech before any
activation decision.

### Natural long-audio control

To separate a backend defect from an artifact of the repeated loop, the probe now
builds a long fixture from **distinct** utterances of public LibriSpeech
`test-clean` (CC BY 4.0). Utterance order is deterministic, texts must be unique,
and 0.3 s of silence separates consecutive utterances. The archive is pinned at
`https://www.openslr.org/resources/12/test-clean.tar.gz`, SHA-256
`39fde525e59672dc6d1551919b1478f724438a95aa55f874b576be21967e6c23`. The manifest
records the dataset, license, selected utterance IDs, gap, and audio/reference
hashes:

```sh
python3 app/tool/whisper_vulkan_probe.py --work "$PROBE_WORK" natural-fixture --seconds 132
```

This fixture is read speech stitched at utterance boundaries, not spontaneous
conversation, overlapping turns, noise, or PT-BR. It removes only one variable:
repetition.

Natural-fixture results (1 warm-up + 2 measured runs per backend, same build,
settings, and device; fixture duration 148.28 s):

| Model | CPU median | Tuned Vulkan median | Latency change | WER CPU / GPU |
| --- | ---: | ---: | ---: | ---: |
| Base Q8 | 23,638.91 ms | 9,139.22 ms | 61.3% less time | 3.49% / 3.49% |
| Turbo Q5_0 | 282,248.30 ms | 60,765.87 ms | 78.5% less time | 1.08% / 0.81% |

Turbo GPU totals were 59,480 and 62,052 ms; CPU totals were 260,105 and 304,392 ms.
**The 8.33% Turbo long regression did not reproduce on natural audio**: GPU WER was
0.81%, below CPU's 1.08%, and both were stable across runs. Base matched exactly at
3.49% on both backends. The earlier error is therefore specific to the repeated
loop fixture, although this experiment does not identify the exact mechanism
(repetition, segmentation at identical boundaries, or another interaction).

The non-zero Base WER is shared by CPU and GPU and is not attributed to Vulkan; it
includes stitching/reference-boundary differences on concatenated utterances. This
probe's WER is a normalized word comparison, not the Open ASR evaluation.

Raw transcript hashes still differ between backends in both models, so equality is
at the normalized-word level and within-fixture, not byte-identical output. Two
measured runs, one English read-speech fixture, and one device do not qualify
spontaneous speech, noise, accents, or PT-BR. No production activation follows
from this control; it only removes the loop artifact as a blocker.

### Production integration

The app depends on the public `theolm/whisper_ggml` fork, version
`2.8.1+smartnotes.1`, based on upstream `master` commit
`9bd9e7f2022eaf3211c9c82da2566b55f96f8c52`. A `git:` dependency pins commit
`330b36b8cd36bf72409a6a5272cc403ed8d5f58e` on `smartnotes/vulkan`, so every
machine builds the same sources. The fork adds:

- `Whisper(backend: WhisperBackend.vulkan)` and
  `Whisper.probeCapabilities()`, which reports availability without loading a
  model.
- `WhisperException` codes and the backend that actually produced a transcript.
- A separate `libwhisper_vulkan.so` for Android `arm64-v8a`, built against the
  API 28 Vulkan stub, while the existing `libwhisper.so` remains the API 24 CPU
  library for every ABI.

The Vulkan library is checked in under
`android/src/main/jniLibs/arm64-v8a/` and is reproducible with the fork's
`tool/build_android_vulkan.sh` from pinned whisper.cpp v1.9.1, SPIRV-Headers, and
Vulkan-Headers archives. It exports only the speech entry points; ggml/whisper
symbols are excluded with `--exclude-libs,ALL`.

Application policy:

| Model | Backend |
| --- | --- |
| Small Q5_1 | GPU at any duration |
| Turbo Q5_0 | GPU at any duration |
| Base Q8 | GPU only at or above `SpeechBackendPolicy.baseGpuMinDuration` |
| Small English, Medium English, Large | CPU until measured |

Eligibility requires Android arm64, API 28+, Vulkan 1.1 hardware, a successful
capability probe, the user preference enabled, and a closed circuit. The
Transcription settings screen exposes a single beta toggle. A recoverable GPU
failure retries once on the CPU; two failures or an interrupted marker open a
crash circuit that only an explicit retry clears. The marker is written before
the capability probe loads the Vulkan library and before inference, and is
resolved before journal recovery. If the marker cannot be read or written, the
service stays on the CPU instead of failing the transcription. The Vulkan library
also rejects a request that upstream would have executed on the CPU, so a CPU
transcript is never reported as GPU success.

Standalone probe results remain feasibility evidence, not app-level acceptance.
PT-BR and noisy-speech screening are recorded below. Other device families,
memory, thermal behavior, lifecycle, and physical fallback still gate the beta's
default; until those are recorded here, the integration is implemented but not
qualified for release.

#### Application-level GPU smoke

An isolated debug install (`dev.theolm.smartnotes.sttbenchmark`, `minSdk` 24)
loaded the 11-second public JFK clip with Small Q5_1 through the real app service,
queue, FFmpeg conversion, and policy. After the tuned defaults were applied at
library load (before the capability probe initializes Vulkan), all four runs
reported `backend: vulkan` with no fallback:

| Run | Total | Whisper request |
| --- | ---: | ---: |
| warm-up | 3,814 ms | 3,749 ms |
| measured 1 | 2,237 ms | 2,180 ms |
| measured 2 | 2,197 ms | 2,131 ms |
| measured 3 | 2,082 ms | 2,052 ms |

The packaged APK contained `libwhisper_vulkan.so` only under `arm64-v8a`
(32.8 MB uncompressed) and the CPU library for `arm64-v8a`, `armeabi-v7a`, and
`x86_64`. The isolated package allowed testing without touching the user's
journal. This is one short English clip on one device; it proves packaging,
backend selection, capability probing, and backend reporting, not quality or
memory acceptance.

Environment ordering matters: the Vulkan library sets `GGML_VK_DISABLE_F16` and
`GGML_VK_PREFER_HOST_MEMORY` in a load-time initializer. Moving them next to
`whisper_init` is too late once `probeCapabilities()` has created the device.

#### Base duration crossover

Natural public read speech (LibriSpeech, English) was trimmed to 5/15/30/45/60 s
without a WER comparison. Base Q8 used one warm-up and two measured runs per
backend:

| Duration | CPU median | Tuned Vulkan median | Vulkan / CPU |
| ---: | ---: | ---: | ---: |
| 5 s | 1,623.4 ms | 2,021.5 ms | 124.5% slower |
| 15 s | 2,615.3 ms | 2,278.9 ms | 87.1% (12.9% faster) |
| 30 s | 5,474.8 ms | 3,253.9 ms | 59.4% (40.6% faster) |
| 45 s | 6,953.8 ms | 3,663.7 ms | 52.7% (47.3% faster) |
| 60 s | 10,096.3 ms | 4,628.2 ms | 45.8% (54.2% faster) |

The crossover is near 12–15 s. `SpeechBackendPolicy.baseGpuMinDuration` is
**20 s**, a deliberate margin above the measured crossover. This is device- and
driver-specific and must be re-measured before extending the policy to other
device families.

Short-capture checks for the models that use the GPU at any duration (5 s
natural audio, one warm-up + two measured runs):

| Model | CPU median | Tuned Vulkan median | Result |
| --- | ---: | ---: | ---: |
| Small Q5_1 | 6,105.3 ms | 3,417.9 ms | 44.0% less time |
| Turbo Q5_0 | 28,923.2 ms | 10,099.7 ms | 65.1% less time |

Neither model needs a minimum-duration cutoff at this length.

#### PT-BR natural speech

A public FLEURS `pt_br` test fixture was built from 10 distinct utterances
(0.3 s gaps), 155.46 s total, with the dataset's reference text. Source artifacts
are pinned by SHA-256 in
`fleurs-pt-148s.json`: audio archive
`968d1b68a90132ca1f044f664866418b0db0351a93601a671d5637016da4f49b` and
transcript TSV. This is read speech, not spontaneous conversation or noise.

Turbo Q5_0, explicit `pt`, one warm-up and one measured run per backend:

| Backend | Native total | WER vs FLEURS reference |
| --- | ---: | ---: |
| CPU | 348,149.8 ms | 7.19% |
| Tuned Vulkan | 77,320.4 ms | 6.83% |

GPU reduced elapsed time by **77.8%** and did not regress WER against the CPU in
this sample (GPU was 0.36 points lower). Raw transcript hashes differ, so this is
normalized-word parity, not byte identity. One measured run and one paragraph do
not qualify spontaneous speech, noise, accents, or other devices.

A 10.74 s PT-BR FLEURS utterance with added pink noise (amplitude 0.01, **not a
calibrated SNR**) produced identical CPU and GPU transcripts, 5.56% WER on both,
with 29,460 ms on CPU and 10,302 ms on GPU (65.0% less time). The GPU warm-up was
16,298 ms versus 10,302 ms measured: first-use shader compilation is real and must
be described separately from warm latency. This screening fixture is not a noise
qualification.







The long Turbo CPU warm-up took 252.398 seconds versus 293.954 seconds measured;
GPU warm-up took 74.272 seconds versus 72.893 seconds measured. One measured pair
cannot establish stable long-Turbo speedup or exclude thermal/scheduling effects.
Its measured model loading was approximately 368 ms CPU and 359 ms GPU, while
inference was 293.479 seconds CPU and 72.411 seconds GPU. The improvement is not
explained by model-file loading alone. Process RSS is not total GPU/device memory
and must not be used as a full memory qualification.

Reports: `s24-base-q8-11s-duration-suite.json`, `s24-base-q8-132s.json`,
`s24-turbo-q5-11s.json`, and `s24-turbo-q5-132s.json` in the external probe work
directory. These standalone timings exclude app conversion, queueing, persistence,
and process launch. No production activation follows from these standalone
timings; the app-level beta policy is described below.

To reproduce compiler experiments on an Apple Silicon development host running
macOS 26 or later:

```sh
python3 app/tool/whisper_vulkan_probe.py --work "$PROBE_WORK" fetch-shaderc
python3 app/tool/whisper_vulkan_probe.py --work "$MODERN_PROBE_WORK" build \
  --sdk "$ANDROID_SDK_ROOT" \
  --glslc "$PROBE_WORK/modern-tools/shaderc/2026.4/bin/glslc" \
  --glslc-sha256 73f9f514345e732bee65d4b92043af384b34f26af3ed797e0afbfb4e1449f8ce
```

Use separate work directories to keep compiler build identities independent.
The public-registry pull token is anonymous, transient, and never persisted or
logged. The bottle SHA-256 is
`12ba0c59a98fb8f671f9473573002b2a812f26d2e60ea4f577f0c8c750c9838a`.

`run` accepts `--flash-attention off`, `--vk-option prefer-host-memory`,
`--vk-option disable-async`, and `--vk-option disable-f16` for controlled
single-variable experiments. `--backends vulkan --runs 1` is a screening mode,
not evidence for production activation. `--profile` retains only aggregate GPU
operation timings, not raw driver logs, and must not be mixed with unprofiled
latency results. `inspect --device "$ANDROID_DEVICE"` reads capability metadata
without loading a speech model.

## Reproducible native feasibility probe

`app/tool/whisper_vulkan_probe.py` builds CPU and Vulkan executables from the
immutable whisper.cpp v1.9.1 commit matching the installed plugin's reported
upstream version. This does not establish source identity with the plugin's
vendored tree. SPIR-V and Vulkan headers are also pinned by commit and archive
SHA-256. Archives are verified before filtered extraction. No git command or
global pub-cache modification is required.

Prerequisites:

- Python 3.12+ (`uv run --python 3.13 --no-project` also works).
- Android SDK CMake 3.22.1, NDK 29.0.13113456, and its host shader tools.
- `adb`, host `ffmpeg`, a physical Android arm64 device, and the stock GPU driver.
- Approved synthetic/public audio and a checksum-verified existing catalog model.

Use a dedicated external scratch directory for all downloads/build artifacts:

```sh
python3 app/tool/whisper_vulkan_probe.py --work "$PROBE_WORK" build --sdk "$ANDROID_SDK_ROOT"
python3 app/tool/whisper_vulkan_probe.py --work "$PROBE_WORK" fetch-model
python3 app/tool/whisper_vulkan_probe.py --work "$PROBE_WORK" run \
  --device "$ANDROID_DEVICE" \
  --model "$PROBE_WORK/ggml-base-q8_0.bin" \
  --model-sha256 c577b9a86e7e048a0b7eada054f4dd79a56bbfa911fbdacf900ac5b567cbb7d9 \
  --audio "$PUBLIC_FIXTURE_WAV" --language en --approved-fixture \
  --output "$PROBE_WORK/report.json"
```

The pinned Whisper source includes the public `samples/jfk.wav` fixture. It is
appropriate for an initial English smoke test, not multilingual qualification.
Pass `--reference` with an approved reference transcript to calculate simple
Unicode-normalized WER. That normalization is not the Open ASR scoring pipeline.
The report contains transcript hashes and optional WER, never transcript text or
host/device paths. Never use personal journal recordings as benchmark fixtures.

The runner stages binaries and fixtures in one randomly named
`/data/local/tmp/smartnotes-whisper-*` directory, deletes only that directory
afterwards, and does not install, launch, stop, or access the user's SmartNotes
application. It alternates CPU/GPU order, labels a first warm-up iteration, and
loads/frees the model on every run. Warm runs mean warmed caches, not resident
model weights. Process-launch, staging, and host audio conversion time are not
part of `native_total_ms`.

The probe rejects a requested Vulkan run if Whisper does not report initializing
the Vulkan backend. This confirms initialization, not the percentage of graph
operations executed on the GPU. GPU profiling is still required for qualification.

### Native packaging finding

The installed `whisper_ggml` package uses a custom CPU-only CMake build and omits
the upstream Vulkan build tree. Merely changing `use_gpu` cannot enable it.

Upstream v1.9.1 directly references `vkGetPhysicalDeviceFeatures2`, which cannot
link against Android API 24's Vulkan stub. The standalone Vulkan executable is
therefore built for API 28; the separate CPU executable targets API 24. The app's
minSdk remains 24. Any eventual production integration must isolate the optional
Vulkan library so older devices can load and run the CPU library without resolving
that symbol. A Dart availability check alone cannot solve load-time linkage.

## Application-level CPU baseline

`LocalTranscriptionService.transcribeMeasured` preserves the ordinary text-only
domain API while exposing monotonic, non-persisted timings for qualification:

- Queue wait.
- Model verification.
- App-owned audio conversion.
- Apple language-detection pre-pass (zero on Android).
- Entire Whisper plugin request.
- Temporary-file cleanup and total elapsed time.

The plugin request itself performs another conversion, model loading, inference,
and disposal. Its duration must not be described as pure native inference. The
baseline makes that additional conversion visible as part of the request rather
than silently removing it during GPU comparisons. Raw transcripts are not logged
by the transcription service, including debug builds.

`app/integration_test/stt_benchmark_platform_test.dart` is opt-in and requires the
isolated package ID `dev.theolm.smartnotes.sttbenchmark`. It never starts the
journal or application DI. Supply these Dart defines through your physical-device
integration-test runner:

```text
STT_BENCHMARK_APPROVED_FIXTURE=true
STT_BENCHMARK_MODEL_PATH=<fixture model readable by the isolated app>
STT_BENCHMARK_MODEL_ID=whisper-base-q8_0
STT_BENCHMARK_AUDIO_PATH=<approved audio readable by the isolated app>
STT_BENCHMARK_AUDIO_SHA256=<approved audio digest>
STT_BENCHMARK_LANGUAGE=en
```

Set `ORG_GRADLE_PROJECT_smartnotesApplicationId=dev.theolm.smartnotes.sttbenchmark`
for that build. A driver is provided for release-mode runs:

Configure disposable test signing through `KEYSTORE_FILE`, `KEY_ALIAS`,
`KEY_PASSWORD`, and `KEYSTORE_PASSWORD`, as in the CI validation documented in
`release.md`. Do not use production signing credentials for this test APK.

```sh
ORG_GRADLE_PROJECT_smartnotesApplicationId=dev.theolm.smartnotes.sttbenchmark \
  flutter drive --release -d "$ANDROID_DEVICE" \
  --driver test_driver/stt_benchmark_driver.dart \
  --target integration_test/stt_benchmark_platform_test.dart \
  --dart-define=STT_BENCHMARK_APPROVED_FIXTURE=true \
  --dart-define=STT_BENCHMARK_MODEL_PATH="$DEVICE_FIXTURE_MODEL" \
  --dart-define=STT_BENCHMARK_AUDIO_PATH="$DEVICE_FIXTURE_AUDIO" \
  --dart-define=STT_BENCHMARK_AUDIO_SHA256="$FIXTURE_AUDIO_SHA256"
```

Run from `app/`; fixtures must already be readable by that isolated installation.
Do not point the test at the installed journal's files. Preserve model,
audio, device, OS, decoding options, and hashes. The test verifies the model through
the existing catalog service and hashes the audio before timed requests. It prints
only timing metadata and hashes. It does not measure GPU acceleration yet.

## Acceptance boundary

A standalone success does not enable production acceleration. Still required:
app-process optional-backend packaging, capability checks, versioned offline
qualification, bounded recoverable fallback, interrupted-attempt protection, and
physical-device lifecycle, memory, quality, sustained-performance, and native
coexistence testing. Root, alternate drivers, and Termux are not acceptable app
requirements. No configuration may be advertised as faster without end-to-end
measurements on the actual application pipeline.
