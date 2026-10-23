# Local multilingual embeddings for SmartNotes

Research date: **2026-10-18**. Scope: private, on-device retrieval of Portuguese (PT-BR/PT-PT) and English voice-journal entries, including cross-language queries, on mid-range Android arm64, iOS 16.4+ and macOS 14+. **Research only, not an ADR or implementation decision.** No Git commands, dependency modifications, model downloads, builds or benchmarks were performed. Only documentation, source code and artifact metadata were fetched.

**Verified** means observed in the cited primary source or current project source. **Assessment/recommendation** is provisional, not measured SmartNotes performance. Decimal MB/GB below describe artifact bytes, **not RAM**. Live documentation can change; selected repository revisions and content hashes are recorded below.

## Executive recommendation

1. **Balanced low-download default to evaluate: `intfloat/multilingual-e5-small`, int8, 384 dimensions.** It is retrieval-trained, multilingual including Portuguese/English, MIT-licensed, and needs only a 512-token window. An existing author-repository ONNX int8 file is **118.35 MB**, or **135.43 MB including the JSON tokenizer/config manifest below**. However, that export is named `avx512_vnni`, not arm64: **a verified ARM-compatible export/runtime/tokenizer integration remains an adoption gate**, not something established by its size. Prefer a reproducible arm64-targeted export and benchmark it; do not silently ship the x86-targeted artifact as phone-validated. [E1, E2, A1, R3]
2. **Current 2026 challenger: text-only EmbeddingGemma 2 Q8_0, initially evaluate 768d and 512d.** This model genuinely exists: Google publishes a 270M text component inside a 740M multimodal model, Apache-2.0, ungated; llama.cpp maintainers publish a **309.86 MB text GGUF**, with tokenizer embedded and no multimodal projector needed for text. This is more attractive than legacy EmbeddingGemma's licensing gate and smaller than Qwen3-Embedding Q8. **But SmartNotes' pinned native llama.cpp revision does not register its `gemma-embedding2` architecture.** It requires a separately audited runtime upgrade or a validated ONNX route; current upstream support is not support in the installed binary. Its superiority on Portuguese diary retrieval remains unmeasured. [G3, A5, R1, R2]
3. **If staying on the existing runtime is decisive, Qwen3-Embedding-0.6B Q8_0 is the more established quality-tier experiment:** official **639.15 MB** single GGUF, Apache-2.0, 1024d with Matryoshka reduction to 512d supported, official llama.cpp instructions using **last-token pooling**. Its larger download/load cost makes it a challenger, not the phone default. Legacy EmbeddingGemma-300M Q8_0 (**333.59 MB**) is another existing-runtime candidate only after reviewing Gemma terms/distribution and its complete projection/pooling conversion. [Q1, Q2, G1, G2, A4, A6]
4. **Do not choose paraphrase-multilingual-MiniLM merely because it is called MiniLM.** Its complete int8 manifest is **127.50 MB**, only modestly below E5-small's inspected manifest, but its SentenceTransformer limit is **128 tokens**, and its similarity/paraphrase objective is less directly matched to short-query → diaristic-passage retrieval. Keep it as a cheap control. E5-base (~295.77 MB inspected int8 manifest) and BGE-M3 (~2.285 GB inspected full ONNX manifest) are controls, not automatic upgrades. [M1, E2, B1, A1–A3, A7]
5. **No free embedding reuse from Qwen3-1.7B formatting.** Calling a hidden-state/embedding API on the existing generative formatter is not evidence of a contrastively trained, multilingual retrieval space. Qwen3-Embedding is a distinct trained checkpoint. Do not replace the missing local retrieval model with generated JSON arrays or unvalidated formatter activations. [Q1; project sources below]

**Decision rule:** choose the smallest *complete deployable pipeline* meeting retrieval, cold-query latency and peak-memory targets on named phones. Start with **E5-small int8 versus EmbeddingGemma 2 text Q8**; use **Qwen3-Embedding Q8** as the established-runtime quality control. This is an experiment order, not a proved ranking. If accepting no new runtime or native revision is a hard constraint, none of the smallest routes is turnkey; do not hide that integration tradeoff.

## 1. Historical project boundaries investigated by this report

Earlier STT and formatting constraints are recorded in ADR-021 and ADR-022, not
as current embedding support. The OpenAI embedding baseline in the remainder of
this section is historical: [PRODUCT.md](../../PRODUCT.md),
[CONTEXT.md](../../CONTEXT.md), [architecture.md](../architecture.md), and
[native-dependencies.md](../native-dependencies.md) document the current local
Qwen embedding pipeline and offline semantic search.

Historical seams inspected during the research:

- [`IEmbeddingService`](../../app/lib/domain/services/i_embedding_service.dart) exposes only `embed(String text)`. The former `OpenAiEmbeddingService` requested `text-embedding-3-small` with **512 output dimensions**.
- [`LocalEntrySearchService`](../../app/lib/data/services/local_entry_search_service.dart) calls that same method for queries and documents, checks the API key even for cached queries, retains up to **20 query vectors**, and rejects queries exceeding 4,000 Dart string code units. Indexing splits `source.runes` into **1,600 Unicode-rune chunks with 1,400-rune steps**, not tokens. `rebuild()` waits for indexing, clears index tables, then indexes again; it does not clear the query-vector cache.
- [`LocalDatabase`](../../app/lib/data/datasources/local/local_database.dart) hard-codes model/dimension, uses SQLite-vec cosine `vec0`, Float32 vector blobs, source-hash stale-response checks, transactional index writes, and a separate indexed-entry model/dimension record. Pending selection joins by entry ID/source hash, not a complete embedding pipeline identity. It retrieves 100 nearest chunks, groups by entry with minimum distance, and returns up to 20 entries. Notes/FTS/audio are independent of derived vectors.

