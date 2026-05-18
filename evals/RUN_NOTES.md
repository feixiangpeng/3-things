# Voice extraction eval — iteration notes

Proxy model: `llama-3.1-8b-instant` via Groq (free tier, 6000 TPM cap is the bottleneck).
Goal: avg@5 ≥ 3.5/5 (ideally 4.5/5) on every case in `extraction_behavior.md`.

## Diagnostic results (7 cases × 5 variants × 5 runs = 175 calls)

| version | overall avg@5 | notes |
|---|---|---|
| v0 baseline (Swift prompt) | 2.21/3 fast | corrections 0/3, dup 1.5/3, overflow 2/3 |
| v1 strict 11-rule list | 2.29/3 fast | corrections improved, duplicates regressed |
| v2 concise | 2.00/3 fast | too terse, lost overflow |
| v3 chain-of-thought | 2.14/3 fast | nailed overflow but broke corrections/dup |
| v4 few-shot | 2.36/3 fast | best fast, but literal regressed from poisoned examples |
| v5 extras-as-overflow-only | 0.86/3 fast | "think before writing" leaked reasoning into output |
| v6 strict + neutral examples | 2.57/3 fast | corrections perfect, dup still off |
| v7 v6 + more correction examples | 2.93/3 fast | only 1 correction variant still flunked |
| **v7 + repair.py** | **4.69/5 (175 calls)** | corrections/dup/literal/no_task/inference all ≥4.6; vague_taxes 3.4 (scorer rigidity) |

After stemmer fix (`tax`/`taxes`, `email`/`emails`, etc.) in scorer.py, expected vague_taxes to clear 4.5+.

## Key learnings

1. The model treats `extraCandidates` as a "I'm unsure" dumping ground. Reframe as overflow-only.
2. Cancellation handling needs explicit "the cancelled task is GONE — not in any field."
3. Few-shot examples poison the model toward putting examples' words in output ("park"→correction trigger). Use NEUTRAL terms in examples.
4. Deterministic post-processing (`repair.py`) crushes the rest: dedup, promote extras→selected when room, recompute overflow.

## Current run

`v7 + repair` on **expanded subset** (12 cases × 5 × 5 = 300 calls). Hits all 11 categories.

## Next steps

Once expanded run lands:

1. If every case ≥ 3.5/5: run full fixture (25 cases × 5 × 5 = 625 calls, ~60-90 min).
2. If 1-2 gaps: surgically add an example to v7 for that category, re-test on the failing case only, then redo expanded.
3. Lock prompt into `FoundationModelsVoiceDraftExtractor.swift` and port `repair.py` semantics into Swift `VoiceDraftPostProcessor`.

## Commands

```bash
# Fast iteration (42 calls, ~5 min):
python runner.py --prompt prompts/v7_more_correction_examples.txt --runs 3 --subset diagnostic --variants 2 --concurrency 2 --repair --out reports/dev.json

# Mid (expanded, 300 calls, ~45 min):
python runner.py --prompt prompts/v7_more_correction_examples.txt --runs 5 --subset expanded --concurrency 2 --repair --out reports/v7_repair_expanded.json

# Full fixture (625 calls, ~90 min):
python runner.py --prompt prompts/v7_more_correction_examples.txt --runs 5 --subset full --concurrency 2 --repair --out reports/v7_repair_full.json

# Analyze:
python analyze.py reports/<report>.json
```
