# AttentionTransformer V2 — Benchmarks

Public **results**, **frozen artifacts**, and a **verification harness** for AttentionTransformer V2 / Geodesic TRADE / WNSM.

Implementation source is proprietary. This repo is what outsiders and evaluators should re-check.

| | |
|---|---|
| **Maintainer** | Eric Waller — [luxiedge.com](https://luxiedge.com) · [@RegularJoe_Ceo](https://x.com/RegularJoe_Ceo) |
| **Snapshot** | 2026-07-11 (H100 suite) + 2026-06 (H200 morph / legacy) |
| **Related** | [MumbleLang](https://github.com/RegularJoe-CEO/MumbleLang) · [LuxiDemo evidence](https://github.com/RegularJoe-CEO/LuxiDemo/tree/main/evidence) |

---

## Quick verify (no engine)

```bash
git clone https://github.com/RegularJoe-CEO/attention-v2-benchmarks.git
cd attention-v2-benchmarks
./run_bench.sh
```

Checks frozen SHA-256, energy-model ratios, MumbleLang short-pass floors, and published claim bands from `frozen/*.json`.

---

## Suite map

Machine-readable catalog: [`suite/manifest.json`](suite/manifest.json)

| ID | Axis | Device | Frozen |
|----|------|--------|--------|
| `h100_trade_cuda_stack` | 12L stack J/token | H100 | `frozen/h100_trade_cuda_20260711.json` |
| `h100_stack12_h2h` | TRADE vs PyTorch Flash | H100 | `frozen/h100_stack12_h2h_20260711.json` |
| `h100_baseline_vs_geo` | Layer + morph/mesh wedges | H100 | `frozen/h100_baseline_vs_geo_20260711.json` |
| `h100_wnsm_free_ride` | Free-ride tax under load | H100 | `frozen/h100_wnsm_free_ride_20260711.json` |
| `h100_longctx_scaling` | O(N) vs O(N²) + CUDA 32k | H100 | `frozen/h100_longctx_scaling_20260711.json` |
| `h100_serve_sustain` | 30m continuous batch | H100 host | `frozen/h100_serve_sustain_20260711.json` |
| `h200_morph_rag` | Morph vs Flash 16k | H200 | `frozen/h200_morph_rag_tokenized_20260620.json` |
| `h200_sprint_a` | Sprint A vs SDPA-math | H200 | `frozen/h200_sprint_a_longctx_20260620.json` |
| `cpu_receipts` | Bit-exact AUDIT | CPU | `frozen/cpu_receipts_20260620.json` |
| `mumblelang_short_pass` | Prompt compression | public | [MUMBLELANG_SHORT_PASS.md](MUMBLELANG_SHORT_PASS.md) |

Tables and honest scope: **[RESULTS.md](RESULTS.md)**

---

## Headline numbers (conservative)

| Claim | Number | Where it holds |
|-------|-------:|----------------|
| Prefill / decode stack J/tok (TRADE 12L) | **0.0131 / 0.0077** | H100 device-resident residual path |
| WNSM free-ride overhead | **~1.01×** | 1L + 12L under load |
| Memory reduction @ 32k / 131k | **256× / 1024×** | Waller state vs dense scores |
| Morph vs Flash joules (compressible KV) | **16.8×** | H200 `rag_tokenized` seq=16k |
| 12L short-seq thr/J vs Flash | **Flash wins ~19×** | Same-shape H2H — published honestly |

---

## Layout

```
suite/manifest.json   # catalog
frozen/               # checksum-locked JSON (+ mem ladder CSV)
RESULTS.md            # tables
run_bench.sh          # public verifier
examples/             # MumbleLang fixtures
MUMBLELANG_SHORT_PASS.md
```

---

## Disclaimer

- Snapshots are host/date specific. Re-run after CUDA or kernel changes.
- Board power ≠ wall-plug energy. Shapes are residual-MLP / GPT-2 width unless labeled full model.
- Flash wins many short-seq thr rows; do not treat every table as a TRADE win.
- Engine, kernels, and patents: proprietary — commercial terms via luxiedge.com.

## License

Benchmark artifacts and verification scripts: **MIT**.  
AttentionTransformer V2 / Geodesic / WNSM implementation: **proprietary**.
