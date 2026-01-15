#!/bin/bash
# Run the two-step upgrade (with candidate) via Vagrant provisioners and verify ports.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_cmd() {
  if command -v direnv >/dev/null 2>&1 && [[ -f .envrc ]]; then
    direnv exec . "$@"
  else
    "$@"
  fi
}

curl_check() {
  local port="$1"
  local desc="$2"
  echo "Checking ${desc} on http://localhost:${port} ..."
  if ! curl --connect-timeout 5 --max-time 10 -f "http://localhost:${port}" >/dev/null 2>&1; then
    echo "ERROR: ${desc} on port ${port} is not responding." >&2
    exit 1
  fi
}

printf "[1/4] Bringing Vagrant VM up (no provisioning) ...\n"
run_cmd vagrant up --no-provision

printf "[2/4] Running upgrade step 1 (Tomcat 9.0.112 / Java 17) ...\n"
run_cmd vagrant provision --provision-with ansible_upgrade_step1

printf "[3/5] Running upgrade step 2 (candidate prepare) ...\n"
run_cmd vagrant provision --provision-with ansible_upgrade_step2_prepare

printf "[4/5] Running controller-side HTTP checks.\n"
curl_check 8080 "primary Tomcat"
curl_check 9080 "candidate Tomcat"

read -r -p "Candidate port (9080) responded successfully. Press Enter to promote/cleanup..." _

printf "[5/5] Finalizing upgrade (promote + cleanup) ...\n"
run_cmd vagrant provision --provision-with ansible_upgrade_step2_finalize

echo "Candidate promotion complete. Primary Tomcat restarted on port 8080."
