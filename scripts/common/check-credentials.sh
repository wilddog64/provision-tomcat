#!/usr/bin/env bash
set -euo pipefail
PROVIDER="${1:-aws}"
case "$PROVIDER" in
  aws)
    printf "=== Checking AWS Credentials ===\n" >&2
    if aws sts get-caller-identity > /dev/null 2>&1; then
      printf "AWS Credentials are valid.\n" >&2
    else
      printf "ERROR: AWS Credentials invalid or expired. Please run 'make sync-aws' manually.\n" >&2
      exit 1
    fi
    ;;
  *)
    printf "=== Checking %s Credentials ===\n" "$PROVIDER" >&2
    printf "ERROR: Credential check not implemented for provider: %s\n" "$PROVIDER" >&2
    exit 1
    ;;
esac
