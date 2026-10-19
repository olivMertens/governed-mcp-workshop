#requires -Version 7.4
<#
.SYNOPSIS
    Module 04 clean-up. Idempotent, plan-reviewed, refuses anything outside module 04.
.DESCRIPTION
    Two guarded phases on infra/workload, in the reverse order of the staged deployment:
      1. reopen the Function App to its module 03 state (gateway_lock_function = false). The Function stays protected by
         Microsoft Entra built-in authentication; nothing becomes anonymous;
      2. remove the governed gateway (enable_governed_gateway = false): API Management, MCP and metadata APIs, policies,
         diagnostics, logger, gateway identity and role, private endpoint, private DNS, subnets, NSG and virtual network.
    Each phase accepts only the module 04 resources listed below (and the known in-place Function App update).
    Modules 02 and 03 stay. Without -Apply it only reports the next phase. With -Apply it applies each exact reviewed plan.
    API Management keeps a soft-deleted copy for 48 hours; the script prints the purge command but never runs it.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [string]$ParametersPath,
    [string]$Module02VarFile,
    [string]$Module03VarFile,
    [string]$Module04VarFile,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$private = Join-Path $root '.workshop'
. (Join-Path $root 'scripts' 'context-common.ps1')

function Get-Before($Change, [string]$Name) {
    $before = $Change.change.before
    if ($before -is [System.Collections.IDictionary] -and $before.Contains($Name)) { return $before[$Name] }
    return $null
}

# Plans, checks every change against the allow-list, keeps only module 04 work, then reports or applies.
# Sets $script:PhaseDone to $true when nothing is left to do in this phase.
function Invoke-GuardedPhase([string]$Directory, [string[]]$Arguments, [hashtable]$Allowed, [scriptblock]$Relevant, [string]$Label) {
    if (-not (Test-Path -LiteralPath $private)) { $null = New-Item -ItemType Directory -Path $private }
    $script:PhaseDone = $false
    $plan = Join-Path $private "module04-cleanup-$([guid]::NewGuid().ToString('N')).tfplan"
    try {
        & terraform "-chdir=$Directory" plan -input=false -no-color @Arguments "-out=$plan" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform plan for '$Label' (expected HTTP 200)." }
        $changes = @((& terraform "-chdir=$Directory" show -json $plan | ConvertFrom-Json -AsHashtable -Depth 100).resource_changes |
            Where-Object { $_.change.actions -notcontains 'no-op' -and $_.change.actions -notcontains 'read' })
        $foreign = @($changes | Where-Object {
            $address = $_.address -replace '\[[^\]]+\]$', ''
            # API Management stores policies as normalised XML (tabs, entities, format 'xml'), so every plan re-sends the
            # policies unchanged. Accept that update only when the text is identical apart from whitespace and entities.
            $whitespaceOnly = $address -in @('azapi_resource.mcp_api_policy', 'azapi_resource.prm_operation_policy') -and
                ($_.change.actions -join ',') -eq 'update' -and
                ([Net.WebUtility]::HtmlDecode([string]$_.change.before.body.properties.value) -replace '\s', '') -ceq
                ([Net.WebUtility]::HtmlDecode([string]$_.change.after.body.properties.value) -replace '\s', '')
            # Module 04 pointed the optional portal's non-secret WORKSHOP_MCP_ENDPOINT hint at the gateway; removing the
            # gateway points it back. Accept that update only when nothing else on the portal changes.
            $portalHint = $address -eq 'azurerm_linux_web_app.portal' -and ($_.change.actions -join ',') -eq 'update' -and $(
                $before = $_.change.before; $after = $_.change.after; $only = $true
                foreach ($name in $before.Keys) {
                    if ($name -eq 'app_settings') {
                        foreach ($key in @(@($before.app_settings.Keys) + @($after.app_settings.Keys) | Sort-Object -Unique)) {
                            if ($key -ne 'WORKSHOP_MCP_ENDPOINT' -and $before.app_settings[$key] -cne $after.app_settings[$key]) { $only = $false }
                        }
                    }
                    elseif ((Get-WorkshopPortalAttributeJson $name $before[$name]) -ne (Get-WorkshopPortalAttributeJson $name $after[$name])) { $only = $false }
                }
                $only)
            -not $whitespaceOnly -and -not $portalHint -and -not (Test-WorkshopPortalTierRestore $_) -and (-not $Allowed.ContainsKey($address) -or ($_.change.actions -join ',') -ne $Allowed[$address]) })
        if ($foreign.Count -gt 0) {
            throw "FAIL '$Label' plan contains $($foreign.Count) change(s) outside module 04; nothing was applied. Review 'terraform plan' privately (expected HTTP N/A)."
        }
        Write-WorkshopPortalTierNotes $changes
        $work = @($changes | Where-Object { & $Relevant $_ })
        if ($work.Count -eq 0) {
            Write-Output "PASS '$Label': nothing to do in this state (idempotent, expected HTTP N/A)."
            $script:PhaseDone = $true
            return
        }
        $work | ForEach-Object { Write-Output "PLAN $($_.change.actions -join ',') $($_.address) ($Label)" }
        if (-not $Apply) {
            Write-Output "PASS '$Label' plan changes only $($work.Count) module 04 object(s). Review it, then rerun with -Apply."
            return
        }
        & terraform "-chdir=$Directory" apply -input=false -no-color $plan
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform apply for '$Label'. Rerun this script; it plans again from the current state." }
        Write-Output "PASS '$Label' applied (expected HTTP 200)."
        $script:PhaseDone = $true
    }
    finally {
        Remove-Item -LiteralPath $plan -Force -ErrorAction SilentlyContinue
    }
}

