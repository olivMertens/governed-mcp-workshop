#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9]{1,7}$')][string]$ParticipantPrefix,
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9]+$')][string]$Location,
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{1,31}$')][string]$Owner,
    [Parameter(Mandatory)][string]$Expiry,
    [ValidatePattern('^[a-zA-Z0-9_().-]{1,90}$')][string]$ExistingResourceGroupName
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$date = [datetime]::MinValue
if (-not [datetime]::TryParseExact($Expiry, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None, [ref]$date) -or $date.Date -le [datetime]::UtcNow.Date) {
    throw 'Expiry must be a future UTC date in yyyy-MM-dd format. It is a tag, not automatic deletion.'
}
if ($ExistingResourceGroupName -and $ExistingResourceGroupName.EndsWith('.')) {
    throw 'A resource group name must not end with a period.'
}
$directory = Join-Path (Split-Path $PSScriptRoot -Parent) '.workshop'
$path = Join-Path $directory 'participant.tfvars.json'
$configuration = [ordered]@{
    participant_prefix = $ParticipantPrefix
    location = $Location
    owner = $Owner
    expiry = $Expiry
    existing_resource_group_name = $(if ($ExistingResourceGroupName) { $ExistingResourceGroupName } else { $null })
}
if (Test-Path -LiteralPath $directory) {
    $entry = Get-Item -LiteralPath $directory -Force
    if (-not $entry.PSIsContainer -or $entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw '.workshop must be a regular local directory.'
    }
} else { [void](New-Item -ItemType Directory -Path $directory) }
if (Test-Path -LiteralPath $path) {
    $entry = Get-Item -LiteralPath $path -Force
    if ($entry.PSIsContainer -or $entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Participant parameters must be a regular local file.'
    }
    $before = Get-Content -LiteralPath $path -Raw
    $existing = $before | ConvertFrom-Json -AsHashtable
    if ($existing.ContainsKey('public_portal_enabled')) {
        throw 'Azure portal hosting is retired. Follow docs/HOSTING.md to remove the old portal safely before removing public_portal_enabled from your private parameters. Keep the same suffix and state.'
    }
    $keys = @($configuration.Keys) + 'resource_suffix'
    $expectedCount = $configuration.Count + 1
    if ($existing.Count -ne $expectedCount -or ($existing.Keys | Where-Object { $_ -notin $keys }) -or
        $existing.resource_suffix -isnot [string] -or $existing.resource_suffix -cnotmatch '^([a-f0-9]{10}|[a-f0-9]{16})$') {
        throw 'Invalid participant file. Restore the original private parameters; do not regenerate names for deployed resources.'
    }
    foreach ($key in $configuration.Keys) {
        if ($existing[$key] -cne $configuration[$key]) {
            throw "Participant setting '$key' differs. Refusing to overwrite parameters or silently replace resources."
        }
    }
    Write-Output 'PASS existing participant parameters reused unchanged.'
} else {
    $workload = Join-Path (Split-Path $PSScriptRoot -Parent) 'infra' 'workload'
    $statePaths = @(
        (Join-Path $workload 'terraform.tfstate'),
        (Join-Path $workload 'terraform.tfstate.backup'),
        (Join-Path $workload 'terraform.tfstate.d'),
        (Join-Path $workload '.terraform' 'terraform.tfstate')
    )
    $savedPlans = @(Get-ChildItem -LiteralPath $directory -File -Force |
        Where-Object { $_.Name -match '\.(tfplan|tfstate)(\.backup)?$' })
    if (($statePaths | Where-Object { Test-Path -LiteralPath $_ }) -or $savedPlans.Count -gt 0) {
        throw 'Participant parameters are missing but local state or saved plans exist. Restore the original private parameters; refusing to generate replacement names.'
    }
    $configuration.resource_suffix = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(8)).ToLowerInvariant()
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($configuration | ConvertTo-Json) + "`n")
    $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes) } finally { $stream.Dispose() }
    Write-Output 'PASS private participant parameters created with a stable random suffix.'
}
Write-Output 'PASS no Azure command executed. Keep .workshop and Terraform state private and backed up through cleanup.'
Write-Output 'NEXT read docs/GETTING-STARTED.md before any Terraform plan or apply.'
