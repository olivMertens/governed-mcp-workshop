#requires -Version 7.4
<#
.SYNOPSIS
    Module 02 validator: offline repository invariants, then live HTTP checks when a deployment exists.
.DESCRIPTION
    Offline mode (default when no tenant/subscription is given, or with -Offline) needs no Azure access.
    Live mode reads the endpoint and the mcp_extension system key at runtime from Azure CLI, keeps the key in memory
    only and never prints, logs or writes it. Each check prints one PASS or FAIL line with the expected HTTP status.
#>
[CmdletBinding()]
param(
    [switch]$Offline,
    [guid]$TenantId,
    [guid]$SubscriptionId,
    [switch]$DemonstrateWrite,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$server = Join-Path $root 'src' 'FunctionsMcpServer'
$workload = Join-Path $root 'infra' 'workload'
$expectedTools = @('create_ticket', 'get_service_health', 'read_report_as_app', 'read_report_as_user', 'whoami')

function Pass([string]$Message) { Write-Output "PASS $Message" }
function Fail([string]$Message) { throw "FAIL $Message" }
$script:StepNumber = 0
function Step([string]$Title, [string]$Why) {
    $script:StepNumber++
    Write-Output ''; Write-Output "== Step $($script:StepNumber): $Title =="; Write-Output "   Why: $Why"
}
Write-Output 'Module 02 validator - the open server answers only with its function key, and shows why a key alone is not enough.'

# ---------------------------------------------------------------- offline checks (always run)

Step 'Offline - your copy keeps the key gate closed and holds no secret (no Azure call)' 'Proves the code and Terraform never open an anonymous endpoint or store a key.'
$hostJson = Get-Content -LiteralPath (Join-Path $server 'host.json') -Raw | ConvertFrom-Json -AsHashtable
$level = $hostJson.extensions?.mcp?.system?.webhookAuthorizationLevel
if ($level -cne 'System') { Fail 'host.json webhookAuthorizationLevel must be System (expected HTTP 401 without key).' }
Pass 'host.json MCP webhook authorization level is System (expected HTTP 401 without the mcp_extension key).'

$sources = Get-ChildItem -LiteralPath $server -Recurse -File -Include *.cs, *.json, *.csproj |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' -and $_.Name -ne 'packages.lock.json' }
if ($sources | Select-String -Pattern 'Anonymous|AuthorizationLevel\.' -SimpleMatch:$false) {
    Fail 'server source must not configure anonymous or custom authorization levels (expected HTTP N/A).'
}
Pass 'no anonymous authorization level in server source (expected HTTP N/A).'

$scanned = @($sources) + @(Get-ChildItem -LiteralPath $workload -Filter *.tf -File) +
    @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.md -File)
$secretPatterns = @(
    'AccountKey=', 'SharedAccessSignature=', '[?&]sig=[A-Za-z0-9%]', 'client_secret', 'ClientSecret',
    'x-functions-key"\s*:\s*"[A-Za-z0-9]', '[?&]code=[A-Za-z0-9_\-]{20,}', 'InstrumentationKey=[0-9a-f]{8}-'
)
foreach ($pattern in $secretPatterns) {
    if ($scanned | Select-String -Pattern $pattern) { Fail "possible secret pattern found in module 02 files (expected HTTP N/A)." }
}
if (Test-Path -LiteralPath (Join-Path $server 'local.settings.json')) {
    Fail 'local.settings.json must not exist in the server folder; use the documented environment (expected HTTP N/A).'
}
Pass 'no key, SAS, connection-string or client-secret pattern in module 02 files (expected HTTP N/A).'

$terraformText = Get-Content -LiteralPath (Join-Path $workload 'mcp-server.tf') -Raw
if ($terraformText -notmatch 'shared_access_key_enabled\s*=\s*false' -or $terraformText -notmatch 'storage_authentication_type\s*=\s*"UserAssignedIdentity"' -or
    $terraformText -match 'storage_access_key\s*=' -or $terraformText -match '(?i)listkeys|functionapp_host_keys|function_app_host_keys') {
    Fail 'Terraform must keep shared keys disabled, identity storage, and no key outputs (expected HTTP N/A).'
}
Pass 'Terraform disables Storage shared keys, uses managed identity and outputs no key (expected HTTP N/A).'

