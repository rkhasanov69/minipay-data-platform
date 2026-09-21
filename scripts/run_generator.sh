#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PYTHON="venv/bin/python"
SCRIPT="$1"

echo "$(date '+%F %T') $SCRIPT start"
"$PYTHON" "scripts/$SCRIPT"
echo "$(date '+%F %T') $SCRIPT OK"
