# MumbleLang Short-Pass — Ultra-Short Attention Context

**AttentionTransformer V2 + MBL/1.0**

MumbleLang compresses human prompts into a structured intermediate form (MBL/1.0) before they enter the attention stack. Fewer tokens → fewer attention positions → measurably lower J/token on every pass, without changing model weights.

This is not "prompt engineering vibes." It is a **documented, budgeted notation** with verification hooks in this repo.

---

## What "Short-Pass" Means

| Stage | Standard pipeline | MumbleLang short-pass |
|-------|-------------------|----------------------|
| Input | Full natural-language prompt (all tokens attend) | MBL/1.0 block (≤22 lines, ≤2 `@residue`) |
| Attention | `seq = tokenize(prompt)` | `seq = tokenize(MBL)` — typically **1.7–3.3× shorter** |
| Energy | Scales with seq (linear Waller / quadratic naive) | Same math, smaller seq |
| Determinism | Model-dependent | MBL budget + `@residue` preserves exact phrases |

**Conservative claim:** We win on **effective attention length** and downstream **J/token**, not on raw tokenizer novelty. Ratios vary by model BPE.

---

## MBL/1.0 Budget (Strict)

```text
MBL/1.0
@task       what the user wants done
@tone       social/voice posture
@ctx        context needed to understand the request
@goal       desired end state
@build      immediate work
@defer      later work (max 2)
@guard      conditional correctness rule
@residue    exact quote worth preserving (max 2 lines)
```

Hard limits: **22 total lines** (including header), **2 `@residue`**, **2 `@defer`**.

Public spec: [github.com/RegularJoe-CEO/MumbleLang](https://github.com/RegularJoe-CEO/MumbleLang) · `docs/mbl-1.0.md`

---

## Before / After Examples (Verified in `run_bench.sh`)

### 1. Customer complaint (425 chars → 244 chars)

**Before (human):**

```text
I am honestly pretty upset. I was told the roof repair would be finished last Thursday, and now it is Monday and nobody has called me. I understand weather happens, but I should not have to chase people down for updates. I need someone to tell me exactly what is going on, when the crew is coming back, and whether this delay is going to affect the price I was quoted. Do not send me a generic apology. I want a real answer.
```

**After (MBL/1.0):**

```text
MBL/1.0
@task reply.real.status.not.generic.apology
@tone upset.chasing.updates
@ctx roof.repair.promised.Thursday.now.Monday
@goal exact.status crew.return.date price.impact
@guard no.generic.apology
@residue "Do not send me a generic apology"
```

| Metric | Value |
|--------|------:|
| Character reduction | **42%** |
| Est. token reduction | **1.7×** |
| MBL/1.0 budget | PASS (8 lines) |

---

### 2. Code debugging (352 chars → 199 chars)

**Before (human):**

```text
My Python script keeps crashing when I process a CSV with empty cells. I am using pandas. The error says "ValueError: cannot convert float NaN to integer". I need you to explain why it happens, show me the safest fix, and give me a corrected code example. Do not rewrite the whole program. Keep the answer focused on the NaN-to-int conversion problem.
```

**After (MBL/1.0):**

```text
MBL/1.0
@task explain.pandas.NaN.to.int.ValueError
@ctx python.csv.empty.cells.pandas
@goal safest.fix.plus.corrected.snippet
@guard focused.answer.not.full.rewrite
@build show.corrected.code.example
```

| Metric | Value |
|--------|------:|
| Character reduction | **43%** |
| Est. token reduction | **1.8×** |
| MBL/1.0 budget | PASS (7 lines) |

---

### 3. Founder architecture note (1331 chars → 406 chars) — largest win

**Before (human):** see `examples/founder-architecture.txt`

**After (MBL/1.0):**

```text
MBL/1.0
@task kernel-shaped.server.synthesis
@ctx WNSM.control-plane.per-kernel.geometry
@build collapse.merge.KV.fold.null.drop.void
@build stretch.rods=active.seq.not.padded
@build run.morphed.layout.HBM.scales.active.nodes
@build dissolve.reset.next.kernel
@defer delete.edges.not.approx.attend
@defer predictive.pulse.geodesic.past-keys-only
@residue "hold it together, nodes pivot, rod length changes"
```

| Metric | Value |
|--------|------:|
| Character reduction | **69%** |
| Est. token reduction | **3.3×** |
| MBL/1.0 budget | PASS (12 lines) |
| Waller attn energy (linear model) | **~3.3× lower** |
| Naive O(N²) attn energy | **~11× lower** |

This example maps directly to Geodesic kernel-morph semantics: collapse void structure, run one morphed pass, dissolve before the next kernel.

---

## Attention-Stage Impact (Engine Integration)

When MBL/1.0 feeds AttentionTransformer V2:

1. **Prefill seq shrinks** — geodesic layer runs at `seq_mbl` not `seq_human`.
2. **Waller streaming** — HBM traffic scales O(seq_mbl) not O(seq_human).
3. **Mesh void** — compressible KV geometry yields additional edge deletion on structured `@build` / `@defer` blocks.
4. **Receipts unchanged** — AUDIT path still emits `sha256_of_f32_slice` over model outputs; MBL affects input length only.

| Prompt type | seq reduction | TRADE J/token reduction (est.) |
|-------------|:-------------:|:------------------------------:|
| Short complaint | 1.7× | ~1.7× |
| Technical debug | 1.8× | ~1.8× |
| Long architecture | 3.3× | ~3.3× |

Combined with Geodesic TRADE's baseline **3.2× J/token vs PyTorch** (see [RESULTS.md](RESULTS.md) §8), a founder-scale prompt can approach **~10× total J/token** vs unfused HF eager — run yourself to confirm on your tokenizer.

---

## Verification Commands

### Public (no API key, no proprietary engine)

```bash
git clone https://github.com/RegularJoe-CEO/attention-v2-benchmarks.git
cd attention-v2-benchmarks
chmod +x run_bench.sh
./run_bench.sh --mumble
```

Expected: three `OK` lines with `est_token_factor` ≥ 1.5× and `budget=True`.

### MumbleLang Lab (public repo, optional LLM)

```bash
git clone https://github.com/RegularJoe-CEO/MumbleLang.git
cd MumbleLang
export LLM_API_KEY="your_key"
export LLM_BASE_URL="https://api.openai.com/v1"
export LLM_MODEL="gpt-4.1-mini"
python3 app.py
# Open http://localhost:8000 — paste examples, mode=strict
```

### Licensed engine (full short-pass forward)

```bash
# Contact luxiedge.com for engine access
# MBL prompt → tokenize → geodesic TRADE forward → compare joules vs human prompt
python3 benchmarks/benchmark_joules.py --profile gpt2 --seq <mbl_token_count>
```

---

## What We Do Not Claim

- MumbleLang is **not** a deterministic parser today — strict MBL in this doc is **reference output** for verification; live conversion uses MumbleLang Lab (LLM-assisted).
- Character-based token estimates (`len/4`) are conservative placeholders — always validate with your model tokenizer.
- Short-pass does **not** replace long-document retrieval — it optimizes **prompt prefill** attention cost.

---

## Patent / Licensing

MBL/1.0 notation is public (MIT). Integration with WNSM geodesic kernel-morph and AttentionTransformer V2 short-pass pipeline is **proprietary**. Contact [luxiedge.com](https://luxiedge.com) for SDK access.