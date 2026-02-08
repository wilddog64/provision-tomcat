#!/usr/bin/env bash
set -euo pipefail

# Default path to the ERB template
ERB_TEMPLATE="${BASH_SOURCE[0]%/*}/azure-sandbox.env.erb"
# Default output file
OUT_FILE="${BASH_SOURCE[0]%/*}/../scratch/azure-sandbox.env"

usage() {
  cat <<'EOF'
Usage: bin/azure-sandbox-env.sh [--auto-fill] [--login] [--write FILE] [--help] [VAR=VALUE ...]

Generates `scratch/azure-sandbox.env` with Azure sandbox credentials and settings.
Values are prioritized as: CLI arguments > existing environment variables > Azure CLI auto-detection > defaults.

Options:
  --auto-fill    Attempt to automatically detect Resource Group, VNet, etc. from Azure.
  --login        Force an `az login --use-device-code` even if already authenticated.
  --write FILE   Write exports to FILE instead of stdout (file is overwritten).
  --help         Show this help text and exit.
  VAR=VALUE      Override any variable (e.g., AZURE_LOCATION=eastus).

EOF
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

info() {
  printf 'INFO: %s\n' "$*" >&2
}

# Default values
AZURE_SUBSCRIPTION_ID=""
AZURE_TENANT_ID=""
AZURE_LOCATION="southcentralus"
AZURE_RESOURCE_GROUP=""
AZURE_VNET_NAME=""
AZURE_SUBNET_NAME=""
AZURE_NSG_NAME=""
AZURE_ADMIN_USERNAME="azureadmin"
AZURE_ADMIN_PASSWORD="ChangeM3!SecurePassword"
AZURE_VM_NAME="kqvm-win11"

FORCE_LOGIN=0
AUTO_FILL=0
declare -A overrides

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-fill)
      AUTO_FILL=1
      shift
      ;;
    --login)
      FORCE_LOGIN=1
      shift
      ;;
    --write)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --write requires a FILE argument" >&2
        exit 1
      fi
      OUT_FILE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *=*)
      key="${1%=*}"
      value="${1#*=}"
      overrides["$key"]="$value"
      shift
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v az >/dev/null 2>&1; then
  warn "Azure CLI (az) not found on PATH. Cannot auto-detect Azure settings."
  AUTO_FILL=0
fi

ensure_login() {
  if [[ $FORCE_LOGIN -eq 1 ]]; then
    info "Forcing Azure CLI login via device code..."
    az login --use-device-code >&2
    return 0
  fi

  if ! az account show >/dev/null 2>&1; then
    info "Azure CLI not authenticated. Launching device login..."
    az login --use-device-code >&2
  fi
}

fetch_account_field() {
  local query="$1"
  az account show --query "$query" -o tsv 2>/dev/null || echo ""
}

fetch_rg_field() {
  local rg_name="$1"
  local query="$2"
  az group show --name "$rg_name" --query "$query" -o tsv 2>/dev/null || echo ""
}

# Apply CLI overrides to variables
for key in "${!overrides[@]}"; do
  printf -v "$key" '%s' "${overrides[$key]}"
done

if [[ $AUTO_FILL -eq 1 ]]; then
  ensure_login
  AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(fetch_account_field 'id')}"
  AZURE_TENANT_ID="${AZURE_TENANT_ID:-$(fetch_account_field 'tenantId')}"

  if [[ -z "$AZURE_RESOURCE_GROUP" ]]; then
    AZURE_RESOURCE_GROUP="$(az group list --query "[?contains(name, 'playground-sandbox')].name" -o tsv 2>/dev/null | head -n 1 || echo "")"
    [[ -n "$AZURE_RESOURCE_GROUP" ]] && info "Auto-detected Resource Group: $AZURE_RESOURCE_GROUP"
  fi

  if [[ -n "$AZURE_RESOURCE_GROUP" ]]; then
    [[ -z "$AZURE_LOCATION" ]] && AZURE_LOCATION="$(fetch_rg_field "$AZURE_RESOURCE_GROUP" 'location')"
    if [[ -z "$AZURE_VNET_NAME" ]]; then
      AZURE_VNET_NAME="$(az network vnet list --resource-group "$AZURE_RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || echo "")"
      [[ -n "$AZURE_VNET_NAME" ]] && info "Auto-detected VNet: $AZURE_VNET_NAME"
    fi
    if [[ -n "$AZURE_VNET_NAME" && -z "$AZURE_SUBNET_NAME" ]]; then
      AZURE_SUBNET_NAME="$(az network vnet subnet list --resource-group "$AZURE_RESOURCE_GROUP" --vnet-name "$AZURE_VNET_NAME" --query "[0].name" -o tsv 2>/dev/null || echo "")"
      [[ -n "$AZURE_SUBNET_NAME" ]] && info "Auto-detected Subnet: $AZURE_SUBNET_NAME"
    fi
  fi
fi

# Final render using Ruby ERB
ruby_code=$(cat <<RUBY_EOF
require 'erb'
require 'ostruct'
require 'time'

scope = OpenStruct.new
scope.subscription_id = "$AZURE_SUBSCRIPTION_ID"
scope.tenant_id = "$AZURE_TENANT_ID"
scope.location = "$AZURE_LOCATION"
scope.resource_group = "$AZURE_RESOURCE_GROUP"
scope.vnet_name = "$AZURE_VNET_NAME"
scope.subnet_name = "$AZURE_SUBNET_NAME"
scope.nsg_name = "$AZURE_NSG_NAME"
scope.admin_username = "$AZURE_ADMIN_USERNAME"
scope.admin_password = "$AZURE_ADMIN_PASSWORD"
scope.vm_name = "$AZURE_VM_NAME"

template = File.read("$ERB_TEMPLATE")
renderer = ERB.new(template, nil, '-')
puts renderer.result(scope.instance_eval { binding })
RUBY_EOF
)

if [[ -n "$OUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUT_FILE")"
  ruby -e "$ruby_code" > "$OUT_FILE"
  info "Generated Azure environment file: $OUT_FILE"
else
  ruby -e "$ruby_code"
fi