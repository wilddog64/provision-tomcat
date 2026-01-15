#!/bin/bash
# Build a Vagrant box that already has Tomcat 9.0.112 + JDK 17 installed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_BOX="boxes/windows11-tomcat9.0.112-java17.box"

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

run_cmd vagrant up --no-provision
run_cmd vagrant provision --provision-with ansible_upgrade_step1
run_cmd vagrant halt
run_cmd vagrant package --output "$OUTPUT_BOX"

cat <<MSG
Baseline box created: $OUTPUT_BOX
Add it via:
  vagrant box add windows11-tomcat112 "$OUTPUT_BOX"
MSG
