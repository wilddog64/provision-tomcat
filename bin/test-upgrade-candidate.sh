#!/bin/bash
# Run the full candidate upgrade workflow: cleanup -> two-pass upgrade -> cleanup
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Tomcat Candidate Upgrade Test ==="

echo "1) Cleaning up any previous upgrade state..."
direnv exec . make candidate-cleanup-win11 >/dev/null || true

echo ""
echo "2) Running upgrade (step 1) + candidate workflow (step 2)..."
direnv exec . make test-upgrade-candidate-stack

echo ""
echo "Candidate workflow complete. Review scratch/ for logs."
