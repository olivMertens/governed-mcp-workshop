#!/usr/bin/env bash
# Module 99 validation wrapper. Offline only.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "FAIL pwsh not found: install PowerShell 7.4 or later"
  exit 1
fi

args=()
for a in "$@"; do
  case "$a" in
    --offline) args+=("-Offline") ;;
    *) args+=("$a") ;;
  esac
done

exec pwsh -NoProfile -File "$root/modules/99-cleanup/validate.ps1" "${args[@]}"
