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
  echo "Browser auto-extract failed (common — keychain prompt, wrong browser, or not logged in)."
  echo
  echo "NOT the X Developer Portal (developer.x.com) — ignore that entirely."
  echo "You need your BROWSER's built-in inspector while logged into x.com."
  echo
  echo "── Fix Chrome keychain timeout (your error) ──"
  echo "  System Settings → Privacy & Security → Full Disk Access"
  echo "  Enable: Terminal.app  (and iTerm if you use it)"
  echo "  Quit Terminal completely, reopen, then:  bird whoami"
  echo
  echo "── Or skip keychain — paste cookies manually (60 seconds) ──"
  echo "  1. Chrome → https://x.com (logged in as @RegularJoe_Ceo)"
  echo "  2. Cmd+Option+I → Network tab → Cmd+R reload"
  echo "  3. Click first 'x.com' request → Headers → Request Headers → cookie:"
  echo "  4. Copy auth_token=XXXX and ct0=YYYY from that line (paste below)"
  echo
  echo "── Manual fallback (Chrome on Mac) ──"
  echo "  1. In Chrome, go to https://x.com (logged in)"
  echo "  2. Press Cmd+Option+I  (or menu: View → Developer → Developer Tools)"
  echo "  3. Click the 'Application' tab (top bar; may be under the >> overflow)"
  echo "  4. Left sidebar: Storage → Cookies → https://x.com"
  echo "  5. In the table on the right, copy the Value column for:"
  echo "       auth_token"
  echo "       ct0"
  echo
  echo "── Manual fallback (Network tab — if you can't find Application) ──"
  echo "  1. Chrome on https://x.com → Cmd+Option+I → Network tab"
  echo "  2. Reload the page (Cmd+R)"
  echo "  3. Click any request to 'x.com' or 'twitter.com'"
  echo "  4. Headers → Request Headers → find the long 'cookie:' line"
  echo "  5. Copy auth_token=... and ct0=... values from that line"
  echo
  echo "── Won't work on ──"
  echo "  • X iPhone/Android app (no browser DevTools)"
  echo "  • developer.x.com API portal (different thing entirely)"
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