#requires -Version 7.4
<#
.SYNOPSIS
    Module 99 clean-up. Runs the module clean-ups in reverse order (05, 04, 03, 02).
.DESCRIPTION
    Without -Apply it runs every module clean-up in report mode: each one plans, checks its allow-list and prints
    what it would change, but applies nothing. With -Apply it passes -Apply to each clean-up in the same order.
    It stops at the first failure. It never runs a blanket terraform destroy.
    Test users, role assignments and the tag-based leftover check are manual steps (see README.md, Clean up).
.PARAMETER TenantId
    Microsoft Entra tenant ID (GUID).
.PARAMETER SubscriptionId
    Azure subscription ID (GUID) that holds the workshop resources.
.PARAMETER Apply
    Apply the reviewed plans. Without this switch nothing is changed.
.EXAMPLE
    pwsh ./modules/99-cleanup/cleanup.ps1 -TenantId <tenant-guid> -SubscriptionId <subscription-guid>
.EXAMPLE
    pwsh ./modules/99-cleanup/cleanup.ps1 -TenantId <tenant-guid> -SubscriptionId <subscription-guid> -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Reverse build order. Module 05 Entra must run before module 03 Entra.
$steps = @(
    @{ Module = '05-delegated-and-app-only'; Scope = 'Workload' },
    @{ Module = '05-delegated-and-app-only'; Scope = 'Entra' },
    @{ Module = '04-governed-gateway'; Scope = $null },
    @{ Module = '03-entra-authentication'; Scope = 'Workload' },
    @{ Module = '03-entra-authentication'; Scope = 'Entra' },
    @{ Module = '02-open-server'; Scope = $null }
)

Write-Output "Module 99 clean-up. Mode: $(if ($Apply) { 'APPLY' } else { 'REPORT ONLY (no change)' })"
foreach ($step in $steps) {
    $script = Join-Path $root "modules/$($step.Module)/cleanup.ps1"
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Output "FAIL missing clean-up script: $($step.Module)"
        exit 1
    }

    $label = if ($step.Scope) { "$($step.Module) -Scope $($step.Scope)" } else { $step.Module }
    Write-Output "--> $label"

    $arguments = @{ TenantId = $TenantId; SubscriptionId = $SubscriptionId }
    if ($step.Scope) { $arguments.Scope = $step.Scope }
    if ($Apply) { $arguments.Apply = $true }

    & $script @arguments
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Output "FAIL $label stopped with exit code $LASTEXITCODE. Fix it, then run this script again."
        exit $LASTEXITCODE
    }
}

if ($Apply) {
    Write-Output 'DONE module clean-ups applied. Next: delete test users and role assignments, then run the tag check in README.md.'
}
else {
    Write-Output 'DONE report only. Nothing was changed. Re-run with -Apply after reviewing each plan.'
}
