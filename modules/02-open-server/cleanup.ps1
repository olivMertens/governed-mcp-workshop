#requires -Version 7.4
<#
.SYNOPSIS
    Removes only the module 02 resources with the participant's private Terraform state. Idempotent.
.DESCRIPTION
    Plans the workload root with enable_mcp_server = false, then refuses unless every planned change is a deletion
    of a module 02 resource, or removal of only the portal's WORKSHOP_MCP_ENDPOINT hint. Without -Apply it only reports.
    With -Apply it applies that exact reviewed plan.
    The resource group, the optional portal itself and later modules' resources are never deleted.
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
    'azurerm_role_assignment.mcp_telemetry', 'azurerm_service_plan.mcp', 'azurerm_function_app_flex_consumption.mcp',
    # Optional private storage (mcp_private_storage); the shared network exists only while module 02 or 04 needs it.
    'azurerm_virtual_network.gateway', 'azurerm_subnet.gateway_private_endpoints', 'azurerm_subnet.mcp_integration',
    'azurerm_private_dns_zone.storage', 'azurerm_private_dns_zone_virtual_network_link.storage', 'azurerm_private_endpoint.storage'
)
$plan = Join-Path $private 'module02-cleanup.tfplan'
try {
    & terraform "-chdir=$workload" init -lockfile=readonly -input=false -no-color | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform init (expected HTTP N/A). Use the pinned Terraform and the locked provider.' }
    & terraform "-chdir=$workload" plan -input=false -no-color "-var-file=$ParametersPath" '-var=enable_mcp_server=false' "-out=$plan" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform cleanup plan (expected HTTP 200 from Azure Resource Manager).' }

    $changes = @((& terraform "-chdir=$workload" show -json $plan | ConvertFrom-Json -AsHashtable -Depth 100).resource_changes |
        Where-Object { $_.change.actions -notcontains 'no-op' -and $_.change.actions -notcontains 'read' })
    # The optional portal received the non-secret WORKSHOP_MCP_ENDPOINT hint with module 02. Removing exactly that key,
    # with every other portal attribute unchanged, is part of this cleanup. Any other portal change is refused.
    $portalHint = @($changes | Where-Object {
        $_.address -eq 'azurerm_linux_web_app.portal[0]' -and ($_.change.actions -join ',') -eq 'update' -and
        $_.change.before.app_settings -is [System.Collections.IDictionary] -and $_.change.before.app_settings.Contains('WORKSHOP_MCP_ENDPOINT') -and
        $_.change.after.app_settings -is [System.Collections.IDictionary] -and $(
            $before = $_.change.before; $after = $_.change.after
            $expected = [ordered]@{}
            foreach ($name in $before.app_settings.Keys) { if ($name -ne 'WORKSHOP_MCP_ENDPOINT') { $expected[$name] = $before.app_settings[$name] } }
            $same = ($expected | ConvertTo-Json -Depth 5 -Compress) -eq ([ordered]@{} + $after.app_settings | ConvertTo-Json -Depth 5 -Compress)
            foreach ($name in $before.Keys) {
                if ($name -ne 'app_settings' -and (($before[$name] | ConvertTo-Json -Depth 50 -Compress) -ne ($after[$name] | ConvertTo-Json -Depth 50 -Compress))) { $same = $false }
            }
            $same) })
    $foreign = @($changes | Where-Object { $_ -notin $portalHint } | Where-Object {
        ($_.change.actions -join ',') -ne 'delete' -or ($_.address -replace '\[[^\]]+\]$', '') -notin $owned })
    if ($foreign.Count -gt 0) {
        throw "FAIL cleanup plan contains $($foreign.Count) change(s) outside module 02 deletions; nothing was applied. Review 'terraform plan' privately (expected HTTP N/A)."
    }
    if ($changes.Count -eq 0) {
        Write-Output 'PASS no module 02 resources remain in this state; nothing to delete (idempotent, expected HTTP N/A).'
        return
    }
    $changes | Where-Object { $_ -notin $portalHint } | ForEach-Object { Write-Output "PLAN delete $($_.address)" }
    $portalHint | ForEach-Object { Write-Output "PLAN update $($_.address): remove only the WORKSHOP_MCP_ENDPOINT hint (portal may restart)" }
    if (-not $Apply) {
        Write-Output "PASS cleanup plan deletes only $($changes.Count - $portalHint.Count) module 02 resource(s)$(if ($portalHint.Count) { ' and removes the portal endpoint hint' }). Review it, then rerun with -Apply."
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
