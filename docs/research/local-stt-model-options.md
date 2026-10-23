# Local speech model options for SmartNotes

Research date: **2026-10-18**. Scope: an English-only quality option, a smaller multilingual option, and a high-quality multilingual option for powerful devices. Research only, not an ADR or implementation. No Git commands, model downloads, builds, or device benchmarks were performed. Only this report was added.

**Verified** means inspected first-party documentation, model cards, artifact metadata, or installed dependency source. **Assessment** means a proposed experiment, not a measured quality or mobile-performance guarantee. “Excellent” and “balanced” below describe intended product tiers, not established SmartNotes results. MB means decimal bytes / 1,000,000; model payload is not process RAM.

## Recommendation

1. **English-only: trial `small.en` Q8_0 first.** It stays within the existing Whisper runtime and costs about **264.48 MB**. Evaluate `medium.en` Q5_0 (**539.23 MB**) only if small.en misses the English quality gate; medium.en is not a lightweight phone default. Neither is proven “excellent” for spontaneous journal speech without evaluation. OpenAI explicitly says the English-only advantage becomes less significant at small/medium sizes. An English-only checkpoint does not itself guarantee better English than a larger multilingual checkpoint. [W1, A1]
2. **Balanced multilingual: `small` Q5_1, with Q8_0 as the quality-control alternative.** Downloads are **190.09 / 264.46 MB**. Portuguese is real supported input, unlike `.en`. Keep the current **base Q8_0 (81.77 MB)** as the genuinely small fallback. Small is a plausible quality upgrade, not proof of acceptable latency on mid-range Android; “moderate quality” cannot be assigned universally across languages. [W1, W4, A1]
3. **High-quality multilingual: prioritize `large-v3-turbo` Q5_0, then compare Q8_0.** Downloads are **574.04 / 874.19 MB**. Turbo preserves large-v3's encoder but reduces decoder depth from 32 to 4: a particularly useful transcription speed/quality tradeoff. It still has 809M parameters and is not a base-sized mobile model. Use full **`large-v3` Q5_0 (1,081.14 MB)** as an optional maximum-quality/control candidate, not the automatic flagship-phone default. Neither is verified here to run well on SmartNotes' CPU-only mobile build. [W1–W3, A1, F1]
4. **Do not switch runtime just to populate the initial three tiers.** Moonshine Medium Streaming is a serious English challenger if live incremental transcription or measured English efficiency justifies a new adapter. Parakeet TDT 0.6B v3 is a serious multilingual/Portuguese challenger if a sherpa-onnx integration wins local tests. Neither can be loaded by whisper.cpp. [M1–M3, P1, S1]

For a three-item trial catalog: **small.en Q8_0 / small Q5_1 / large-v3-turbo Q5_0**. Retain base Q8_0 as fallback. Do not advertise any tier as “excellent Portuguese” or set minimum device RAM until measured on target devices.

## Current project context, not the older report's implementation assumptions

The earlier cloud-era STT investigation is historical. Current [CONTEXT.md](../../CONTEXT.md), [PRODUCT.md](../../PRODUCT.md), and [ADR-020](../adr/020-transcript-first-optional-organization.md) require on-device transcription, retained original audio, and independently saved transcription before optional formatting; [ADR-021](../adr/021-local-speech-model-catalog.md) records the current model catalog.

Verified in current source:

- [`SpeechModel.whisperBaseQ8`](../../app/lib/domain/entities/speech_model.dart) pins multilingual `ggml-base-q8_0.bin` at revision `5359861c739e955e79d9a303bcbc70fb988958b1`, **81,768,585 bytes**, SHA-256 `c577b9a86e7e048a0b7eada054f4dd79a56bbfa911fbdacf900ac5b567cbb7d9`.
- [`app/pubspec.yaml`](../../app/pubspec.yaml) pins **whisper_ggml 2.7.1**.
- [`LocalTranscriptionService`](../../app/lib/data/services/local_transcription_service.dart) converts original-speed audio to 16-kHz mono PCM WAV, serializes inference, requests transcription rather than translation, and unloads the model after each job. Its `WhisperModel.base` constructor value is currently fixed, but the actual file path is supplied separately.
- Apple automatic language detection has an app-owned workaround in [`whisper_language_detector.dart`](../../app/lib/data/services/whisper_language_detector.dart). An English-only model should force `en` and bypass automatic multilingual detection; do not silently accept a Portuguese selection with `.en` weights.

## Distinct capabilities and tradeoffs

