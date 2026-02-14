#!/usr/bin/env bash
# OpenGateway POC – Phase 1: Install dependencies (Linux only).
# Usage: curl -fsSL https://raw.githubusercontent.com/<org>/opengateway/main/scripts/install.sh | bash
#        ./scripts/install.sh
#
# Phase 1: deps. Phase 2: CLI. Phase 3: gauge + poc-node.
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

source_asdf() {
  [[ -f "$HOME/.asdf/asdf.sh" ]] && . "$HOME/.asdf/asdf.sh"
  true
}
ensure_asdf() {
  if [[ ! -d "$HOME/.asdf" ]]; then
    command -v git &>/dev/null || return 1
    git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.14.0 2>/dev/null || \
    git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.13.1 2>/dev/null || return 1
  fi
  [[ -f "$HOME/.asdf/asdf.sh" ]]
}

echo "=============================================="
echo "  OpenGateway POC – Phase 1, 2 & 3"
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

# --- 2. Python 3.10+ and pip (prefer asdf) ---
echo "[2/5] Python 3.10+ and pip"
# Git is required to clone asdf; install it now if missing
if ! command -v git &>/dev/null; then
  echo "  Git not found. Installing (required for asdf)..."
  sudo apt-get update -qq
  sudo apt-get install -y git
fi
command -v git &>/dev/null || { echo "  WARN: git still missing; asdf will be skipped, using apt for Python/Node"; }
need_python() {
  echo "  Python 3.10+ required. Install with:"
  echo "    asdf plugin add python && asdf install python 3.12 && asdf global python 3.12.x"
  echo "  Or: sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv"
  exit 1
}
install_python_linux() {
  if ensure_asdf; then
    source_asdf
    asdf plugin add python 2>/dev/null || true
    asdf install python 3.12.0 2>/dev/null || asdf install python 3.11.0 2>/dev/null || asdf install python 3.10.0 2>/dev/null || true
    PY_INSTALLED=$(asdf list python 2>/dev/null | grep -E '^  3\.(1[0-2]|[0-9]+)' | tail -1 | xargs)
    [[ -z "$PY_INSTALLED" ]] && PY_INSTALLED=$(asdf list python 2>/dev/null | tail -1 | xargs)
    asdf global python "${PY_INSTALLED:-3.12.0}" 2>/dev/null || true
    source_asdf
    command -v python3 &>/dev/null && return 0
  fi
  echo "  Falling back to apt..."
  sudo apt-get update -qq
  sudo apt-get install -y python3 python3-pip python3-venv
  return 0
}
if ! command -v python3 &>/dev/null; then
  echo "  Python3 not found. Installing (using asdf when possible)..."
  install_python_linux
fi
source_asdf
PY_VER=$(python3 -c 'import sys; v=sys.version_info; print(f"{v.major}.{v.minor}" if v.major==3 else "0")' 2>/dev/null || echo "0")
PY_MAJOR=$(echo "$PY_VER" | cut -d. -f1)
PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
if [[ "$PY_MAJOR" -lt 3 ]] || { [[ "$PY_MAJOR" -eq 3 ]] && [[ "${PY_MINOR:-0}" -lt 10 ]]; }; then
  echo "  Python 3.10+ required; found $PY_VER. Installing..."
  install_python_linux
  source_asdf
  PY_VER=$(python3 -c 'import sys; v=sys.version_info; print(f"{v.major}.{v.minor}" if v.major==3 else "0")' 2>/dev/null || echo "0")
  PY_MAJOR=$(echo "$PY_VER" | cut -d. -f1)
  PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
  if [[ "$PY_MAJOR" -lt 3 ]] || { [[ "$PY_MAJOR" -eq 3 ]] && [[ "${PY_MINOR:-0}" -lt 10 ]]; }; then
    need_python
  fi
fi
if ! command -v python3 &>/dev/null; then
  need_python
