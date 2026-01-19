#!/bin/bash
# Simple HTT Pcheck of Vagrant forwarded ports using curl.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAGRANTFILE_PATH="$ROOT_DIR/Vagrantfile-upgrade"
cd "$ROOT_DIR"

run_vagrant() {
  if command -v direnv >/dev/null 2>&1 && [[ -f .envrc ]]; then
    VAGRANT_VAGRANTFILE="$VAGRANTFILE_PATH" direnv exec . "$@"
  else
    VAGRANT_VAGRANTFILE="$VAGRANTFILE_PATH" "$@"
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

curl_check() {
  local port="$1"
  local desc="$2"
  echo "Checking ${desc} on http://localhost:${port} ..."
  curl --connect-timeout 5 --max-time 15 -f "http://localhost:${port}" >/dev/null
}

PRIMARY_PORT=$(get_host_port 8080)
CANDIDATE_PORT=$(get_host_port 9080)

curl_check "$PRIMARY_PORT" "primary Tomcat"
curl_check "$CANDIDATE_PORT" "candidate Tomcat"

