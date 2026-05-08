#!/usr/bin/env bash
set -euo pipefail

JAVA_OLD_VERSION="${JAVA_OLD_VERSION:-}"
JAVA_NEW_VERSION="${JAVA_NEW_VERSION:-}"
TOMCAT_OLD_VERSION="${TOMCAT_OLD_VERSION:-}"
TOMCAT_NEW_VERSION="${TOMCAT_NEW_VERSION:-}"
TOMCAT_OLD_DOWNLOAD_URL="${TOMCAT_OLD_DOWNLOAD_URL:-}"
TOMCAT_NEW_DOWNLOAD_URL="${TOMCAT_NEW_DOWNLOAD_URL:-}"
TOMCAT_OLD_CHECKSUM="${TOMCAT_OLD_CHECKSUM:-}"
TOMCAT_NEW_CHECKSUM="${TOMCAT_NEW_CHECKSUM:-}"

resolve_tomcat_release() {
  local version="$1"
  local resolved_url="$2"
  local resolved_checksum="$3"
  local label="$4"
  local dlcdn_url archive_url checksum_url

  if [[ -z "$resolved_url" ]]; then
    dlcdn_url="https://dlcdn.apache.org/tomcat/tomcat-9/v${version}/bin/apache-tomcat-${version}-windows-x64.zip"
    archive_url="https://archive.apache.org/dist/tomcat/tomcat-9/v${version}/bin/apache-tomcat-${version}-windows-x64.zip"
    if curl -fsI "$dlcdn_url" >/dev/null 2>&1; then
      resolved_url="$dlcdn_url"
    elif curl -fsI "$archive_url" >/dev/null 2>&1; then
      resolved_url="$archive_url"
    else
      printf 'ERROR: Failed to resolve Tomcat %s download URL for version %s.\n' "$label" "$version" >&2
      exit 1
    fi
  fi

  if [[ -z "$resolved_checksum" ]]; then
    checksum_url="${resolved_url}.sha512"
    resolved_checksum="$(curl -fsSL "$checksum_url" | awk 'NF {print $1; exit}')"
    if [[ -z "$resolved_checksum" ]]; then
      printf 'ERROR: Failed to resolve Tomcat %s checksum from %s.\n' "$label" "$checksum_url" >&2
      exit 1
    fi
  fi

  case "$label" in
    old)
      export UPGRADE_TOMCAT_OLD_DOWNLOAD_URL="$resolved_url"
      export UPGRADE_TOMCAT_OLD_CHECKSUM="$resolved_checksum"
      ;;
    new)
      export UPGRADE_TOMCAT_NEW_DOWNLOAD_URL="$resolved_url"
      export UPGRADE_TOMCAT_NEW_CHECKSUM="$resolved_checksum"
      ;;
    *)
      printf 'ERROR: Unknown Tomcat label %s.\n' "$label" >&2
      exit 1
      ;;
  esac

  printf 'Resolved Tomcat %s version %s\n' "$label" "$version"
  printf '  URL: %s\n' "$resolved_url"
  printf '  SHA512: %s\n' "$resolved_checksum"
}

export UPGRADE_JAVA_OLD_VERSION="${JAVA_OLD_VERSION}"
export UPGRADE_JAVA_NEW_VERSION="${JAVA_NEW_VERSION}"
export UPGRADE_TOMCAT_OLD_VERSION="${TOMCAT_OLD_VERSION}"
export UPGRADE_TOMCAT_NEW_VERSION="${TOMCAT_NEW_VERSION}"

resolve_tomcat_release "${TOMCAT_OLD_VERSION}" "${TOMCAT_OLD_DOWNLOAD_URL}" "${TOMCAT_OLD_CHECKSUM}" old
resolve_tomcat_release "${TOMCAT_NEW_VERSION}" "${TOMCAT_NEW_DOWNLOAD_URL}" "${TOMCAT_NEW_CHECKSUM}" new

# Print for eval context
printf 'export UPGRADE_JAVA_OLD_VERSION="%s"\n' "${UPGRADE_JAVA_OLD_VERSION}"
printf 'export UPGRADE_JAVA_NEW_VERSION="%s"\n' "${UPGRADE_JAVA_NEW_VERSION}"
printf 'export UPGRADE_TOMCAT_OLD_VERSION="%s"\n' "${UPGRADE_TOMCAT_OLD_VERSION}"
printf 'export UPGRADE_TOMCAT_NEW_VERSION="%s"\n' "${UPGRADE_TOMCAT_NEW_VERSION}"
printf 'export UPGRADE_TOMCAT_OLD_DOWNLOAD_URL="%s"\n' "${UPGRADE_TOMCAT_OLD_DOWNLOAD_URL}"
printf 'export UPGRADE_TOMCAT_OLD_CHECKSUM="%s"\n' "${UPGRADE_TOMCAT_OLD_CHECKSUM}"
printf 'export UPGRADE_TOMCAT_NEW_DOWNLOAD_URL="%s"\n' "${UPGRADE_TOMCAT_NEW_DOWNLOAD_URL}"
printf 'export UPGRADE_TOMCAT_NEW_CHECKSUM="%s"\n' "${UPGRADE_TOMCAT_NEW_CHECKSUM}"
