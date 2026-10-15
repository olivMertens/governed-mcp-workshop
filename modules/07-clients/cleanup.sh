#!/usr/bin/env bash
# Module 07 cleanup wrapper. Nothing is created by this module, so nothing is deleted.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "FAIL pwsh not found: install PowerShell 7.4 or later to run module 07 cleanup"
  exit 1
fi

exec pwsh -NoProfile -File "$root/modules/07-clients/cleanup.ps1" "$@"
