#!/usr/bin/env bash
set -euo pipefail

# Default path to the ERB template and output file
ERB_TEMPLATE="${BASH_SOURCE[0]%/*}/../scratch/azure-sandbox.env.erb"
OUT_FILE="${BASH_SOURCE[0]%/*}/../scratch/azure-sandbox.env"

usage() {
  cat <<'EOF'
Usage: bin/azure-sandbox-env.sh [--auto-fill] [--login] [--help] [VAR=VALUE ...]

Generates `scratch/azure-sandbox.env` with Azure sandbox credentials and settings.
Values are prioritized as: CLI arguments > existing environment variables > Azure CLI auto-detection > defaults.

Options:
  --auto-fill    Attempt to automatically detect Resource Group, VNet, etc. from Azure.
  --login        Force an `az login --use-device-code` even if already authenticated.
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
AZURE_LOCATION="southcentralus" # Default for ACG sandbox
AZURE_RESOURCE_GROUP=""
AZURE_VNET_NAME=""
AZURE_SUBNET_NAME=""
AZURE_NSG_NAME=""
AZURE_ADMIN_USERNAME="azureadmin" # Default for ACG Windows VMs
AZURE_ADMIN_PASSWORD="ChangeM3!SecurePassword" # Default for ACG Windows VMs

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
    --help|-h)
      usage
      exit 0
      ;;
    *=*)
      # Store overrides
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
    az login --use-device-code >/dev/null
    return 0
  fi

  if ! az account show >/dev/null 2>&1; then
    info "Azure CLI not authenticated. Launching device login..."
    az login --use-device-code >/dev/null
  fi
}

fetch_account_field() {
  local query="$1"
  if ! az account show >/dev/null 2>&1; then # Check auth every time for safety
    return 0
  fi
  az account show --query "$query" -o tsv 2>/dev/null || true
}

fetch_rg_field() {
  local rg_name="$1"
  local query="$2"
  if ! az account show >/dev/null 2>&1; then
    return 0
  fi
  # Use the sandbox RG if --auto-fill, otherwise use the provided one
  az group show --name "$rg_name" --query "$query" -o tsv 2>/dev/null || true
}


# Prioritize: Overrides > Env Vars > Auto-fill > Defaults
# Apply existing env vars
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$subscription_id}"
AZURE_TENANT_ID="${AZURE_TENANT_ID:-$tenant_id}"
AZURE_LOCATION="${AZURE_LOCATION:-$location}"
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-$resource_group}"
AZURE_VNET_NAME="${AZURE_VNET_NAME:-$vnet_name}"
AZURE_SUBNET_NAME="${AZURE_SUBNET_NAME:-$subnet_name}"
AZURE_NSG_NAME="${AZURE_NSG_NAME:-$nsg_name}"
AZURE_ADMIN_USERNAME="${AZURE_ADMIN_USERNAME:-$admin_username}"
AZURE_ADMIN_PASSWORD="${AZURE_ADMIN_PASSWORD:-$admin_password}"

# Apply CLI arguments (overrides everything else)
for key in "${!overrides[@]}"; do
  printf -v "$key" '%s' "${overrides[$key]}"
done

