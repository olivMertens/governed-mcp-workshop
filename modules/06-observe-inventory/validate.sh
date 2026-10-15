#!/usr/bin/env bash
# Module 06 validator (offline only). Delegates to validate.ps1 under pwsh.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "FAIL pwsh not found: install PowerShell 7.4 or later to run module 06 checks"
  exit 1
fi

args=()
for a in "$@"; do
  case "$a" in
    --offline) args+=("-Offline") ;;
    *) echo "FAIL unknown argument: $a"; exit 1 ;;
  esac
done

exec pwsh -NoProfile -File "$root/modules/06-observe-inventory/validate.ps1" "${args[@]}"