**Historical assessment:** keep database/storage and domain/data boundaries, not
provider-specific constants inside the search contract. The current local
pipeline implements the relevant local readiness, query/document separation,
token-aware chunking, and pipeline identity decisions; the discussion below
preserves the evidence and alternatives considered at research time.

## 2. Candidate comparison and exact embedding semantics

These are **one-vector dense retrieval** candidates. “Multilingual” is not proof of equal PT-BR/PT-PT performance or reliable cross-language retrieval. Cards/evaluations support the shortlist, not a phone/journal winner. [E1–E2, M1, G1, G3, Q1, B1]

| Candidate | Window / dimensions | Required text representation | License / assessment |
| --- | --- | --- | --- |
| **multilingual-e5-small** | **512 tokens**, **384d** | Bidirectional encoder; attention-mask-aware **mean pooling**, L2 normalize. Prefix **`query: `** for queries and **`passage: `** for corpus chunks, including Portuguese text. | MIT weights. Explicit PT/EN metadata; retrieval-focused default experiment. No verified MRL support: do not pad/truncate to 512d. [E1] |
| **multilingual-e5-base** | **512 tokens**, **768d** | Same E5 prefixes, masked mean, L2 normalization; bidirectional XLM-R encoder. | MIT weights. Larger control; not a 384d/512d drop-in and no verified MRL. [E2] |
| **paraphrase-multilingual-MiniLM-L12-v2** | SentenceTransformer **128 tokens**, **384d** | Bidirectional encoder; masked mean pooling. No E5 prefixes in author instructions. Normalize consistently for this cosine pipeline. | Apache-2.0; PT and PT-BR explicitly in metadata. Symmetric/paraphrase control, not assumed best asymmetric retriever. The card's stray “max pooling” comment contradicts its function/config; the actual configured operation is **mean**. No established MRL. [M1] |
| **EmbeddingGemma-300m (v1)** | **2,048 tokens**, **768d**; MRL **512/256/128** | **Non-causal** attention, mean pooling and the complete learned Dense projection stack; query **`task: search result \| query: {query}`**, document **`title: {title or none} \| text: {content}`**. L2 normalize; truncate MRL output then re-normalize. | **Gemma terms**, author access gated. ggml-org Q8 exists. Do not confuse core hidden states without Dense modules with the published embedding pipeline. [G1, G2, R2] |
| **EmbeddingGemma 2** | Author retrieval limit **8,192 tokens**, **768d**, MRL **512/256/128** | **Non-causal**, mean pooling and **512→768 learned projection**; same retrieval query/document prompt forms above. L2 normalize, including after MRL slicing. Text-only mode omits vision/audio encoders. | **Apache-2.0, ungated** author metadata. Current-upstream `gemma-embedding2` exists; absent from inspected pinned native revision. Promising 2026 challenger, not legacy Gemma with a renamed file. [G3, A5, R2] |
| **Qwen3-Embedding-0.6B** | **32K tokens**, **1024d**, MRL **32–1024d** | **Causal** decoder; last **non-padding** token pooling, L2 normalization. Query **`Instruct: {task description}\nQuery:{query}`**; corpus text receives **no instruction**. Choose/pin an English journal-retrieval instruction, not a chat template. | Apache-2.0. Dedicated embedding training; official GGUF/llama.cpp path. Larger established-runtime control. [Q1, Q2] |
| **BGE-M3** | **8,192 tokens**, **1024d** | Bidirectional encoder; dense representation uses **CLS**, normalized. **No query instruction required**. Sparse and ColBERT outputs are different retrieval representations, not extra features automatically enabled by SQLite cosine. | MIT. 100+ languages and cross-lingual evaluation; large control. No verified MRL for arbitrary dense truncation. [B1, B2] |

All windows include applicable special tokens and prefixes; do not equate them to characters. Query/document encoding must use **the same checkpoint, quantization policy, tokenizer, compatible prompt scheme, pooling/projection and final dimension**. Normalize only finite, nonzero vectors; reject NaNs/zero output rather than storing them. [E1, Q1, G3; project vector validation]

### Newer/smaller alternatives: existence checked, not assumed