fi
echo "  OK: Python $PY_VER ($(python3 -c 'import sys; print(sys.executable)' 2>/dev/null))"
pip3 --version 2>/dev/null || { python3 -m ensurepip --user 2>/dev/null; echo "  OK: pip available"; }

# --- 3. EXO (optional for Phase 1: exo-explore is from source) ---
echo "[3/5] EXO"
echo "  Skip: EXO (exo-explore) is installed from source; add in a later phase. POC discovery uses Hyperswarm first."

# --- 4. Node.js 18+ and npm (prefer asdf) ---
echo "[4/5] Node.js 18+ and npm"
install_node_linux() {
  ensure_asdf || true
  if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
    source_asdf
    asdf plugin add nodejs 2>/dev/null || true
    asdf install nodejs 20.18.0 2>/dev/null || asdf install nodejs latest 2>/dev/null || return 1
    INSTALLED=$(asdf list nodejs 2>/dev/null | grep -E '^  20\.' | tail -1 | xargs)
    [[ -z "$INSTALLED" ]] && INSTALLED=$(asdf list nodejs 2>/dev/null | tail -1 | xargs)
    asdf global nodejs "${INSTALLED:-20.18.0}" 2>/dev/null || true
    source_asdf
    command -v node &>/dev/null && return 0
  fi
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
source_asdf
if ! command -v node &>/dev/null; then
  echo "  Node not found. Installing (using asdf when possible)..."
  if ! install_node_linux; then
    echo ""
    echo "  FAILED: Could not install Node.js automatically."
    echo "  Install Node 18+ manually, then re-run this script:"
    echo "    asdf plugin add nodejs && asdf install nodejs 20 && asdf global nodejs 20.x.x"
    echo "  Or: sudo apt-get update && sudo apt-get install -y nodejs npm"
    echo ""
    exit 1
  fi
  source_asdf
fi
NODE_VER=$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo "0")
if [[ "${NODE_VER:-0}" -lt 18 ]]; then
  echo "  Node 18+ required; found $(node -v). Installing Node 20..."
  if ! install_node_linux; then
    echo ""
    echo "  FAILED: Could not upgrade Node. Install Node 18+ manually, then re-run this script."
    echo "    asdf install nodejs 20 && asdf global nodejs 20.x.x"
    echo ""
    exit 1
  fi
  source_asdf
fi
echo "  OK: Node $(node -v), npm $(npm -v 2>/dev/null)"

# --- 5. POC root and Hyperswarm ---
echo "[5/5] POC root and Hyperswarm"
source_asdf
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

# Add POC root to PATH so "opengateway" works (curl-only install; no repo on node)
add_path_to_shell() {
  local file="$1"
  local line="export PATH=\"$OPENGATEWAY_POC_ROOT:\$PATH\""
  [[ ! -f "$file" ]] && return
  if grep -qF "$OPENGATEWAY_POC_ROOT" "$file" 2>/dev/null; then
    return
  fi
  echo "" >> "$file"
  echo "# OpenGateway POC CLI" >> "$file"
  echo "$line" >> "$file"
  echo "  Added POC root to PATH in $file"
}
PROFILE_HOME="${HOME:-/root}"
[[ ! -f "$PROFILE_HOME/.profile" ]] && touch "$PROFILE_HOME/.profile"
add_path_to_shell "$PROFILE_HOME/.profile"
add_path_to_shell "$PROFILE_HOME/.bashrc"
[[ -f "$PROFILE_HOME/.zshrc" ]] && add_path_to_shell "$PROFILE_HOME/.zshrc"

# Optional: install wrapper into ~/.local/bin so "opengateway" is on PATH
BIN_DIR="${OPENGATEWAY_BIN_DIR:-${HOME:-/root}/.local/bin}"
mkdir -p "$BIN_DIR" 2>/dev/null || true
if [[ -d "$BIN_DIR" && -w "$BIN_DIR" ]]; then
  cat > "$BIN_DIR/opengateway" << BINWRAP
