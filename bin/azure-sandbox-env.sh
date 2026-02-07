#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bin/azure-sandbox-env.sh [--write FILE] [--login] [--help]

Helper for ACG/Pluralsight Azure sandbox sessions. The script:
  1. Ensures Azure CLI is available and (if needed) triggers `az login --use-device-code`.
  2. Prompts for sandbox-specific values (resource group, VNet/subnet, admin user/password).
  3. Emits `export` statements you can eval or write to a file with --write FILE.

Environment variables already set in your shell are used as defaults for each prompt.

Options:
  --write FILE   Write exports to FILE instead of stdout (file is overwritten).
  --login        Force an `az login --use-device-code` even if already authenticated.
  --help         Show this help text and exit.
EOF
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

info() {
  printf 'INFO: %s\n' "$*" >&2
}

prompt_value() {
  local __var_name="$1"
  local __prompt="$2"
  local __default="$3"
  local __current="${!__var_name:-}"
  local __effective="${__current:-$__default}"
  local __input

  if [[ -n "$__effective" ]]; then
    read -r -p "$__prompt [$__effective]: " __input
  else
    read -r -p "$__prompt: " __input
  fi

  if [[ -z "$__input" ]]; then
    __input="$__effective"
  fi

  printf -v "$__var_name" '%s' "$__input"
}

prompt_secret() {
  local __var_name="$1"
  local __prompt="$2"
  local __default_masked=""
  if [[ -n "${!__var_name:-}" ]]; then
    __default_masked="****"
  fi

  local __input
  if [[ -n "$__default_masked" ]]; then
    read -r -s -p "$__prompt [$__default_masked]: " __input
  else
    read -r -s -p "$__prompt: " __input
  fi
  echo

  if [[ -z "$__input" ]]; then
    __input="${!__var_name:-}"
  fi

  printf -v "$__var_name" '%s' "$__input"
}

OUT_FILE=""
FORCE_LOGIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write|-w)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --write requires a FILE argument" >&2
        exit 1
      fi
      OUT_FILE="$2"
      shift 2
      ;;
    --login)
      FORCE_LOGIN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$OUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUT_FILE")"
fi

have_az=1
if ! command -v az >/dev/null 2>&1; then
  have_az=0
  warn "Azure CLI (az) not found on PATH; subscription/tenant defaults will be blank."
fi

ensure_login() {
  [[ $have_az -eq 1 ]] || return 0

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
  if [[ $have_az -eq 0 ]]; then
    return 0
  fi

  az account show --query "$query" -o tsv 2>/dev/null || true
}

subscription_id="${AZURE_SUBSCRIPTION_ID:-}"
tenant_id="${AZURE_TENANT_ID:-}"
location="${AZURE_LOCATION:-eastus}"
resource_group="${AZURE_RESOURCE_GROUP:-}"
vnet_name="${AZURE_VNET_NAME:-}"
subnet_name="${AZURE_SUBNET_NAME:-}"
nsg_name="${AZURE_NSG_NAME:-}"
admin_username="${AZURE_ADMIN_USERNAME:-}"
admin_password="${AZURE_ADMIN_PASSWORD:-}"

ensure_login

if [[ -z "$subscription_id" ]]; then
  subscription_id="$(fetch_account_field 'id')"
fi

if [[ -z "$tenant_id" ]]; then
  tenant_id="$(fetch_account_field 'tenantId')"
fi

prompt_value subscription_id "Azure subscription ID" "$subscription_id"
prompt_value tenant_id "Azure tenant ID" "$tenant_id"
prompt_value location "Azure location/region" "$location"
prompt_value resource_group "Sandbox resource group" "$resource_group"
prompt_value vnet_name "Sandbox virtual network name" "$vnet_name"
prompt_value subnet_name "Sandbox subnet name" "$subnet_name"
prompt_value nsg_name "Sandbox network security group name" "$nsg_name"
prompt_value admin_username "Admin username for sandbox VMs" "$admin_username"
prompt_secret admin_password "Admin password for sandbox VMs"

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

emit_exports() {
  local target="$1"
  {
    echo "# Azure sandbox env exports generated $timestamp"
    printf 'export %s=%q\n' "AZURE_SUBSCRIPTION_ID" "$subscription_id"
    printf 'export %s=%q\n' "AZURE_TENANT_ID" "$tenant_id"
    printf 'export %s=%q\n' "AZURE_LOCATION" "$location"
    printf 'export %s=%q\n' "AZURE_RESOURCE_GROUP" "$resource_group"
    printf 'export %s=%q\n' "AZURE_VNET_NAME" "$vnet_name"
    printf 'export %s=%q\n' "AZURE_SUBNET_NAME" "$subnet_name"
    printf 'export %s=%q\n' "AZURE_NSG_NAME" "$nsg_name"
    printf 'export %s=%q\n' "AZURE_ADMIN_USERNAME" "$admin_username"
    printf 'export %s=%q\n' "AZURE_ADMIN_PASSWORD" "$admin_password"
  } >"$target"
}

if [[ -n "$OUT_FILE" ]]; then
  tmp="$(mktemp)"
  emit_exports "$tmp"
  mv "$tmp" "$OUT_FILE"
  info "Wrote Azure exports to $OUT_FILE"
  info "Source it with: source $OUT_FILE"
else
  emit_exports /dev/stdout
fi
