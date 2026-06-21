#!/usr/bin/env bash
# Post an X thread via bird CLI.
#
# Usage:
#   ./scripts/post_x_thread.sh --dry-run
#   ./scripts/post_x_thread.sh
#   ./scripts/post_x_thread.sh --media /path/to/screenshot.png
#   ./scripts/post_x_thread.sh --thread scripts/x/thread_benchmarks_20260620.json
#   ./scripts/post_x_thread.sh --with-mumble
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CREDS_FILE="${X_POST_CREDS:-${HOME}/.config/x-post/credentials.env}"
THREAD_JSON="${ROOT}/scripts/x/thread_benchmarks_20260620.json"
MEDIA=""
DRY_RUN=0
WITH_MUMBLE=0
DELAY_SECS=3

usage() {
  sed -n '2,12p' "$0" | tr -d '#'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --media) MEDIA="$2"; shift 2 ;;
    --thread) THREAD_JSON="$2"; shift 2 ;;
    --with-mumble) WITH_MUMBLE=1; shift ;;
    --delay) DELAY_SECS="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown arg: $1"; usage 1 ;;
  esac
done

if ! command -v bird >/dev/null 2>&1; then
  echo "bird not found. Run: ./scripts/x_auth_setup.sh"
  exit 1
fi

if [[ ! -f "${THREAD_JSON}" ]]; then
  echo "Thread file not found: ${THREAD_JSON}"
  exit 1
fi

if [[ ${DRY_RUN} -eq 0 ]]; then
  if [[ ! -f "${CREDS_FILE}" ]]; then
    echo "Credentials not found: ${CREDS_FILE}"
    echo "Run: ./scripts/x_auth_setup.sh"
    exit 1
  fi
  # shellcheck disable=SC1090
  source "${CREDS_FILE}"
  if [[ -z "${AUTH_TOKEN:-}" || -z "${CT0:-}" ]]; then
    echo "AUTH_TOKEN and CT0 must be set in ${CREDS_FILE}"
    exit 1
  fi
  export AUTH_TOKEN CT0
  BIRD=(bird --plain --no-color --auth-token "${AUTH_TOKEN}" --ct0 "${CT0}")
fi

TWEET_COUNT=$(python3 - "${THREAD_JSON}" <<'PY'
import json, sys
print(len(json.load(open(sys.argv[1]))["tweets"]))
PY
)

get_tweet() {
  python3 - "${THREAD_JSON}" "$1" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["tweets"][int(sys.argv[2])])
PY
}

get_optional() {
  python3 - "${THREAD_JSON}" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get("optional_reply", ""))
PY
}

extract_tweet_id() {
  echo "$1" | grep -oE 'https://x\.com/[^/]+/status/[0-9]+' | tail -1 | grep -oE '[0-9]+$' || true
}

char_count() {
  python3 -c "import sys; print(len(sys.argv[1]))" "$1"
}

echo "═══════════════════════════════════════════════════════════════"
echo " X Thread Poster — ${TWEET_COUNT} tweets"
echo " Thread: $(basename "${THREAD_JSON}")"
echo " Mode: $([[ ${DRY_RUN} -eq 1 ]] && echo DRY RUN || echo LIVE POST)"
echo "═══════════════════════════════════════════════════════════════"

for ((i = 0; i < TWEET_COUNT; i++)); do
  text=$(get_tweet "${i}")
  n=$((i + 1))
  c=$(char_count "${text}")
  flag=""
  [[ "${c}" -gt 280 ]] && flag=" ⚠ OVER 280"
  echo "Tweet ${n}: ${c} chars${flag}"
done
echo

if [[ ${DRY_RUN} -eq 1 ]]; then
  for ((i = 0; i < TWEET_COUNT; i++)); do
    n=$((i + 1))
    echo "──────── Tweet ${n} ────────"
    get_tweet "${i}"
    echo
  done
  if [[ ${WITH_MUMBLE} -eq 1 ]]; then
    opt=$(get_optional)
    if [[ -n "${opt}" ]]; then
      echo "──────── Optional Mumble reply ────────"
      echo "${opt}"
    fi
  fi
  echo "DRY RUN complete — no posts sent."
  exit 0
fi

echo "── Auth check ──"
if ! "${BIRD[@]}" whoami 2>&1 | head -5; then
  echo "Auth failed. Re-run: ./scripts/x_auth_setup.sh"
  exit 1
fi
echo

FIRST_ID=""
LAST_ID=""
for ((i = 0; i < TWEET_COUNT; i++)); do
  n=$((i + 1))
  text=$(get_tweet "${i}")
  echo "── Posting tweet ${n}/${TWEET_COUNT} ──"

  if [[ "${n}" -eq 1 && -n "${MEDIA}" ]]; then
    if [[ ! -f "${MEDIA}" ]]; then
      echo "Media file not found: ${MEDIA}"
      exit 1
    fi
    out=$("${BIRD[@]}" --media "${MEDIA}" tweet "${text}" 2>&1) || {
      echo "${out}"
      exit 1
    }
  elif [[ "${n}" -eq 1 ]]; then
    out=$("${BIRD[@]}" tweet "${text}" 2>&1) || {
      echo "${out}"
      exit 1
    }
  else
    if [[ -z "${LAST_ID}" ]]; then
      echo "Missing parent tweet ID for reply ${n}"
      exit 1
    fi
    out=$("${BIRD[@]}" reply "${LAST_ID}" "${text}" 2>&1) || {
      echo "${out}"
      exit 1
    }
  fi

  echo "${out}"
  NEW_ID=$(extract_tweet_id "${out}")
  if [[ -z "${NEW_ID}" ]]; then
    echo "Could not parse tweet ID from bird output."
    exit 1
  fi
  [[ -z "${FIRST_ID}" ]] && FIRST_ID="${NEW_ID}"
  LAST_ID="${NEW_ID}"
  echo "Posted: https://x.com/i/status/${LAST_ID}"

  if [[ "${n}" -lt "${TWEET_COUNT}" ]]; then
    sleep "${DELAY_SECS}"
  fi
done

if [[ ${WITH_MUMBLE} -eq 1 ]]; then
  opt=$(get_optional)
  if [[ -n "${opt}" && -n "${LAST_ID}" ]]; then
    echo "── Posting optional Mumble reply ──"
    sleep "${DELAY_SECS}"
    out=$("${BIRD[@]}" reply "${LAST_ID}" "${opt}" 2>&1) || {
      echo "${out}"
      exit 1
    }
    echo "${out}"
    MUMBLE_ID=$(extract_tweet_id "${out}")
    [[ -n "${MUMBLE_ID}" ]] && echo "Mumble reply: https://x.com/i/status/${MUMBLE_ID}"
  fi
fi

echo
echo "Thread complete."
echo "  First tweet: https://x.com/i/status/${FIRST_ID}"
echo "  Last tweet:  https://x.com/i/status/${LAST_ID}"