#requires -Version 7.4
<#
.SYNOPSIS
    Module 04 low-code track: fills the two gateway policy templates with your values, without Terraform.
.DESCRIPTION
    Reads policies/mcp-server.xml and policies/protected-resource-metadata.xml (the same templates Terraform uses) and
    writes the ready-to-paste XML to .workshop/policy-mcp-server.xml and .workshop/policy-prm.xml. Only non-secret
    values go in: tenant ID, the MCP API client ID (audience), allowed client IDs, limits and URLs.
.EXAMPLE
    pwsh ./modules/04-governed-gateway/render-policies.ps1 -TenantId $tenant -ApiClientId $apiClientId -GatewayName $apim
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][guid]$ApiClientId,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{1,50}$')][string]$GatewayName,
    [guid[]]$AllowedClientIds = @('aebc6443-996d-45c2-90f0-388ff96faa56', '04b07795-8ddb-461a-bbee-02f9e1bf7b46'), # VS Code, Azure CLI
    [ValidateRange(1, 1000)][int]$RateLimitCalls = 30,
    [ValidateRange(1, 3600)][int]$RateLimitPeriod = 60,
    [ValidatePattern('^[a-z0-9-]+$')][string]$McpPath = 'workshop-mcp',
    # Optional allow-list, for example '203.0.113.0/24'. Empty: no IP filter.
    [string[]]$AllowedIpRanges = @()
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$out = Join-Path $root '.workshop'
$null = New-Item -ItemType Directory -Force -Path $out

$gateway = "https://$GatewayName.azure-api.net"
$values = @{
    tenant_id = "$TenantId"; rate_limit_calls = "$RateLimitCalls"; rate_limit_period = "$RateLimitPeriod"; mcp_path = $McpPath
    resource = "$gateway/$McpPath/mcp"; issuer = "https://login.microsoftonline.com/$TenantId/v2.0"
    scope = "api://$ApiClientId/user_impersonation"; resource_metadata_url = "$gateway/.well-known/oauth-protected-resource/$McpPath/mcp"
}
$lists = @{ client_ids = @($AllowedClientIds | ForEach-Object { "$_" }); audiences = @("api://$ApiClientId", "$ApiClientId") }
$ranges = @(foreach ($cidr in $AllowedIpRanges) {
    $ip, $bits = $cidr -split '/'; $bits = [int]$bits
    $bytes = ([Net.IPAddress]::Parse($ip)).GetAddressBytes(); [Array]::Reverse($bytes); $start = [BitConverter]::ToUInt32($bytes, 0)
    $all = [uint64]4294967295
    $mask = [uint64](($all -shl (32 - $bits)) -band $all)
    $first = [uint64]$start -band $mask; $last = $first -bor ($all -bxor $mask)
    $toIp = { param($n) $b = [BitConverter]::GetBytes([uint32]$n); [Array]::Reverse($b); ([Net.IPAddress]::new($b)).ToString() }
    @{ from = & $toIp $first; to = & $toIp $last }
})

function Expand-Template([string]$Text, [hashtable]$Override = @{}) {
    $local = $values.Clone(); foreach ($k in $Override.Keys) { $local[$k] = $Override[$k] }
    $Text = $Text -replace "`r`n", "`n"
    # %{ if length(ip_ranges) > 0 ~} ... %{ endif ~}
    $Text = [regex]::Replace($Text, '(?s)%\{ if length\(ip_ranges\) > 0 ~\}\n(.*?)%\{ endif ~\}\n', { param($m) if ($ranges.Count) { $m.Groups[1].Value } else { '' } })
    # %{ for range in ip_ranges ~} ... %{ endfor ~}
    $Text = [regex]::Replace($Text, '(?s)%\{ for range in ip_ranges ~\}\n(.*?)%\{ endfor ~\}\n', {
        param($m) ($ranges | ForEach-Object { $m.Groups[1].Value.Replace('${range.from}', $_.from).Replace('${range.to}', $_.to) }) -join '' })
    foreach ($name in $lists.Keys) {
        $item = if ($name -eq 'client_ids') { 'client_id' } else { 'audience' }
        $Text = [regex]::Replace($Text, "(?s)%\{ for $item in $name ~\}\n(.*?)%\{ endfor ~\}\n", {
            param($m) ($lists[$name] | ForEach-Object { $m.Groups[1].Value.Replace("`${$item}", $_) }) -join '' })
    }
    foreach ($name in $local.Keys) { $Text = $Text.Replace("`${$name}", $local[$name]) }
    if ($Text -match '\$\{|%\{') { throw 'FAIL a template placeholder was left unfilled (expected HTTP N/A).' }
    return $Text
}

$policies = Join-Path $PSScriptRoot 'policies'
# Part B (optional): the REST API exposed as MCP has its own path and metadata URL.
$restUrls = @{ resource = "$gateway/contoso-tickets-mcp/mcp"; resource_metadata_url = "$gateway/.well-known/oauth-protected-resource/contoso-tickets-mcp/mcp" }
$files = [ordered]@{
    'policy-mcp-server.xml' = @('mcp-server.xml', @{}); 'policy-prm.xml' = @('protected-resource-metadata.xml', @{})
    'policy-rest-api.xml' = @('rest-api.xml', @{}); 'policy-rest-mcp-server.xml' = @('rest-mcp-server.xml', $restUrls)
    'policy-rest-prm.xml' = @('protected-resource-metadata.xml', $restUrls)
}
foreach ($target in $files.Keys) {
    $source, $override = $files[$target]
    [IO.File]::WriteAllText((Join-Path $out $target), (Expand-Template (Get-Content -Raw (Join-Path $policies $source)) $override))
}
Write-Output "PASS $($files.Count) policies rendered for $gateway with $($lists.client_ids.Count) allowed client(s) and $($ranges.Count) IP range(s) in .workshop/ (part A: policy-mcp-server.xml, policy-prm.xml; part B: policy-rest-*.xml) (expected HTTP N/A)."