- **EmbeddingGemma 2 is the most relevant newly verified option.** Google's current card (updated 2026-10-06) and actual author/ggml-org repositories establish existence, not merely a roadmap. Its full multimodal checkpoint is **1,488,915,288 bytes** before tokenizer; that is not the text-only download. The text GGUF's **309,855,456 bytes** excludes an optional Q8 multimodal projector of **554,821,024 bytes**, which journal-text retrieval does not need. Google's text multilingual MTEB v2 scores are **61.36** versus v1 **61.15** at 768d; these small aggregate differences are not evidence of better PT diary retrieval. [G3, A5]
- **Jina embeddings v5 text nano (239M), released 2026-02-18, exists**, with an author-published retrieval-specific merged-adapter ONNX pipeline, 768d/MRL and last-token pooling. The inspected q4 graph + external weights + JSON tokenizer/config manifest is **155,165,750 bytes**. Retrieval uses **`Query: ` / `Document: `**, not E5 prefixes. But weights are **CC-BY-NC-4.0**, commercial use requires contacting the author; its card also points to a special llama.cpp branch. Thus it is a research control only until licensing/native compatibility are resolved. The generic card says “32K” in prose but its feature table and retrieval-specific card say **8,192**; pin the latter conservative limit pending verification. No phone result follows from the headline MTEB score. [J1, J2, A8]
- **Nomic Embed v2 MoE exists**, but **305M active** does not mean 305M total weights: the author states **475M total**, 512 tokens and 768→256 MRL. This is not an obviously smaller-download default than dense E5-small. [N1]
- **MrBERT (2026) exists**, with 150M–300M multilingual encoder research and MRL adaptations. A foundational masked-language encoder is not automatically a ready asymmetric journal retriever; this investigation did not establish a smaller, complete, pinned phone deployment that should displace the shortlist. [X1]
- Do not substitute English-only **e5-small-v2**, all-MiniLM-L6-v2 or bge-small-en on the basis of a smaller file. The verified ggml-org `e5-small-v2` repository is explicitly English, not multilingual-e5-small. [X2]

## 3. Artifact sizes, full manifests and provenance

### Reproducible byte accounting

For the E5/MiniLM ONNX rows, **manifest total** = selected graph + root `tokenizer.json`, `tokenizer_config.json`, `special_tokens_map.json`, `config.json`, `1_Pooling/config.json`, `sentence_bert_config.json`. This is a reproducibility manifest for a JSON-tokenizer implementation, **not proof a Dart/native tokenizer exists or that pooling is inside the graph**. Native runtime libraries, notices, app assets and download staging space are additional. Tokenizer-only/config numbers are sums from the same tree API. [A1–A3]

| Repository / selected artifact | Model/graph bytes | Tokenizer + listed configuration bytes | Total manifest bytes |
| --- | ---: | ---: | ---: |
| `intfloat/multilingual-e5-small`, `onnx/model_qint8_avx512_vnni.onnx` | 118,346,824 | 17,084,252 | **135,431,076** |
| Same model, reference `onnx/model.onnx` | 470,268,510 | 17,084,252 | **487,352,762** |
| `intfloat/multilingual-e5-base`, `onnx/model_qint8_avx512_vnni.onnx` | 278,686,411 | 17,084,309 | **295,770,720** |
| `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2`, `onnx/model_qint8_arm64.onnx` | 118,412,398 | 9,083,171 | **127,495,569** |
| `ggml-org/embeddinggemma-300M-GGUF`, `embeddinggemma-300M-Q8_0.gguf` | 333,590,944 | Embedded tokenizer; no separate tokenizer download | **333,590,944** |
| `ggml-org/embeddinggemma-2-GGUF`, `embeddinggemma-2-Q8_0.gguf` | 309,855,456 | Embedded tokenizer; text only, no projector | **309,855,456** |
| Same text model, `embeddinggemma-2-BF16.gguf` | 557,950,176 | Embedded | **557,950,176** |
| `Qwen/Qwen3-Embedding-0.6B-GGUF`, `Qwen3-Embedding-0.6B-Q8_0.gguf` | 639,150,592 | Embedded tokenizer | **639,150,592** |
| Same model, `Qwen3-Embedding-0.6B-f16.gguf` | 1,197,629,632 | Embedded | **1,197,629,632** |
| `BAAI/bge-m3`, full ONNX manifest described below | 2,267,611,083 | 17,100,448 | **2,284,711,531** |
| `jinaai/jina-embeddings-v5-text-nano-retrieval`, q4 ONNX manifest below | 137,953,355 | 17,212,395 | **155,165,750** |

BGE graph total includes `onnx/model.onnx` **724,923**, **`model.onnx_data` 2,266,820,608**, and `Constant_7_attr__value` **65,552**. A tiny graph file is not the whole model. Jina q4 graph is **129,099** plus **137,824,256** external bytes; remaining files are tokenizer.json, tokenizer_config.json, config.json and 1_Pooling/config.json. These are artifact-owner metadata observations, not a local graph execution audit. [A7, A8]

E5/MiniLM also publish **`sentencepiece.bpe.model` 5,069,051 bytes**. If a native SentencePiece implementation reproduces the model's exact normalization/special-token/post-processing behavior, it can use that instead of JSON tokenizer data; if both are needed, add it to the totals. Simply loading SentencePiece without XLM-R/BERT wrapping does not establish tokenizer equivalence. The tokenizer choice must be fixed before publishing a final manifest. [A1–A3, E1, M1]

**Important E5 gap:** the inspected author repository has no `model_qint8_arm64.onnx`; only its `avx512_vnni` int8 export was established. That filename is not proof the graph must fail on ARM, but neither does ONNX portability prove all fused kernels, quantization configuration and chosen mobile execution provider work. Upstream SentenceTransformers supports an **`arm64`** dynamic quantization configuration: export from the pinned source, inspect operators/opset and revalidate. **135.43 MB is an observed existing manifest, not a promised size/hash of a future arm64 export.** [A1, R3, R4]

