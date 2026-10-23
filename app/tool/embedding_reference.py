"""Generate public-text reference vectors; never reads journal data.

uv run --with torch --with transformers python \
  tool/embedding_reference.py /absolute/path/reference.json

The runtime versions actually used are recorded in the output. The output is
an opt-in integration-test input, not a bundled model or production dependency.
"""
import json
import sys

import torch
import transformers
from transformers import AutoModel, AutoTokenizer

MODEL = "Qwen/Qwen3-Embedding-0.6B"
REVISION = "97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3"
TEXTS = [
    "Passei as férias na praia com a minha família.",
    "São Paulo 👨‍👩‍👧 日本語",
    "Instruct: Given a personal journal search query, retrieve relevant journal passages\nQuery:Where did I spend my vacation?",
    "Preparei uma receita de bolo de chocolate para o jantar.",
]

torch.set_num_threads(4)
tokenizer = AutoTokenizer.from_pretrained(MODEL, revision=REVISION, padding_side="left")
model = AutoModel.from_pretrained(MODEL, revision=REVISION, dtype=torch.float32)
model.eval()
examples = []
with torch.inference_mode():
    for text in TEXTS:
        inputs = tokenizer(text, return_tensors="pt", truncation=False)
        # Author recipe: last non-padding token. Inputs here have no padding.
        vector = model(**inputs).last_hidden_state[:, -1, :][0]
        examples.append({"text": text, "tokens": inputs["input_ids"][0].tolist(), "vector": vector.tolist()})
with open(sys.argv[1], "w", encoding="utf-8") as output:
    json.dump({"model": MODEL, "revision": REVISION, "torch": torch.__version__, "transformers": transformers.__version__, "dtype": "float32", "examples": examples}, output)
print(f"Wrote {len(examples)} reference vectors to {sys.argv[1]}")