#!/usr/bin/env bash
export OPENGATEWAY_POC_ROOT="$OPENGATEWAY_POC_ROOT"
exec node "$OPENGATEWAY_POC_ROOT/cli.js" "\$@"
BINWRAP
  chmod +x "$BIN_DIR/opengateway" 2>/dev/null || true
  if [[ -x "$BIN_DIR/opengateway" ]]; then
    echo "  OK: CLI in $BIN_DIR/opengateway"
    if ! grep -qF "$BIN_DIR" "$PROFILE_HOME/.profile" 2>/dev/null; then
      echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$PROFILE_HOME/.profile"
    fi
  fi
else
  echo "  Note: could not write to $BIN_DIR (missing or not writable)"
fi

echo ""
echo "  For this shell, run:  export PATH=\"$OPENGATEWAY_POC_ROOT:\$PATH\""
echo "  Then: opengateway status"
echo "  (Or open a new login shell; PATH is set in .profile)"

# --- Phase 3: Gauge and join (poc-node) ---
echo ""
echo "Phase 3: Gauge resources and node"
if [[ -n "$REPO_ROOT" && -f "$SCRIPT_DIR/poc-node.js" ]]; then
  cp "$SCRIPT_DIR/poc-node.js" "$OPENGATEWAY_POC_ROOT/"
else
  curl -fsSL -o "$OPENGATEWAY_POC_ROOT/poc-node.js" "$REPO_RAW_URL/scripts/poc-node.js" || {
    echo "  Failed to download poc-node.js. Run from repo or set REPO_RAW_URL."
    exit 1
  }
fi
chmod +x "$OPENGATEWAY_POC_ROOT/poc-node.js"
if [[ -n "$REPO_ROOT" && -f "$SCRIPT_DIR/node-run.sh" ]]; then
  cp "$SCRIPT_DIR/node-run.sh" "$OPENGATEWAY_POC_ROOT/"
else
  curl -fsSL -o "$OPENGATEWAY_POC_ROOT/node-run.sh" "$REPO_RAW_URL/scripts/node-run.sh" || {
    echo "  Failed to download node-run.sh. Run from repo or set REPO_RAW_URL."
    exit 1
  }
fi
chmod +x "$OPENGATEWAY_POC_ROOT/node-run.sh"
if [[ -n "$REPO_ROOT" && -f "$SCRIPT_DIR/send-prompt.js" ]]; then
  cp "$SCRIPT_DIR/send-prompt.js" "$OPENGATEWAY_POC_ROOT/"
else
  curl -fsSL -o "$OPENGATEWAY_POC_ROOT/send-prompt.js" "$REPO_RAW_URL/scripts/send-prompt.js" || {
    echo "  Failed to download send-prompt.js. Run from repo or set REPO_RAW_URL."
    exit 1
  }
fi
chmod +x "$OPENGATEWAY_POC_ROOT/send-prompt.js"
# Gauge machine resources (Linux)
if command -v node &>/dev/null; then
  OPENGATEWAY_POC_ROOT="$OPENGATEWAY_POC_ROOT" node "$OPENGATEWAY_POC_ROOT/cli.js" gauge 2>/dev/null || true
fi
echo "  OK: poc-node.js + node-run.sh installed; resources gauged (see opengateway resources / eligible)"
echo "  To join cluster: $OPENGATEWAY_POC_ROOT/opengateway connect <cluster-id>   # e.g. gatewayai-poc"
echo "  Then start node: $OPENGATEWAY_POC_ROOT/node-run.sh   (or: opengateway start)"

echo ""
if [[ -x "$OPENGATEWAY_POC_ROOT/opengateway" ]]; then
  echo "Phase 1–3 complete. Run ./node-run.sh or 'opengateway start' to join the cluster and stay discoverable."
else
  echo "WARN: $OPENGATEWAY_POC_ROOT/opengateway missing or not executable. Install may have failed earlier (e.g. Node step); check output above."
fi
echo "  POC root: $OPENGATEWAY_POC_ROOT"
echo ""
