#requires -Version 7.4

# A clean-up plan may also restore the optional presenter portal to its reviewed tier when something outside Terraform
# downgraded it (for example a tenant automation that switches App Service plans to F1 at night). Only two exact
# changes qualify: the portal plan's sku_name, and the portal app's site_config.always_on (F1 cannot keep it on).
# Every other attribute must be identical, so a clean-up can never hide a real portal change.
function Test-WorkshopPortalTierRestore {
    param([Parameter(Mandatory)]$Change)
    try { return Test-WorkshopPortalTierRestoreCore $Change } catch { return $false }
}

function Test-WorkshopPortalTierRestoreCore {
    param([Parameter(Mandatory)]$Change)
    if (($Change.change.actions -join ',') -ne 'update') { return $false }
    $address = $Change.address -replace '\[[^\]]+\]$', ''
    $before = $Change.change.before; $after = $Change.change.after
    if ($before -isnot [System.Collections.IDictionary] -or $after -isnot [System.Collections.IDictionary]) { return $false }
    $json = { param($value) $value | ConvertTo-Json -Depth 50 -Compress }
    $keys = @(@($before.Keys) + @($after.Keys) | Sort-Object -Unique)
    if ($address -eq 'azurerm_service_plan.portal') {
        foreach ($key in $keys) { if ($key -ne 'sku_name' -and (& $json $before[$key]) -ne (& $json $after[$key])) { return $false } }
        return $before.sku_name -cne $after.sku_name
    }
    if ($address -eq 'azurerm_linux_web_app.portal') {
        $changed = $false
        foreach ($key in $keys) {
            if ($key -ne 'site_config') { if ((& $json $before[$key]) -ne (& $json $after[$key])) { return $false }; continue }
            $b = @($before.site_config)[0]; $a = @($after.site_config)[0]
            if ($b -isnot [System.Collections.IDictionary] -or $a -isnot [System.Collections.IDictionary]) { return $false }
            foreach ($name in @(@($b.Keys) + @($a.Keys) | Sort-Object -Unique)) {
                if ((& $json $b[$name]) -eq (& $json $a[$name])) { continue }
                if ($name -ne 'always_on') { return $false }
                $changed = $true
            }
        }
        return $changed
    }
    return $false
}

# Compares one top-level resource attribute, ignoring site_config.always_on (see Test-WorkshopPortalTierRestore).
function Get-WorkshopPortalAttributeJson {
    param([string]$Name, $Value)
    if ($Name -eq 'site_config' -and $null -ne $Value) {
        $copy = @(@($Value) | ForEach-Object { if ($_ -is [System.Collections.IDictionary]) { $c = [ordered]@{} + $_; $c.Remove('always_on'); $c } else { $_ } })
        return $copy | ConvertTo-Json -Depth 50 -Compress
    }
    return $Value | ConvertTo-Json -Depth 50 -Compress
}

function Write-WorkshopPortalTierNotes {
    param([object[]]$Changes)
    foreach ($change in @($Changes | Where-Object { Test-WorkshopPortalTierRestore $_ })) {
        Write-Output "NOTE plan also restores $($change.address) to its reviewed tier (changed outside Terraform, for example F1 at night). Not a module change; the portal is kept."
    }
}

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

function Get-WorkshopAccessToken {
    # Requests a token with Azure CLI and never waits for an interactive sign-in. When Microsoft Entra refuses the
    # token (for example AADSTS50105 for an unassigned user), recent Azure CLI versions fall back to a pop-up sign-in
    # that never returns in a script; the refusal is already written to stderr, so stop after a short wait.
    param([Parameter(Mandatory)][string]$TenantId, [Parameter(Mandatory)][string]$Resource, [int]$TimeoutSeconds = 60)
    $arguments = @('account', 'get-access-token', '--tenant', $TenantId, '--resource', $Resource, '--query', 'accessToken', '--output', 'tsv')
    $pattern = '^[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*$'
    $command = Get-Command az -ErrorAction Stop | Select-Object -First 1
    if ($command.CommandType -ne 'Application') {
        # A PowerShell function or alias (for example a test double) runs in-process with the same parsing.
        $output = (& az @arguments 2>&1 | Out-String).Trim()
        $ok = $LASTEXITCODE -eq 0 -and $output -match $pattern
        return [pscustomobject]@{ Ok = $ok; Value = $(if ($ok) { $output } else { [regex]::Match($output, 'AADSTS\d+').Value }) }
    }
    $info = [System.Diagnostics.ProcessStartInfo]::new($command.Source)
    foreach ($argument in $arguments) { $info.ArgumentList.Add($argument) }
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($info)
    $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
    $exited = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $exited) { try { $process.Kill($true) } catch { } }
    $text = $stdout.Result.Trim(); $errors = $stderr.Result
    $ok = $exited -and $process.ExitCode -eq 0 -and $text -match $pattern
    # Only the AADSTS error code is kept from stderr: no trace ID, user name or token is returned.
    $code = [regex]::Match($errors, 'AADSTS\d+').Value
    return [pscustomobject]@{ Ok = $ok; Value = $(if ($ok) { $text } else { $code }) }
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