For comparison, the ONNX-community v1 EmbeddingGemma q4 export has **519,322-byte graph + 196,725,760-byte external data**, before its ~20.32 MB JSON tokenizer and configs. This can reduce storage relative to v1 GGUF Q8 but brings another runtime/tokenizer and operator-compatibility problem; it is not a demonstrated low-RAM or equivalent-quality shortcut. [A9]

### Revisions and selected SHA-256 hashes

Revisions come from `https://huggingface.co/api/models/{repository}`; sizes and LFS SHA-256 content IDs from `/api/models/{repository}/tree/main?recursive=true&limit=100`. Use **revision-resolved download URLs**, not `main`, when implementing a manifest. Hashes below were read from metadata, **not verified against downloaded files**. Masked gated metadata is not a usable hash. [A1–A9]

| Repository | Observed revision |
| --- | --- |
| `intfloat/multilingual-e5-small` | `614241f622f53c4eeff9890bdc4f31cfecc418b3` |
| `intfloat/multilingual-e5-base` | `d128750597153bb5987e10b1c3493a34e5a4502a` |
| `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` | `e8f8c211226b894fcb81acc59f3b34ba3efd5f42` |
| `google/embeddinggemma-300m` | `57c266a740f537b4dc058e1b0cda161fd15afa75` |
| `ggml-org/embeddinggemma-300M-GGUF` | `0f741b5a6585bd53aeb15cd1372c56f2a0f65e12` |
| `google/embeddinggemma-2` | `914f7f89142e33e77833254d9c9b90c3cef7303b` |
| `ggml-org/embeddinggemma-2-GGUF` | `bfcd298762cc34d0357ece5ebdd31791a3a374d8` |
| `Qwen/Qwen3-Embedding-0.6B-GGUF` | `370f27d7550e0def9b39c1f16d3fbaa13aa67728` |
| `BAAI/bge-m3` | `5617a9f61b028005a4858fdac845db406aefb181` |
| `jinaai/jina-embeddings-v5-text-nano-retrieval` | `ac5d898c8d382b17167c33e5c8af644a3519b47d` |

Selected model file SHA-256:

- E5-small inspected int8: `dd476dd0c2514e9b9be83aeb3853fac0763e0bdf4a71645407587d77c48a2d88`.
- E5-base inspected int8: `2523551878658b305550d8759443822dbfda9ed9c8012ef2c354ba2c5b9de503`.
- MiniLM arm64 int8: `783fea82d71a58179b830a4dbd2d58447e640609e98eedf9ffa12622d375a672`.
- EmbeddingGemma v1 ggml-org Q8: `b5ce9d77a3fc4b3b39ccb5643c36777911cc4eb46a66962eadfa3f5f60490d63`.
- EmbeddingGemma 2 text ggml-org Q8: `2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135`.
- Qwen3-Embedding official Q8: `06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439`.
- E5-small JSON tokenizer: `0b44a9d7b51c3c62626640cda0e2c2f70fdacdc25bbbd68038369d14ebdf4c39`.

`intfloat`, `Qwen`, `Google`, `BAAI`, SentenceTransformers and Jina are model/artifact authors; **ggml-org is the runtime/conversion maintainer, not Google**. ONNX-community is an export maintainer, not automatic Google endorsement. Conversion provenance does not validate native execution, quantized quality, or licensing compliance.

## 4. Flutter/runtime completeness: reuse versus another runtime

### Existing llamadart route

Installed dependencies were investigated with **Dart `read_package_uris` and `rip_grep_packages`**, not inferred from a generic package description. The cached **llamadart 0.11.1** source exposes **`LlamaEngine.embed(text, normalize: true)`**, `embedBatch`, and `supportsEmbeddings`. Native implementation runs via its worker, distinguishes encoder-only `llama_encode` from decoder `llama_decode`, reads sequence/token embeddings according to the context's pooling type, resolves output dimension, and L2-normalizes by default. This is a real embedding API, not generation disguised as embedding. [R1]

Verified integration boundaries in that source:

- It relies on the **GGUF/native context pooling metadata**; the ordinary `ModelParams` API inspected does not expose an explicit general pooling override. Verify converted metadata produces **mean for E5/Gemma, last for Qwen, CLS for BGE**. A fallback that returns the last hidden state is not correct for a mean-trained encoder.
- Inputs exceeding context fail rather than silently truncate. Encoder-only models, no-KV models, **MEAN/CLS pooling**, or non-causal models must fit a **single physical micro-batch (`n_ubatch`)**. Set logical `batchSize` and `microBatchSize` to accommodate the actual complete tokenized input; do not split a bidirectional sentence into causal prefill batches and average their outputs. Batch independent sequences only with correct sequence IDs/masks.
- Native inference is not proof of semantic equivalence. Compare token IDs, special tokens, pooling/projections and output vectors to the author reference. Confirm prefixes are supplied once, not injected twice by a framework template. Use raw embedding text, not formatter `ChatSession` prompts.
- Source comments identify the pinned native base as llama.cpp **`7fe450e1`**. Its architecture registry includes `bert`, `qwen3`, `gemma-embedding`, but **not `gemma-embedding2`**; requesting the latter's GGUF is not enough. Current upstream adds that architecture and non-causal graph. Check the exact Android and Apple companion binary revisions/symbols before choosing an upgrade; this report did not change or run them. [R1, R2]