| Candidate | Capability that matters | Portuguese | What it does not establish |
| --- | --- | --- | --- |
| Whisper `small.en`, 244M | English-only ASR at the same size class as multilingual small; existing enum/runtime path | No | A large English advantage over small, or best English quality overall [W1, F1] |
| Whisper `medium.en`, 769M | Larger English-only quality challenger within the same runtime | No | Acceptable mid-range phone speed; a necessary upgrade before trying turbo [W1, F1] |
| Whisper `small`, 244M | Broad multilingual transcription, language identification, and translation into English | Yes, `pt` | Equal quality for every supported language, reliable within-recording code-switching, or mobile real-time speed [W1, W4] |
| Whisper `large-v3-turbo`, 809M | Large-v3 encoder with a 4-layer rather than 32-layer decoder; multilingual transcription at lower decoding cost | Yes, `pt` | Reliable speech translation into English; OpenAI says turbo is not trained for translation [W1, W2] |
| Whisper `large-v3`, 1,550M | Full large-v3 capacity; multilingual ASR plus speech-to-English translation; 128 Mel bins and added Cantonese token versus earlier large variants | Yes, `pt` | Best result on every individual utterance, or phone feasibility [W1, W3] |
| Moonshine Medium/Small Streaming, 245M/123M | True incremental streaming: process speech while it arrives instead of repeatedly running a full Whisper window | No published Portuguese STT checkpoint found in current catalog | General multilingual recognition from one English checkpoint; current streaming graphs working in a legacy Moonshine export adapter [M1–M3] |
| Parakeet TDT 0.6B v3 | 25-language ASR without a language prompt, punctuation/capitalization, word/segment timestamps, non-Whisper transducer architecture | Yes; see actual evaluation below | All Parakeet versions being multilingual, or the upstream Python chunked path being supported by every native export [P1, S1] |

Whisper's usual 30-second inference window is not a maximum recording duration: the transcription pipeline processes longer recordings by windowing. It is also not true cached streaming. Full large-v3 and turbo use 128 Mel bins; compatibility must come from the actual native loader, not changing a display name or treating every model like base's 80-bin input. [W1–W3]

**Translation caveat:** the turbo Hugging Face card includes generic translation examples. OpenAI's implementation README explicitly says turbo is not trained for that task and should not be used for it. Prefer that explicit limitation over inherited template examples. SmartNotes currently needs transcription, so this does not block turbo. [W1, W2]

## Verified GGML payloads

Exact file sizes returned by the whisper.cpp maintainer's model metadata API on the research date. These are single model-file downloads, not ONNX exports, Python checkpoints, archives, total installed application size, or RAM. “Not listed” means absent from the inspected listing, not impossible to quantize. [A1]

| Model | Q5 artifact and bytes | Q8_0 bytes | Unquantized bytes |
| --- | ---: | ---: | ---: |
| base multilingual | Q5_1: 59,707,625 | 81,768,585 | 147,951,465 |
| small.en | Q5_1: 190,098,681 | 264,477,561 | 487,614,201 |
| medium.en | Q5_0: 539,225,533 | 823,382,461 | 1,533,774,781 |
| small multilingual | Q5_1: 190,085,487 | 264,464,607 | 487,601,967 |
| large-v3-turbo | Q5_0: 574,041,195 | 874,188,075 | 1,624,555,275 |
| large-v3 | Q5_0: 1,081,140,203 | Not listed | 3,095,033,483 |

Do not confuse Q5_0 with Q5_1. Quantization reduces weight storage and generally memory, but does not scale activations, decoder state, working buffers and decoded audio by the same ratio. No quantized Android/iOS/macOS peak-RSS measurements were established here, and no minimum total-device-RAM recommendation is supported by this research. OpenAI's A100 VRAM/relative-speed table is not whisper.cpp phone memory or latency. [W1, W5]

## Does whisper_ggml 2.7.1 actually support these choices?

The installed dependency was inspected through Dart package tools, not inferred from upstream whisper.cpp's current README. Public reproduction source is the immutable pub.dev version archive. [F1]

- `lib/src/models/whisper_model.dart` exposes `smallEn`, `mediumEn`, `small`, and `large`; **`large` maps to `large-v3`**, not a generic unspecified large. There is **no turbo enum member**.
- `lib/src/whisper.dart` passes the caller's **explicit `modelPath`** through `TranscribeRequestDto` to native inference. The enum is not the sole mechanism selecting the transcription weights. This makes a custom turbo path plausible without first adding an enum, but **it is not an end-to-end compatibility test**. Validate turbo loading, language detection, and long recordings on every supported platform before exposing it.
- `android/src/whisper/CMakeLists.txt` explicitly vendors **whisper.cpp v1.9.1, CPU backend only**. It does not enable Vulkan or a phone NPU.
- `macos/whisper_ggml.podspec` declares **CPU + Accelerate** and links Accelerate. It does **not** enable Metal/Core ML. Apple's iOS podspec similarly declares CPU/Accelerate. Upstream whisper.cpp GPU/ANE support must not be presented as acceleration already shipped by this plugin.
- `LICENSE` is **MIT**. Native dependencies and FFmpeg packaging still need their own notice/license audit; the plugin's MIT license is not an umbrella license for its entire dependency graph.

