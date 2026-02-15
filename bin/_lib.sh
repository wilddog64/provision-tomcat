#!/usr/bin/env bash
# Shared helpers — source this, do not execute.

info() { echo "--> $*" >&2; }
warn() { echo "    WARN: $*" >&2; }
err()  { echo "    ERROR: $*" >&2; exit 1; }

require_var() {
    [[ -n "${!1:-}" ]] || err "$1 is required but not set"
}

get_vault_token() {
    local ns="${VAULT_NS:-vault}"
    local token
    token=$(kubectl get secret vault-root -n "$ns" \
        -o jsonpath='{.data.root_token}' 2>/dev/null | base64 -d)
    [[ -n "$token" ]] || err "Could not retrieve Vault root token"
    echo "$token"
}

vault_kv_exec() {
    local ns="${VAULT_NS:-vault}" pod="${VAULT_POD:-vault-0}"
    local token; token=$(get_vault_token)
    kubectl exec -n "$ns" "$pod" -- \
        sh -c "VAULT_TOKEN=$token vault kv get $*" 2>/dev/null
}