**Assessment:** prefer reuse when a **complete, tested conversion** exists: it avoids an additional native runtime and can share worker/lifetime patterns. Qwen official GGUF is the clearest established author deployment recipe; v1 EmbeddingGemma also has runtime-maintainer instructions. E5-small GGUF conversion is possible in principle with a compatible BERT exporter, but **no author-published multilingual E5-small GGUF was established here**, so conversion/tokenizer equivalence and resulting size are not verified facts. Do not substitute the English e5-small-v2 export. [Q2, G2, X2]

### ONNX Runtime route

Microsoft ONNX Runtime is **MIT**, supports native Android/iOS deployment and desktop C APIs, and gives explicit export/operator/quantization requirements. It executes tensor graphs; it does **not** turn a `tokenizer.json` and model file into the full SentenceTransformer retrieval pipeline automatically. Tokenizer, preprocessing, attention mask, pooling, projection, dimension selection and normalization still need an app-owned adapter unless explicitly included and verified in the graph. [R3–R5]

- Maintainer metadata lists community Flutter packages **`onnxruntime` 1.4.1** (FFI) and **`flutter_onnxruntime` 1.9.0** (native wrapper); neither is a first-party Microsoft Dart SDK. Both list Android/iOS/macOS. The latter maintainer's current README lists mobile/Apple ORT **1.28.0**, iOS **16+**, macOS **14+**, CPU support, CocoaPods/SPM, and an Android 16-KB compatibility note. These are compatible *stated platform floors*, not a successful SmartNotes build or pinned-release audit. [R6]
- Prefer CPU as the portable first experiment. NNAPI/CoreML availability does not prove full transformer/int8 operator coverage or faster execution; partial graph fallback/copies can erase expected gains. Check exact opset, contrib operators and external-data loading. Quantized Gather/MatMul formats can require specific ORT versions; not every `.onnx` loads on every prebuilt Flutter runtime. [R3, R4]
- A complete E5 adapter needs native HF-tokenizers-equivalent JSON handling **or** SentencePiece plus correct wrapper logic. Whitespace tokenization, approximate Dart BPE, character counts and copying the Qwen formatter tokenizer are not equivalent. Test accents, composed/decomposed Unicode, emojis, PT contractions/names, newline/Markdown and special-token injection against reference token IDs.
- Run tokenization, graph execution and any large tensor pooling off the UI path. Await native session/tensor destruction before releasing the shared inference lease; a Future-returning platform method alone does not prove execution is off the platform's main thread. Bound batches and avoid retaining full token-hidden-state outputs in the UI isolate.

**Assessment:** ONNX is the practical small-encoder route if the added binary/tokenizer maintenance is acceptable; **E5 int8 is not a one-line dependency swap**. Measure the complete app/native-library delta against the extra ~174 MB between the inspected E5 manifest and text Gemma 2 GGUF, not only weight-file sizes.

### Licensing and gating are separate from runtime support

E5/BGE weights: **MIT**. MiniLM, Qwen3-Embedding and **EmbeddingGemma 2** weights: **Apache-2.0**. Legacy **EmbeddingGemma-300m**: **Gemma terms**, not Apache because sample code or llama.cpp is permissive. Its author API reports **manual gating**, and unauthenticated README retrieval returned **401**; ggml-org's ungated conversion does not erase the source weight obligations. Resolve access/redistribution, notices and permitted download hosting before promising frictionless setup. The actual terms, not a model-family nickname, govern. Jina nano is **CC-BY-NC-4.0**, not an unrestricted default. [A4, A5, G1, G3, J1]

llama.cpp/llamadart and ORT licenses do not cover all wrappers, tokenizers, converters or transitive native libraries. Audit the exact pinned set, Android arm64/16-KB packaging, iOS frameworks/simulator slices, signing and macOS sandbox access. No legal opinion or complete third-party notice audit is supplied here.

## 5. Chunking, memory and scheduling

**Assessment:** replace rune-count chunking with tokenizer-aware, sentence/paragraph-conscious chunks. Reserve budget for special tokens and model-specific prefixes/title. E5's **512** and MiniLM's **128** are hard pipeline constraints, not an invitation to pass the current 1,600-rune chunks and silently lose the tail. Include overlap in tokens and version the policy. Index all content through multiple chunks, not only the first window; constrain oversized queries explicitly without silent semantic truncation. [E1, E2, M1]

The formatter report's **2K–4K total generation budget is not an encoder requirement**. Embeddings have no generated Markdown/JSON output budget. Allocate only what selected retrieval chunks need; do not impose 4K on E5 or eagerly allocate 8K/32K because Gemma/Qwen advertise it. A longer encoder window also does not guarantee a better single vector for a multi-topic diary entry.

Weight download size does not determine peak app RAM. Include tokenizer structures, resident/mapped weights, input tensors, attention/activation/scratch buffers, output tensors, native thread stacks, backend allocations and Flutter heap. Quantized weight bytes do not imply all activations/compute are int8. Bidirectional attention/micro-batch constraints can raise memory with longer inputs. mmap is not free residency, and loading through a Dart byte buffer can add a transient copy. **No phone minimum RAM, milliseconds/query or peak RSS is established by this report.** [R1, R3, R4]

