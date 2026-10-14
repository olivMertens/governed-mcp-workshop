#requires -Version 7.4

function Assert-WorkshopInteractiveEnvironment {
    foreach ($name in @('ARM_CLIENT_ID', 'ARM_CLIENT_SECRET', 'ARM_CLIENT_CERTIFICATE_PATH',
        'ARM_CLIENT_CERTIFICATE', 'ARM_CLIENT_CERTIFICATE_PASSWORD', 'ARM_USE_MSI',
        'ARM_USE_OIDC', 'ARM_OIDC_TOKEN', 'ARM_ACCESS_KEY', 'AZURE_CLIENT_ID',
        'AZURE_CLIENT_SECRET', 'AZURE_CLIENT_CERTIFICATE_PATH', 'ARM_ENVIRONMENT',
        'ARM_USE_CLI', 'ARM_USE_AKS_WORKLOAD_IDENTITY', 'ARM_OIDC_TOKEN_FILE_PATH',
        'ARM_OIDC_REQUEST_TOKEN', 'ARM_OIDC_REQUEST_URL', 'AZURE_FEDERATED_TOKEN_FILE',
        'AZURE_AUTHORITY_HOST', 'ARM_MSI_ENDPOINT', 'ARM_CLIENT_ID_FILE_PATH',
        'ARM_TENANT_ID_FILE_PATH', 'ARM_SUBSCRIPTION_ID_FILE_PATH')) {
        if ([Environment]::GetEnvironmentVariable($name)) {
            throw 'An authentication override is present. Use a separate approved interactive-user terminal; do not combine credential flows.'
        }
    }
}

function Invoke-WorkshopAzureJson {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $text = & az @Arguments --output json --only-show-errors 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI '$($Arguments[0])' read/check failed. Verify the selected context and exact scoped permissions privately; no resource was changed by this check."
    }
    try { $value = ConvertFrom-Json -InputObject $text -AsHashtable -Depth 100 -ErrorAction Stop }
    catch [System.ArgumentException] { throw 'Azure CLI returned invalid JSON; the check cannot pass.' }
    if ($null -eq $value) { throw 'Azure CLI returned no data; the check cannot pass.' }
    return ,$value
}

function Assert-WorkshopAzureContext {
    param([Parameter(Mandatory)][guid]$TenantId, [Parameter(Mandatory)][guid]$SubscriptionId)
    if ($TenantId -eq [guid]::Empty -or $SubscriptionId -eq [guid]::Empty) {
        throw 'Specify the approved non-production tenant and subscription; empty identifiers are refused.'
    }
    Assert-WorkshopInteractiveEnvironment
    foreach ($entry in @{ ARM_TENANT_ID = $TenantId; ARM_SUBSCRIPTION_ID = $SubscriptionId }.GetEnumerator()) {
        $current = [Environment]::GetEnvironmentVariable($entry.Key)
        if ($current -and $current -ne $entry.Value.ToString()) {
            throw 'ARM context variables differ from the explicit target. Use the approved context selector in a separate terminal.'
        }
    }
    $cloud = Invoke-WorkshopAzureJson -Arguments @('cloud', 'show')
    if ($cloud.name -ne 'AzureCloud') { throw 'Only Azure public cloud is supported by this workshop.' }
    $account = Invoke-WorkshopAzureJson -Arguments @('account', 'show', '--query',
        '{id:id,tenantId:tenantId,state:state,environmentName:environmentName,userType:user.type}')
    if ($account.id -ne $SubscriptionId.ToString() -or $account.tenantId -ne $TenantId.ToString() -or
        $account.state -ne 'Enabled' -or $account.environmentName -ne 'AzureCloud' -or $account.userType -ne 'user') {
        throw 'The active interactive account does not match the explicit enabled test target. No login or subscription switch was attempted.'
    }
}

function Read-WorkshopParameters {
    param([Parameter(Mandatory)][string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $parent = Get-Item -LiteralPath $item.DirectoryName -Force -ErrorAction Stop
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Participant parameters must be a regular file in a regular directory.'
    }
    $value = Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    $patterns = @{
        participant_prefix = '^[a-z][a-z0-9]{1,7}$'
        resource_suffix = '^([a-f0-9]{10}|[a-f0-9]{16})$'
        location = '^[a-z][a-z0-9]+$'
        owner = '^[a-z][a-z0-9-]{1,31}$'
        expiry = '^\d{4}-\d{2}-\d{2}$'
    }
    if ($value -isnot [System.Collections.IDictionary]) { throw 'Participant parameters must be an object.' }
    $allowed = @($patterns.Keys) + 'existing_resource_group_name', 'public_portal_enabled'
    if ($value.Keys | Where-Object { $_ -notin $allowed }) { throw 'Unexpected participant parameter; use the preparation script.' }
    foreach ($entry in $patterns.GetEnumerator()) {
        if ($value[$entry.Key] -isnot [string] -or $value[$entry.Key] -cnotmatch $entry.Value) {
            throw "Invalid participant parameter '$($entry.Key)'."
        }
    }
    $date = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($value.expiry, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None, [ref]$date) -or $date.Date -le [datetime]::UtcNow.Date) {
        throw 'Participant expiry must be a real future date. Preserve the suffix and state when reviewing an expired deployment.'
    }
    if (-not $value.Contains('existing_resource_group_name') -or ($null -ne $value.existing_resource_group_name -and
        ($value.existing_resource_group_name -isnot [string] -or
         $value.existing_resource_group_name -notmatch '^[a-zA-Z0-9_().-]{1,90}$' -or
         $value.existing_resource_group_name.EndsWith('.')))) {
        throw 'Invalid existing resource group parameter.'
    }
    if ($value.Contains('public_portal_enabled') -and $value.public_portal_enabled -isnot [bool]) {
        throw 'public_portal_enabled must be a Boolean.'
    }
    return $value
}
