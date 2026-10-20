#!/usr/bin/env bash
# Module 07 clean-up wrapper: removes what part A (Foundry, Preview) added. Report mode unless --apply.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "FAIL pwsh not found: install PowerShell 7.4 or later to run module 07 cleanup"
  exit 1
fi

args=(); for a in "$@"; do [ "$a" = "--apply" ] && args+=("-Apply") || args+=("$a"); done
exec pwsh -NoProfile -File "$root/modules/07-clients/cleanup.ps1" "${args[@]}"
