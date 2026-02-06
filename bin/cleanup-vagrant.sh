#!/usr/bin/env bash
# Robust cleanup script for stale Vagrant/Kitchen/VirtualBox instances
# Specifically designed for self-hosted CI runners.

set -uo pipefail

PROJECT_PATTERN="provision-tomcat"
KITCHEN_PATTERN="kitchen-provision-tomcat"

echo "=== Starting Robust Cleanup for ${PROJECT_PATTERN} ==="

# 1. Kill stuck processes
echo "Checking for stuck processes..."
PIDS=$(ps aux | grep -E "VBoxHeadless|ansible-playbook|kitchen" | grep "${PROJECT_PATTERN}" | grep -v grep | awk '{print $2}' || true)

if [[ -n "$PIDS" ]]; then
  echo "Killing stuck PIDs: $PIDS"
  kill -9 $PIDS 2>/dev/null || true
  sleep 2
else
  echo "No matching stuck processes found."
fi

# 2. Cleanup VirtualBox VMs
echo "Checking for registered VirtualBox VMs..."
VMS=$(VBoxManage list vms | grep -E "${KITCHEN_PATTERN}|${PROJECT_PATTERN}" | awk -F'"' '{print $2}' || true)

for VM in $VMS; do
  echo "Cleaning up VM: $VM"
  # Try graceful shutdown if it's running (rare in cleanup but good practice)
  if VBoxManage showvminfo "$VM" 2>/dev/null | grep -q "State:.*running"; then
    echo "  Powering off $VM..."
    VBoxManage controlvm "$VM" poweroff 2>/dev/null || true
    sleep 2
  fi
  echo "  Unregistering and deleting $VM..."
  VBoxManage unregistervm "$VM" --delete 2>/dev/null || true
done

# 3. Cleanup Inaccessible VMs
echo "Checking for inaccessible VirtualBox VMs..."
INACCESSIBLE_VMS=$(VBoxManage list vms | grep "<inaccessible>" | awk -F'{' '{print $2}' | tr -d '}' || true)
for UUID in $INACCESSIBLE_VMS; do
  echo "  Removing inaccessible VM UUID: $UUID"
  VBoxManage unregistervm "$UUID" 2>/dev/null || true
done

# 4. Cleanup stale disk registrations
if [[ -f "./bin/vbox-cleanup-disks" ]]; then
  echo "Cleaning up stale disk registrations..."
  ./bin/vbox-cleanup-disks || true
fi

# 5. Prune Vagrant global status
if command -v vagrant >/dev/null 2>&1; then
  echo "Pruning Vagrant global status..."
  vagrant global-status --prune >/dev/null 2>&1 || true
fi

# 6. Purge Kitchen state
if [[ -d ".kitchen" ]]; then
  echo "Purging .kitchen state directory..."
  rm -rf .kitchen
fi

echo "=== Cleanup Complete ==="
