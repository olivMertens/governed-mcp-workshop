#!/usr/bin/env bash
set -euo pipefail
command -v pwsh >/dev/null || { printf '%s\n' 'FAIL PowerShell 7.4+ is required. See docs/GETTING-STARTED.md.' >&2; exit 1; }
exec pwsh -NoProfile -File "$(dirname "${BASH_SOURCE[0]}")/check-tools.ps1" "$@"
