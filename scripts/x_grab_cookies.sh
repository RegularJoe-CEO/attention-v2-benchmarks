#!/usr/bin/env bash
# Grab x.com cookies from Chrome automatically — no DevTools.
# Run in Terminal.app while logged into x.com in Chrome.
set -euo pipefail

CREDS_DIR="${HOME}/.config/x-post"
CREDS_FILE="${CREDS_DIR}/credentials.env"

echo "Grabbing x.com cookies from Chrome..."
echo "(macOS may ask for Keychain access — click Allow)"
echo

if ! python3 -c "import browser_cookie3" 2>/dev/null; then
  echo "Installing browser-cookie3..."
  pip3 install --user browser-cookie3
fi

eval "$(python3 <<'PY'
import sys
try:
    import browser_cookie3
except ImportError:
    print("echo 'ERROR: pip install browser-cookie3 failed' >&2; exit 1")
    sys.exit(0)

try:
    jar = {c.name: c.value for c in browser_cookie3.chrome(domain_name="x.com")}
except Exception as e:
    print(f"echo 'ERROR: {e}' >&2")
    print("echo 'Fix: System Settings → Privacy → Full Disk Access → enable Terminal' >&2")
    print("echo 'Then quit Chrome completely, reopen, log into x.com, rerun this script.' >&2")
    print("exit 1")
    sys.exit(0)

auth = jar.get("auth_token", "")
ct0 = jar.get("ct0", "")
if not auth or not ct0:
    print("echo 'ERROR: auth_token or ct0 not found in Chrome cookies.' >&2")
    print("echo 'Make sure Chrome is open and you are logged into https://x.com' >&2")
    print("exit 1")
    sys.exit(0)

# shell-safe export (values are hex-ish)
import shlex
print(f"export AUTH_TOKEN={shlex.quote(auth)}")
print(f"export CT0={shlex.quote(ct0)}")
print(f"echo 'OK  auth_token ({len(auth)} chars)  ct0 ({len(ct0)} chars)'")
PY
)"

mkdir -p "${CREDS_DIR}"
chmod 700 "${CREDS_DIR}"
cat > "${CREDS_FILE}" <<EOF
# Auto-grabbed from Chrome — $(date -u +%Y-%m-%dT%H:%M:%SZ)
AUTH_TOKEN=${AUTH_TOKEN}
CT0=${CT0}
EOF
chmod 600 "${CREDS_FILE}"
echo "Saved ${CREDS_FILE}"
echo

if ! command -v bird >/dev/null 2>&1; then
  npm install -g @steipete/bird
fi

echo "── Verifying with bird ──"
bird --plain --auth-token "${AUTH_TOKEN}" --ct0 "${CT0}" whoami

echo
echo "Ready. Post the benchmark thread:"
echo "  cd $(cd "$(dirname "$0")/.." && pwd)"
echo "  ./scripts/post_x_thread.sh --dry-run"
echo "  ./scripts/post_x_thread.sh"