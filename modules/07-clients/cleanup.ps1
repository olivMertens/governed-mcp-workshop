#requires -Version 7.4
<#
.SYNOPSIS
    Module 07 clean-up. Idempotent, plan-reviewed, refuses anything outside module 07.
.DESCRIPTION
    Removes what part A (Microsoft Foundry, Preview) added, in this order:
      1. infra/workload without .workshop/module07.tfvars.json: the Foundry client leaves the allowed applications of the
         gateway policies and of the Function's built-in authentication (in-place updates only).
      2. infra/entra without .workshop/entra-module07.tfvars.json: the Foundry client's pre-authorization is deleted.
      3. The Foundry agent identity blueprints that Foundry created in Microsoft Entra (one per agent), then the Foundry
         resource group named in .workshop/module07.private.json, only if it carries the tags workshop=governed-mcp and
         module=07; then the soft-deleted Foundry account is purged.
      4. The Foundry client app registration (and with it its short-lived secret), only if its name starts with
         workshop-mcp-foundry-client-.
    Without -Apply it only reports. With -Apply it applies the exact reviewed plans. Nothing to do when part A was skipped.
.EXAMPLE
    pwsh ./modules/07-clients/cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
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
$private = Join-Path $root '.workshop'
. (Join-Path $root 'scripts' 'context-common.ps1')

$stateFile = Join-Path $private 'module07.private.json'
$workloadFile = Join-Path $private 'module07.tfvars.json'
$entraFile = Join-Path $private 'entra-module07.tfvars.json'
if (-not (Test-Path $stateFile) -and -not (Test-Path $workloadFile) -and -not (Test-Path $entraFile)) {
    Write-Output 'PASS module 07 part A was not deployed from this copy: nothing to delete (idempotent, expected HTTP N/A).'
    return
}
Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
Write-Output 'PASS explicit Azure context (expected HTTP 200 from Azure Resource Manager).'
$state = if (Test-Path $stateFile) { Get-Content -Raw $stateFile | ConvertFrom-Json } else { $null }
$clientId = if ($state) { [string]$state.foundry_client_app_id } else { '' }

# Plans, accepts only the listed actions, reports or applies. A change is module 07 work only if it mentions the client ID.
function Invoke-GuardedPhase([string]$Directory, [string[]]$Arguments, [hashtable]$Allowed, [string]$Label) {
    $plan = Join-Path $private "module07-cleanup-$([guid]::NewGuid().ToString('N')).tfplan"
    try {
        & terraform "-chdir=$Directory" init -lockfile=readonly -input=false -no-color | Out-Null
        & terraform "-chdir=$Directory" plan -input=false -no-color @Arguments "-out=$plan" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform plan for '$Label' (expected HTTP 200)." }
        $document = & terraform "-chdir=$Directory" show -json $plan | ConvertFrom-Json -AsHashtable -Depth 100
        $all = if ($document.Contains('resource_changes') -and $null -ne $document.resource_changes) { @($document.resource_changes) } else { @() }
        $changes = @($all | Where-Object { $_.change.actions -notcontains 'no-op' -and $_.change.actions -notcontains 'read' })
        $foreign = @($changes | Where-Object {
            $address = $_.address -replace '\[[^\]]+\]$', ''
            -not (Test-WorkshopPortalTierRestore $_) -and (-not $Allowed.ContainsKey($address) -or ($_.change.actions -join ',') -ne $Allowed[$address]) })
        if ($foreign.Count -gt 0) {
            throw "FAIL '$Label' plan contains $($foreign.Count) change(s) outside module 07; nothing was applied. Pass the same var files you deployed with (expected HTTP N/A)."
        }
        Write-WorkshopPortalTierNotes $changes
        $work = @($changes | Where-Object { $clientId -and (($_.change.before | ConvertTo-Json -Depth 100 -Compress) -match [regex]::Escape($clientId)) })
        if ($work.Count -eq 0) { Write-Output "PASS '$Label': nothing to do in this state (idempotent, expected HTTP N/A)."; return }
        $work | ForEach-Object { Write-Output "PLAN $($_.change.actions -join ',') $($_.address) ($Label)" }
        if (-not $Apply) { Write-Output "PASS '$Label' plan changes only $($work.Count) module 07 object(s). Review it, then rerun with -Apply."; return }
        & terraform "-chdir=$Directory" apply -input=false -no-color $plan | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform apply for '$Label'. Rerun this script; it plans again from the current state." }
        Write-Output "PASS '$Label' applied (expected HTTP 200)."
    } finally { Remove-Item -LiteralPath $plan -Force -ErrorAction SilentlyContinue }
}

