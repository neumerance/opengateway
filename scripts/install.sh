#!/usr/bin/env bash
# OpenGateway POC installer (Linux-only, system packages only)
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<org>/opengateway/main/scripts/install.sh | bash
#   ./scripts/install.sh

set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This installer is Linux-only for now."
  exit 1
fi

OPENGATEWAY_POC_ROOT="${OPENGATEWAY_POC_ROOT:-${HOME:-/root}/.opengateway-poc}"
REPO_RAW_URL="${REPO_RAW_URL:-https://raw.githubusercontent.com/opengateway/opengateway/main}"
PROFILE_HOME="${HOME:-/root}"

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || true)"
else
  SCRIPT_DIR=""
  REPO_ROOT=""
fi

echo "=============================================="
echo "  OpenGateway POC – Linux system installer"
echo "=============================================="
echo "  POC root: $OPENGATEWAY_POC_ROOT"
echo ""

run_as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

append_if_missing() {
  local file="$1"
  local needle="$2"
  local line="$3"
  [[ -f "$file" ]] || touch "$file"
  if ! grep -qF "$needle" "$file" 2>/dev/null; then
    echo "" >> "$file"
    echo "$line" >> "$file"
  fi
}

python_major_minor() {
  python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "0.0"
}

node_major() {
  node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo "0"
}