Reuse [`LocalInferenceQueue`](../../app/lib/data/services/local_inference_queue.dart): **one native inference job at a time**, off the UI, including embeddings even if using ORT. Unload Whisper/Qwen before loading the embedding model and await its disposal before another engine takes over. Do not keep all three resident. For indexing, bounded micro-batches can amortize cold loading, but release/yield between bounded jobs so a backlog cannot monopolize inference. [Project architecture; assessment]

**Recommend priority:** foreground capture/transcription/formatting and **user-submitted semantic queries ahead of backlog indexing**, with explicit bounded scheduling/fairness. A FIFO queue alone does not establish priority or preemption. Cancel queued/stale searches when superseded, reject old results by query/pipeline generation, and let note edits/deletions cancel obsolete indexing. Native cancellation may not interrupt an individual forward pass: bound work so cancellation can take effect at safe boundaries. Test query latency while indexing, not just an idle microbenchmark.

## 6. Safe index migration: rebuild even if dimensions stay 512

**Assessment:** model replacement is a **new vector space**. A 512d Gemma/Qwen vector cannot search 512d OpenAI vectors. Nor should model quantization or prompt/pooling changes be assumed interchangeable without explicit validation. Do not zero-pad E5's 384d to preserve today's schema. MRL shortens output/storage/search work, **not proportionally encoder weight download or inference cost**. [G3, Q1; project schema]

Recommended future migration contract:

1. Define an embedding identity containing model/repository revision and **weight hash**, tokenizer hash/version, runtime/export revision, quantization, attention/pooling/projection policy, **query and document prompt versions**, normalization, output dimension, and source/chunking policy version. Record it for each index generation, not just a friendly model string.
2. Stop accepting old-generation writes, cancel or fence in-flight indexing/search, and clear/version **all query caches**. Cache key includes pipeline identity, role and normalized input policy; current `_queries` keyed only by text is insufficient. Failed-index markers also need generation identity/reset so old failures do not suppress new work.
3. Create a fresh dimension-appropriate vec0 table/index generation and re-embed **all eligible entries**, even when staying at 512d. Carry source hashes into jobs and recheck current source hash, existence **and generation** when publishing. If title is supplied separately in a Gemma document prompt, include it in the indexed-source identity too.
4. Make schema/metadata activation transactional and crash-safe. Prefer build-then-atomically-switch with extra temporary disk budget; alternatively invalidate/drop the old derived index atomically and expose an explicit rebuilding state with FTS fallback. Never expose mixed old/new vectors or silently present partial results as a complete journal search. Keep one active query/index identity at a time.
5. Retain stale-hash protections for edits/import/delete and stop late results resurrecting deleted entries. Persist/resume indexing progress after interruption; expose failed counts/retry. Test cancellation, model replacement mid-index, process death, low storage and repeated rebuilds. Clean staging generations only after safe activation/rollback.
6. Preserve **journal entries, original recordings, original transcriptions, formatted notes, FTS and backups**. Only disposable vectors/chunks/index metadata/cache are rebuilt. Model files and derived index remain excluded from journal backups. A failed migration must not convert successful notes to processing errors or upload anything as fallback.

Implement readiness/download as the existing model workflow: explicit size/storage explanation, progress/cancel, **resumable partial download, pinned revision and SHA-256 for every file, atomic manifest publication only after all artifacts validate**, missing/corrupt recovery, sufficient staging space and an import/bundle option if needed. Do not reuse the formatter's readiness flag for a new embedding artifact. For legacy gated Gemma, onboarding/access-token/redistribution design must be resolved first. Installation may need network; subsequent embedding/search/indexing must pass airplane-mode tests without an API key.

## 7. Validation plan and remaining uncertainty

**Measured in SmartNotes here: nothing.** Verified artifact bytes, source APIs, windows and licensing are not device performance or retrieval quality measurements. Vendor MTEB multilingual aggregates, English task scores, MIRACL, translation similarity and journal Recall@k are **not interchangeable benchmarks**; do not rank unrelated published tables or claim equivalence to OpenAI text-embedding-3-small 512d. Quantization quality must be tested independently from dimension reduction. [E1, G1, G3, Q1, R4]

Recommended adoption gates:

