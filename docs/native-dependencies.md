# Native dependency notices

SmartNotes uses `sqlite3_vec` 0.1.2, an MIT community binding by ZhuJHua,
which compiles the bundled upstream sqlite-vec 0.1.9 C source using native
build hooks. Android builds link libm and request 16 KB library alignment;
macOS builds package the matching native code asset and load it in the app
(verified by `integration_test/macos_platform_test.dart`).

- [Binding source and MIT license](https://github.com/ZhuJHua/sqlite3_vec)
- [Binding third-party notices](https://github.com/ZhuJHua/sqlite3_vec/blob/main/THIRD_PARTY_NOTICES.md)
- [sqlite-vec 0.1.9 source](https://github.com/asg017/sqlite-vec/tree/v0.1.9)
- [sqlite-vec MIT license](https://github.com/asg017/sqlite-vec/blob/v0.1.9/LICENSE-MIT)
- [sqlite3 Dart binding (MIT)](https://pub.dev/packages/sqlite3)
- [SQLite public-domain dedication](https://www.sqlite.org/copyright.html)

Flutter's license registry includes package LICENSE files. Redistribution must
retain the applicable copyright/permission notices for the pinned package and
bundled native source. Other native dependencies, including FFmpeg, require
their own license compliance; this document does not replace their notices.

## Local speech recognition

`whisper_ggml` is pinned to **2.7.1** and vendors **whisper.cpp 1.9.1** for
Android/iOS/macOS. Both use MIT licenses; retain their upstream notices.
All six speech artifacts (Base Q8_0, Small.en Q8_0, Medium.en Q5_0, Small Q5_1,
Large-v3-turbo Q5_0, Large-v3 Q5_0) are downloaded separately and verified against
pinned SHA-256 hashes, not bundled or exported with the journal. Android excludes
all app data from backup/transfer; iOS explicitly excludes model directories and
verified artifacts from iCloud Backup. macOS has no iCloud container, but external
system backups remain user-managed and can include replaceable model files. The complete
catalog pins revision `5359861c739e955e79d9a303bcbc70fb988958b1`; exact sizes,
filenames, and hashes live in `app/lib/domain/entities/speech_model.dart`.
Whisper's code and weights are MIT; the OpenAI notice is included in
`app/assets/licenses/whisper-model-MIT.txt` and Flutter's license registry.
The upstream Large-v3 model-card metadata has an Apache-2.0 discrepancy versus
OpenAI's repository statement that Whisper code and weights are MIT. Preserve
the bundled OpenAI notice and audit distribution notices before release; do not
infer the license of the complete native dependency graph from that statement.

The installed binding is CPU-only, with Accelerate on Apple; it does not enable
Metal/Vulkan/Core ML or Android NPU. Explicit artifact paths select weights;
Turbo uses this path because the public enum has no Turbo entry. A native
six-model smoke suite is in `integration_test/whisper_catalog_platform_test.dart`.
Use isolated device-test packages as described in the README, never a user's
journal installation. File verification is not a device compatibility benchmark.

### Measured device smoke result

Samsung Galaxy S23 (**SM-S921B**), Android 16, arm64-v8a, 7.4 GB `MemTotal`.
Debug APK, CPU-only, isolated validation package. Each cell is **cold model
load + one transcription**, with a synthetic 11-second English WAV and a 6.7-second
Brazilian Portuguese AIFF. All six artifacts loaded and produced the expected
fixture words. This is one run, not a release-build benchmark, peak-RSS,
thermal, or battery measurement.

| Model | English | Portuguese | Automatic |
| --- | ---: | ---: | ---: |
| Base Q8_0 | 1.3 s | 1.1 s | 2.0 s |
| Small.en Q8_0 | 3.9 s | — | — |
| Medium.en Q5_0 | 16.1 s | — | — |
| Small Q5_1 | 5.6 s | 5.7 s | 12.6 s |
| Large-v3-turbo Q5_0 | 33.5 s | 39.3 s | 78.1 s |
| Large-v3 Q5_0 | 45.1 s | 47.5 s | 92.5 s |

Automatic language detection is substantially slower than an explicit language
on this Android device. The recommendation policy remains conservative and does
not yet qualify a high-end SoC from these single-fixture timings.

Apple M5 Mac (24 GB, macOS 26.5.2), debug app, CPU + Accelerate, same fixtures:

| Model | English | Portuguese | Automatic |
| --- | ---: | ---: | ---: |
| Base Q8_0 | 0.8 s | 0.4 s | 0.7 s |
| Small.en Q8_0 | 1.2 s | — | — |
| Medium.en Q5_0 | 5.0 s | — | — |
| Small Q5_1 | 1.8 s | 1.7 s | 3.8 s |
| Large-v3-turbo Q5_0 | 8.5 s | 8.9 s | 20.3 s |
| Large-v3 Q5_0 | 11.5 s | 13.7 s | 25.0 s |

Android and macOS validated the six-model loader and output. iOS six-model
validation and release-build performance remain pending. These figures are not
representative of a 5-minute journal entry and must not be converted into RAM
requirements.

- [Binding source/license](https://github.com/sk3llo/whisper_ggml)
- [whisper.cpp source/license](https://github.com/ggml-org/whisper.cpp/tree/v1.9.1)
- [Whisper model license](https://github.com/openai/whisper/blob/main/LICENSE)
- [Pinned model artifact](https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base-q8_0.bin)

Audio decoding uses `ffmpeg_kit_flutter_new_min` 3.6.7 (the non-GPL `min`
variant), replacing the old audio speedup dependency. FFmpeg's LGPL/native
framework notices and redistribution obligations still apply independently of
Whisper's MIT license. A pinned dependency override replaces the binding's
older `^2.1.0` dependency: 3.6.7 retains the consumed Dart API and ships native
arm64 iOS simulator XCFramework slices, alongside device binaries. Revalidate
native builds and the real-model smoke test when either dependency changes.

## Local note formatting

`llamadart` **0.11.1** uses llama.cpp for GGUF inference, with the Apple SwiftPM
runtime companion `llamadart_llama_cpp_flutter` **0.0.21** (native release
`v0.5.0-2`). The bindings and llama.cpp use MIT licenses; retain their notices.
Build hooks select only llama.cpp and CPU Android libraries, not LiteRT-LM or
Vulkan. Apple binaries require **iOS 16.4+ / macOS 14+**; Android remains API 24+.
Native build downloads occur at build time, not during user inference.

The Qwen3-1.7B Q4_K_M artifact is downloaded separately (1,107,409,472 bytes).
Revision `d7f544eead698dbd1f15126ef60b45a1e1933222`, SHA-256
`b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897`.
The weights use Apache-2.0; its license is in
`app/assets/licenses/qwen3-model-Apache-2.0.txt` and Flutter's license registry.
Models are excluded from journal exports. Android excludes all app data from
backup/transfer and iOS explicitly excludes model files from iCloud Backup;
macOS system-backup inclusion remains user-managed.

- [Dart binding / MIT](https://github.com/leehack/llamadart)
- [Native runtime releases](https://github.com/leehack/llamadart-native/releases/tag/v0.5.0-2)
- [Qwen3 license](https://huggingface.co/Qwen/Qwen3-1.7B/blob/main/LICENSE)
- [Pinned quantized weights](https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/blob/d7f544eead698dbd1f15126ef60b45a1e1933222/Qwen3-1.7B-Q4_K_M.gguf)

Validation: 296 unit/widget tests passed, including the speech catalog,
recommendation, onboarding, migration, deletion, and queue-coordination cases.
Earlier real-model macOS formatting checks are recorded separately. Six-model
Whisper smoke tests passed on an Android Galaxy S23 and an Apple M5 macOS host
with CPU-only inference. They are not phone RAM/latency, thermal, or full
factual-fidelity benchmarks.
Android debug APK, iOS unsigned device/simulator and macOS debug builds passed.
Hot restart and the macOS runtime check found no errors. Whisper currently still
uses CocoaPods; Flutter warns that missing SwiftPM support will become an error
in a future Flutter version.

## Local semantic embeddings

The same pinned llamadart/llama.cpp runtime runs **Qwen3-Embedding-0.6B Q8_0**
on CPU workers. No additional embedding runtime is bundled. The official GGUF
is 639,150,592 bytes, revision `370f27d7550e0def9b39c1f16d3fbaa13aa67728`,
SHA-256 `06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439`.
The weights use Apache-2.0, covered by the bundled Qwen license and Flutter's
license registry. Preserve upstream copyright/license notices when distributing.

- [Official GGUF and license](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF)
- [Author pipeline](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B)

Use raw text, LAST pooling (validated metadata), 1024 native dimensions, MRL
slicing to 512 followed by L2 normalization. Queries alone receive the retrieval
instruction. Inputs are checked with the real tokenizer; documents use
384-token chunks with up to 64-token overlap, within a 1024-token context.
Indexing releases its native model every four chunks, including bounded
tokenization. Interactive jobs precede backlog with bounded fairness; no native
model lifetime overlaps another model's lease.

`integration_test/local_embeddings_platform_test.dart` accepts
`EMBEDDING_MODEL_PATH` and optional `EMBEDDING_REFERENCE_PATH`. Generate the
latter with `app/tool/embedding_reference.py` using public synthetic text, never
private journal content. It compares author-tokenizer IDs and full FP32
last-token vectors against Q8 (cosine >0.99), plus single/batch consistency.
This is a correctness/smoke gate, not a representative retrieval-quality or
physical-phone memory/latency benchmark.

Validated on macOS: all four author-reference tokenizer sequences match exactly;
full and MRL-512 Q8 vectors exceed 0.99 cosine against FP32 last-token outputs,
and batch/single vectors exceed 0.9999 cosine. The reference uses PyTorch
2.14.1 / Transformers 5.20.1, model revision
`97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3`. The offline Portuguese/English
vacation-versus-cooking retrieval smoke also passes. These small checks do not
establish recall, multilingual coverage, or mobile resource requirements.

The local-embedding change passes 251 unit/widget tests and clean analysis,
including v1 migration, rollback on migration failure, stale-generation writes,
index-progress cancellation, recoverable downloads/setup and legacy-credential
cleanup. Android debug APK, macOS debug and unsigned iOS device/simulator builds
pass. The remaining Whisper CocoaPods/SwiftPM warning is unchanged.