**Assessment:** adding a pinned model artifact is lower risk than replacing the runtime, but a model catalog also needs language constraints, compatible loader/backend metadata, explicit download sizes and recovery. A larger model should remain opt-in; retain the previous verified model until its replacement is installed and validated. Measure cold loading because the service currently sets `keepModelLoaded: false`.

## Alternatives: real Portuguese support versus family names

### Moonshine

The current first-party STT catalog lists English Medium/Small/Tiny Streaming (**245M/123M/34M**) and streaming Arabic, German, Japanese, Mandarin, Spanish, Tagalog and Vietnamese; legacy Korean/Ukrainian models remain non-streaming. **Portuguese STT is not listed.** Portuguese TTS, a multilingual marketing statement, or a future roadmap does not establish Portuguese recognition weights. [M1]

The catalog reports English leaderboard-average WER **6.65% for Medium Streaming** and **7.84% for Small Streaming**, but explicitly says these are floating-point reference results; quantized scores are different. They are useful reasons to benchmark, not proof that a specific mobile quantized build beats small.en or turbo on SmartNotes recordings. Do not convert an English leaderboard average into a Brazilian Portuguese score. [M1]

The runtime supports Android, iOS and macOS/native C APIs; the inspected official platform list does not provide a turnkey Flutter binding. It requires another native/Dart adapter or a separately verified runtime export. The current streaming family should not be confused with older non-streaming Tiny/Base Moonshine ONNX models. For SmartNotes' current post-stop batch workflow, streaming is an extra capability, not a requirement. [M2, M3]

**Licenses:** runtime code is MIT except separately licensed third-party code. All English and all streaming STT models are MIT. Enumerated legacy non-streaming non-English models retain the Community License; its actual agreement allows limited commercial use with registration/revenue restrictions, so neither “all non-English models are MIT” nor “every Moonshine model prohibits commercial use” is accurate. [M3]

### Parakeet

Use the complete checkpoint name: **`nvidia/parakeet-tdt-0.6b-v3`** supports Portuguese and English among 25 European languages. Its predecessor **v2 is English-only**; “Parakeet” alone is not a language-support promise. v3 weights are **CC-BY-4.0**, including attribution obligations, not Apache merely because a runtime is Apache. [P1]

There is real Portuguese evidence: NVIDIA reports WER **4.76% FLEURS**, **7.50% MLS**, and **3.96% CoVoST**, with punctuation and capitalization removed. The FLEURS metadata explicitly identifies **`pt_br`**. NVIDIA also warns that training uses European Portuguese while most benchmarks use Brazilian Portuguese. These are the vendor's reference-model evaluations, **not SmartNotes results, not a matched comparison against these Whisper quantizations, and not sherpa int8 accuracy measurements**. [P1]

Deployable native alternatives exist:

- **sherpa-onnx** publishes the v3 int8 export, native Android example/APK and offline recognizer configuration; its own Flutter package covers Android/iOS/macOS. This is a different adapter/runtime, not a new GGML file for whisper_ggml. Its VAD-plus-offline examples do not establish stateful transducer streaming in that export. [S1, S2]
- NVIDIA's official **NeMo-Speech.cpp** supports Parakeet v3, a Q8 GGUF model, native C SDK, and CPU/Metal/Vulkan build options. Its documented desktop tooling is promising for macOS, but no ready supported Flutter Android distribution was established here. Do not reuse its Nemotron streaming benchmark numbers as Parakeet Portuguese/mobile results. Runtime is Apache-2.0 with separate third-party notices; weights remain CC-BY-4.0. [P1, N1]

NVIDIA's “at least 2GB RAM” model-loading statement refers to its reference deployment, not measured int8 ONNX/GGUF mobile peak RSS. Its long-audio claims include an A100 80GB condition. Neither is a phone support specification. [P1]

## Evidence gates before product claims

No source establishes a universal best model for Brazilian Portuguese journals or guarantees excellent English on target phones. Before selecting defaults:

1. Compare the proposed three artifacts with current base Q8_0 on the **same original-speed** recordings and decoding settings. Include medium.en and full large-v3 only as quality challengers where their additional cost can be justified.
2. Evaluate English accents, **Brazilian and European Portuguese separately**, names, dates/numbers, PT/EN code-switching, background noise, silence, soft speech and long pauses. Use manually checked references and consistent WER/CER normalization; record omissions, repetitions and hallucinations too. Whisper's own model card warns about hallucinations and unequal dialect/language performance. [W3]
3. Measure release-build end-to-end transcription time, cold loading, peak RSS, thermal throttling, battery cost, storage and native-library delta on named Android/iOS devices and Macs. Include repeated and long jobs, cancellation/process death and memory pressure. No unsupported “requires 4/6/8 GB RAM” rules.
4. Verify artifact hash/revision, large-v3/turbo loader compatibility, language selection and Apple auto-detection. Check actual compiled backend rather than hardware marketing; GPU availability is not GPU use.
5. Preserve audio and original transcription, keep formatting optional, and never silently send a failed local job to a cloud service. Do not allow an English-only speech model to masquerade as multilingual readiness.

## Primary sources

- **W1:** [OpenAI Whisper README](https://github.com/openai/whisper/blob/main/README.md): model sizes, limited `.en` advantage at small/medium, English A100 speed caveat, turbo translation limitation, MIT code/weights, windowing.
- **W2:** [OpenAI large-v3-turbo model card](https://huggingface.co/openai/whisper-large-v3-turbo/blob/main/README.md): pruning 32 decoder layers to 4, multilingual language inventory, MIT metadata. Generic translation examples conflict with W1's explicit warning.
- **W3:** [OpenAI large-v3 model card](https://huggingface.co/openai/whisper-large-v3/blob/main/README.md): 128 Mel bins, training, Cantonese, language inventory and hallucination/dialect limitations. **License metadata discrepancy:** this card currently says `apache-2.0`, whereas OpenAI's repository explicitly releases Whisper code and weights under MIT. Preserve/audit the exact chosen distribution's license notices rather than silently flattening this inconsistency; no legal interpretation is asserted here.
- **W4:** [OpenAI tokenizer language inventory](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py): `pt` Portuguese, `en` English.
- **W5:** [whisper.cpp README](https://github.com/ggml-org/whisper.cpp/blob/master/README.md): model support, quantization, native platforms/backends, distinction between reference memory and artifact sizes, naive rolling streaming example.
- **A1:** [Maintainer GGML model metadata API](https://huggingface.co/api/models/ggerganov/whisper.cpp/tree/main?limit=100), [file listing](https://huggingface.co/ggerganov/whisper.cpp/tree/main): exact payload bytes inspected above.
- **F1:** [whisper_ggml 2.7.1 immutable archive](https://pub.dev/api/archives/whisper_ggml-2.7.1.tar.gz), [version metadata](https://pub.dev/api/packages/whisper_ggml/versions/2.7.1), [maintainer repository](https://github.com/sk3llo/whisper_ggml). Published 2026-10-02; archive SHA-256 `f7b249fa79846ddcf6ca96e4709beae60769f612fdfa8ad27c55dfe710bc353f`. Installed source paths inspected are specified above; current repository HEAD is not substituted for pinned package evidence.
- **M1:** [Moonshine available STT models](https://moonshine-voice.readthedocs.io/en/latest/models/available-models/): actual languages, parameter counts, reference versus quantized evaluation caveats.
- **M2:** [Moonshine official runtime README](https://github.com/moonshine-ai/moonshine/blob/main/README.md): on-device streaming and native platform list.
- **M3:** [Moonshine actual LICENSE](https://github.com/moonshine-ai/moonshine/blob/main/LICENSE): MIT defaults, exact Community exceptions and agreement terms.
- **P1:** [NVIDIA Parakeet TDT 0.6B v3 card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3/blob/main/README.md): Portuguese, `pt_br` evaluation metadata, WER protocol/results, European/Brazilian caveat, v2/v3 distinction, CC-BY-4.0, deployment limits and native GGUF path.
- **S1:** [Official sherpa Parakeet v3 int8 deployment](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/nemo/parakeet-tdt-0.6b-v3.html): export, model configuration, Android and VAD/offline examples.
- **S2:** [Official sherpa Flutter documentation](https://k2-fsa.github.io/sherpa/onnx/flutter/index.html), [upstream Flutter package](https://pub.dev/packages/sherpa_onnx): native Flutter integration/platforms. Model licenses are separate from the Apache runtime license.
- **N1:** [NVIDIA NeMo-Speech.cpp README](https://github.com/NVIDIA/NeMo-Speech.cpp/blob/main/README.md): supported models, native SDK, desktop installs/build backends, Apache-2.0 and third-party notice boundary.