if (-not $SkipBuild) {
    Step 'Offline - build, unit tests and Terraform mock plans' 'Proves the server compiles, the tools behave and the plan is valid, without deploying.'
    $tests = Join-Path $root 'tests' 'FunctionsMcpServer.Tests' 'FunctionsMcpServer.Tests.csproj'
    & dotnet restore $tests --locked-mode --verbosity quiet
    if ($LASTEXITCODE -ne 0) { Fail 'locked package restore (expected HTTP N/A; check SDK, package access and lock files).' }
    & dotnet test $tests --no-restore --configuration Release --verbosity quiet --nologo
    if ($LASTEXITCODE -ne 0) { Fail 'server build and unit tests (expected HTTP N/A).' }
    Pass 'locked build and tool unit tests: synthetic results, strict inputs, no write without the exact shape (expected HTTP N/A).'

    foreach ($arguments in @(@('fmt', '-check', '-recursive'), @('validate', '-no-color'), @('test', '-no-color'))) {
        $output = & terraform "-chdir=$workload" @arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            $output | Select-Object -Last 15 | ForEach-Object { Write-Warning $_ }
            Fail 'Terraform checks (expected HTTP N/A). Install Terraform 1.16.6+ and run init with the locked provider first.'
        }
    }
    Pass 'Terraform format, schema and mock-only plans, including module 02 opt-in (expected HTTP N/A; no live plan/apply).'
}

if ($Offline -or -not $TenantId -or -not $SubscriptionId -or $TenantId -eq [guid]::Empty -or $SubscriptionId -eq [guid]::Empty) {
    Write-Output 'NOT DEPLOYED CHECKS SKIPPED: supply -TenantId and -SubscriptionId after an approved deployment for HTTP checks.'
    Write-Output 'PASS offline checks only. Module 02 is NOT deployed or Azure-validated by this result.'
    return
}

# ---------------------------------------------------------------- live checks (approved deployment only)

. (Join-Path $root 'scripts' 'context-common.ps1')
Step 'Live - Azure context and Function App state' 'Proves you target the approved subscription and the app runs over HTTPS only.'
Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
Pass 'explicit Azure context matches the approved test target (expected HTTP 200 from Azure Resource Manager).'

$outputs = & terraform "-chdir=$workload" output -json | ConvertFrom-Json -AsHashtable
if ($LASTEXITCODE -ne 0 -or $null -eq $outputs) { Fail 'Terraform outputs unavailable; use the same private state as the deployment (expected HTTP N/A).' }
$app = $outputs.mcp_function_app_name?.value
$group = $outputs.resource_group_name?.value
if (-not $app -or -not $group) { Fail 'module 02 is not deployed in this state (enable_mcp_server is false). Deploy it first, or use -Offline.' }

$site = Invoke-WorkshopAzureJson -Arguments @('functionapp', 'show', '--resource-group', $group, '--name', $app,
    # Azure CLI 2.91 returns the raw ARM shape (fields under properties) for Flex Consumption apps; older versions flatten it.
    '--query', '{host:properties.defaultHostName || defaultHostName,httpsOnly:properties.httpsOnly || httpsOnly,state:properties.state || state}')
if (-not $site.httpsOnly -or $site.state -ne 'Running' -or $site.host -notmatch '^[a-z0-9.-]+$') {
    Fail 'Function App must be running with HTTPS only (expected HTTP 200 from Azure Resource Manager).'
}
Pass 'Function App is running and HTTPS-only (expected HTTP 200 from Azure Resource Manager).'
$endpoint = "https://$($site.host)/runtime/webhooks/mcp"

