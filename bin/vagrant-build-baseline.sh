#!/bin/bash
# Build a Vagrant box with D: drive, optionally with Tomcat + JDK pre-installed.
#
# Usage:
#   ./vagrant-build-baseline.sh              # Full: D: drive + Tomcat + Java
#   ./vagrant-build-baseline.sh --disk-only  # Minimal: D: drive only
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DISK_SIZE_GB="${VAGRANT_DISK_SIZE_GB:-50}"
DISK_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --disk-only|--minimal)
      DISK_ONLY=true
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build a Vagrant baseline box with D: drive.

Options:
  --disk-only, --minimal  Build minimal box with D: drive only (no Tomcat/Java)
  -h, --help              Show this help message

Environment variables:
  VAGRANT_DISK_SIZE_GB    Size of D: drive in GB (default: 50)
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Set output box name based on mode
if [[ "$DISK_ONLY" == "true" ]]; then
  OUTPUT_BOX="boxes/windows11-disk.box"
  BOX_NAME="windows11-disk"
else
  OUTPUT_BOX="boxes/windows11-tomcat9.0.112-java17.box"
  BOX_NAME="windows11-tomcat112"
fi

run_cmd() {
  if command -v direnv >/dev/null 2>&1 && [[ -f .envrc ]]; then
    direnv exec . "$@"
  else
    "$@"
  fi
}

mkdir -p "$(dirname "$OUTPUT_BOX")"

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

if [[ "$DISK_ONLY" == "false" ]]; then
  echo "==> Installing Tomcat and Java..."
  run_cmd vagrant provision --provision-with ansible_upgrade_step1
fi

echo "==> Packaging box..."
run_cmd vagrant halt

# Note: The secondary disk is NOT included in the packaged box by default.
# The box will have the D: drive configured but empty on first use.
run_cmd vagrant package --output "$OUTPUT_BOX"

cat <<MSG

Baseline box created: $OUTPUT_BOX

Add it via:
  vagrant box add $BOX_NAME "$OUTPUT_BOX"

Note: The D: drive configuration is included, but the disk itself is created
fresh on first 'vagrant up'. Run 'vagrant provision --provision-with disk_setup'
to initialize the D: drive on new instances.
MSG