if (-not $ParametersPath) { $ParametersPath = Join-Path $private 'participant.tfvars.json' }
if (-not $Module02VarFile) { $Module02VarFile = Join-Path $private 'module02.tfvars.json' }
if (-not $Module03VarFile) { $Module03VarFile = Join-Path $private 'module03.tfvars.json' }
if (-not $Module04VarFile) { $Module04VarFile = Join-Path $private 'module04.tfvars.json' }
$parameters = Read-WorkshopParameters -Path $ParametersPath
foreach ($file in @($Module02VarFile, $Module03VarFile)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw 'FAIL module 02 or 03 opt-in file not found. Without both, the plan would also remove the server or its authentication; clean up module 04 first with the same files (expected HTTP N/A).'
    }
}
Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
Write-Output 'PASS explicit Azure context and private participant parameters (expected HTTP 200 from Azure Resource Manager).'
$directory = Join-Path $root 'infra' 'workload'
& terraform "-chdir=$directory" init -lockfile=readonly -input=false -no-color | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform init (expected HTTP N/A). Use the pinned Terraform and the locked providers.' }
$common = @("-var-file=$ParametersPath", "-var-file=$Module02VarFile", "-var-file=$Module03VarFile")

# Phase 1: only the Function App, and only its public network access, may change.
if (Test-Path -LiteralPath $Module04VarFile -PathType Leaf) {
    Invoke-GuardedPhase $directory ($common + @("-var-file=$Module04VarFile", '-var=gateway_lock_function=false')) @{ 'azurerm_function_app_flex_consumption.mcp' = 'update' } {
        param($change)
        (Get-Before $change 'public_network_access_enabled') -eq $false
    } 'phase 1: reopen the Function behind Entra (stage 2 to stage 1)'
    if (-not $script:PhaseDone) { return }
}

# Phase 2: delete module 04 resources only (the module 02 app_settings diff is a known in-place update, not work).
$gatewayDeletes = @(
    'azapi_resource.mcp_api_diagnostic', 'azapi_resource.mcp_api_policy', 'azapi_resource.mcp_api', 'azapi_resource.prm_operation_policy',
    'azapi_resource.prm_operation', 'azapi_resource.prm_api', 'azurerm_api_management_diagnostic.gateway', 'azurerm_api_management_logger.gateway',
    'azurerm_api_management.gateway', 'azurerm_role_assignment.gateway_telemetry', 'azurerm_user_assigned_identity.gateway',
    'azurerm_private_endpoint.function', 'azurerm_private_dns_zone_virtual_network_link.functions', 'azurerm_private_dns_zone.functions',
    'azurerm_subnet_network_security_group_association.gateway_apim', 'azurerm_network_security_group.gateway_apim',
    'azurerm_subnet.gateway_apim', 'azurerm_subnet.gateway_private_endpoints', 'azurerm_virtual_network.gateway'
)
$allowed = @{ 'azurerm_function_app_flex_consumption.mcp' = 'update' }
foreach ($address in $gatewayDeletes) { $allowed[$address] = 'delete' }
Invoke-GuardedPhase $directory ($common + @('-var=enable_governed_gateway=false', '-var=gateway_lock_function=false')) $allowed {
    param($change)
    $change.change.actions -contains 'delete'
} 'phase 2: remove the governed gateway'
if ($script:PhaseDone -and $Apply) {
    $service = "apim-mcp-$($parameters.participant_prefix)-$($parameters.resource_suffix)"
    Write-Output "INFO API Management keeps a soft-deleted copy for 48 hours. To reuse the name sooner: az apim deletedservice purge --service-name $service --location $($parameters.location)"
    Write-Output 'PASS the Function is back at level 1 (Entra only). Remove .workshop/module04.tfvars.json; use modules/03-entra-authentication/cleanup.ps1 next if you continue cleaning up.'
}
