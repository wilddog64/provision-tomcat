#!/bin/bash
# Drive the candidate upgrade using Vagrantfile-upgrade (baseline box).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAGRANTFILE_PATH="$ROOT_DIR/Vagrantfile-upgrade"
cd "$ROOT_DIR"

if [[ ! -f "$VAGRANTFILE_PATH" ]]; then
  echo "Vagrantfile-upgrade not found at $VAGRANTFILE_PATH" >&2
  exit 1
fi

run_vagrant() {
  local cmd=("$@")
  if command -v direnv >/dev/null 2>&1 && [[ -f .envrc ]]; then
    VAGRANT_VAGRANTFILE="$VAGRANTFILE_PATH" direnv exec . "${cmd[@]}"
  else
    VAGRANT_VAGRANTFILE="$VAGRANTFILE_PATH" "${cmd[@]}"
  fi
}

curl_check() {
  local port="$1"
  local desc="$2"
  echo "Checking ${desc} on http://localhost:${port} ..."
  curl --connect-timeout 5 --max-time 10 -f "http://localhost:${port}" >/dev/null 2>&1 || {
    echo "ERROR: ${desc} on port ${port} is not responding." >&2
    exit 1
  }
}

KEEP_VM=false
if [[ ${1-} == "--keep" ]]; then
  KEEP_VM=true
  shift
fi

echo "[1/5] Bringing baseline VM up (no provisioning) ..."
run_vagrant vagrant up --no-provision

echo "[2/5] Preparing candidate (step 2 with manual control) ..."
run_vagrant vagrant provision --provision-with ansible_upgrade_step2_prepare

echo "[3/5] Verifying from controller ports ..."
curl_check 8080 "primary Tomcat"
curl_check 9080 "candidate Tomcat"

read -r -p "Candidate port (9080) is live. Press Enter to promote and clean up..." _

echo "[4/5] Finalizing upgrade (promote + cleanup) ..."
run_vagrant vagrant provision --provision-with ansible_upgrade_step2_finalize

if ! $KEEP_VM; then
  echo "[5/5] Destroying VM (pass --keep to skip) ..."
  run_vagrant vagrant destroy -f
else
  echo "[5/5] Skipping destroy because --keep was passed."
fi

echo "Upgrade demo complete."
