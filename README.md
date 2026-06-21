# AttentionTransformer V2 — Public Benchmark Hub

**AttentionTransformer V2 · MumbleLang · Geodesic TRADE Engine**

Independent verification artifacts for energy efficiency, deterministic receipts, long-context stability, and MumbleLang short-pass attention reduction.

| | |
|---|---|
| **Maintainer** | Eric Waller — [luxiedge.com](https://luxiedge.com) · [@RegularJoe_Ceo](https://x.com/RegularJoe_Ceo) |
| **Snapshot** | 2026-06-20 |
| **Repo** | [github.com/RegularJoe-CEO/attention-v2-benchmarks](https://github.com/RegularJoe-CEO/attention-v2-benchmarks) |
| **Related (public)** | [MumbleLang](https://github.com/RegularJoe-CEO/MumbleLang) |

---

## Where This Stack Wins (Verified, Conservative)

This is not a claim to beat every framework on every metric. Documented, reproducible wins concentrate on five axes — **strongest first**:

| Axis | Demonstrated advantage | Evidence |
|------|------------------------|----------|
| **Kernel morph + CGA (compressible KV)** | **16.8× less joules**, **9.8× faster** vs Flash attn @ seq=16k `rag_tokenized` (H200); full layer **2.06×** morph-auto vs morph-off | [RESULTS_2026.md](RESULTS_2026.md) §11, `frozen/h200_morph_rag_tokenized_20260620.json` |
| **Sprint A longctx (attn-only)** | **329–438× less joules** vs PyTorch SDPA-math on three compressible fixtures @ seq=16k | [RESULTS_2026.md](RESULTS_2026.md) §11b, `frozen/h200_sprint_a_longctx_20260620.json` |
| **Energy (J/token, general KV)** | Geodesic fused layer **3.2×** less measured GPU energy than unfused PyTorch full-layer @ GPT-2 shapes (H100) | [RESULTS_2026.md](RESULTS_2026.md) §2 |
| **Determinism** | Bit-exact SHA-256 receipts across CPU/CUDA AUDIT paths; `max_diff 0.00e0` | [RESULTS_2026.md](RESULTS_2026.md) §4 |
| **Long-context stability** | O(N) Waller memory — **341×** less score-matrix footprint @ 131k tokens | [RESULTS_2026.md](RESULTS_2026.md) §5 |
| **MumbleLang short-pass** | Structured prompts cut effective attention sequence **1.7–3.3×** | [MUMBLELANG_SHORT_PASS.md](MUMBLELANG_SHORT_PASS.md) |

**Scope:** Morph/CGA wins require **compressible KV geometry** (RAG chunks, clustered keys). Flash often wins raw fp16 attn @ short seq — we do not claim that row. The defensible headlines are **morph longctx joules**, **full-layer geodesic energy**, **AUDIT determinism**, and **O(N) headroom**.

---

## Quick Verify (Public — No Proprietary Code)

Anyone can run the public verification harness in under 60 seconds:

```bash
git clone https://github.com/RegularJoe-CEO/attention-v2-benchmarks.git
cd attention-v2-benchmarks
chmod +x run_bench.sh
./run_bench.sh
```

This checks:

1. Frozen benchmark artifact checksums (H100 / Mac snapshots)
2. HBM energy model math (`20 pJ/byte` — matches engine `EnergyReport`)
3. MumbleLang short-pass compression ratios on bundled examples
4. Published SHA-256 receipt constants

**Pass criteria:** exit code `0`, all `PASS` lines green.

---

## Full Engine Reproduction (Licensed Access)

Core AttentionTransformer V2, Geodesic CUDA kernels, and WNSM control plane are **proprietary**. This repo publishes **results + verification**, not implementation source.

| Platform | Command (requires engine access) |
|----------|----------------------------------|
| **Mac / CPU** | `bash scripts/cpu_full_test.sh` inside licensed engine tree |
| **RunPod H100** | `source scripts/pod_env.sh && bash scripts/runpod_quant_gate.sh` |
| **Joules/token** | `bash scripts/benchmark_joules_pod.sh --profile gpt2` |
| **Flash compare** | `bash scripts/compare_flash_pod.sh 200 1024 1024 16` |

Contact for engine access, integration pilots, and press briefings:

- **Web:** [luxiedge.com](https://luxiedge.com)
- **X:** [@RegularJoe_Ceo](https://x.com/RegularJoe_Ceo)
- **Subject line:** `Attention V2 benchmark verification`

---

## Repository Map

| File | Purpose |
|------|---------|
| [RESULTS_2026.md](RESULTS_2026.md) | Full tables: FlashAttention, vLLM, HF Transformers, RULER, nanoGPT |
| [MUMBLELANG_SHORT_PASS.md](MUMBLELANG_SHORT_PASS.md) | Short-pass attention reduction — before/after, verification |
| [run_bench.sh](run_bench.sh) | One-click public verification (safe, no private repos) |
| [frozen/](frozen/) | Checksum-locked benchmark JSON snapshots (H100 + H200 morph) |
| [X_THREAD_DRAFT.md](X_THREAD_DRAFT.md) | Ready-to-post announcement thread |

---

## Headline Numbers (2026-06-20 Snapshot)

### Tier 1 — H200 morph longctx (compressible KV)

| Metric | Value | Config |
|--------|------:|--------|
| Morph vs Flash attn joules | **16.8× lower** | `rag_tokenized` seq=16k, attn-only |
| Morph vs Flash attn latency | **9.8× faster** | 0.65 ms vs 6.41 ms |
| Full layer morph-auto vs off | **2.06× less joules** | P3+Flash, same fixture |
| Sprint A vs PyTorch math | **329–438× less joules** | three fixtures, seq=16k |

### Tier 2 — H100 conservative baseline (general KV)

| Metric | Value | Config |
|--------|------:|--------|
| AUDIT decoder receipt (CUDA) | `0ae659948eabc3fa…d37ada` | H100, seq=1024 |
| CPU production receipt | `e1980a6fa77252dc…37628` | `production_demo`, seq=8 |
| Waller-eval median latency | **13.084 ms** | H100 Phase-0, 500×1024×1024×16 |
| Geodesic full-layer median | **6.8 ms** | H100 TRADE, `hidden=1024 heads=16` |
| J/token (TRADE vs PyTorch full) | **3.2× lower** | H100, GPT-2 dims, measured power |
| GPT-2 H200 production path | **53 ms** / **6.07 mJ/token** | P3+Flash+morph-auto — see `frozen/h200_gpt2_trade_20260620.json` |
| Attention energy @ 131k tokens | **2048×** vs naive O(N²) HBM model | `energy_sweep` |
| Long-context memory @ 131k | **201 MB** vs **68.7 GB** naive scores | `scaling_sweep` |

Run `./run_bench.sh` to confirm artifact integrity. Run licensed engine commands to regenerate live numbers.

---

## Disclaimer

- Benchmarks reflect **specific hardware snapshots** (NVIDIA H100 NVL, Apple Silicon M-series). Re-run gates after CUDA changes.
- **FlashAttention** comparisons use same-pod methodology documented in engine `FLASH_BASELINE.md`. Do not compare `energy.csv` naive-O(N²) ratios directly to Flash.
- **MumbleLang** compression uses character/token estimates in public harness; tokenizer-specific ratios vary by model.
- Patents and licensing apply to Waller Operator, WNSM, Geodesic TRADE, and kernel-morph geometry. Contact for commercial terms.
- Numbers in `frozen/` are integrity-checked snapshots — not a substitute for your own measured runs on your hardware.

---

## License

Benchmark artifacts and verification scripts: **MIT**.  
AttentionTransformer V2 engine, CUDA kernels, and Geodesic implementation: **proprietary** — contact for license.