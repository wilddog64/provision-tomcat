#!/usr/bin/env bash
set -euo pipefail

PROMOTION_HOST_FILE=".kitchen/ansiblepush/ansiblepush_host_candidate-aws-disk-aws-minimal-win-disk.yml"

if [[ ! -f "${PROMOTION_HOST_FILE}" ]]; then
  printf 'ERROR: AWS candidate host file not found: %s\n' "${PROMOTION_HOST_FILE}" >&2
  exit 1
fi

PROMOTION_HOST=$(yq '."candidate-aws-disk-aws-minimal-win-disk".ansible_ssh_host' "${PROMOTION_HOST_FILE}")
export PROMOTION_HOST
PROMOTION_USER=$(yq '."candidate-aws-disk-aws-minimal-win-disk".ansible_ssh_user' "${PROMOTION_HOST_FILE}")
export PROMOTION_USER
PROMOTION_PASS=$(yq '."candidate-aws-disk-aws-minimal-win-disk".ansible_ssh_pass' "${PROMOTION_HOST_FILE}")
export PROMOTION_PASS

if [[ -z "${PROMOTION_HOST}" || "${PROMOTION_HOST}" == "null" || -z "${PROMOTION_USER}" || "${PROMOTION_USER}" == "null" || -z "${PROMOTION_PASS}" || "${PROMOTION_PASS}" == "null" ]]; then
  printf 'ERROR: Failed to extract AWS promotion host credentials from %s\n' "${PROMOTION_HOST_FILE}" >&2
  exit 1
fi

PROMOTION_INVENTORY=$(mktemp)
export PROMOTION_INVENTORY
PROMOTION_VARS=$(mktemp)
export PROMOTION_VARS

_cleanup() {
  rm -f "${PROMOTION_INVENTORY}" "${PROMOTION_VARS}"
}
trap _cleanup EXIT

python3 "$(dirname "$0")/build-inventory.py"

printf '=== Promoting AWS candidate on %s ===\n' "${PROMOTION_HOST}"
ANSIBLE_CONFIG=ansible.cfg ansible-playbook tests/playbook-upgrade.yml -i "${PROMOTION_INVENTORY}" -e @"${PROMOTION_VARS}"

printf '=== Verifying promoted primary on localhost:8080 via WinRM ===\n'
ANSIBLE_CONFIG=ansible.cfg ansible aws_candidate -i "${PROMOTION_INVENTORY}" -m ansible.windows.win_uri -a 'url=http://localhost:8080 status_code=200,404'
