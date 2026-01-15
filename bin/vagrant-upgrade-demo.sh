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

get_host_port() {
  local guest_port="$1"
  local host_port
  host_port=$(run_vagrant vagrant port --machine-readable 2>/dev/null | awk -F, -v gp="$guest_port" '$3=="forwarded_port" && $4==gp {print $5; exit}')
  if [[ -z "$host_port" ]]; then
    host_port="$guest_port"
  fi
  printf '%s' "$host_port"
}

port_check() {
  local port="$1"
  local desc="$2"
  echo "Checking ${desc} on localhost:${port} ..."
  local attempts=0
  until nc -z localhost "$port" >/dev/null 2>&1; do
    attempts=$((attempts+1))
    if (( attempts >= 3 )); then
      echo "ERROR: ${desc} on port ${port} is not accepting TCP connections." >&2
      exit 1
    fi
    echo "  retry ${attempts}/3 ..."
    sleep 5
  done
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

echo "[3/5] Verifying candidate ports from controller ..."
PRIMARY_PORT=$(get_host_port 8080)
[[ -z "$PRIMARY_PORT" ]] && PRIMARY_PORT=8080
CANDIDATE_PORT=$(get_host_port 9080)
[[ -z "$CANDIDATE_PORT" ]] && CANDIDATE_PORT=9080
port_check "$PRIMARY_PORT" "primary Tomcat"
port_check "$CANDIDATE_PORT" "candidate Tomcat"

echo "Candidate port (9080) is live. Press Enter to promote and re-check..."
read -r _

echo "[4/6] Finalizing upgrade (promote + cleanup) ..."
run_vagrant vagrant provision --provision-with ansible_upgrade_step2_finalize

echo "[5/6] Verifying primary port after promotion ..."
PRIMARY_PORT=$(get_host_port 8080)
port_check "$PRIMARY_PORT" "primary Tomcat"

echo "[6/6] Final cleanup ..."
if ! $KEEP_VM; then
  run_vagrant vagrant destroy -f
else
  echo "Skipping destroy because --keep was passed."
fi

echo "Upgrade demo complete."
