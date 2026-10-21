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
    -LowCodeTrack skips steps 1 and 2 (no Terraform state): module 99's low-code checklist deletes the MCP API registration
    and the workload resource group, which removes those entries with them.
.EXAMPLE
    pwsh ./modules/07-clients/cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [switch]$Apply,
    [switch]$LowCodeTrack
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
if (-not $state) { throw 'FAIL module07.private.json is missing or empty. Restore the original private inventory before cleanup; other module 07 files were kept.' }
$clientId = if ($state) { [string]$state.foundry_client_app_id } else { '' }
$parsedClientId = [guid]::Empty
if (-not [guid]::TryParse($clientId, [ref]$parsedClientId) -or $parsedClientId -eq [guid]::Empty) {
    throw 'FAIL the saved Foundry client app ID is invalid; nothing was deleted.'
}
$clientId = $parsedClientId.ToString()

# Plans, accepts only the listed actions, reports or applies. A change is module 07 work only if it mentions the client ID.
function Invoke-GuardedPhase([string]$Directory, [string[]]$Arguments, [hashtable]$Allowed, [string]$Label) {
    $plan = Join-Path $private "module07-cleanup-$([guid]::NewGuid().ToString('N')).tfplan"
    try {
        & terraform "-chdir=$Directory" init -lockfile=readonly -input=false -no-color | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform init for '$Label'; nothing was applied." }
        & terraform "-chdir=$Directory" plan -input=false -no-color @Arguments "-out=$plan" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform plan for '$Label' (expected HTTP 200)." }
        $planJson = & terraform "-chdir=$Directory" show -json $plan
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform show for '$Label'; the plan cannot be checked." }
        $document = $planJson | ConvertFrom-Json -AsHashtable -Depth 100
        $all = if ($document.Contains('resource_changes') -and $null -ne $document.resource_changes) { @($document.resource_changes) } else { @() }
        $changes = @($all | Where-Object { $_.change.actions -notcontains 'no-op' -and $_.change.actions -notcontains 'read' })
        $foreign = @($changes | Where-Object {
            $address = $_.address -replace '\[[^\]]+\]$', ''
            -not $Allowed.ContainsKey($address) -or ($_.change.actions -join ',') -ne $Allowed[$address] })
        if ($foreign.Count -gt 0) {
            throw "FAIL '$Label' plan contains $($foreign.Count) change(s) outside module 07; nothing was applied. Pass the same var files you deployed with (expected HTTP N/A)."
        }
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
if ($LowCodeTrack) {
    Write-Output 'INFO low-code track: no Terraform state; the allowed-application entries go with the API registration and resource group (module 99).'
} else {
$workload = @('participant.tfvars.json', 'module02.tfvars.json', 'module03.tfvars.json', 'module04.tfvars.json', 'module04b.tfvars.json', 'module05.tfvars.json') |
    ForEach-Object { Join-Path $private $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | ForEach-Object { "-var-file=$_" }
$allowed = @{ 'azurerm_function_app_flex_consumption.mcp' = 'update' }
foreach ($a in @('azapi_resource.mcp_api_policy', 'azapi_resource.prm_operation_policy', 'azapi_resource.rest_api_policy', 'azapi_resource.rest_mcp_policy', 'azapi_resource.rest_mcp_prm_operation_policy')) { $allowed[$a] = 'update' }
Invoke-GuardedPhase (Join-Path $root 'infra' 'workload') $workload $allowed 'remove the Foundry client from the allowed applications'

# 2. Entra: same var files as deployed, minus module 07.
$entra = @('entra.tfvars.json', 'entra-module05.tfvars.json') | ForEach-Object { Join-Path $private $_ } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | ForEach-Object { "-var-file=$_" }
Invoke-GuardedPhase (Join-Path $root 'infra' 'entra') $entra @{ 'azuread_application_pre_authorized.clients' = 'delete' } 'remove the Foundry client pre-authorization'
}

# 3. Foundry resource group (tag-checked), then purge the soft-deleted account so the name and quota are released.
if ($state -and $state.PSObject.Properties['foundry_resource_group'] -and $state.foundry_resource_group) {
    $group = [string]$state.foundry_resource_group
    if ($group -notmatch '^[a-zA-Z0-9_().-]{1,90}$' -or $group.EndsWith('.')) { throw 'FAIL invalid saved Foundry resource group name.' }
    $exists = Invoke-WorkshopAzureJson -Arguments @('group', 'exists', '--name', $group)
    if ($exists -isnot [bool]) { throw 'FAIL Azure did not return a Boolean resource-group existence result.' }
    $accounts = if ($state.PSObject.Properties['foundry_cleanup_accounts']) { @($state.foundry_cleanup_accounts) } else { @() }
    if ($exists) {
        $tags = Invoke-WorkshopAzureJson -Arguments @('group', 'show', '--name', $group, '--query', 'tags')
        if ($tags -isnot [System.Collections.IDictionary] -or -not $tags.Contains('workshop') -or -not $tags.Contains('module') -or
            $tags.workshop -ne 'governed-mcp' -or $tags.module -ne '07') {
            throw 'FAIL the Foundry resource group is not tagged workshop=governed-mcp and module=07; nothing was deleted.'
        }
        $accounts = Invoke-WorkshopAzureJson -Arguments @('cognitiveservices', 'account', 'list', '-g', $group, '--query', '[].{name:name,location:location}') -AllowEmptyArray
        if ($accounts -isnot [array]) { throw 'FAIL Azure did not return an account inventory array.' }
        # Foundry creates one Microsoft Entra agent identity blueprint per agent, named <account>-<project>-<agent>-...;
        # deleting the resource group does not remove it (verified 2026-10-20).
        $graph = Get-WorkshopAccessToken -TenantId $TenantId -Resource 'https://graph.microsoft.com'
        if (-not $graph.Ok) { throw 'FAIL no Microsoft Graph token to find the Foundry agent identity blueprints (expected HTTP 200).' }
        $headers = @{ Authorization = "Bearer $($graph.Value)"; ConsistencyLevel = 'eventual' }
        $projects = Invoke-WorkshopAzureJson -Arguments @('resource', 'list', '-g', $group, '--resource-type',
            'Microsoft.CognitiveServices/accounts/projects', '--query', '[].name') -AllowEmptyArray
        if ($projects -isnot [array]) { throw 'FAIL Azure did not return a Foundry project array.' }
        $blueprints = @(foreach ($a in $accounts) {
            foreach ($project in $projects) {
                $prefix = "$($a.name)-$(($project -split '/')[-1])-"
                $uri = "https://graph.microsoft.com/beta/applications?`$filter=startswith(displayName,'$prefix')&`$select=id,appId,displayName&`$count=true"
                @((Invoke-RestMethod -Uri $uri -Headers $headers).value)
            }
        })
        Write-Output "PLAN delete resource group (Foundry project, model deployment, monitoring), purge $($accounts.Count) Foundry account(s) and delete $($blueprints.Count) agent identity blueprint(s)"
        if ($Apply) {
            $state | Add-Member -NotePropertyName foundry_cleanup_accounts -NotePropertyValue @($accounts) -Force
            $pending = "$stateFile.$([guid]::NewGuid().ToString('N')).tmp"
            try {
                [IO.File]::WriteAllText($pending, ($state | ConvertTo-Json -Depth 50))
                Move-Item -LiteralPath $pending -Destination $stateFile -Force
            } finally {
                if (Test-Path -LiteralPath $pending) { Remove-Item -LiteralPath $pending -Force }
            }
            foreach ($b in $blueprints) {
                $sps = @((Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/servicePrincipals?`$filter=appId eq '$($b.appId)'&`$select=id" -Headers $headers).value)
                foreach ($sp in $sps) { Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/servicePrincipals/$($sp.id)" -Headers $headers | Out-Null }
                Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/applications/$($b.id)" -Headers $headers | Out-Null
            }
            if ($blueprints.Count) { Write-Output "PASS $($blueprints.Count) Foundry agent identity blueprint(s) deleted (expected HTTP 204 from Microsoft Graph)." }
            az group delete -n $group --yes --only-show-errors
            if ($LASTEXITCODE -ne 0) { throw 'FAIL resource group deletion. Rerun this script.' }
            Write-Output 'PASS Foundry resource group deleted (expected HTTP 200 from Azure Resource Manager).'
        }
    } else {
        Write-Output 'PASS Foundry resource group is absent (successful Azure group exists check, expected HTTP 200).'
    }
    if (-not $exists -or $Apply) {
        $deleted = Invoke-WorkshopAzureJson -Arguments @('cognitiveservices', 'account', 'list-deleted') -AllowEmptyArray
        if ($deleted -isnot [array]) { throw 'FAIL Azure did not return a deleted-account inventory array.' }
        $accountPath = '^/subscriptions/' + [regex]::Escape("$SubscriptionId") + '/resourceGroups/' +
            [regex]::Escape($group) + '/providers/Microsoft\.CognitiveServices/accounts/[^/]+$'
        $remaining = @($deleted | Where-Object { $_.id -match $accountPath })
        foreach ($a in $remaining) {
            $known = @($accounts | Where-Object { $_.name -eq $a.name -and $_.location -eq $a.location })
            if ($known.Count -ne 1) {
                throw 'FAIL a soft-deleted account has no matching saved ownership inventory. Verify it with the administrator; private files were kept.'
            }
            Write-Output 'PLAN purge one owned soft-deleted Foundry account (permanent deletion)'
            if ($Apply) {
                az cognitiveservices account purge -g $group -n $a.name -l $a.location --only-show-errors | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'FAIL Foundry account purge. Keep the private inventory and rerun after the administrator checks the exact deleted-account permissions.' }
            }
        }
        if ($Apply) {
            $verified = Invoke-WorkshopAzureJson -Arguments @('cognitiveservices', 'account', 'list-deleted') -AllowEmptyArray
            if ($verified -isnot [array] -or @($verified | Where-Object { $_.id -match $accountPath }).Count -gt 0) {
                throw 'FAIL account purge is not yet confirmed by Azure. Private files were kept; wait for propagation, then rerun.'
            }
            Write-Output "PASS $($remaining.Count) owned soft-deleted Foundry account(s) purged; private inventory was available for retry (expected HTTP 200)."
        }
    }
}

# 4. Foundry client app registration (deleting it also deletes its short-lived secret).
if ($clientId) {
    $apps = Invoke-WorkshopAzureJson -Arguments @('ad', 'app', 'list', '--filter', "appId eq '$clientId'", '--query', '[].displayName') -AllowEmptyArray
    if ($apps -isnot [array] -or $apps.Count -gt 1) { throw 'FAIL Microsoft Graph did not return an unambiguous client app lookup.' }
    if ($apps.Count -eq 0) { Write-Output 'PASS Foundry client app registration is absent (successful filtered Microsoft Graph list, expected HTTP 200).' }
    elseif ($apps[0] -notlike 'workshop-mcp-foundry-client-*') { throw 'FAIL the client app registration name does not start with workshop-mcp-foundry-client-; nothing was deleted (expected HTTP N/A).' }
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
    foreach ($file in @($workloadFile, $entraFile, $stateFile)) {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -ErrorAction Stop }
    }
    Write-Output 'DONE module 07 part A removed. Private module 07 files deleted.'
} else {
    Write-Output 'DONE report only. Nothing was changed. Rerun with -Apply after reviewing every PLAN line.'
}