install_python_system() {
  if [[ -f /etc/debian_version ]]; then
    run_as_root apt-get update -qq
    run_as_root apt-get install -y python3 python3-pip python3-venv
    return 0
  fi
  if [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
    run_as_root dnf install -y python3 python3-pip || run_as_root yum install -y python3 python3-pip
    return 0
  fi
  return 1
}

install_node_system() {
  if [[ -f /etc/debian_version ]]; then
    run_as_root apt-get update -qq
    run_as_root apt-get install -y nodejs npm || true
    if [[ "$(node_major)" -lt 18 ]]; then
      curl -fsSL https://deb.nodesource.com/setup_20.x | run_as_root bash -
      run_as_root apt-get install -y nodejs
    fi
    return 0
  fi
  if [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
    run_as_root dnf install -y nodejs npm || run_as_root yum install -y nodejs npm || true
    if [[ "$(node_major)" -lt 18 ]]; then
      curl -fsSL https://rpm.nodesource.com/setup_20.x | run_as_root bash -
      run_as_root dnf install -y nodejs || run_as_root yum install -y nodejs
    fi
    return 0
  fi
  return 1
}

echo "[1/8] Ensure curl"
if ! command -v curl &>/dev/null; then
  if [[ -f /etc/debian_version ]]; then
    run_as_root apt-get update -qq
    run_as_root apt-get install -y curl
  elif [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
    run_as_root dnf install -y curl || run_as_root yum install -y curl
  else
    echo "  FAILED: curl missing and unsupported distro."
    exit 1
  fi
fi
echo "  OK: $(curl -sV 2>/dev/null | head -1 || true)"

echo "[2/8] Install Python 3.10+ and pip (system)"
if ! command -v python3 &>/dev/null; then
  install_python_system || { echo "  FAILED: could not install python3"; exit 1; }
fi
PY_MM="$(python_major_minor)"
PY_MAJ="${PY_MM%%.*}"
PY_MIN="${PY_MM##*.}"
if [[ "$PY_MAJ" -lt 3 ]] || { [[ "$PY_MAJ" -eq 3 ]] && [[ "$PY_MIN" -lt 10 ]]; }; then
  install_python_system || true
  PY_MM="$(python_major_minor)"
  PY_MAJ="${PY_MM%%.*}"
  PY_MIN="${PY_MM##*.}"
fi
if [[ "$PY_MAJ" -lt 3 ]] || { [[ "$PY_MAJ" -eq 3 ]] && [[ "$PY_MIN" -lt 10 ]]; }; then
  echo "  FAILED: Python 3.10+ required, found $PY_MM."
  exit 1
fi
if ! pip3 --version &>/dev/null; then
  python3 -m ensurepip --user 2>/dev/null || true
fi
if ! pip3 --version &>/dev/null; then
  install_python_system || true
fi
if ! pip3 --version &>/dev/null; then
  echo "  FAILED: pip3 unavailable."
  exit 1
fi
echo "  OK: Python $PY_MM"

echo "[3/8] Install Node.js 18+ and npm (system)"
if ! command -v node &>/dev/null; then
  install_node_system || { echo "  FAILED: could not install nodejs"; exit 1; }
fi
if [[ "$(node_major)" -lt 18 ]]; then
  install_node_system || true
fi
if [[ "$(node_major)" -lt 18 ]]; then
  echo "  FAILED: Node 18+ required, found $(node -v 2>/dev/null || echo unknown)."
  exit 1
fi
echo "  OK: Node $(node -v), npm $(npm -v)"

echo "[4/8] Install POC dependencies"
mkdir -p "$OPENGATEWAY_POC_ROOT"
cd "$OPENGATEWAY_POC_ROOT"
if [[ -n "$REPO_ROOT" && -f "$SCRIPT_DIR/package.json" ]]; then
  cp "$SCRIPT_DIR/package.json" "$OPENGATEWAY_POC_ROOT/"
else
  curl -fsSL -o "$OPENGATEWAY_POC_ROOT/package.json" "$REPO_RAW_URL/scripts/package.json"
fi
npm install --silent --no-fund --no-audit 2>/dev/null || npm install --no-fund --no-audit
echo "  OK: Hyperswarm installed"

echo "[5/8] Install OpenGateway CLI files"
for f in cli.js poc-node.js node-run.sh send-prompt.js; do
  if [[ -n "$REPO_ROOT" && -f "$SCRIPT_DIR/$f" ]]; then
    cp "$SCRIPT_DIR/$f" "$OPENGATEWAY_POC_ROOT/"
  else
    curl -fsSL -o "$OPENGATEWAY_POC_ROOT/$f" "$REPO_RAW_URL/scripts/$f"
  fi
  chmod +x "$OPENGATEWAY_POC_ROOT/$f" || true
done
cat > "$OPENGATEWAY_POC_ROOT/opengateway" << WRAP
#!/usr/bin/env bash
export OPENGATEWAY_POC_ROOT="$OPENGATEWAY_POC_ROOT"
exec node "$OPENGATEWAY_POC_ROOT/cli.js" "\$@"
WRAP
chmod +x "$OPENGATEWAY_POC_ROOT/opengateway"
[[ -f "$OPENGATEWAY_POC_ROOT/state.json" ]] || echo '{"clusters":[],"nodePid":null}' > "$OPENGATEWAY_POC_ROOT/state.json"
echo "  OK: CLI files installed to $OPENGATEWAY_POC_ROOT"

echo "[6/8] Install CLI to machine bin dir"
if [[ -w /usr/local/bin ]]; then
  BIN_DIR="/usr/local/bin"
else
  BIN_DIR="${OPENGATEWAY_BIN_DIR:-${PROFILE_HOME}/.local/bin}"
  mkdir -p "$BIN_DIR"
fi
cat > "$BIN_DIR/opengateway" << BINWRAP
#!/usr/bin/env bash
export OPENGATEWAY_POC_ROOT="$OPENGATEWAY_POC_ROOT"
exec node "$OPENGATEWAY_POC_ROOT/cli.js" "\$@"
BINWRAP
chmod +x "$BIN_DIR/opengateway"
echo "  OK: CLI in $BIN_DIR/opengateway"

echo "[7/8] Include CLI bin dir in machine PATH"
append_if_missing "$PROFILE_HOME/.profile" "$BIN_DIR" "export PATH=\"$BIN_DIR:\$PATH\""
append_if_missing "$PROFILE_HOME/.bashrc" "$BIN_DIR" "export PATH=\"$BIN_DIR:\$PATH\""
[[ -f "$PROFILE_HOME/.zshrc" ]] && append_if_missing "$PROFILE_HOME/.zshrc" "$BIN_DIR" "export PATH=\"$BIN_DIR:\$PATH\""
export PATH="$BIN_DIR:$PATH"
echo "  OK: PATH updated"

echo "[8/8] Gauge resources"
OPENGATEWAY_POC_ROOT="$OPENGATEWAY_POC_ROOT" node "$OPENGATEWAY_POC_ROOT/cli.js" gauge 2>/dev/null || true

echo ""
echo "Install complete."
echo "  POC root:  $OPENGATEWAY_POC_ROOT"
echo "  CLI bin:   $BIN_DIR/opengateway"
echo ""
echo "Run now:"
echo "  export PATH=\"$BIN_DIR:\$PATH\""
echo "  opengateway status"
echo ""
