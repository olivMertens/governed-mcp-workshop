#requires -Version 7.4
<#
.SYNOPSIS
    Module 06 cleanup (guarded). Reports by default; removes nothing without -Apply.

.DESCRIPTION
    Module 06 creates no Azure resources. With -Apply the script only confirms that
    no module-owned resource exists in the local state. It never deletes API Center
    assets, BYO listings or Agent 365 policy: those are removed by hand in the portal
    or the Microsoft 365 admin center.

.PARAMETER Apply
    Required to make any change. Without it the script only reports.

.EXAMPLE
    pwsh ./modules/06-observe-inventory/cleanup.ps1
#>
[CmdletBinding()]
param(
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Output 'Module 06 creates no Azure resources. Nothing is deleted by this script.'
Write-Output 'Manual cleanup, if you created them:'
Write-Output '  - API Center asset: delete in the Azure portal (API center > Assets).'
Write-Output '  - BYO MCP listing: removed only by a Microsoft 365 administrator.'
Write-Output '  - Agent 365 policy (demo): removed only by a tenant administrator.'

if (-not $Apply) {
    Write-Output 'Report only. Re-run with -Apply to confirm the guard passed (no deletions are performed).'
    exit 0
}

$stateFiles = Get-ChildItem -Path $PSScriptRoot -Filter '*.tfstate' -Recurse -ErrorAction SilentlyContinue
if ($stateFiles) {
    Write-Output "Refusing to continue: unexpected Terraform state found: $($stateFiles.FullName -join ', ')"
    exit 1
}

Write-Output 'Guard passed. No module-owned resources to remove.'
exit 0
