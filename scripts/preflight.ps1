#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [ValidateSet('foundation', 'portal', 'mcp')][string]$Stage = 'foundation',
    [ValidateSet('terraform', 'low-code')][string]$Track = 'terraform',
    [string]$ParametersPath = (Join-Path (Split-Path $PSScriptRoot -Parent) '.workshop/participant.tfvars.json'),
    [string]$CapacityReviewPath,
    [ValidateSet(512, 2048, 4096)][int]$FlexMemoryMB = 2048,
    [ValidateRange(1, 1000)][int]$FlexMaximumInstances = 10
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'context-common.ps1')
$dynamicInstall = $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL
$env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = 'no'
try {
    & (Join-Path $PSScriptRoot 'check-tools.ps1') -Track $Track
    $parameters = Read-WorkshopParameters -Path $ParametersPath
    Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
    Write-Output 'PASS explicit interactive context (expected HTTP N/A; no sign-in, token output or context change)'

    $subscription = $SubscriptionId.ToString()
    $scope = "/subscriptions/$subscription"
    $prefix = if ($Track -eq 'low-code') { "$($parameters.participant_prefix)lc" } else { $parameters.participant_prefix }
    $stem = "mcp-$prefix-$($parameters.resource_suffix)"
    $group = if ($parameters.existing_resource_group_name) { $parameters.existing_resource_group_name } else { "rg-$stem" }
    $groupScope = "$scope/resourceGroups/$group"
    if ($Stage -ne 'foundation' -or $parameters.existing_resource_group_name) {
        $groupInfo = Invoke-WorkshopAzureJson -Arguments @('group', 'show', '--name', $group, '--subscription', $subscription)
        if ($groupInfo.id -ne $groupScope) { throw 'Resource group lookup does not match the explicit target.' }
        $permissionScope = $groupScope
    } else { $permissionScope = $scope }
    $locations = Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--url',
        "https://management.azure.com$scope/locations?api-version=2022-12-01")
    if (-not $locations.Contains('value') -or $locations.value -isnot [System.Collections.IList]) {
        throw 'The subscription locations response is missing its documented array.'
    }
    if (-not (@($locations.value) | Where-Object { $_.name -eq $parameters.location })) {
        throw 'FAIL region (expected HTTP 200 and the selected region in the subscription location list).'
    }
    Write-Output 'PASS subscription region (expected HTTP 200; availability is not a capacity reservation)'

    $requiredProviders = switch ($Stage) {
        'foundation' { @('Microsoft.Resources') }
        'portal' { @('Microsoft.Resources', 'Microsoft.Web') }
        'mcp' { @('Microsoft.Resources', 'Microsoft.Web', 'Microsoft.App', 'Microsoft.Storage',
            'Microsoft.ManagedIdentity', 'Microsoft.Network', 'Microsoft.Insights',
            'Microsoft.OperationalInsights', 'Microsoft.ApiManagement', 'Microsoft.ApiCenter') }
    }
    $providers = Invoke-WorkshopAzureJson -Arguments @('provider', 'list', '--subscription', $subscription)
    foreach ($provider in $requiredProviders) {
        if (-not (@($providers) | Where-Object { $_.namespace -eq $provider -and $_.registrationState -eq 'Registered' })) {
            throw "FAIL provider $provider (expected HTTP 200 and Registered). Ask the administrator; this script never registers providers."
        }
        Write-Output "PASS provider $provider (expected HTTP 200; Registered)"
    }

    $permissions = @()
    $url = "https://management.azure.com$permissionScope/providers/Microsoft.Authorization/permissions?api-version=2022-04-01"
    $pages = 0
    while ($url) {
        $uri = $null
        if ($url -isnot [string] -or -not [uri]::TryCreate($url, [UriKind]::Absolute, [ref]$uri) -or
            $uri.Scheme -ne 'https' -or $uri.Host -ne 'management.azure.com' -or $uri.Port -ne 443 -or
            $uri.UserInfo -or $uri.Fragment -or
            $uri.AbsolutePath -ine "$permissionScope/providers/Microsoft.Authorization/permissions" -or
            ++$pages -gt 100) {
            throw 'Unsafe or excessive permissions pagination was refused.'
        }
        $page = Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--url', $url)
        if (-not $page.Contains('value') -or $page.value -isnot [System.Collections.IList]) {
            throw 'The permissions response is missing its documented array.'
        }
        $permissions += @($page.value)
        $url = if ($page.Contains('nextLink')) { $page.nextLink } else { $null }
    }
    $requiredActions = @('Microsoft.Resources/subscriptions/resourceGroups/read')
    if ($Stage -eq 'foundation' -and -not $parameters.existing_resource_group_name) {
        $requiredActions += 'Microsoft.Resources/subscriptions/resourceGroups/write', 'Microsoft.Resources/subscriptions/resourceGroups/delete'
    }
    if ($Stage -in @('portal', 'mcp')) {
        foreach ($resource in @('Microsoft.Web/serverfarms', 'Microsoft.Web/sites')) {
            foreach ($verb in @('read', 'write', 'delete')) { $requiredActions += "$resource/$verb" }
        }
    }
    if ($Stage -eq 'portal') {
        $requiredActions += 'Microsoft.Web/sites/publish/Action', 'Microsoft.Web/serverfarms/join/action',
            'Microsoft.Web/sites/config/read', 'Microsoft.Web/sites/config/write', 'Microsoft.Web/sites/config/list/action',
            'Microsoft.Web/sites/basicPublishingCredentialsPolicies/read', 'Microsoft.Web/sites/basicPublishingCredentialsPolicies/write'
    }
    if ($Stage -eq 'mcp') {
        foreach ($resource in @('Microsoft.Storage/storageAccounts', 'Microsoft.ManagedIdentity/userAssignedIdentities',
            'Microsoft.Network/virtualNetworks', 'Microsoft.Network/privateEndpoints', 'Microsoft.Network/privateDnsZones',
            'Microsoft.Insights/components', 'Microsoft.OperationalInsights/workspaces',
            'Microsoft.ApiManagement/service', 'Microsoft.ApiCenter/services')) {
            foreach ($verb in @('read', 'write', 'delete')) { $requiredActions += "$resource/$verb" }
        }
        $requiredActions += 'Microsoft.Authorization/roleAssignments/write', 'Microsoft.Authorization/roleAssignments/delete'
    }
    foreach ($action in $requiredActions) {
        $granted = $false
        foreach ($permission in $permissions) {
            if (-not $permission.Contains('actions') -or -not $permission.Contains('notActions')) {
                throw 'The permissions response is malformed.'
            }
            $allow = @($permission.actions | Where-Object { $action -like $_ }).Count -gt 0
            $exclude = @($permission.notActions | Where-Object { $action -like $_ }).Count -gt 0
            if ($allow -and -not $exclude) { $granted = $true; break }
        }
        if (-not $granted) { throw "FAIL permission grant for $action (expected HTTP 200 and a matching grant at the required scope)." }
    }
    Write-Output 'PASS required ARM permission grants (expected HTTP 200; deny assignments, policy and deployment approval remain separate)'

    if ($Stage -eq 'foundation' -and -not $parameters.existing_resource_group_name) {
        $groups = Invoke-WorkshopAzureJson -Arguments @('group', 'list', '--subscription', $subscription)
        if ($groups -isnot [System.Collections.IList]) { throw 'The resource groups response is missing its documented array.' }
        $count = $groups.Count
        if ($count -ge 980 -or $count -lt 0) { throw 'FAIL resource group capacity (expected HTTP 200 and fewer than 980 groups).' }
        Write-Output 'PASS resource group capacity (expected HTTP 200; below the documented 980-group limit)'
    } elseif ($Stage -eq 'foundation') {
        Write-Output 'PASS existing group mode (expected HTTP N/A; no new group quota required and group is not managed)'
    }
    if ($Stage -eq 'portal') {
        $regions = Invoke-WorkshopAzureJson -Arguments @('appservice', 'list-locations', '--sku', 'B1',
            '--linux-workers-enabled', '--subscription', $subscription)
        if (-not (@($regions) | Where-Object { ($_.name -replace ' ', '') -eq $parameters.location })) {
            throw 'FAIL B1 Linux region (expected HTTP 200 and the selected region).'
        }
        Write-Output 'PASS B1 Linux region (expected HTTP 200; paid worker capacity is reviewed separately)'
    }
    if ($Stage -eq 'mcp') {
        $regions = Invoke-WorkshopAzureJson -Arguments @('functionapp', 'list-flexconsumption-locations', '--subscription', $subscription)
        $runtimes = Invoke-WorkshopAzureJson -Arguments @('functionapp', 'list-flexconsumption-runtimes',
            '--location', $parameters.location, '--runtime', 'dotnet-isolated', '--subscription', $subscription)
        if (-not (@($regions) | Where-Object { $_.name -eq $parameters.location }) -or
            -not (@($runtimes) | Where-Object { $_.name -eq 'dotnet-isolated' -and $_.version -match '^10(\.0)?$' })) {
            throw 'FAIL Flex region/runtime (expected HTTP 200, selected region and isolated .NET 10).'
        }
        Write-Output 'PASS Flex region and isolated .NET 10 runtime (expected HTTP 200; does not reserve compute)'
    }
    if ($Stage -ne 'foundation') {
        if (-not $CapacityReviewPath) {
            throw 'FAIL capacity review: provide a private, same-target quota/cost review from the last 24 hours. Region availability alone cannot pass this gate.'
        }
        $reviewItem = Get-Item -LiteralPath $CapacityReviewPath -Force
        if ($reviewItem.PSIsContainer -or ($reviewItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Capacity evidence must be a regular private file.'
        }
        $jsonOptions = @{ AsHashtable = $true }
        if ($PSVersionTable.PSVersion -ge [version]'7.5') { $jsonOptions.DateKind = 'String' }
        $review = Get-Content -LiteralPath $reviewItem.FullName -Raw | ConvertFrom-Json @jsonOptions
        $checked = [datetimeoffset]::MinValue
        $now = [datetimeoffset]::UtcNow
        $required = if ($Stage -eq 'portal') { 1 } else { $FlexMemoryMB * $FlexMaximumInstances }
        $unit = if ($Stage -eq 'portal') { 'workers' } else { 'MB' }
        if ($review.subscriptionId -ne $subscription -or $review.location -ne $parameters.location -or
            $review.stage -ne $Stage -or $review.unit -cne $unit -or $review.costApproved -isnot [bool] -or
            -not $review.costApproved -or ($review.availableUnits -isnot [long] -and $review.availableUnits -isnot [int]) -or
            $review.availableUnits -lt $required -or
            -not [datetimeoffset]::TryParseExact($review.checkedAtUtc, 'yyyy-MM-ddTHH:mm:ssZ',
                [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$checked) -or
            $checked -gt $now -or $checked -lt $now.AddHours(-24)) {
            throw 'FAIL capacity/cost review: stale, insufficient, malformed or for a different target.'
        }
        Write-Output 'PASS private human capacity/cost review (expected HTTP N/A; not a live quota API check or reservation)'
    }
    Write-Output "PASS $Stage preflight only. No resource, registration, permission, login or context was changed. A real plan and separate approval are still required."
} finally { $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = $dynamicInstall }
