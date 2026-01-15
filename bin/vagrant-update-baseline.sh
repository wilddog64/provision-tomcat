#!/bin/bash
# Rebuild and re-register the baseline Windows 11 box with Tomcat 9.0.112 + Java 17.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_BOX="$ROOT_DIR/boxes/windows11-tomcat9.0.112-java17.box"
cd "$ROOT_DIR"

run_vagrant() {
  if command -v direnv >/dev/null 2>&1 && [[ -f .envrc ]]; then
    direnv exec . VAGRANT_VAGRANTFILE="$ROOT_DIR/Vagrantfile" "$@"
  else
    VAGRANT_VAGRANTFILE="$ROOT_DIR/Vagrantfile" "$@"
  fi
}

if [[ -f "$OUTPUT_BOX" ]]; then
  echo "Removing old box artifact $OUTPUT_BOX"
  rm -f "$OUTPUT_BOX"
fi

if vagrant box list | grep -q '^windows11-tomcat112 '; then
  echo "Removing previously registered box windows11-tomcat112"
  vagrant box remove -f windows11-tomcat112
fi

echo "Bringing base VM up (no provisioning)"
run_vagrant vagrant up --no-provision

echo "Running upgrade step 1 to lay down Tomcat 9.0.112 / Java 17"
run_vagrant vagrant provision --provision-with ansible_upgrade_step1

echo "Halting VM"
run_vagrant vagrant halt

echo "Packaging VM to $OUTPUT_BOX"
run_vagrant vagrant package --output "$OUTPUT_BOX"

echo "Registering box as windows11-tomcat112"
vagrant box add --name windows11-tomcat112 "$OUTPUT_BOX"

echo "Baseline box refreshed."