1. **Reference correctness before quality:** compare author-reference token IDs/masks, prefixes/special tokens, projection/pooling, dimension and normalized vectors on fixed examples. Compare full-precision versus quantized on the **same corpus**. Test single versus batched output consistency, unequal lengths/padding and one-pass limits. For Gemma 2, follow the author's numerical warning: **BF16/FP32, not generic FP16 activations**, whose range can yield NaNs or silently degraded vectors; an available fp16 export is not evidence that it is correct. Inspect the actual quantized runtime compute path. [G3, R1]
2. **Representative retrieval corpus:** manually labeled PT-BR, PT-PT, EN, PT→EN and EN→PT query/entry pairs; short vague queries versus long diaristic entries; realistic Whisper noise/misspellings; names/places/dates/numbers, accents, code switching, negation (“quero mudar” versus “não quero mudar”), corrections, paraphrases, same-topic hard negatives and no-relevant-entry queries. No private evaluation text leaves the device without explicit consent.
3. **Comparable metrics:** same source corpus, relevance labels, Unicode/text normalization policy, entry-level deduplication and scoring. Report **Recall@5/10, MRR@10, nDCG@10**, per-language/cross-language slices and false positives/abstention. Use native full dimensions first, then separately compare MRL 512/256 and int8/Q8/q4; do not change chunking and quantization simultaneously and attribute the difference solely to the model. The former OpenAI comparison is historical and is not a current product path.
4. **Device protocol:** named mid-range Android arm64, lower-memory supported iPhone and Apple Silicon Mac; Intel Mac separately if retained. Record SoC/OS, runtime native commit/build flags, backend, threads, artifact hashes, input-token distribution and batch/context settings. Measure **cold load, cold/warm query embedding, end-to-end query p50/p95, index chunks/sec and full reindex duration**, peak whole-app memory, post-dispose release, download/installed/native-binary delta, battery/heat, and contention while STT/formatter/backlog jobs are queued.
5. **Product safety:** airplane mode/no key, missing/corrupt tokenizer or external data, partial downloads, stale edits/delete/import during indexing, canceled searches, failure retry, background/process death, low disk/memory, old-model caches, migration rollback and model removal. Search failure must leave text search and saved entries available. No implicit online fallback.

**Unresolved deployment gaps:** E5-small ARM int8 artifact and full tokenizer/ORT packaging; GGUF conversion equivalence if avoiding ORT; Gemma 2 native upgrade and all-platform packaging; v1 Gemma gate/redistribution and complete projection conversion; phone cold-load/memory/thermal costs; PT-BR versus PT-PT and cross-language quality; acceptable quantization/MRL regression thresholds. These are the conditions for a shipping choice, not implementation details that can be assumed away.

## Primary sources

### Implementation follow-up

The research above records the pre-implementation comparison. SmartNotes now
uses the selected official Qwen3-Embedding-0.6B Q8_0 GGUF via the existing
llamadart runtime, with last pooling, 512-dimensional MRL + L2 normalization,
role-specific query instructions and token-aware chunks. The artifact's size
and SHA-256 were verified locally by the model service. On macOS, four public
author-reference tokenizer sequences match exactly; Q8 full/MRL vectors exceed
0.99 cosine versus FP32 last-token reference outputs, and batch/single native
vectors exceed 0.9999 cosine. The PT/EN retrieval smoke passes offline.
See [native dependency notices](../native-dependencies.md) for exact reference
versions and the opt-in reproducible test. These are correctness/smoke checks,
not the representative retrieval or physical-phone memory/latency evaluation
recommended above. Cloud embedding adapters and API-key UI have been removed;
only deletion-only legacy credential cleanup remains.

### Authors and embedding pipeline semantics

