#!/bin/bash
# Build a Vagrant box that already has Tomcat 9.0.112 + JDK 17 installed with D: drive.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_BOX="boxes/windows11-tomcat9.0.112-java17.box"
DISK_SIZE_GB="${VAGRANT_DISK_SIZE_GB:-50}"

run_cmd() {
  if command -v direnv >/dev/null 2>&1 && [[ -f .envrc ]]; then
    direnv exec . "$@"
  else
    "$@"
  fi
}

if [[ -f "$OUTPUT_BOX" ]]; then
  read -r -p "Box $OUTPUT_BOX already exists. Overwrite? [y/N] " answer
  case "$answer" in
    [Yy]*) rm -f "$OUTPUT_BOX" ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

# Clean up any existing disk file
rm -f .vagrant/data_disk.vdi

echo "==> Creating VM with ${DISK_SIZE_GB}GB D: drive..."
run_cmd vagrant up --no-provision

echo "==> Setting up D: drive..."
run_cmd vagrant provision --provision-with disk_setup

echo "==> Installing Tomcat and Java..."
run_cmd vagrant provision --provision-with ansible_upgrade_step1

echo "==> Packaging box..."
run_cmd vagrant halt

# Note: The secondary disk is NOT included in the packaged box by default.
# The box will have the D: drive configured but empty on first use.
run_cmd vagrant package --output "$OUTPUT_BOX"

cat <<MSG

Baseline box created: $OUTPUT_BOX

Add it via:
  vagrant box add windows11-tomcat112 "$OUTPUT_BOX"

Note: The D: drive configuration is included, but the disk itself is created
fresh on first 'vagrant up'. Run 'vagrant provision --provision-with disk_setup'
to initialize the D: drive on new instances.
MSG
