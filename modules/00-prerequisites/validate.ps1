#requires -Version 7.4
[CmdletBinding()]
param(
    [switch]$Offline,
    [guid]$TenantId,
    [guid]$SubscriptionId,
    [ValidateSet('foundation', 'portal', 'mcp')][string]$Stage = 'foundation',
    [string]$ParametersPath,
    [string]$CapacityReviewPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:StepNumber = 0
function Step([string]$Title, [string]$Why) {
    $script:StepNumber++
    Write-Output ''; Write-Output "== Step $($script:StepNumber): $Title =="; Write-Output "   Why: $Why"
}
Write-Output 'Module 00 validator - your tools, scripts and Azure subscription are ready for the workshop.'
if ($Offline) {
    Step 'Offline - workspace, preflight and portal scripts behave (no Azure call)' 'Proves the helper scripts work on synthetic data before you touch Azure.'
    & node --test (Join-Path $root 'scripts/workspace.test.mjs') (Join-Path $root 'scripts/preflight.test.mjs') `
        (Join-Path $root 'scripts/site.test.mjs') (Join-Path $root 'scripts/portal.test.mjs') (Join-Path $root 'scripts/portal-deploy.test.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'FAIL local script/HTTP checks (expected HTTP N/A; synthetic context only).' }
    Write-Output 'PASS local script/HTTP checks (expected HTTP N/A; no Azure access)'
    Step 'Offline - Terraform files are valid (mock plans only)' 'Proves the infrastructure code is well formed without creating anything in Azure.'
    $terraform = Join-Path $root 'infra/workload'
    foreach ($arguments in @(@('fmt', '-check', '-recursive'), @('validate', '-no-color'), @('test', '-no-color'))) {
        & terraform "-chdir=$terraform" @arguments
        if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform checks (expected HTTP N/A). Install the pinned version and initialize the locked provider first.' }
    }
    Write-Output 'PASS Terraform schema and mock-only plans (expected HTTP N/A; no live plan/apply)'
    Write-Output 'PASS offline checks only. Module 00 is NOT Azure-validated by this result.'
} else {
    if ($TenantId -eq [guid]::Empty -or $SubscriptionId -eq [guid]::Empty) {
        throw 'FAIL explicit target required. Use -Offline for synthetic tests, or supply the privately approved tenant/subscription.'
    }
    $arguments = @{ TenantId = $TenantId; SubscriptionId = $SubscriptionId; Stage = $Stage }
    if ($ParametersPath) { $arguments.ParametersPath = $ParametersPath }
    if ($CapacityReviewPath) { $arguments.CapacityReviewPath = $CapacityReviewPath }
    Step "Live - preflight reads your tenant and subscription ($Stage stage, read-only)" 'Proves your tools, sign-in, permissions and capacity are ready before any deployment.'
    & (Join-Path $root 'scripts/preflight.ps1') @arguments
    Step 'Administrator request is ready' 'Proves you have the template to ask an identity administrator for the Entra objects.'
    if (-not (Test-Path -LiteralPath (Join-Path $root 'docs/requests/identity-request.md') -PathType Leaf)) {
        throw 'FAIL administrator request (expected HTTP N/A; template missing).'
    }
    Write-Output 'PASS administrator request template present (expected HTTP N/A; approval and identity creation are separate)'
    Write-Output "PASS module 00 $Stage environment checks. Record only the verified workspace route and stage; this is not MCP runtime validation."
}
