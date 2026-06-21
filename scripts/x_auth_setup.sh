#!/usr/bin/env bash
# One-time X auth setup for bird CLI auto-posting.
set -euo pipefail

CREDS_DIR="${HOME}/.config/x-post"
CREDS_FILE="${CREDS_DIR}/credentials.env"
BIRD_CONFIG="${HOME}/.config/bird/config.json5"

echo "═══════════════════════════════════════════════════════════════"
echo " X Auto-Post Setup (@RegularJoe_Ceo)"
echo "═══════════════════════════════════════════════════════════════"
echo

if ! command -v bird >/dev/null 2>&1; then
  echo "Installing bird CLI..."
  npm install -g @steipete/bird
fi

mkdir -p "${CREDS_DIR}"
chmod 700 "${CREDS_DIR}"

if [[ -f "${CREDS_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CREDS_FILE}"
fi

try_browser_auth() {
  echo "── Trying browser cookie extraction (Chrome → Safari → Firefox) ──"
  if bird --plain whoami 2>/dev/null | grep -qi 'screen_name\|@'; then
    echo "OK  bird whoami succeeded via browser cookies."
    if [[ -z "${AUTH_TOKEN:-}" || -z "${CT0:-}" ]]; then
      echo
      echo "Browser auth works, but saving explicit cookies enables headless posting."
      echo "Skip manual entry? [y/N]"
      read -r skip
      if [[ "${skip}" =~ ^[Yy]$ ]]; then
        return 0
      fi
    else
      return 0
    fi
  fi
  return 1
}

if ! try_browser_auth; then
  echo
  echo "Browser extraction failed (common on first run — keychain prompt or not logged in)."
  echo
  echo "Manual cookie setup:"
  echo "  1. Open https://x.com while logged in as @RegularJoe_Ceo"
  echo "  2. DevTools (Cmd+Opt+I) → Application → Storage → Cookies → https://x.com"
  echo "  3. Copy values for: auth_token  and  ct0"
  echo
fi

if [[ -z "${AUTH_TOKEN:-}" ]]; then
  echo -n "Paste auth_token: "
  read -rs AUTH_TOKEN
  echo
fi

if [[ -z "${CT0:-}" ]]; then
  echo -n "Paste ct0: "
  read -rs CT0
  echo
fi

if [[ -z "${AUTH_TOKEN}" || -z "${CT0}" ]]; then
  echo "ERROR: both AUTH_TOKEN and CT0 are required."
  exit 1
fi

cat > "${CREDS_FILE}" <<EOF
# X credentials for bird CLI — keep private (chmod 600)
AUTH_TOKEN=${AUTH_TOKEN}
CT0=${CT0}
EOF
chmod 600 "${CREDS_FILE}"
echo "Wrote ${CREDS_FILE}"

mkdir -p "$(dirname "${BIRD_CONFIG}")"
if [[ ! -f "${BIRD_CONFIG}" ]]; then
  cat > "${BIRD_CONFIG}" <<'EOF'
{
  // bird CLI config — see https://bird.fast
  cookieTimeoutMs: 10000,
  timeoutMs: 30000,
  cookieSource: ["chrome", "safari", "firefox"]
}
EOF
  echo "Wrote ${BIRD_CONFIG}"
fi

echo
echo "── Verifying credentials ──"
# shellcheck disable=SC1090
source "${CREDS_FILE}"
export AUTH_TOKEN CT0

if bird --plain --auth-token "${AUTH_TOKEN}" --ct0 "${CT0}" whoami 2>&1; then
  echo
  echo "AUTH OK — ready to post."
  echo
  echo "Next:"
  echo "  cd $(cd "$(dirname "$0")/.." && pwd)"
  echo "  ./scripts/post_x_thread.sh --dry-run    # preview"
  echo "  ./scripts/post_x_thread.sh              # post thread"
else
  echo
  echo "WARN: whoami failed — cookies may be expired. Re-run after fresh x.com login."
  exit 1
fi