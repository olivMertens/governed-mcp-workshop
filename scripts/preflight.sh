#!/usr/bin/env bash
set -euo pipefail
command -v pwsh >/dev/null || { printf '%s\n' 'FAIL PowerShell 7.4+ is required.' >&2; exit 1; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pwsh -NoProfile -File "$root/preflight.ps1" "$@"
