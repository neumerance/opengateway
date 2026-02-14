#!/usr/bin/env bash
# OpenGateway POC – run node (join cluster via Hyperswarm).
# Usage: ./node-run.sh   (run from POC root, or set OPENGATEWAY_POC_ROOT)
set -e
ROOT="${OPENGATEWAY_POC_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
export OPENGATEWAY_POC_ROOT="$ROOT"
exec node "$ROOT/poc-node.js"
