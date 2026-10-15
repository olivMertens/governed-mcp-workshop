#!/usr/bin/env bash
# Module 99 cleanup wrapper. Report-only unless you pass --apply.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "FAIL pwsh not found: install PowerShell 7.4 or later to run module 99 cleanup"
  exit 1
fi

args=()
for a in "$@"; do
  case "$a" in
    --apply) args+=("-Apply") ;;
    *) args+=("$a") ;;
  esac
done

exec pwsh -NoProfile -File "$root/modules/99-cleanup/cleanup.ps1" "${args[@]}"
