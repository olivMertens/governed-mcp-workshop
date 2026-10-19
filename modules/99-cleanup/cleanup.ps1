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
# Each step needs the private files its own clean-up requires. Without them that clean-up cannot plan safely,
# so the step is skipped with a visible reason instead of failing the whole run.
$steps = @(
    @{ Module = '05-delegated-and-app-only'; Scope = 'Workload'; Requires = @('module02.tfvars.json', 'module03.tfvars.json') },
    @{ Module = '05-delegated-and-app-only'; Scope = 'Entra'; Requires = @('entra.tfvars.json') },
    @{ Module = '04-governed-gateway'; Scope = $null; Requires = @('module02.tfvars.json', 'module03.tfvars.json') },
    @{ Module = '03-entra-authentication'; Scope = 'Workload'; Requires = @('module02.tfvars.json') },
    @{ Module = '03-entra-authentication'; Scope = 'Entra'; Requires = @('entra.tfvars.json') },
    @{ Module = '02-open-server'; Scope = $null; Requires = @('participant.tfvars.json') }
)

Write-Output "Module 99 clean-up. Mode: $(if ($Apply) { 'APPLY' } else { 'REPORT ONLY (no change)' })"
$pending = $false
$waiting = @()
foreach ($step in $steps) {
    $script = Join-Path $root "modules/$($step.Module)/cleanup.ps1"
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Output "FAIL missing clean-up script: $($step.Module)"
        exit 1
    }

    $label = if ($step.Scope) { "$($step.Module) -Scope $($step.Scope)" } else { $step.Module }
    $missing = @($step.Requires | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root '.workshop' $_) -PathType Leaf) })
    if ($missing.Count) {
        Write-Output "SKIP $label (missing .workshop/$($missing -join ', .workshop/'); if you deployed this stage, restore the file and run again)"
        continue
    }
    Write-Output "--> $label"

    $arguments = @{ TenantId = $TenantId; SubscriptionId = $SubscriptionId }
    if ($step.Scope) { $arguments.Scope = $step.Scope }
    if ($Apply) { $arguments.Apply = $true }

    try {
        $global:LASTEXITCODE = 0
        & $script @arguments | ForEach-Object {
            if (-not $Apply -and "$_" -match '^PLAN ') { $pending = $true }
            $_
        }
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
    }
    catch {
        $reason = ($_.Exception.Message -split "`n")[0]
        # In report mode nothing is applied, so a later stage still sees objects that an earlier stage only planned to
        # remove, and its guard refuses. That is expected; it plans cleanly once the earlier stages are applied.
        if (-not $Apply -and $pending) {
            Write-Output "WAIT $label cannot be planned yet: earlier stages above still have PLAN lines to apply ($reason)"
            $waiting += $label
            continue
        }
        Write-Output "FAIL $label stopped: $reason Fix it, then run this script again."
        exit 1
    }
}

if ($Apply) {
    Write-Output 'DONE module clean-ups applied. Next: delete test users and role assignments, then run the tag check in README.md.'
}
elseif ($waiting.Count) {
    Write-Output "DONE report only. Nothing was changed. $($waiting.Count) stage(s) wait for earlier stages: run with -Apply (it applies in order and plans each stage again), or rerun this report after applying."
}
else {
    Write-Output 'DONE report only. Nothing was changed. Re-run with -Apply after reviewing each plan.'
}