# 1. Workload: same var files as deployed, minus module 07.
$workload = @('participant.tfvars.json', 'module02.tfvars.json', 'module03.tfvars.json', 'module04.tfvars.json', 'module04b.tfvars.json', 'module05.tfvars.json') |
    ForEach-Object { Join-Path $private $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | ForEach-Object { "-var-file=$_" }
$allowed = @{ 'azurerm_function_app_flex_consumption.mcp' = 'update' }
foreach ($a in @('azapi_resource.mcp_api_policy', 'azapi_resource.prm_operation_policy', 'azapi_resource.rest_api_policy', 'azapi_resource.rest_mcp_policy', 'azapi_resource.rest_mcp_prm_operation_policy')) { $allowed[$a] = 'update' }
Invoke-GuardedPhase (Join-Path $root 'infra' 'workload') $workload $allowed 'remove the Foundry client from the allowed applications'

# 2. Entra: same var files as deployed, minus module 07.
$entra = @('entra.tfvars.json', 'entra-module05.tfvars.json') | ForEach-Object { Join-Path $private $_ } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | ForEach-Object { "-var-file=$_" }
Invoke-GuardedPhase (Join-Path $root 'infra' 'entra') $entra @{ 'azuread_application_pre_authorized.clients' = 'delete' } 'remove the Foundry client pre-authorization'

# 3. Foundry resource group (tag-checked), then purge the soft-deleted account so the name and quota are released.
if ($state -and $state.foundry_resource_group) {
    $group = [string]$state.foundry_resource_group
    $tags = az group show -n $group --query tags -o json --only-show-errors 2>$null | ConvertFrom-Json
    if (-not $tags) { Write-Output "PASS Foundry resource group already deleted (idempotent, expected HTTP 404 from Azure Resource Manager)." }
    elseif ($tags.workshop -ne 'governed-mcp' -or $tags.module -ne '07') { throw "FAIL the Foundry resource group is not tagged workshop=governed-mcp and module=07; nothing was deleted (expected HTTP N/A)." }
    else {
        $accounts = @(az cognitiveservices account list -g $group --query "[].{name:name,location:location}" -o json --only-show-errors | ConvertFrom-Json)
        # Foundry creates one Microsoft Entra agent identity blueprint per agent, named <account>-<project>-<agent>-...;
        # deleting the resource group does not remove it (verified 2026-10-20).
        $graph = Get-WorkshopAccessToken -TenantId $TenantId -Resource 'https://graph.microsoft.com'
        if (-not $graph.Ok) { throw 'FAIL no Microsoft Graph token to find the Foundry agent identity blueprints (expected HTTP 200).' }
        $headers = @{ Authorization = "Bearer $($graph.Value)"; ConsistencyLevel = 'eventual' }
        $projects = @(az resource list -g $group --resource-type Microsoft.CognitiveServices/accounts/projects --query "[].name" -o tsv --only-show-errors)
        $blueprints = @(foreach ($a in $accounts) {
            foreach ($project in $projects) {
                $prefix = "$($a.name)-$(($project -split '/')[-1])-"
                $uri = "https://graph.microsoft.com/beta/applications?`$filter=startswith(displayName,'$prefix')&`$select=id,appId,displayName&`$count=true"
                @((Invoke-RestMethod -Uri $uri -Headers $headers).value)
            }
        })
        Write-Output "PLAN delete resource group (Foundry project, model deployment, monitoring), purge $($accounts.Count) Foundry account(s) and delete $($blueprints.Count) agent identity blueprint(s)"
        if ($Apply) {
            foreach ($b in $blueprints) {
                $sps = @((Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/servicePrincipals?`$filter=appId eq '$($b.appId)'&`$select=id" -Headers $headers).value)
                foreach ($sp in $sps) { Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/servicePrincipals/$($sp.id)" -Headers $headers | Out-Null }
                Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/applications/$($b.id)" -Headers $headers | Out-Null
            }
            if ($blueprints.Count) { Write-Output "PASS $($blueprints.Count) Foundry agent identity blueprint(s) deleted (expected HTTP 204 from Microsoft Graph)." }
            az group delete -n $group --yes --only-show-errors
            if ($LASTEXITCODE -ne 0) { throw 'FAIL resource group deletion. Rerun this script.' }
            foreach ($a in $accounts) { az cognitiveservices account purge -g $group -n $a.name -l $a.location --only-show-errors 2>$null | Out-Null }
            Write-Output 'PASS Foundry resource group deleted and accounts purged (expected HTTP 200 from Azure Resource Manager).'
        }
    }
}

# 4. Foundry client app registration (deleting it also deletes its short-lived secret).
if ($clientId) {
    $name = az ad app show --id $clientId --query displayName -o tsv --only-show-errors 2>$null
    if (-not $name) { Write-Output 'PASS Foundry client app registration already deleted (idempotent, expected HTTP 404 from Microsoft Graph).' }
    elseif ($name -notlike 'workshop-mcp-foundry-client-*') { throw 'FAIL the client app registration name does not start with workshop-mcp-foundry-client-; nothing was deleted (expected HTTP N/A).' }
    else {
        Write-Output 'PLAN delete the Foundry client app registration and its short-lived secret'
        if ($Apply) {
            az ad app delete --id $clientId --only-show-errors
            if ($LASTEXITCODE -ne 0) { throw 'FAIL app registration deletion. Rerun this script.' }
            Write-Output 'PASS Foundry client app registration and secret deleted (expected HTTP 204 from Microsoft Graph).'
        }
    }
}

if ($Apply) {
    Remove-Item -LiteralPath $stateFile, $workloadFile, $entraFile -ErrorAction SilentlyContinue
    Write-Output 'DONE module 07 part A removed. Private module 07 files deleted.'
} else {
    Write-Output 'DONE report only. Nothing was changed. Rerun with -Apply after reviewing every PLAN line.'
}
