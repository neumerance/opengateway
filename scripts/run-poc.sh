#!/usr/bin/env bash
# OpenGateway POC runner - simple script to curl and execute.
# Usage: curl -fsSL https://raw.githubusercontent.com/.../run-poc.sh | bash
#    or: curl -fsSL <url> -o run-poc.sh && chmod +x run-poc.sh && ./run-poc.sh

set -e

POC_CLUSTER_ID="${POC_CLUSTER_ID:-gatewayai-poc}"
if [[ -n "${BASH_SOURCE[0]}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  SCRIPT_DIR="$(pwd)"
  REPO_ROOT="${REPO_ROOT:-$(pwd)}"
fi

echo "=============================================="
echo "  OpenGateway POC - GatewayAI"
echo "=============================================="
echo ""
echo "Cluster ID (POC): $POC_CLUSTER_ID"
echo "Repo root:       $REPO_ROOT"
echo ""

# Phase 1 checks
echo "--- Phase 1: Environment ---"
need_ok=0

if command -v go &>/dev/null; then
  echo "  [OK] go: $(go version 2>/dev/null | head -1)"
else
  echo "  [--] go: not found (optional for POC)"
fi

if command -v python3 &>/dev/null; then
  echo "  [OK] python3: $(python3 --version 2>/dev/null)"
else
  echo "  [--] python3: not found (optional for POC)"
fi

if command -v curl &>/dev/null; then
  echo "  [OK] curl: $(curl --version 2>/dev/null | head -1)"
else
  echo "  [!!] curl: not found"
  need_ok=1
fi

if [ "$need_ok" -eq 1 ]; then
  echo ""
  echo "Install missing tools and run again."
  exit 1
fi

echo ""
echo "--- POC phases (see docs/BUILDING_POC.md) ---"
echo "  Phase 1: Environment & cluster identity"
echo "  Phase 2: NodeA - first node joins cluster"
echo "  Phase 3: NodeB - second node (other location) joins"
echo "  Phase 4: NodeC - third node joins and sends prompt"
echo "  Phase 5: Validate & document"
echo ""
echo "Next: implement node process and use cluster ID: $POC_CLUSTER_ID"
echo "Doc:  $REPO_ROOT/docs/BUILDING_POC.md"
echo ""
