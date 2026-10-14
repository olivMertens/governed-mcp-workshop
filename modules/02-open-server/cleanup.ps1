#requires -Version 7.4
<#
.SYNOPSIS
    Removes only the module 02 resources with the participant's private Terraform state. Idempotent.
.DESCRIPTION
    Plans the workload root with enable_mcp_server = false, then refuses unless every planned change is a deletion
    of a module 02 resource. Without -Apply it only reports. With -Apply it applies that exact reviewed plan.
    The resource group, the optional portal and later modules' resources are never in scope.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [string]$ParametersPath,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$workload = Join-Path $root 'infra' 'workload'
$private = Join-Path $root '.workshop'
if (-not $ParametersPath) { $ParametersPath = Join-Path $private 'participant.tfvars.json' }
. (Join-Path $root 'scripts' 'context-common.ps1')

$null = Read-WorkshopParameters -Path $ParametersPath
Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
Write-Output 'PASS explicit Azure context and private participant parameters (expected HTTP 200 from Azure Resource Manager).'

$owned = @(
    'azurerm_user_assigned_identity.mcp', 'azurerm_storage_account.mcp', 'azurerm_storage_container.mcp_package',
    'azurerm_storage_queue.tickets', 'azurerm_log_analytics_workspace.mcp', 'azurerm_application_insights.mcp',
    'azurerm_role_assignment.mcp_host_storage', 'azurerm_role_assignment.mcp_ticket_sender',
    'azurerm_role_assignment.mcp_telemetry', 'azurerm_service_plan.mcp', 'azurerm_function_app_flex_consumption.mcp'
)
$plan = Join-Path $private 'module02-cleanup.tfplan'
try {
    & terraform "-chdir=$workload" init -lockfile=readonly -input=false -no-color | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform init (expected HTTP N/A). Use the pinned Terraform and the locked provider.' }
    & terraform "-chdir=$workload" plan -input=false -no-color "-var-file=$ParametersPath" '-var=enable_mcp_server=false' "-out=$plan" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform cleanup plan (expected HTTP 200 from Azure Resource Manager).' }

    $changes = @((& terraform "-chdir=$workload" show -json $plan | ConvertFrom-Json -AsHashtable -Depth 100).resource_changes |
        Where-Object { $_.change.actions -notcontains 'no-op' -and $_.change.actions -notcontains 'read' })
    $foreign = @($changes | Where-Object {
        ($_.change.actions -join ',') -ne 'delete' -or ($_.address -replace '\[\d+\]$', '') -notin $owned })
    if ($foreign.Count -gt 0) {
        throw "FAIL cleanup plan contains $($foreign.Count) change(s) outside module 02 deletions; nothing was applied. Review 'terraform plan' privately (expected HTTP N/A)."
    }
    if ($changes.Count -eq 0) {
        Write-Output 'PASS no module 02 resources remain in this state; nothing to delete (idempotent, expected HTTP N/A).'
        return
    }
    $changes | ForEach-Object { Write-Output "PLAN delete $($_.address)" }
    if (-not $Apply) {
        Write-Output "PASS cleanup plan deletes only $($changes.Count) module 02 resource(s). Review it, then rerun with -Apply."
        return
    }
    & terraform "-chdir=$workload" apply -input=false -no-color $plan
    if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform cleanup apply. Rerun this script; it plans again from the current state.' }
    Write-Output "PASS module 02 resources deleted; the system key was deleted with the Function App (expected HTTP 200 from Azure Resource Manager)."
    Write-Output 'KEEP private participant parameters, Terraform state and the resource group for later modules.'
}
finally {
    Remove-Item -LiteralPath $plan -Force -ErrorAction SilentlyContinue
}
