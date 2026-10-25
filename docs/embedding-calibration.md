# Embedding catalog validation and calibration

Measured 2026-10-24 on macOS arm64, CPU only, four threads, with the app's
llamadart 0.11.1 / llama.cpp 7fe450e1 runtime. No journal was opened. All input
was the predetermined synthetic bilingual corpus in
`app/integration_test/search_relevance_test.dart`.

## Procedure

- 16 synthetic notes. Training: 19 relevant queries (12 precise) and seven
  absent-topic queries. Holdout: five relevant queries (four precise) and three
  absent-topic queries. Some broad queries deliberately exercise weak matches.
- Encode documents/queries with each profile's exact prefixes. Validate all
  native dimensions, apply supported MRL truncation and re-normalize for cosine.
- Threshold selection uses training only. When max relevant distance is below
  min absent-topic nearest distance, take their midpoint. Otherwise choose
  `min absent-topic nearest distance - 0.005`, prioritizing no absent-topic hits
  on training while explicitly accepting lower recall. Round to four decimals.
- Evaluate the frozen cutoff on holdout. Never adjust it based on holdout.
- These small synthetic samples are regression evidence, not a multilingual
  benchmark or a guarantee of no false positives on real journals.

## Results

| Pinned profile | Max relevant training distance | Min absent training distance | Cutoff |
| --- | ---: | ---: | ---: |
| Qwen3-Embedding 0.6B Q8, 512d | 0.603089 | 0.627758 | 0.6154 |
| EmbeddingGemma 300M Q8, 512d | 0.714128 | 0.614309 | 0.6093 |

| Profile / split | Relevant note retained | Absent-topic queries with hits | Precise top-1 before filtering |
| --- | ---: | ---: | ---: |
| Qwen / training | 19/19 | 0/7 | 12/12 |
| Qwen / holdout | 5/5 | 0/3 | 4/4 |
| Gemma / training | 13/19 | 0/7 | 12/12 |
| Gemma / holdout | 3/5 | 0/3 | 4/4 |

Gemma's held-out precise-note retention is 3/4: its otherwise correctly ranked
cross-language query about saving for a new home is filtered out. Its overlapping
score distributions do not admit a perfect global cutoff on this corpus. Do not
silently relax filtering to hide this limitation. Qwen stays the existing/default
model; Gemma is an explicit smaller-download alternative.

Artifact bytes, revisions and SHA-256 are in `EmbeddingModel`. The measured
Gemma artifact has `gemma-embedding.pooling_type=1` and both dense projection
layers. Queries use `task: search result | query: `, documents use
`title: none | text: `. Qwen keeps its existing representation identity; only
its retrieval cutoff changed from 0.61 to 0.6154.

## Unavailable candidates

- **EmbeddingGemma 2 Q8:** pinned ggml-org artifact
  `58faf90940886df2d62be555c8765d00dac362c5`, SHA-256
  `2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135`.
  Its architecture is `gemma-embedding2`, not `gemma4` or `gemma-embedding`.
  Loading fails with the fixed native runtime. No cutoff is invented. Validate
  a deliberate native-runtime upgrade separately before enabling it.
- **multilingual-e5-small:** the catalog's cstr Q8 conversion at
  `178420da727e544c2689e89b6648b205ad176eda` fails to load. Alternative public
  conversions were probed separately, not substituted silently:
  keisuke-miyako Q8 at `e1da94460f223e3204e75dfe51350e5491c879d4` and
  rodion-m FP32 at `a4ad957ad6070d20a0474222ca158bfd18bdc196` each retain only
  2/12 precise training queries at top-1; rodion retains 0/4 precise holdout
  queries at top-1. A milimyname conversion at
  `1695e17549efbfddbe77a6374d151dd57b0ccaad` aborts in native tensor addition.
  These are conversion/runtime validation failures, not an assessment of the
  original E5 model. A reference-validated tokenizer/conversion is required.
  Its 384-dimensional profile is implemented and covered by synthetic database
  transition tests, but installation and activation stay disabled.

The UI displays these candidates as unavailable; their cutoffs are null and
their download/activation paths are rejected at the service boundary too.

## Responsiveness and native packaging

The production Gemma session was tested with a live Flutter button while loading
and running eight CPU embeddings. The button responded before inference finished;
170 UI-isolate heartbeats ran during 2,743 ms of work; the maximum heartbeat gap
was 42 ms. This is a macOS debug smoke test, not an Android/iOS frame benchmark.

The E5 probe exposed an Apple dyld collision: llama.cpp was executing Whisper's
different GGML CPU implementation. The Podfiles now hide Whisper's GGML/GGUF and
quantization implementation exports while preserving `whisper_*`. No native
dependency version was upgraded. Revalidate speech as well as embeddings when
changing this linker configuration.

Final checks: 653 unit/widget tests passed; static analysis is clean; Android
debug APK and iOS simulator builds succeeded. Native macOS checks passed for the
catalog/calibration, live UI responsiveness, Qwen retrieval through the database,
and Whisper transcription of the public JFK sample with automatic and explicit
English language. Physical Android/iOS runtime acceptance remains outstanding.

## Reproduction

Download exactly the public pinned artifacts to a separate model directory.
Never point these tests at the user's journal database. Stop any running native
debug app before rebuilding frameworks.

```sh
cd app
flutter test integration_test/embedding_catalog_test.dart -d macos \
  --dart-define=EMBEDDING_MODELS_DIRECTORY=/absolute/path/public-models \
  --dart-define=QWEN_EMBEDDING_MODEL_PATH=/absolute/path/Qwen3-Embedding-0.6B-Q8_0.gguf \
  --dart-define=EMBEDDING_CALIBRATION_REPORT=/absolute/path/report.json
```

The JSON records metadata, full pairwise distances, frozen split labels and
training-only suggested cutoffs. Unsupported probes are recorded as failures,
not successful inference. For risky alternative-conversion investigation, use
`EMBEDDING_CANDIDATE=e5-fp32.gguf` in a disposable test process; never expose
unvalidated conversions through the production catalog.
