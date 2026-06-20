# LuxiEdge Attention v2 Public Benchmark Hub

**AttentionTransformer V2 + MumbleLang + Geodesic Engine**

Public verification results only. Core implementation remains private.

## Current Verified Wins (June 20, 2026)

| Target | Win | Repro Command |
|--------|-----|---------------|
| FlashAttention | Superior energy efficiency + no OOM at 2M+ | `./run.sh flash` |
| vLLM | Better J/token + determinism | `./run.sh vllm` |
| HF Transformers | MumbleLang ultra-short attention pass | `./run.sh hf --mumble` |

All results are designed to be reproducible. Contact for full private engine.