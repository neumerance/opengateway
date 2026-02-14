#!/usr/bin/env bash
# OpenGateway POC uninstaller (Linux only)
# Removes: OpenGateway CLI files, POC root, asdf, Node.js/npm.
# Python cleanup defaults to pip/venv only; use --remove-system-python to remove python3 itself.
#
# Usage:
#   ./scripts/uninstall.sh
#   ./scripts/uninstall.sh --yes
#   ./scripts/uninstall.sh --yes --remove-system-python

set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This uninstaller is Linux-only."
  exit 1
fi

PROFILE_HOME="${HOME:-/root}"
OPENGATEWAY_POC_ROOT="${OPENGATEWAY_POC_ROOT:-${PROFILE_HOME}/.opengateway-poc}"
REMOVE_SYSTEM_PYTHON=0
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      ASSUME_YES=1
      shift
      ;;
    --remove-system-python)
      REMOVE_SYSTEM_PYTHON=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--yes|-y] [--remove-system-python]"
      exit 1
      ;;
  esac
done

run_as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

remove_line_matches() {
  local file="$1"
  local pattern="$2"
  [[ -f "$file" ]] || return 0
  run_as_root sed -i "/$pattern/d" "$file"
}

echo "=============================================="
echo "  OpenGateway POC – Uninstall"
echo "=============================================="
echo "Home:      $PROFILE_HOME"
echo "POC root:  $OPENGATEWAY_POC_ROOT"
echo ""
echo "Planned cleanup:"
echo "- OpenGateway CLI binaries (/usr/local/bin/opengateway, ~/.local/bin/opengateway)"
echo "- OpenGateway POC root ($OPENGATEWAY_POC_ROOT)"
echo "- asdf (~/.asdf) and asdf profile lines"
echo "- Node.js/npm system packages (apt/dnf/yum)"
if [[ "$REMOVE_SYSTEM_PYTHON" -eq 1 ]]; then
  echo "- Python system packages including python3 (requested)"
else
  echo "- Python helper packages only (python3-pip/python3-venv)"
fi
echo ""

if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -r -p "Proceed? [y/N] " confirm
  case "${confirm:-}" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

echo ""
echo "[1/6] Remove OpenGateway CLI binaries"
run_as_root rm -f /usr/local/bin/opengateway || true
rm -f "${PROFILE_HOME}/.local/bin/opengateway" || true
echo "  OK"

echo "[2/6] Remove OpenGateway POC root"
rm -rf "$OPENGATEWAY_POC_ROOT" || true
echo "  OK"

echo "[3/6] Remove asdf and profile hooks"
rm -rf "${PROFILE_HOME}/.asdf" || true
remove_line_matches "${PROFILE_HOME}/.profile" '\.asdf/asdf\.sh'
remove_line_matches "${PROFILE_HOME}/.bashrc" '\.asdf/asdf\.sh'
remove_line_matches "${PROFILE_HOME}/.zshrc" '\.asdf/asdf\.sh'
echo "  OK"

echo "[4/6] Remove OpenGateway PATH entries"
remove_line_matches "${PROFILE_HOME}/.profile" 'opengateway-poc'
remove_line_matches "${PROFILE_HOME}/.bashrc" 'opengateway-poc'
remove_line_matches "${PROFILE_HOME}/.zshrc" 'opengateway-poc'
echo "  OK"

echo "[5/6] Remove Node.js/npm packages"
if [[ -f /etc/debian_version ]]; then
  run_as_root apt-get remove -y nodejs npm || true
  run_as_root apt-get autoremove -y || true
elif [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
  run_as_root dnf remove -y nodejs npm || run_as_root yum remove -y nodejs npm || true
else
  echo "  Unknown distro; skipped package removal."
fi
echo "  OK"

echo "[6/6] Remove Python helper/system packages"
if [[ -f /etc/debian_version ]]; then
  if [[ "$REMOVE_SYSTEM_PYTHON" -eq 1 ]]; then
    run_as_root apt-get remove -y python3 python3-pip python3-venv || true
  else
    run_as_root apt-get remove -y python3-pip python3-venv || true
  fi
  run_as_root apt-get autoremove -y || true
elif [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
  if [[ "$REMOVE_SYSTEM_PYTHON" -eq 1 ]]; then
    run_as_root dnf remove -y python3 python3-pip || run_as_root yum remove -y python3 python3-pip || true
  else
    run_as_root dnf remove -y python3-pip || run_as_root yum remove -y python3-pip || true
  fi
else
  echo "  Unknown distro; skipped package removal."
fi
echo "  OK"

echo ""
echo "Uninstall complete."
echo "Open a new shell to refresh PATH."
echo ""
