#!/usr/bin/env bash
set -euo pipefail

_usage() {
  printf 'Usage: %s authorize|revoke\n' "$0" >&2
  exit 1
}

[[ $# -eq 1 ]] || _usage
action="$1"

AWS_REGION="${AWS_REGION:-}"
AWS_SECURITY_GROUP_ID="${AWS_SECURITY_GROUP_ID:-}"
RUNNER_IP="${RUNNER_IP:-}"

[[ -n "${AWS_REGION}" ]] || { printf 'ERROR: AWS_REGION not set\n' >&2; exit 1; }
[[ -n "${AWS_SECURITY_GROUP_ID}" ]] || { printf 'ERROR: AWS_SECURITY_GROUP_ID not set\n' >&2; exit 1; }
[[ -n "${RUNNER_IP}" ]] || { printf 'ERROR: RUNNER_IP not set\n' >&2; exit 1; }

case "${action}" in
  authorize)
    printf 'Authorizing ingress for runner IP: %s\n' "${RUNNER_IP}"
    aws ec2 authorize-security-group-ingress --region "${AWS_REGION}" --group-id "${AWS_SECURITY_GROUP_ID}" --protocol tcp --port 5985 --cidr "${RUNNER_IP}/32" >/dev/null 2>&1 || true
    aws ec2 authorize-security-group-ingress --region "${AWS_REGION}" --group-id "${AWS_SECURITY_GROUP_ID}" --protocol tcp --port 8080 --cidr "${RUNNER_IP}/32" >/dev/null 2>&1 || true
    aws ec2 authorize-security-group-ingress --region "${AWS_REGION}" --group-id "${AWS_SECURITY_GROUP_ID}" --protocol tcp --port 9080 --cidr "${RUNNER_IP}/32" >/dev/null 2>&1 || true
    ;;
  revoke)
    printf 'Revoking ingress for runner IP: %s\n' "${RUNNER_IP}"
    aws ec2 revoke-security-group-ingress --region "${AWS_REGION}" --group-id "${AWS_SECURITY_GROUP_ID}" --protocol tcp --port 5985 --cidr "${RUNNER_IP}/32" >/dev/null 2>&1 || true
    aws ec2 revoke-security-group-ingress --region "${AWS_REGION}" --group-id "${AWS_SECURITY_GROUP_ID}" --protocol tcp --port 8080 --cidr "${RUNNER_IP}/32" >/dev/null 2>&1 || true
    aws ec2 revoke-security-group-ingress --region "${AWS_REGION}" --group-id "${AWS_SECURITY_GROUP_ID}" --protocol tcp --port 9080 --cidr "${RUNNER_IP}/32" >/dev/null 2>&1 || true
    ;;
  *)
    _usage
    ;;
esac
