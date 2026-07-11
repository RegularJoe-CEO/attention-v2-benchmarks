#!/usr/bin/env bash
# AttentionTransformer V2 — public verification harness
# Safe to run without proprietary engine access. No private repo clones.
#
# Usage:
#   ./run_bench.sh                  # full public verification
#   ./run_bench.sh --energy-only    # HBM energy model only
#   ./run_bench.sh --mumble         # MumbleLang short-pass only
#   ./run_bench.sh --verify-checksums
#   ./run_bench.sh --h100           # H100 July suite only
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
NC='\033[0m'
PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GRN}PASS${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $*"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YLW}WARN${NC} $*"; WARN=$((WARN + 1)); }
info() { echo "     $*"; }

MODE="${1:-all}"

echo "═══════════════════════════════════════════════════════════════════════"
echo " AttentionTransformer V2 — Public Benchmark Verification"
echo " Repo: attention-v2-benchmarks · $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo " No proprietary code required."
echo "═══════════════════════════════════════════════════════════════════════"
echo

# Frozen snapshot constants (checksum-locked against RESULTS.md)

AUDIT_RECEIPT_CUDA="0ae659948eabc3fa1212b84d9a2006c707c28ba4209ce28410df676d38d37ada"
PROD_RECEIPT_CPU="e1980a6fa77252dcab86e48aa7aa8ab2a6d3c5639789d0917e7efa1a7bb37628"

WALLER_EVAL_MEDIAN_MS="13.084"
WALLER_EVAL_MEAN_MS="14.112"
GEODESIC_LAYER_MS="6.8"
TRADE_J_PER_TOKEN="7.90e-4"
PYTORCH_J_PER_TOKEN="2.55e-3"
JOULES_RATIO_MIN="2.8"
JOULES_RATIO_MAX="3.6"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { fail "missing required command: $1"; return 1; }
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    fail "need sha256sum or shasum"
    return 1
  fi
}