$key = $null
try {
    $key = (& az functionapp keys list --resource-group $group --name $app --query 'systemKeys.mcp_extension' --output tsv --only-show-errors 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $key) { Fail 'mcp_extension system key not found. Publish the server code first (expected HTTP 200 from Azure Resource Manager).' }

    $base = @{ Accept = 'application/json, text/event-stream' }
    function Invoke-Mcp([hashtable]$Body, [hashtable]$Headers) {
        $json = $Body | ConvertTo-Json -Depth 10 -Compress
        $response = Invoke-WebRequest -Uri $endpoint -Method Post -Body $json -ContentType 'application/json' -Headers $Headers `
            -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 60
        $payload = $null
        $text = [string]$response.Content
        if ($text) {
            if ("$($response.Headers['Content-Type'])" -match 'text/event-stream') {
                $text = ($text -split "`n" | Where-Object { $_ -like 'data:*' } | ForEach-Object { $_.Substring(5).Trim() } | Select-Object -Last 1)
            }
            try { $payload = $text | ConvertFrom-Json -AsHashtable -Depth 20 } catch { $payload = $null }
        }
        return [pscustomobject]@{ Status = [int]$response.StatusCode; Headers = $response.Headers; Payload = $payload }
    }

    $initialize = @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{
        protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'workshop-validator'; version = '0.2.0' } } }

    Step 'Live - the server refuses callers without the key' 'Proves a missing or wrong key gets HTTP 401, so the endpoint is not anonymous.'
    $anonymous = Invoke-Mcp $initialize $base
    if ($anonymous.Status -ne 401) { Fail "request without key returned HTTP $($anonymous.Status) (expected HTTP 401)." }
    Pass 'MCP request without the mcp_extension key is refused (expected HTTP 401).'

    $wrong = Invoke-Mcp $initialize ($base + @{ 'x-functions-key' = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)) })
    if ($wrong.Status -ne 401) { Fail "request with a wrong key returned HTTP $($wrong.Status) (expected HTTP 401)." }
    Pass 'anonymous access disabled: a random wrong key is refused (expected HTTP 401).'

    Step 'Live - the key alone opens every tool (the risk)' 'Shows that anyone holding the key can list and call tools; no user or role is checked.'
    $keyed = $base + @{ 'x-functions-key' = $key }
    $init = Invoke-Mcp $initialize $keyed
    $version = $init.Payload?.result?.protocolVersion
    if ($init.Status -ne 200 -or -not $version) { Fail "MCP initialize with key returned HTTP $($init.Status) (expected HTTP 200 with a protocol version)." }
    Pass "MCP initialize with the key succeeds; negotiated protocol $version (expected HTTP 200)."

    $session = "$($init.Headers['Mcp-Session-Id'])"
    if ($session) { $keyed['Mcp-Session-Id'] = $session }
    $keyed['MCP-Protocol-Version'] = $version
    $notified = Invoke-Mcp @{ jsonrpc = '2.0'; method = 'notifications/initialized' } $keyed
    if ($notified.Status -notin 200, 202) { Fail "initialized notification returned HTTP $($notified.Status) (expected HTTP 202)." }

    $list = Invoke-Mcp @{ jsonrpc = '2.0'; id = 2; method = 'tools/list'; params = @{} } $keyed
    $names = @($list.Payload?.result?.tools | ForEach-Object { $_.name } | Sort-Object)
    if ($list.Status -ne 200 -or $names.Count -ne 5 -or (Compare-Object $names $expectedTools)) {
        Fail "tools/list with key returned HTTP $($list.Status) and an unexpected tool set (expected HTTP 200 with five tools)."
    }
    Pass 'tools/list with the key returns exactly the five workshop tools (expected HTTP 200).'

    if ($DemonstrateWrite) {
        $call = Invoke-Mcp @{ jsonrpc = '2.0'; id = 3; method = 'tools/call'; params = @{ name = 'create_ticket'; arguments = @{
            service = 'ticket-queue'; severity = 'low'; summary = 'Synthetic level 0 risk demonstration' } } } $keyed
        $result = $call.Payload?.result
        $isError = $result -is [System.Collections.IDictionary] -and $result.Contains('isError') -and $result['isError']
        if ($call.Status -ne 200 -or $result -isnot [System.Collections.IDictionary] -or $isError) { Fail "create_ticket with only the key returned HTTP $($call.Status) (expected HTTP 200)." }
        Pass 'RISK SHOWN: create_ticket succeeds with only the key; no user or role was checked (expected HTTP 200).'
    } else {
        Write-Output 'INFO write demonstration skipped. Rerun with -DemonstrateWrite to queue one synthetic ticket.'
    }
    Write-Output 'PASS module 02 live checks complete. Rotate or remove the key after the exercise (see README).'
}
finally {
    $key = $null
    Remove-Variable -Name key, keyed -ErrorAction SilentlyContinue
}
