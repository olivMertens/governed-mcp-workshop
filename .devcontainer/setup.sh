#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
npm view azure-functions-core-tools@4.14.0 version
npm install --global azure-functions-core-tools@4.14.0
pwsh -NoProfile -File ./scripts/check-tools.ps1
