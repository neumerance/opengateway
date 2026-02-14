#!/usr/bin/env bash
# OpenGateway POC – Phase 1: Install dependencies (Linux only).
# Usage: curl -fsSL https://raw.githubusercontent.com/<org>/opengateway/main/scripts/install.sh | bash
#        ./scripts/install.sh
#
# Phase 1: dependencies. Phase 2: CLI.
# EXO (exo-explore) is from source; add in a later phase if needed.

set -e

OPENGATEWAY_POC_ROOT="${OPENGATEWAY_POC_ROOT:-$HOME/.opengateway-poc}"
REPO_RAW_URL="${REPO_RAW_URL:-https://raw.githubusercontent.com/opengateway/opengateway/main}"

if [[ -n "${BASH_SOURCE[0]}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
else
  SCRIPT_DIR=""
  REPO_ROOT=""
fi

echo "=============================================="
echo "  OpenGateway POC – Phase 1 & 2"
echo "=============================================="
echo "  POC root: $OPENGATEWAY_POC_ROOT"
echo ""

# --- Linux only ---
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script is for Linux only. (POC scope)"
  exit 1
fi

# --- 1. curl (required) ---
echo "[1/5] curl"
if ! command -v curl &>/dev/null; then
  echo "  curl is required. Install with: sudo apt-get update && sudo apt-get install -y curl"
  exit 1
fi
echo "  OK: $(curl -sV 2>/dev/null | head -1 || true)"

# --- 2. Python 3.10+ and pip ---
echo "[2/5] Python 3.10+ and pip"
need_python() {
  echo "  Python 3.10+ required. Install with:"
  echo "    sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv"
  echo "  or (Ubuntu 22.04+): python3 is usually 3.10+."
  exit 1
}
if ! command -v python3 &>/dev/null; then
  echo "  Python3 not found. Installing..."
  sudo apt-get update -qq
  sudo apt-get install -y python3 python3-pip python3-venv
fi
PY_VER=$(python3 -c 'import sys; v=sys.version_info; print(f"{v.major}.{v.minor}" if v.major==3 else "0")' 2>/dev/null || echo "0")
PY_MAJOR=$(echo "$PY_VER" | cut -d. -f1)
PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
if [[ "$PY_MAJOR" -lt 3 ]] || { [[ "$PY_MAJOR" -eq 3 ]] && [[ "${PY_MINOR:-0}" -lt 10 ]]; }; then
  need_python
fi
echo "  OK: Python $PY_VER ($(python3 -c 'import sys; print(sys.executable)' 2>/dev/null))"
pip3 --version 2>/dev/null || { python3 -m ensurepip --user 2>/dev/null; echo "  OK: pip available"; }

# --- 3. EXO (optional for Phase 1: exo-explore is from source) ---
echo "[3/5] EXO"
echo "  Skip: EXO (exo-explore) is installed from source; add in a later phase. POC discovery uses Hyperswarm first."

# --- 4. Node.js 18+ and npm ---
echo "[4/5] Node.js 18+ and npm"
install_node_linux() {
  if command -v fnm &>/dev/null; then
    eval "$(fnm env)" 2>/dev/null || true
    fnm install 20
    fnm use 20
    return 0
  fi
  if [[ -f /etc/debian_version ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    return 0
  fi
  if [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
    curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
    sudo dnf install -y nodejs || sudo yum install -y nodejs
    return 0
  fi
  return 1
}
if ! command -v node &>/dev/null; then
  echo "  Node not found. Installing..."
  if ! install_node_linux; then
    echo "  Install Node 18+ manually: https://nodejs.org or fnm / nvm"
    exit 1
  fi
fi
NODE_VER=$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo "0")
if [[ "${NODE_VER:-0}" -lt 18 ]]; then
  echo "  Node 18+ required; found $(node -v). Installing Node 20..."
  install_node_linux || exit 1
fi
echo "  OK: Node $(node -v), npm $(npm -v 2>/dev/null)"

# --- 5. POC root and Hyperswarm ---
echo "[5/5] POC root and Hyperswarm"
mkdir -p "$OPENGATEWAY_POC_ROOT"
cd "$OPENGATEWAY_POC_ROOT"
if [[ -n "$REPO_ROOT" && -f "$SCRIPT_DIR/package.json" ]]; then
  cp "$SCRIPT_DIR/package.json" "$OPENGATEWAY_POC_ROOT/"
else
  curl -fsSL -o package.json "$REPO_RAW_URL/scripts/package.json" || {
    echo '{"name":"opengateway-poc","private":true,"dependencies":{"hyperswarm":"^4.16.0"}}' > package.json
  }
fi
npm install --silent --no-fund --no-audit 2>/dev/null || npm install --no-fund --no-audit
echo "  OK: Hyperswarm in $OPENGATEWAY_POC_ROOT"

# --- Phase 2: Install CLI ---
echo ""
echo "Phase 2: CLI"
if [[ -n "$REPO_ROOT" && -f "$SCRIPT_DIR/cli.js" ]]; then
  cp "$SCRIPT_DIR/cli.js" "$OPENGATEWAY_POC_ROOT/"
else
  curl -fsSL -o "$OPENGATEWAY_POC_ROOT/cli.js" "$REPO_RAW_URL/scripts/cli.js" || {
    echo "  Failed to download cli.js. Run from repo or set REPO_RAW_URL."
    exit 1
  }
fi
chmod +x "$OPENGATEWAY_POC_ROOT/cli.js"
# Wrapper so user can run "opengateway" from POC root or add to PATH
cat > "$OPENGATEWAY_POC_ROOT/opengateway" << 'WRAP'
#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")" && pwd)"
export OPENGATEWAY_POC_ROOT="$ROOT"
exec node "$ROOT/cli.js" "$@"
WRAP
chmod +x "$OPENGATEWAY_POC_ROOT/opengateway"
# Initial state if missing
if [[ ! -f "$OPENGATEWAY_POC_ROOT/state.json" ]]; then
  echo '{"clusters":[],"nodePid":null}' > "$OPENGATEWAY_POC_ROOT/state.json"
fi
echo "  OK: CLI at $OPENGATEWAY_POC_ROOT/opengateway"
echo "  Run: $OPENGATEWAY_POC_ROOT/opengateway status"
echo "  Or add to PATH: export PATH=\"\$PATH:$OPENGATEWAY_POC_ROOT\""

echo ""
echo "Phase 1 (dependencies) and Phase 2 (CLI) complete. Next: Phase 3 (gauge + join)."
echo "  POC root: $OPENGATEWAY_POC_ROOT"
echo ""
