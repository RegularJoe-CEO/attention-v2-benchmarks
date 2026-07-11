# Results

**Updated:** 2026-07-11 · **Hardware:** H100 NVL (primary), H200 (morph longctx), Apple Silicon (CPU)  
**Verify:** `./run_bench.sh` · **Catalog:** [`suite/manifest.json`](suite/manifest.json) · **Artifacts:** [`frozen/`](frozen/)

Honest scope: Flash often wins short-seq layer thr/J/token. Defensible axes are **AUDIT/free-ride**, **O(N) memory**, **morph on compressible KV**, and **measured 12L stack energy**.

---

## Scoreboard

| Axis | Result | Frozen |
|------|--------|--------|
| TRADE 12L stack energy (H100) | prefill **0.0131** / decode **0.0077** J/tok @ ~170–177 W | `h100_trade_cuda_20260711.json` |
| 12L H2H thr/J/tok | **PyTorch Flash wins** (~19× lower J/tok, ~19× thr) at GPT-2 width | `h100_stack12_h2h_20260711.json` |
| WNSM free-ride tax | **~1.01×** ON vs OFF; stack inject residual **0.0** | `h100_wnsm_free_ride_20260711.json` |
| Long-ctx memory | slopes **~1.0 / ~2.0**; **256×** @ 32k, **1024×** @ 131k | `h100_longctx_scaling_20260711.json` |
| Morph vs Flash (H200, compressible) | **16.8×** joules, **9.8×** speed @ 16k RAG | `h200_morph_rag_tokenized_20260620.json` |
| Sprint A vs SDPA-math (H200) | **329–438×** joules @ 16k | `h200_sprint_a_longctx_20260620.json` |
| Determinism (CPU) | bit-exact WNSM receipts | `cpu_receipts_20260620.json` |
| Serve sustain 30m | ~378 req/s, **0** audit failures (CPU serve on H100 host) | `h100_serve_sustain_20260711.json` |

---

## 1. TRADE CUDA — 12L stack energy (H100, 2026-07-11)

**Shape:** 12L, h=768, heads=12, mlp=3072 · **Power:** pynvml board W (not wall-plug, not Δ-idle)

| Path | Median W | J/token | Notes |
|------|--------:|--------:|-------|
| Prefill device-resident stack, seq=1024 | 177.0 | **0.01312** | 132 iters / 10 s sustain |
| Decode resident-batch 2048→+64 | 169.0 | **0.00773** | 3416 iters |
| Composite job (1024 prefill + 64 decode) | — | **13.93 J** | vs city-block 13.27 J |

City-block constants used for model blend: 0.0125 / 0.0075 J/tok.

---

## 2. 12L stack H2H — TRADE vs PyTorch Flash (H100)

Same shape, 10 s sustain, board power.

| Stack | ms/iter | tok/s | median W | J/token |
|-------|--------:|------:|---------:|--------:|
| TRADE device-resident | 74.3 | 1.38e4 | 177.2 | 0.01286 |
| PyTorch 12× pre-norm + SDPA Flash fp16 | 3.90 | 2.63e5 | 176.4 | **0.000671** |
| TRADE / PyTorch J/tok | — | — | — | **19.2×** (PT lower) |

**Read:** At short-seq GPT-2 width, Flash thr wins. TRADE pack (§1) remains the absolute stack-energy measurement for the device-resident residual path.

---

## 3. Single-layer baseline + wedges (H100)

| Metric | Value |
|--------|------:|
| Geodesic layer ms / J/tok | 5.30 / 3.75e-4 |
| PyTorch unfused fp16 ms / J/tok | 0.414 / 3.98e-5 |
| geodesic_vs_pytorch_joules_ratio | **0.106** (PT lower at this microbench) |
| Mesh void vs waller @ seq=8192 | **7.53×** speed |
| Morph full-layer @ seq=8192 h=64 | **2.09×** vs energy path |

---

## 4. WNSM free-ride under load (H100)