# Auto-fill from Azure CLI if requested and not already set
if [[ $AUTO_FILL -eq 1 ]]; then
  ensure_login

  AZURE_SUBSCRIPTION_ID="$(fetch_account_field 'id' || echo "$AZURE_SUBSCRIPTION_ID")"
  AZURE_TENANT_ID="$(fetch_account_field 'tenantId' || echo "$AZURE_TENANT_ID")"

  # Find a playground sandbox RG
  if [[ -z "$AZURE_RESOURCE_GROUP" ]]; then
    AZURE_RESOURCE_GROUP="$(az group list --query "[?contains(name, 'playground-sandbox')].name" -o tsv 2>/dev/null | head -n 1 || echo "")"
    if [[ -z "$AZURE_RESOURCE_GROUP" ]]; then
      warn "Could not auto-detect a 'playground-sandbox' resource group."
    else
      info "Auto-detected Resource Group: $AZURE_RESOURCE_GROUP"
    fi
  fi

  # Auto-detect location from the chosen RG
  if [[ -n "$AZURE_RESOURCE_GROUP" && -z "$AZURE_LOCATION" ]]; then
    AZURE_LOCATION="$(fetch_rg_field "$AZURE_RESOURCE_GROUP" 'location' || echo "$AZURE_LOCATION")"
    if [[ -n "$AZURE_LOCATION" ]]; then
      info "Auto-detected Location from RG: $AZURE_LOCATION"
    fi
  fi

  # Auto-detect VNet/Subnet/NSG if they exist within the RG
  if [[ -n "$AZURE_RESOURCE_GROUP" ]]; then
    if [[ -z "$AZURE_VNET_NAME" ]]; then
      AZURE_VNET_NAME="$(az network vnet list --resource-group "$AZURE_RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || echo "$AZURE_VNET_NAME")"
      if [[ -n "$AZURE_VNET_NAME" ]]; then
        info "Auto-detected VNet: $AZURE_VNET_NAME"
      fi
    fi
    if [[ -n "$AZURE_VNET_NAME" && -z "$AZURE_SUBNET_NAME" ]]; then
      AZURE_SUBNET_NAME="$(az network vnet subnet list --resource-group "$AZURE_RESOURCE_GROUP" --vnet-name "$AZURE_VNET_NAME" --query "[0].name" -o tsv 2>/dev/null || echo "$AZURE_SUBNET_NAME")"
      if [[ -n "$AZURE_SUBNET_NAME" ]]; then
        info "Auto-detected Subnet: $AZURE_SUBNET_NAME"
      fi
    fi
    if [[ -z "$AZURE_NSG_NAME" ]]; then
      AZURE_NSG_NAME="$(az network nsg list --resource-group "$AZURE_RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || echo "$AZURE_NSG_NAME")"
      if [[ -n "$AZURE_NSG_NAME" ]]; then
        info "Auto-detected NSG: $AZURE_NSG_NAME"
      fi
    fi
  fi
fi

# Prepare data for ERB
ruby_code=$(cat <<RUBY_EOF
require 'erb'
require 'ostruct'
require 'time'

# Create an OpenStruct to hold the variables for ERB
scope = OpenStruct.new
scope.subscription_id = ENV.fetch('AZURE_SUBSCRIPTION_ID', "$AZURE_SUBSCRIPTION_ID")
scope.tenant_id = ENV.fetch('AZURE_TENANT_ID', "$AZURE_TENANT_ID")
scope.location = ENV.fetch('AZURE_LOCATION', "$AZURE_LOCATION")
scope.resource_group = ENV.fetch('AZURE_RESOURCE_GROUP', "$AZURE_RESOURCE_GROUP")
scope.vnet_name = ENV.fetch('AZURE_VNET_NAME', "$AZURE_VNET_NAME")
scope.subnet_name = ENV.fetch('AZURE_SUBNET_NAME', "$AZURE_SUBNET_NAME")
scope.nsg_name = ENV.fetch('AZURE_NSG_NAME', "$AZURE_NSG_NAME")
scope.admin_username = ENV.fetch('AZURE_ADMIN_USERNAME', "$AZURE_ADMIN_USERNAME")
scope.admin_password = ENV.fetch('AZURE_ADMIN_PASSWORD', "$AZURE_ADMIN_PASSWORD")

# Define the template content
template = File.read("$ERB_TEMPLATE")

# Render the template
renderer = ERB.new(template, nil, '%-')
puts renderer.result(scope.instance_eval { binding })
RUBY_EOF
)

# Render the ERB template using Ruby and write to OUT_FILE
if command -v ruby >/dev/null 2>&1; then
  ruby -r json -e "$ruby_code" > "$OUT_FILE"
  info "Generated Azure environment file: $OUT_FILE"
else
  warn "Ruby not found. Cannot render ERB template. Please install Ruby."
  exit 1
fi
