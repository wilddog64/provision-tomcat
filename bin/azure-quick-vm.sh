#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bin/azure-quick-vm.sh [--name NAME] [--size VM_SIZE] [--image IMAGE] [--nsg-rule RULE] [--env FILE] [--keep]

Creates a short-lived Azure VM inside the current sandbox/company subscription using
the environment variables exported via bin/azure-sandbox-env.sh, prints connection
info, and (by default) deletes the VM and its NIC/PIP/OS disk before exiting.

Environment (required unless --env provides them):
  AZURE_SUBSCRIPTION_ID   Subscription GUID
  AZURE_RESOURCE_GROUP    Target resource group
  AZURE_LOCATION          Azure region (e.g., eastus)
  AZURE_ADMIN_USERNAME    Admin username to configure on the VM
  AZURE_ADMIN_PASSWORD    Admin password

Optional environment:
  AZURE_CONFIG_DIR        Custom Azure CLI config directory

Options:
  --name NAME   Set VM name (default: short Windows-safe ID like kqvm-1a2b)
  --size SIZE   Azure VM size (default: Standard_DS1_v2)
  --image IMG   Image URN/alias (default: Win2022Datacenter)
  --nsg-rule RULE  NSG rule to auto-open (default: RDP). Examples: RDP, SSH.
  --env FILE    Source environment exports from FILE (default: scratch/azure-sandbox.env)
  --keep        Do not delete the VM automatically (script prints cleanup commands)
  --help        Show this message
EOF
}

require_env() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: $var is required" >&2
    missing_env=1
  fi
}

info() {
  printf 'INFO: %s\n' "$*" >&2
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_ENV_FILE="$REPO_ROOT/scratch/azure-sandbox.env"

VM_NAME=""
VM_SIZE="Standard_DS1_v2"
VM_IMAGE="Win2022Datacenter"
NSG_RULE="RDP"
KEEP_VM=0
ENV_FILE="$DEFAULT_ENV_FILE"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      VM_NAME="$2"; shift 2;;
    --size)
      VM_SIZE="$2"; shift 2;;
    --image)
      VM_IMAGE="$2"; shift 2;;
    --keep)
      KEEP_VM=1; shift;;
    --env)
      ENV_FILE="$2"; shift 2;;
    --nsg-rule)
      NSG_RULE="$2"; shift 2;;
    --help|-h)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2
      usage; exit 1;;
  esac
done

if [[ -n "$ENV_FILE" ]]; then
  if [[ -f "$ENV_FILE" ]]; then
    info "Sourcing environment from $ENV_FILE"
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  else
    warn "Env file $ENV_FILE not found; relying on current environment."
  fi
fi

missing_env=0
require_env AZURE_SUBSCRIPTION_ID
require_env AZURE_RESOURCE_GROUP
require_env AZURE_LOCATION
require_env AZURE_ADMIN_USERNAME
require_env AZURE_ADMIN_PASSWORD

if [[ $missing_env -eq 1 ]]; then
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "ERROR: Azure CLI (az) not found" >&2
  exit 1
fi

if [[ -z "$VM_NAME" ]]; then
  rand_suffix="$(printf '%04x' $((RANDOM % 65536)))"
  timestamp="$(date -u +%H%M)"
  VM_NAME="kqvm-${timestamp}${rand_suffix}"
  # Ensure Windows computer name limit (<=15 chars)
  VM_NAME="${VM_NAME:0:15}"
fi

SUBSCRIPTION="$AZURE_SUBSCRIPTION_ID"
RESOURCE_GROUP="$AZURE_RESOURCE_GROUP"
LOCATION="$AZURE_LOCATION"
ADMIN_USER="$AZURE_ADMIN_USERNAME"
ADMIN_PASS="$AZURE_ADMIN_PASSWORD"

info "Setting Azure subscription to $SUBSCRIPTION"
az account set --subscription "$SUBSCRIPTION" >/dev/null

TMP_JSON="$(mktemp)"
cleanup_tmp() {
  rm -f "$TMP_JSON"
}
trap cleanup_tmp EXIT

info "Creating VM $VM_NAME in $RESOURCE_GROUP ($LOCATION)"
az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --location "$LOCATION" \
  --size "$VM_SIZE" \
  --image "$VM_IMAGE" \
  --admin-username "$ADMIN_USER" \
  --admin-password "$ADMIN_PASS" \
  --authentication-type password \
  --nsg-rule "$NSG_RULE" \
  --public-ip-sku Standard \
  --output json >"$TMP_JSON"

parse_json() {
  local key="$1"
  python3 - "$TMP_JSON" "$key" <<'PY'
import json, sys
path = sys.argv[2]
with open(sys.argv[1]) as fh:
    data = json.load(fh)
parts = path.split(".")
value = data
for part in parts:
    if part.endswith("]"):
        name, index = part[:-1].split("[")
        value = value[name][int(index)]
    else:
        value = value[part]
print(value if value is not None else "")
PY
}

OS_DISK_NAME="$(parse_json 'storageProfile.osDisk.name')"
NIC_ID="$(parse_json 'networkProfile.networkInterfaces[0].id')"
NIC_NAME="${NIC_ID##*/}"
PUBLIC_IP="$(parse_json 'publicIpAddress')"

info "VM ready: $VM_NAME"
echo "Public IP: $PUBLIC_IP"
echo "Admin user: $ADMIN_USER"

info "Retrieving Public IP resource id"
PUBLIC_IP_ID="$(az network nic show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NIC_NAME" \
  --query 'ipConfigurations[0].publicIpAddress.id' -o tsv 2>/dev/null || true)"

delete_vm_resources() {
  info "Deleting VM $VM_NAME (force-deletion yes)"
  az vm delete \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --yes \
    --force-deletion yes >/dev/null || warn "vm delete reported an error"

  if [[ -n "$NIC_ID" ]]; then
    az resource delete --ids "$NIC_ID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$PUBLIC_IP_ID" ]]; then
    az resource delete --ids "$PUBLIC_IP_ID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$OS_DISK_NAME" ]]; then
    az disk delete \
      --resource-group "$RESOURCE_GROUP" \
      --name "$OS_DISK_NAME" \
      --yes >/dev/null 2>&1 || true
  fi
}

if [[ $KEEP_VM -eq 1 ]]; then
  warn "Keeping VM $VM_NAME running. Remember to delete it manually when finished."
  echo "Suggested cleanup commands:"
  echo "  az vm delete --resource-group $RESOURCE_GROUP --name $VM_NAME --yes --force-deletion yes"
  if [[ -n "$NIC_ID" ]]; then
    echo "  az resource delete --ids $NIC_ID"
  fi
  if [[ -n "$PUBLIC_IP_ID" ]]; then
    echo "  az resource delete --ids $PUBLIC_IP_ID"
  fi
  if [[ -n "$OS_DISK_NAME" ]]; then
    echo "  az disk delete --resource-group $RESOURCE_GROUP --name $OS_DISK_NAME --yes"
  fi
  exit 0
fi

read -r -p "Delete VM now? [Y/n] (use --keep to skip this prompt) " answer
case "$answer" in
  n|N) warn "Leaving VM running. Re-run with --keep next time if you want to skip this prompt."; exit 0;;
  *) delete_vm_resources;;
esac

info "Done."