| Config | OFF ms | ON ms | Overhead | Fidelity |
|--------|-------:|------:|---------:|----------|
| 1L `cuda_wnsm_energy` | 7.185 | 7.253 | **1.0095×** | out max abs drift **1.07e-2** (honest GPU TRADE); payload err **7.5e-8** |
| 12L stack free-ride | 75.65 | 75.14 | free_ride_vs_side **1.0104×** | out_drift **0.0**, null residual **2.5e-8** |

CPU AUDIT free-ride path targets bit-exact receipts (`cpu_receipts_*`); GPU primary-output drift on 1L is reported, not zeroed.

---

## 5. Long-context memory scaling (H100 host, 2026-07-11)

| seq | Waller state MB | Dense scores MB | Reduction |
|----:|----------------:|----------------:|----------:|
| 1 024 | 0.52 | 4.2 | 8× |
| 8 192 | 4.2 | 268 | 64× |
| 32 768 | 16.8 | 4 295 | **256×** |
| 131 072 | 67.1 | 68 719 | **1024×** (analytical; 131k wall-clock skipped) |

Measured CPU `long_context_bench` slopes: waller **~1.003**, standard **~2.002** (256–8192).  
CUDA longctx @ 32k (clustered, h=4096, 32 heads): median **7098 ms**, median **228 W**, **~34e9** contact bytes avoided.

---

## 6. Continuous-batch serve (30 min, H100 host)

| Metric | Value |
|--------|------:|
| Wall | 1800 s · concurrency 32 · ctx ladder 512–4096 |
| Throughput | **~378 req/s** · ~680k OK requests |
| Latency | p50 **2.48 ms** · p99 **4.47 ms** (server) |
| Audit failures | **0** |
| GPU board | ~64 W (CPU toy serve; GPU not loaded) |

---

## 7. H200 morph longctx (2026-06-20)

| Fixture / path | Joules ratio | Speed |
|----------------|-------------:|------:|
| Morph vs Flash attn, `rag_tokenized` seq=16k | **16.8×** | **9.8×** |
| Full layer morph-auto vs off (P3+Flash) | **2.06×** | — |
| Sprint A vs PyTorch SDPA-math (3 fixtures @ 16k) | **329–438×** | — |

Requires **compressible KV** (RAG/clustered). Not claimed on arbitrary short-seq weights.

---

## 8. Legacy H100 layer energy + waller-eval (2026-06-01)

| Stack | Median ms | J/token | Ratio |
|-------|----------:|--------:|------:|
| Geodesic TRADE layer (h=1024 path / GPT-2 frozen) | 6.8 | 7.90e-4 | 1.0× |
| PyTorch unfused fp16 | 22.1 | 2.55e-3 | **3.2×** worse |

Waller-eval Phase-0: median **13.084 ms** (AUDIT latency anchor).

---

## 9. Determinism

| Path | Receipt / check |
|------|-----------------|
| CPU `production_demo` NORMAL = WNSM | `e1980a6fa77252dc…37628`, max_diff **0.00e0** |
| CUDA AUDIT decoder | `0ae659948eabc3fa…d37ada` |

Flash / vLLM fp16 paths: **non-deterministic** across backends (serving thr not our claim).

---

## 10. MumbleLang short-pass

Structured MBL/1.0 prompts cut estimated attention sequence **1.7–3.3×** on bundled examples. See [MUMBLELANG_SHORT_PASS.md](MUMBLELANG_SHORT_PASS.md).

---

## Method notes

- **Power:** GPU board via pynvml / `nvidia-smi` unless stated. Not AC wall plug.
- **Shapes:** residual-MLP / GPT-2-small width unless noted; not full 124M weights unless labeled.
- **Reproduce public checks:** `./run_bench.sh` (checksums + energy model + frozen claim bands).
- **Reproduce live GPU:** licensed engine on H100/H200 — contact [luxiedge.com](https://luxiedge.com).