- **E1:** [Multilingual E5-small author card: prefixes, mean pooling, normalization, languages, 512-token truncation](https://huggingface.co/intfloat/multilingual-e5-small), [author technical report](https://arxiv.org/html/2402.05672).
- **E2:** [Multilingual E5-base author card](https://huggingface.co/intfloat/multilingual-e5-base), [768d mean-pooling configuration](https://huggingface.co/intfloat/multilingual-e5-base/blob/main/1_Pooling/config.json).
- **M1:** [SentenceTransformers multilingual MiniLM author card and full 128-token architecture](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2).
- **G1:** [Google EmbeddingGemma v1 card: terms, window, MRL and exact retrieval prompts](https://ai.google.dev/gemma/docs/embeddinggemma/model_card), [actual Gemma terms](https://ai.google.dev/gemma/terms).
- **G2:** [llama.cpp maintainer v1 GGUF card: real embedding commands and normalization](https://huggingface.co/ggml-org/embeddinggemma-300M-GGUF).
- **G3:** [Google EmbeddingGemma 2 author card: architecture, selective text loading, prompts, MRL, license, precision warning and evaluations](https://huggingface.co/google/embeddinggemma-2), [Google docs, updated 2026-10-06](https://ai.google.dev/gemma/docs/embeddinggemma/model_card_2), [actual author config](https://huggingface.co/google/embeddinggemma-2/blob/main/config.json), [runtime-maintainer conversion card](https://huggingface.co/ggml-org/embeddinggemma-2-GGUF). **Source discrepancy:** model-card sliding-window table says 1024, while inspected config says 512; use pinned implementation/config and test rather than copying the prose table. The supported retrieval window is 8192, not config `max_position_embeddings=262144`.
- **Q1:** [Qwen3-Embedding-0.6B author card: dedicated training, instructions, last non-padding pooling, normalization and MRL](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B), [author release](https://qwenlm.github.io/blog/qwen3-embedding/).
- **Q2:** [Official Qwen GGUF card: llama.cpp embedding commands and last pooling](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF).
- **B1:** [BAAI BGE-M3 author card: dense/sparse/multi-vector distinction, cross-lingual evaluations, no query instruction, windows/dimensions](https://huggingface.co/BAAI/bge-m3).
- **B2:** [BGE-M3 author CLS pooling configuration](https://huggingface.co/BAAI/bge-m3/blob/main/1_Pooling/config.json).
- **J1:** [Jina v5 nano author card: 2026 release, 239M, license, task adapters and length inconsistency](https://huggingface.co/jinaai/jina-embeddings-v5-text-nano).
- **J2:** [Jina v5 nano retrieval author card: merged adapters, ONNX, special llama.cpp branch, Query/Document prompts and last pooling](https://huggingface.co/jinaai/jina-embeddings-v5-text-nano-retrieval).
- **N1:** [Nomic Embed v2 author card: active versus total parameters, window and MRL](https://huggingface.co/nomic-ai/nomic-embed-text-v2-moe).
- **X1:** [MrBERT authors' 2026 paper](https://arxiv.org/abs/2602.21379).
- **X2:** [Runtime-maintainer English e5-small-v2 conversion: explicitly not multilingual-e5-small](https://huggingface.co/ggml-org/e5-small-v2-Q8_0-GGUF).

### Artifact-owner metadata APIs

- **A1:** E5 [small file metadata](https://huggingface.co/api/models/intfloat/multilingual-e5-small/tree/main?recursive=true&limit=100), [base metadata](https://huggingface.co/api/models/intfloat/multilingual-e5-base/tree/main?recursive=true&limit=100).
- **A2:** [MiniLM file metadata](https://huggingface.co/api/models/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2/tree/main?recursive=true&limit=100).
- **A3:** [BGE-M3 file metadata](https://huggingface.co/api/models/BAAI/bge-m3/tree/main?recursive=true&limit=100).
- **A4:** [Legacy Google EmbeddingGemma metadata/gating/license](https://huggingface.co/api/models/google/embeddinggemma-300m), [runtime-maintainer Q8 metadata](https://huggingface.co/api/models/ggml-org/embeddinggemma-300M-GGUF/tree/main?recursive=true&limit=100).
- **A5:** [Google EmbeddingGemma 2 metadata/license/gating](https://huggingface.co/api/models/google/embeddinggemma-2), [runtime-maintainer text GGUF and projector metadata](https://huggingface.co/api/models/ggml-org/embeddinggemma-2-GGUF/tree/main?recursive=true&limit=100).
- **A6:** [Official Qwen3-Embedding GGUF metadata](https://huggingface.co/api/models/Qwen/Qwen3-Embedding-0.6B-GGUF/tree/main?recursive=true&limit=100).
- **A7:** [BGE-M3 graph/external-data/tokenizer metadata](https://huggingface.co/api/models/BAAI/bge-m3/tree/main?recursive=true&limit=100).
- **A8:** [Jina nano retrieval graph/external-data/tokenizer metadata](https://huggingface.co/api/models/jinaai/jina-embeddings-v5-text-nano-retrieval/tree/main?recursive=true&limit=100).
- **A9:** [ONNX-community legacy EmbeddingGemma export metadata](https://huggingface.co/api/models/onnx-community/embeddinggemma-300m-ONNX/tree/main?recursive=true&limit=100).

### Runtime and integration owners

- **R1:** Installed **llamadart 0.11.1** package source inspected via Dart package tools: `src/core/engine/engine.dart` (embed APIs), `src/backends/llama_cpp/llama_cpp_service.dart` (pooling, encoder/decoder, token limits, metadata, normalization), `src/core/models/inference/model_params.dart` (batch/micro-batch), `src/backends/llama_cpp/worker.dart` (worker dispatch). [Maintainer repository](https://github.com/leehack/llamadart), [published 0.11.1 package](https://pub.dev/packages/llamadart/versions/0.11.1). This records the locally resolved source, not an assumption that moving upstream `main` equals the installed version.
- **R2:** llama.cpp [pinned `7fe450e1` architecture registry](https://github.com/ggml-org/llama.cpp/blob/7fe450e1/src/llama-arch.cpp), [current registry](https://github.com/ggml-org/llama.cpp/blob/master/src/llama-arch.cpp), [v1 non-causal embedding graph/projection loading](https://github.com/ggml-org/llama.cpp/blob/master/src/models/gemma-embedding.cpp), [v2 non-causal embedding graph/output projection](https://github.com/ggml-org/llama.cpp/blob/master/src/models/gemma-embedding2.cpp). [Project pinned-native notices](../native-dependencies.md).
- **R3:** [SentenceTransformers owner docs: ONNX export, pooling outside exported transformer and arm64 quantization option](https://sbert.net/docs/sentence_transformer/usage/efficiency.html).
- **R4:** [Microsoft ONNX Runtime quantization: loss/overhead, formats, hardware dependence, contrib operators/version requirements](https://onnxruntime.ai/docs/performance/model-optimizations/quantization.html).
- **R5:** [Microsoft ORT mobile deployment](https://onnxruntime.ai/docs/get-started/with-mobile.html), [MIT license](https://github.com/microsoft/onnxruntime/blob/main/LICENSE).
- **R6:** Community-wrapper maintainers: [onnxruntime 1.4.1 API metadata](https://pub.dev/api/packages/onnxruntime), [FFI repository](https://github.com/gtbluesky/onnxruntime_flutter); [flutter_onnxruntime 1.9.0 API metadata](https://pub.dev/api/packages/flutter_onnxruntime), [native wrapper README/platform/version requirements](https://github.com/masicai/flutter_onnxruntime). These uninstalled candidates were examined remotely; no package was added or downloaded.