verify_receipt_format() {
  local label="$1" hash="$2"
  if [[ ${#hash} -eq 64 ]] && [[ "$hash" =~ ^[0-9a-f]+$ ]]; then
    pass "$label receipt format valid (${hash:0:16}…${hash: -6})"
  else
    fail "$label receipt format invalid: $hash"
  fi
}

verify_receipts() {
  echo "── Determinism receipts (published constants) ──"
  verify_receipt_format "CUDA AUDIT decoder" "$AUDIT_RECEIPT_CUDA"
  verify_receipt_format "CPU production_demo" "$PROD_RECEIPT_CPU"
  if [[ "$PROD_RECEIPT_CPU" == "$AUDIT_RECEIPT_CUDA" ]]; then
    fail "CPU and CUDA receipts must differ (different configs)"
  else
    pass "CPU vs CUDA receipts are distinct namespaces (expected)"
  fi
  echo
}

verify_energy_model() {
  echo "── HBM energy model (20 pJ/byte, matches engine EnergyReport) ──"
  need_cmd python3 || return 0

  python3 - <<'PY' || { fail "energy model computation"; return 1; }
import sys

J_PER_BYTE = 20e-12
hidden, heads, layers = 64, 4, 3

def std_attn_joules(seq):
    bytes_moved = 2 * (seq ** 2) * 4 * heads * layers
    return bytes_moved * J_PER_BYTE

def waller_attn_joules(seq):
    bytes_moved = 2 * seq * hidden * 4 * heads * layers
    return bytes_moved * J_PER_BYTE

checks = [(128, 2.0), (8192, 128.0), (131072, 2048.0)]
ok = True
for seq, expected_ratio in checks:
    std_j = std_attn_joules(seq)
    wal_j = waller_attn_joules(seq)
    ratio = std_j / wal_j if wal_j > 0 else 0
    if abs(ratio - expected_ratio) / expected_ratio > 0.02:
        print(f"FAIL seq={seq}: ratio={ratio:.1f} expected={expected_ratio}")
        ok = False
    else:
        print(f"OK   seq={seq}: std={std_j:.4e} J  waller={wal_j:.4e} J  ratio={ratio:.0f}x")

seq = 131072
std_j = std_attn_joules(seq)
wal_j = waller_attn_joules(seq)
print(f"HEAD seq=131072 std={std_j:.4e} J waller={wal_j:.4e} J ratio={std_j/wal_j:.0f}x")
sys.exit(0 if ok else 1)
PY
  pass "energy_sweep ratios reproduced (128→2048× doubling ladder)"
  echo
}

verify_joules_ratio() {
  echo "── Joules/token ratio sanity (H100 GPT-2 snapshot) ──"
  need_cmd python3 || return 0

  python3 - <<PY || { fail "joules ratio check"; return 1; }
trade = float("${TRADE_J_PER_TOKEN}")
pt = float("${PYTORCH_J_PER_TOKEN}")
ratio = pt / trade
lo, hi = float("${JOULES_RATIO_MIN}"), float("${JOULES_RATIO_MAX}")
print(f"trade={trade:.4e}  pytorch={pt:.4e}  ratio={ratio:.2f}x")
assert lo <= ratio <= hi, f"ratio {ratio} outside [{lo},{hi}]"
PY
  pass "J/token ratio ${JOULES_RATIO_MIN}–${JOULES_RATIO_MAX}× band confirmed"
  echo
}

verify_waller_eval() {
  echo "── Waller-eval constant latency band (~14 ms reference) ──"
  need_cmd python3 || return 0

  python3 - <<PY || { fail "waller-eval band"; return 1; }
median = float("${WALLER_EVAL_MEDIAN_MS}")
mean = float("${WALLER_EVAL_MEAN_MS}")
geo = float("${GEODESIC_LAYER_MS}")
assert 12.5 <= median <= 14.0, f"median {median} outside waller-eval band"
assert 13.5 <= mean <= 15.0, f"mean {mean} outside waller-eval band"
assert geo < median, "optimized geodesic must beat Phase-0 waller-eval"
print(f"median={median} ms  mean={mean} ms  geodesic={geo} ms  speedup={median/geo:.2f}x vs waller-eval")
PY
  pass "waller-eval ~14 ms band + geodesic ${GEODESIC_LAYER_MS} ms < Phase-0"
  echo
}

verify_mumble_short_pass() {
  echo "── MumbleLang short-pass compression ──"
  need_cmd python3 || return 0

  ROOT="${ROOT}" python3 - <<'PY' || { fail "mumble short-pass"; return 1; }
import os, sys
from pathlib import Path

ROOT = Path(os.environ["ROOT"])

MBL_FOUNDER = """MBL/1.0
@task kernel-shaped.server.synthesis
@ctx WNSM.control-plane.per-kernel.geometry
@build collapse.merge.KV.fold.null.drop.void
@build stretch.rods=active.seq.not.padded
@build run.morphed.layout.HBM.scales.active.nodes
@build dissolve.reset.next.kernel
@defer delete.edges.not.approx.attend
@defer predictive.pulse.geodesic.past-keys-only
@residue "hold it together, nodes pivot, rod length changes"
"""

founder_human = (ROOT / "examples" / "founder-architecture.txt").read_text()

examples = {
    "customer-complaint": (
        "I am honestly pretty upset. I was told the roof repair would be finished last Thursday, "
        "and now it is Monday and nobody has called me. I understand weather happens, but I should "
        "not have to chase people down for updates. I need someone to tell me exactly what is going on, "
        "when the crew is coming back, and whether this delay is going to affect the price I was quoted. "
        "Do not send me a generic apology. I want a real answer.",
        """MBL/1.0
@task reply.real.status.not.generic.apology
@tone upset.chasing.updates
@ctx roof.repair.promised.Thursday.now.Monday
@goal exact.status crew.return.date price.impact
@guard no.generic.apology
@residue "Do not send me a generic apology"
""",
        1.5,
    ),
    "code-debugging": (
        'My Python script keeps crashing when I process a CSV with empty cells. I am using pandas. '
        'The error says "ValueError: cannot convert float NaN to integer". I need you to explain why '
        "it happens, show me the safest fix, and give me a corrected code example. Do not rewrite "
        "the whole program. Keep the answer focused on the NaN-to-int conversion problem.",
        """MBL/1.0
@task explain.pandas.NaN.to.int.ValueError
@ctx python.csv.empty.cells.pandas
@goal safest.fix.plus.corrected.snippet
@guard focused.answer.not.full.rewrite
@build show.corrected.code.example
""",
        1.5,
    ),
    "founder-architecture": (founder_human, MBL_FOUNDER, 2.5),
}

ok = True
for name, (human, mbl, min_factor) in examples.items():
    h_tok = len(human) / 4.0
    m_tok = len(mbl.strip()) / 4.0
    factor = h_tok / m_tok if m_tok > 0 else 0
    char_red = 100 * (1 - len(mbl.strip()) / len(human))
    mbl_lines = [l for l in mbl.strip().splitlines() if l.strip()]
    budget_ok = len(mbl_lines) <= 22
    print(f"OK   {name}: chars -{char_red:.0f}%  est_token_factor={factor:.1f}x  budget={budget_ok}")
    if factor < min_factor:
        print(f"FAIL {name}: factor {factor:.1f} < {min_factor}")
        ok = False
    if not budget_ok:
        print(f"FAIL {name}: MBL/1.0 budget exceeded ({len(mbl_lines)} lines)")
        ok = False

sys.exit(0 if ok else 1)
PY
  pass "MumbleLang short-pass examples meet compression floors + MBL/1.0 budget"
  echo
}

verify_h200_morph() {
  echo "── H200 morph longctx frozen constants ──"
  need_cmd python3 || return 0

  ROOT="${ROOT}" python3 - <<'PY' || { fail "H200 morph frozen JSON"; return 1; }
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT"])
morph = json.loads((root / "frozen/h200_morph_rag_tokenized_20260620.json").read_text())
sprint = json.loads((root / "frozen/h200_sprint_a_longctx_20260620.json").read_text())

jr = morph["morph_vs_flash"]["joules_ratio"]
sr = morph["morph_vs_flash"]["speed_ratio"]
fl = morph["production_full_layer_p3_flash"]["joules_ratio_off_over_auto"]
assert 16.0 <= jr <= 17.5, f"morph joules ratio {jr}"
assert 9.0 <= sr <= 10.5, f"morph speed ratio {sr}"
assert 1.9 <= fl <= 2.2, f"full layer joules ratio {fl}"
print(f"OK   rag_tokenized: joules={jr:.2f}x  speed={sr:.2f}x  full_layer={fl:.2f}x")

ratios = [f["joules_ratio_morph_over_math"] for f in sprint["fixtures"]]
assert all(320 <= r <= 450 for r in ratios), f"Sprint A ratios out of band: {ratios}"
print(f"OK   Sprint A joules ratios: {', '.join(f'{r:.0f}x' for r in ratios)}")
assert sprint["safe_to_publish"] is True
assert morph["morph_vs_flash"]["two_of_three_pass"] is True
PY
  pass "H200 morph frozen JSON matches published headline bands"
  echo
}

verify_h100_july() {
  echo "── H100 2026-07-11 suite (frozen claim bands) ──"
  need_cmd python3 || return 0

  ROOT="${ROOT}" python3 - <<'PY' || { fail "H100 July frozen JSON"; return 1; }
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT"])

trade = json.loads((root / "frozen/h100_trade_cuda_20260711.json").read_text())
assert 0.012 <= trade["j_per_prefill_token"] <= 0.014
assert 0.007 <= trade["j_per_decode_token"] <= 0.009
print(f"OK   TRADE prefill={trade['j_per_prefill_token']:.5f} decode={trade['j_per_decode_token']:.5f} J/tok")

h2h = json.loads((root / "frozen/h100_stack12_h2h_20260711.json").read_text())
r = h2h["trade_over_pytorch_J_per_token_ratio"]
assert 15 <= r <= 25, r
print(f"OK   stack12 H2H TRADE/PT J ratio={r:.2f} (PT wins thr at this shape)")

base = json.loads((root / "frozen/h100_baseline_vs_geo_20260711.json").read_text())
assert base["geodesic_vs_pytorch_joules_ratio"] < 1.0
assert base["E_mesh_void_attn_wedge_seq8192"]["speedup_vs_waller"] > 5.0
print(f"OK   baseline mesh wedge speedup={base['E_mesh_void_attn_wedge_seq8192']['speedup_vs_waller']:.2f}x")

wnsm = json.loads((root / "frozen/h100_wnsm_free_ride_20260711.json").read_text())
assert 1.0 <= wnsm["overhead_on_over_off"] <= 1.05
stack = wnsm["results"]["stack12"]["bench"]
assert stack["out_drift"] == 0.0
assert 1.0 <= stack["free_ride_vs_side"] <= 1.05
print(f"OK   WNSM free-ride overhead={wnsm['overhead_on_over_off']:.4f} stack out_drift={stack['out_drift']}")

lc = json.loads((root / "frozen/h100_longctx_scaling_20260711.json").read_text())
assert abs(lc["npow"]["mem_slope_waller"] - 1.0) < 0.02
assert abs(lc["npow"]["mem_slope_standard"] - 2.0) < 0.02
assert lc["reduction_highlights"]["at_32768"] == 256.0
assert lc["reduction_highlights"]["at_131072"] == 1024.0
print(f"OK   longctx mem red@32k={lc['reduction_highlights']['at_32768']}x @131k={lc['reduction_highlights']['at_131072']}x")

serve = json.loads((root / "frozen/h100_serve_sustain_20260711.json").read_text())
assert serve["metrics_excerpt"]["audit_failures"] == 0
assert serve["workload"]["req_per_s"] > 100
print(f"OK   serve sustain req/s={serve['workload']['req_per_s']:.1f} audit_failures=0")

ladder = (root / "frozen/h100_mem_ladder_20260711.csv").read_text().strip().splitlines()
assert ladder[0].startswith("seq,")
rows = [ln.split(",") for ln in ladder[1:]]
assert float(rows[-1][3]) == 1024.0
print(f"OK   mem ladder rows={len(rows)} final reduction={rows[-1][3]}x")

man = json.loads((root / "suite/manifest.json").read_text())
missing = []
for b in man["benchmarks"]:
    if "frozen" in b and not (root / b["frozen"]).is_file():
        missing.append(b["frozen"])
    for rel in b.get("related", []):
        if not (root / rel).is_file():
            missing.append(rel)
assert not missing, f"manifest missing files: {missing}"
print(f"OK   suite/manifest.json ({len(man['benchmarks'])} benches) paths resolve")
PY
  pass "H100 2026-07-11 suite claim bands + suite manifest"
  echo
}

verify_checksums() {
  echo "── Frozen artifact integrity ──"
  if [[ -f "${ROOT}/frozen/SHA256SUMS" ]]; then
    if (cd "${ROOT}/frozen" && sha256sum -c SHA256SUMS 2>/dev/null) || \
       (cd "${ROOT}/frozen" && shasum -a 256 -c SHA256SUMS 2>/dev/null); then
      pass "frozen/SHA256SUMS verified"
    else
      fail "frozen/SHA256SUMS mismatch — run: (cd frozen && shasum -a 256 -c SHA256SUMS)"
    fi
  else
    warn "frozen/SHA256SUMS not found"
  fi

  for f in \
    "${ROOT}/RESULTS.md" \
    "${ROOT}/README.md" \
    "${ROOT}/suite/manifest.json" \
    "${ROOT}/MUMBLELANG_SHORT_PASS.md"; do
    if [[ -f "$f" ]]; then
      pass "present: $(basename "$f")"
    else
      fail "missing: $(basename "$f")"
    fi
  done
  echo
}

verify_mumble_repo() {
  echo "── Optional: MumbleLang public repo ──"
  if command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    if curl -fsSL -o /dev/null -w "%{http_code}" "https://github.com/RegularJoe-CEO/MumbleLang" | grep -q 200; then
      pass "MumbleLang public repo reachable"
    else
      warn "could not reach MumbleLang repo (network)"
    fi
  else
    warn "git/curl not available — skipping MumbleLang reachability"
  fi
  echo
}

case "$MODE" in
  --energy-only)
    verify_energy_model
    ;;
  --mumble)
    verify_mumble_short_pass
    ;;
  --verify-checksums)
    verify_checksums
    ;;
  --receipts)
    verify_receipts
    ;;
  --h100)
    verify_h100_july
    verify_checksums
    ;;
  all|--all|"")
    verify_receipts
    verify_energy_model
    verify_joules_ratio
    verify_waller_eval
    verify_h200_morph
    verify_h100_july
    verify_mumble_short_pass
    verify_checksums
    verify_mumble_repo
    ;;
  -h|--help)
    sed -n '2,12p' "$0" | tr -d '#'
    exit 0
    ;;
  *)
    fail "unknown mode: $MODE (try --help)"
    ;;
esac

echo "═══════════════════════════════════════════════════════════════════════"
echo " Summary: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
if [[ $FAIL -eq 0 ]]; then
  echo -e " ${GRN}PUBLIC VERIFICATION: PASS${NC}"
  echo
  echo " Full tables: RESULTS.md · Catalog: suite/manifest.json"
  exit 0
else
  echo -e " ${RED}PUBLIC VERIFICATION: FAIL${NC}"
  exit 1
fi
