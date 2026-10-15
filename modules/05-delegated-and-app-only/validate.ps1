#requires -Version 7.4
<#
.SYNOPSIS
    Module 05 validator: offline repository invariants, then live On-Behalf-Of vs app-only checks after an approved deployment.
.DESCRIPTION
    Offline (default without -TenantId, or with -Offline): no Azure or Entra access. Checks the server code (On-Behalf-Of with a
    managed-identity assertion, separate Graph and Storage tokens, app-only callers refused, no developer-credential fallback,
    no hand-written token validation), the Entra and workload opt-ins (federated credential, exact delegated scopes,
    container-scoped roles, no secret), the synthetic data, then runs the unit tests and Terraform format, schema and mock tests.
    Operator mode (-TenantId -SubscriptionId): the Function settings hold no secret, the MCP API registration has no password
    credential and trusts exactly the OBO identity, and the report container roles are what the module promises.
    Persona mode (-TenantId -Persona Alice|Bob, signed in to Azure CLI as that test account in a separate AZURE_CONFIG_DIR):
    whoami returns the persona label; read_report_as_user returns the report for Alice and HTTP 200 with isError true for Bob
    (downstream Storage HTTP 403); read_report_as_app returns the same synthetic report for both.
    Tokens stay in memory only. They are never printed, logged or written.
#>
[CmdletBinding()]
param(
    [switch]$Offline,
    [guid]$TenantId,
    [guid]$SubscriptionId,
    [ValidateSet('Alice', 'Bob')][string]$Persona,
    [string]$PersonaObjectIdsPath,
    [string]$EvidenceDirectory,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$workload = Join-Path $root 'infra' 'workload'
$entra = Join-Path $root 'infra' 'entra'
$server = Join-Path $root 'src' 'FunctionsMcpServer'
$private = Join-Path $root '.workshop'
$expectedTools = @('create_ticket', 'get_service_health', 'read_report_as_app', 'read_report_as_user', 'whoami')
$synthetic = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'synthetic-data' 'monthly-usage.json') -Raw | ConvertFrom-Json -AsHashtable
if (-not $PersonaObjectIdsPath) { $PersonaObjectIdsPath = Join-Path $private 'module03-personas.json' }
if (-not $EvidenceDirectory) { $EvidenceDirectory = $private }

function Pass([string]$Message) { Write-Output "PASS $Message" }
function Fail([string]$Message) { throw "FAIL $Message" }
function Test-All([string]$Text, [string[]]$Patterns) {
    foreach ($pattern in $Patterns) { if ($Text -notmatch $pattern) { return $false } }
    return $true
}
# Lists can be legitimately empty (for example no password credential), which Invoke-WorkshopAzureJson refuses; read them here.
function Get-AzureList([string[]]$Arguments) {
    $text = & az @Arguments --output json --only-show-errors 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { Fail "Azure CLI '$($Arguments[0]) $($Arguments[1])' read failed; check the context and your read permissions privately (expected HTTP 200)." }
    try { $value = ConvertFrom-Json -InputObject $text -AsHashtable -Depth 100 -NoEnumerate -ErrorAction Stop } catch { Fail 'Azure CLI returned invalid JSON (expected HTTP 200).' }
    if ($value -isnot [System.Collections.IList]) { Fail "Azure CLI '$($Arguments[0]) $($Arguments[1])' did not return a list (expected HTTP 200)." }
    return @($value)
}
# Strict-mode-safe read of nested JSON objects (hashtables); missing keys return $null.
function Get-Value($Object, [string]$Path) {
    foreach ($name in $Path.Split('.')) {
        if ($Object -isnot [System.Collections.IDictionary] -or -not $Object.Contains($name)) { return $null }
        $Object = $Object[$name]
    }
    return $Object
}
function Get-Rows($Report) { return (@(Get-Value $Report 'rows') | ForEach-Object { "$(Get-Value $_ 'service')|$(Get-Value $_ 'requests')|$(Get-Value $_ 'errors')" }) -join ';' }

# ---------------------------------------------------------------- offline checks (always run)

$code = (Get-ChildItem -LiteralPath $server -Recurse -File -Filter *.cs | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
$credentials = Get-Content -LiteralPath (Join-Path $server 'Identity' 'DownstreamCredentials.cs') -Raw
$caller = Get-Content -LiteralPath (Join-Path $server 'Logic' 'CallerContext.cs') -Raw
$clients = Get-Content -LiteralPath (Join-Path $server 'Logic' 'DownstreamClients.cs') -Raw
if (-not (Test-All $credentials @('new OnBehalfOfCredential\(', 'ManagedIdentityId\.FromUserAssignedClientId', 'api://AzureADTokenExchange/\.default')) -or
    -not (Test-All $clients @('https://graph\.microsoft\.com/User\.Read', 'https://storage\.azure\.com/user_impersonation', 'https://storage\.azure\.com/\.default',
        'v1\.0/me\?\$select=id', 'exception\.Status == 403')) -or
    -not (Test-All $caller @('App-only callers cannot use a user-context tool', 'RequiredScope = "user_impersonation"', 'X-MS-CLIENT-PRINCIPAL')) -or
    $code -match 'AzureCliCredential|DefaultAzureCredential|VisualStudioCodeCredential|VisualStudioCredential|AzureDeveloperCliCredential|ChainedTokenCredential|InteractiveBrowserCredential|ClientSecretCredential' -or
    $code -match 'JwtSecurityTokenHandler|JsonWebTokenHandler|System\.IdentityModel|ValidateToken\(|\.Split\(''\.''\)' -or
    $code -match 'DisplayName|userPrincipalName|\bmail\b') {
    Fail 'server code must use On-Behalf-Of with a managed-identity assertion, separate Graph and Storage tokens, refuse app-only callers, never fall back to a developer identity and never parse tokens itself (expected HTTP N/A).'
}
Pass 'server: On-Behalf-Of with a managed-identity assertion, one token per downstream (Graph User.Read, Storage user_impersonation), app-only identity for read_report_as_app, app-only callers refused, no developer-credential fallback, no token parsing (expected HTTP N/A).'

$delegationTf = Get-Content -LiteralPath (Join-Path $entra 'delegation.tf') -Raw
$entraTf = (Get-ChildItem -LiteralPath $entra -Filter *.tf -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
if (-not (Test-All $delegationTf @('resource "azuread_application_federated_identity_credential" "obo"', 'audiences\s*=\s*\[local\.federated_token_audience\]',
        'issuer\s*=\s*local\.federated_issuer', 'subject\s*=\s*var\.obo_identity_principal_id', 'scope = "User\.Read"', 'scope = "user_impersonation"',
        'e406a681-f3d4-42a8-90b6-c2b029497af1', '00000003-0000-0000-c000-000000000000', 'var\.grant_downstream_admin_consent')) -or
    $entraTf -notmatch 'federated_token_audience\s*=\s*"api://AzureADTokenExchange"' -or $entraTf -notmatch 'federated_issuer\s*=\s*"https://login\.microsoftonline\.com/\$\{var\.tenant_id\}/v2\.0"' -or
    $entraTf -match 'azuread_application_password|azuread_application_certificate|azuread_service_principal_password|\brole_ids\s*=') {
    Fail 'infra/entra must trust one managed identity through a federated credential and request only Graph User.Read and Storage user_impersonation, with opt-in consent and no password or certificate (expected HTTP N/A).'
}
Pass 'infra/entra: federated credential (tenant v2.0 issuer, managed identity principal ID subject, api://AzureADTokenExchange), delegated Graph User.Read + Storage user_impersonation only, admin consent opt-in, no password or certificate (expected HTTP N/A).'

$delegatedTf = Get-Content -LiteralPath (Join-Path $workload 'delegated-access.tf') -Raw
$serverTf = Get-Content -LiteralPath (Join-Path $workload 'mcp-server.tf') -Raw
$roleScopes = @([regex]::Matches($delegatedTf, '(?m)^\s*scope\s*=\s*(\S+)') | ForEach-Object { $_.Groups[1].Value })
if (-not (Test-All $delegatedTf @('resource "azurerm_user_assigned_identity" "delegated_obo"', 'resource "azurerm_user_assigned_identity" "delegated_report"',
        'container_access_type = "private"', 'principal_id\s*=\s*azurerm_user_assigned_identity\.delegated_report\[0\]\.principal_id',
        'delegated_enabled\s*=\s*local\.mcp_auth_enabled && var\.enable_delegated_access')) -or
    $roleScopes.Count -ne 3 -or @($roleScopes | Where-Object { $_ -ne 'azurerm_storage_container.reports[0].id' }).Count -gt 0 -or
    $delegatedTf -match '(?m)^\s*principal_id\s*=\s*azurerm_user_assigned_identity\.(delegated_obo|mcp)\[0\]\.principal_id' -or
    $delegatedTf -match 'role_definition_name\s*=\s*"(Owner|Contributor|Storage Blob Data Owner)"' -or
    $serverTf -notmatch 'identity_ids = concat\(\[azurerm_user_assigned_identity\.mcp\[0\]\.id\], local\.delegated_identity_ids\)' -or
    $serverTf -notmatch 'local\.mcp_auth_app_settings, local\.delegated_app_settings') {
    Fail 'infra/workload must add two separate identities and scope every module 05 role to the one report container; the OBO identity gets no role (expected HTTP N/A).'
}
Pass 'infra/workload: separate OBO assertion and app-only identities, every module 05 role on the one report container, no role for the OBO or host identity, Bob none, opt-in only (expected HTTP N/A).'

$guides = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter 'README*.md')
$syntheticFiles = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'synthetic-data') -File)
if ($synthetic.report -ne 'monthly-usage' -or $synthetic.source -ne 'synthetic' -or @($synthetic.rows).Count -lt 1 -or
    @($syntheticFiles | Select-String -Pattern '@|eyJ[A-Za-z0-9_-]{8,}' ).Count -gt 0) {
    Fail 'synthetic data must be the labelled synthetic report with no address or token (expected HTTP N/A).'
}
Pass "synthetic report and expected results are labelled synthetic and contain no address, ID or token ($($syntheticFiles.Count) files, expected HTTP N/A)."

$scanned = @(Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File -Include *.md, *.ps1, *.sh, *.json) +
    @(Get-ChildItem -LiteralPath $workload, $entra -Filter *.tf -File) +
    @(Get-ChildItem -LiteralPath $server -Recurse -File -Include *.cs, *.json, *.csproj | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' })
$secretPatterns = @(
    'eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.', 'AccountKey=', 'SharedAccessSignature=', '[?&]sig=[A-Za-z0-9%]',
    'client_secret', 'ClientSecret', 'clientSecretSettingName', 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET', 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID\s*[:=]',
    'x-functions-key"\s*:\s*"[A-Za-z0-9]', 'Bearer\s+[A-Za-z0-9_\-]{20,}\.'
)
foreach ($pattern in $secretPatterns) {
    $hit = @($scanned | Where-Object { $_.FullName -ne $PSCommandPath } | Select-String -Pattern $pattern -CaseSensitive)
    if ($hit.Count -gt 0) { Fail "possible token, key or client secret in module 05 files: $(Split-Path $hit[0].Path -Leaf) (expected HTTP N/A)." }
}
Pass "no client secret, key, SAS or token in module 05, server, infra/entra or infra/workload files ($($scanned.Count) files, expected HTTP N/A)."

if (-not $SkipBuild) {
    $tests = & dotnet test (Join-Path $root 'tests' 'FunctionsMcpServer.Tests') --nologo 2>&1
    if ($LASTEXITCODE -ne 0) { $tests | Select-Object -Last 15 | ForEach-Object { Write-Warning $_ }; Fail 'locked build and unit tests (expected HTTP N/A).' }
    Pass 'locked build and unit tests: Alice reads, Bob denied downstream, app-only identical for everyone, app-only callers refused, Graph gets only its own token (expected HTTP N/A).'
    foreach ($terraformRoot in @($entra, $workload)) {
        if (-not (Test-Path -LiteralPath (Join-Path $terraformRoot '.terraform'))) {
            & terraform "-chdir=$terraformRoot" init -lockfile=readonly -input=false -no-color | Out-Null
            if ($LASTEXITCODE -ne 0) { Fail "Terraform init for $(Split-Path $terraformRoot -Leaf) (expected HTTP N/A). Use Terraform 1.16.6+ and registry access." }
        }
        foreach ($arguments in @(@('fmt', '-check', '-recursive'), @('validate', '-no-color'), @('test', '-no-color'))) {
            $output = & terraform "-chdir=$terraformRoot" @arguments 2>&1
            if ($LASTEXITCODE -ne 0) {
                $output | Select-Object -Last 15 | ForEach-Object { Write-Warning $_ }
                Fail "Terraform $($arguments[0]) for $(Split-Path $terraformRoot -Leaf) (expected HTTP N/A)."
            }
        }
    }
    Pass 'Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).'
}

if ($Offline -or -not $TenantId -or $TenantId -eq [guid]::Empty) {
    Write-Output 'NOT DEPLOYED CHECKS SKIPPED: supply -TenantId with -SubscriptionId (operator) or -Persona (test account) after an approved deployment.'
    Write-Output 'PASS offline checks only. Module 05 is NOT deployed or validated by this result.'
    return
}

# ---------------------------------------------------------------- live checks (approved deployment only)

. (Join-Path $root 'scripts' 'context-common.ps1')
Assert-WorkshopInteractiveEnvironment
$outputs = & terraform "-chdir=$workload" output -json | ConvertFrom-Json -AsHashtable
if ($LASTEXITCODE -ne 0 -or $null -eq $outputs) { Fail 'Terraform outputs unavailable; use the same private workload state as the deployment (expected HTTP N/A).' }
$audience = $outputs.mcp_auth_audience?.value
$issuer = $outputs.mcp_auth_issuer?.value
$endpoint = if ($outputs.gateway_enabled?.value) { $outputs.gateway_mcp_endpoint?.value } else { $outputs.mcp_endpoint?.value }
if (-not $outputs.delegated_access_enabled?.value -or -not $audience -or -not $issuer -or -not $endpoint) {
    Fail 'module 05 is not deployed in this state (enable_delegated_access is false). Apply it first, or use -Offline.'
}
if ($issuer -ne "https://login.microsoftonline.com/$TenantId/v2.0") { Fail 'the deployed issuer is not the explicit tenant (expected HTTP N/A).' }
$clientId = $audience -replace '^api://', ''
$oboPrincipal = $outputs.delegated_obo_identity_principal_id?.value
$personas = if (Test-Path -LiteralPath $PersonaObjectIdsPath) { Get-Content -LiteralPath $PersonaObjectIdsPath -Raw | ConvertFrom-Json -AsHashtable } else { $null }

$token = $null; $authorized = $null
try {
    if ($SubscriptionId -and $SubscriptionId -ne [guid]::Empty) {
        Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
        Pass 'explicit Azure context matches the approved test target (expected HTTP 200 from Azure Resource Manager).'
        $group = $outputs.resource_group_name?.value
        $app = $outputs.mcp_function_app_name?.value
        $names = @(Get-AzureList @('functionapp', 'config', 'appsettings', 'list', '--resource-group', $group, '--name', $app, '--query', '[].name'))
        foreach ($required in 'WORKSHOP_DELEGATED_ACCESS', 'WORKSHOP_OBO_ASSERTION_CLIENT_ID', 'WORKSHOP_REPORT_IDENTITY_CLIENT_ID', 'WORKSHOP_REPORT_CONTAINER_URL') {
            if ($names -notcontains $required) { Fail "the Function App lacks $required; module 05 settings are not deployed (expected HTTP 200 from Azure Resource Manager)." }
        }
        if (@($names | Where-Object { $_ -match '(?i)secret|password|OVERRIDE_USE_MI_FIC' }).Count -gt 0) {
            Fail 'the Function App has a secret-like setting; module 05 must stay secretless (expected HTTP 200 from Azure Resource Manager).'
        }
        Pass 'Function App settings name both module 05 identities and hold no secret setting (expected HTTP 200 from Azure Resource Manager).'

        $passwords = @(Get-AzureList @('ad', 'app', 'credential', 'list', '--id', $clientId))
        $federated = @(Get-AzureList @('ad', 'app', 'federated-credential', 'list', '--id', $clientId))
        $trust = @($federated | Where-Object { $_.subject -eq $oboPrincipal -and $_.issuer -eq $issuer -and @($_.audiences) -contains 'api://AzureADTokenExchange' })
        if ($passwords.Count -ne 0) { Fail 'the MCP API registration has a password credential (client secret); remove it (expected HTTP 200 from Microsoft Graph with an empty list).' }
        if ($trust.Count -ne 1 -or $federated.Count -ne 1) {
            Fail 'the MCP API registration must have exactly one federated credential trusting the OBO identity (expected HTTP 200 from Microsoft Graph).'
        }
        Pass 'MCP API registration: no client secret, exactly one federated credential trusting the OBO managed identity (expected HTTP 200 from Microsoft Graph).'

        $account = $outputs.delegated_storage_account_name?.value
        $container = "/subscriptions/$SubscriptionId/resourceGroups/$group/providers/Microsoft.Storage/storageAccounts/$account/blobServices/default/containers/reports"
        $roles = @(Get-AzureList @('role', 'assignment', 'list', '--scope', $container, '--query', '[].{role:roleDefinitionName,principal:principalId,scope:scope}'))
        $direct = @($roles | Where-Object { $_.scope -eq $container })
        $readers = @($direct | Where-Object { $_.role -eq 'Storage Blob Data Reader' })
        if (@($direct | Where-Object { $_.role -notin @('Storage Blob Data Reader', 'Storage Blob Data Contributor') }).Count -gt 0 -or $readers.Count -lt 1 -or $readers.Count -gt 2 -or
            @($direct | Where-Object { $_.principal -eq $oboPrincipal }).Count -gt 0 -or ($personas -and $personas.bob -and @($direct | Where-Object { $_.principal -eq $personas.bob }).Count -gt 0) -or
            ($personas -and $personas.alice -and @($readers | Where-Object { $_.principal -eq $personas.alice }).Count -ne 1)) {
            Fail 'report container roles must be Reader for the app-only identity and Alice only (plus the publisher); none for the OBO identity or Bob (expected HTTP 200 from Azure Resource Manager).'
        }
        Pass "report container: $($readers.Count) Storage Blob Data Reader assignment(s) (app-only identity, Alice), none for the OBO identity or Bob (expected HTTP 200 from Azure Resource Manager)."
    }

    if (-not $Persona) {
        Write-Output 'INFO persona checks skipped. Sign in as each test account in a separate AZURE_CONFIG_DIR and rerun with -Persona Alice, then -Persona Bob.'
        Write-Output 'PASS module 05 operator checks complete. Persona checks are still required for validation.'
        return
    }

    $account = Invoke-WorkshopAzureJson -Arguments @('account', 'show', '--query', '{tenantId:tenantId,userType:user.type}')
    if ($account.tenantId -ne $TenantId.ToString() -or $account.userType -ne 'user') {
        Fail 'Azure CLI must be signed in interactively as the test account in the explicit tenant (expected HTTP N/A).'
    }
    if ($personas) {
        $expected = $personas[$Persona.ToLowerInvariant()]
        $actual = (& az ad signed-in-user show --query id --output tsv --only-show-errors 2>$null | Out-String).Trim()
        if (-not $expected -or $actual -ne $expected) { Fail "the signed-in account is not the recorded $Persona test account (expected HTTP 200 from Microsoft Graph)." }
        Pass "signed-in account matches the private $Persona object ID (expected HTTP 200 from Microsoft Graph)."
    } else {
        Write-Output "INFO no private persona file; the signed-in account was not cross-checked against $Persona."
    }

    $text = (& az account get-access-token --tenant $TenantId --resource $audience --query accessToken --output tsv --only-show-errors 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $text -notmatch '^[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*$') {
        $text = $null
        Fail "$Persona could not obtain a token for the MCP API (expected HTTP 200 from the token endpoint)."
    }
    $authorized = @{ Accept = 'application/json, text/event-stream'; Authorization = "Bearer $text" }
    $text = $null

    function Invoke-Mcp([hashtable]$Body) {
        $response = Invoke-WebRequest -Uri $endpoint -Method Post -Body ($Body | ConvertTo-Json -Depth 10 -Compress) -ContentType 'application/json' `
            -Headers $authorized -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 90
        $payload = $null
        $content = [string]$response.Content
        if ($content) {
            if ("$($response.Headers['Content-Type'])" -match 'text/event-stream') {
                $content = ($content -split "`n" | Where-Object { $_ -like 'data:*' } | ForEach-Object { $_.Substring(5).Trim() } | Select-Object -Last 1)
            }
            try { $payload = $content | ConvertFrom-Json -AsHashtable -Depth 20 } catch { $payload = $null }
        }
        return [pscustomobject]@{ Status = [int]$response.StatusCode; Headers = $response.Headers; Payload = $payload }
    }
    function Get-ToolJson($Response) {
        $first = @(Get-Value $Response.Payload 'result.content')[0]
        try { return ([string](Get-Value $first 'text') | ConvertFrom-Json -AsHashtable -Depth 20) } catch { return $null }
    }

    $init = Invoke-Mcp @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{
            protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'workshop-validator'; version = '0.5.0' } } }
    $version = Get-Value $init.Payload 'result.protocolVersion'
    if ($init.Status -ne 200 -or -not $version) { Fail "$Persona initialize returned HTTP $($init.Status) (expected HTTP 200 with a protocol version)." }
    $session = "$($init.Headers['Mcp-Session-Id'])"
    if ($session) { $authorized['Mcp-Session-Id'] = $session }
    $authorized['MCP-Protocol-Version'] = $version
    $null = Invoke-Mcp @{ jsonrpc = '2.0'; method = 'notifications/initialized' }
    $list = Invoke-Mcp @{ jsonrpc = '2.0'; id = 2; method = 'tools/list'; params = @{} }
    $toolNames = @(Get-Value $list.Payload 'result.tools' | ForEach-Object { Get-Value $_ 'name' } | Sort-Object)
    if ($list.Status -ne 200 -or (Compare-Object $toolNames $expectedTools)) { Fail "$Persona tools/list returned HTTP $($list.Status) and an unexpected tool set (expected HTTP 200 with five tools)." }
    Pass "$Persona initialize and tools/list succeed; negotiated protocol $version (expected HTTP 200)."

    $who = Invoke-Mcp @{ jsonrpc = '2.0'; id = 3; method = 'tools/call'; params = @{ name = 'whoami'; arguments = @{} } }
    $whoJson = Get-ToolJson $who
    if ($who.Status -ne 200 -or (Get-Value $who.Payload 'result.isError') -or $null -eq $whoJson -or (Get-Value $whoJson 'persona') -ne $Persona.ToLowerInvariant() -or
        -not (Get-Value $whoJson 'graphMatchesCaller') -or ([string]($who.Payload | ConvertTo-Json -Depth 20 -Compress)) -match '@') {
        Fail "$Persona whoami returned HTTP $($who.Status) without the allowlisted persona label (expected HTTP 200, persona $($Persona.ToLowerInvariant()), no name or email)."
    }
    Pass "$Persona whoami: On-Behalf-Of to Microsoft Graph returns the synthetic persona '$(Get-Value $whoJson 'persona')' and no name or email (expected HTTP 200)."

    $asUser = Invoke-Mcp @{ jsonrpc = '2.0'; id = 4; method = 'tools/call'; params = @{ name = 'read_report_as_user'; arguments = @{ report = 'monthly-usage' } } }
    if ($Persona -eq 'Alice') {
        $userJson = Get-ToolJson $asUser
        if ($asUser.Status -ne 200 -or (Get-Value $asUser.Payload 'result.isError') -or $null -eq $userJson -or (Get-Value $userJson 'mode') -ne 'as-user' -or (Get-Rows $userJson) -ne (Get-Rows $synthetic)) {
            Fail "Alice read_report_as_user returned HTTP $($asUser.Status) without the synthetic report (expected HTTP 200, isError false, her own Storage role)."
        }
        Pass 'Alice read_report_as_user returns the synthetic report with her own Storage role (expected HTTP 200, isError false).'
    } else {
        if ($asUser.Status -ne 200 -or (Get-Value $asUser.Payload 'result.isError') -ne $true) {
            Fail "Bob read_report_as_user returned HTTP $($asUser.Status), isError $(Get-Value $asUser.Payload 'result.isError') (expected HTTP 200 with result.isError true: Storage refuses Bob with HTTP 403)."
        }
        Pass 'Bob read_report_as_user: the MCP call succeeds but the tool result is an error, because Storage refuses Bob downstream (expected HTTP 200, isError true, downstream HTTP 403).'
    }

    $asApp = Invoke-Mcp @{ jsonrpc = '2.0'; id = 5; method = 'tools/call'; params = @{ name = 'read_report_as_app'; arguments = @{ report = 'monthly-usage' } } }
    $appJson = Get-ToolJson $asApp
    if ($asApp.Status -ne 200 -or (Get-Value $asApp.Payload 'result.isError') -or $null -eq $appJson -or (Get-Value $appJson 'mode') -ne 'as-app' -or $null -ne (Get-Value $appJson 'persona') -or
        (Get-Rows $appJson) -ne (Get-Rows $synthetic)) {
        Fail "$Persona read_report_as_app returned HTTP $($asApp.Status) without the shared synthetic report (expected HTTP 200, isError false, same result for everyone)."
    }
    $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes((Get-Rows $appJson))))
    if (-not (Test-Path -LiteralPath $EvidenceDirectory)) { $null = New-Item -ItemType Directory -Path $EvidenceDirectory }
    Set-Content -LiteralPath (Join-Path $EvidenceDirectory "module05-as-app-$($Persona.ToLowerInvariant()).sha256") -Value $digest -Encoding ascii
    $other = Join-Path $EvidenceDirectory "module05-as-app-$(if ($Persona -eq 'Alice') { 'bob' } else { 'alice' }).sha256"
    if (Test-Path -LiteralPath $other) {
        if ((Get-Content -LiteralPath $other -Raw).Trim() -ne $digest) { Fail 'read_report_as_app returned different results for Alice and Bob (expected the same result for everyone).' }
        Pass 'read_report_as_app returned the same result for Alice and Bob: the managed identity, not the caller, carries the rights (expected HTTP 200).'
    } else {
        Pass "$Persona read_report_as_app returns the shared synthetic report through the app-only identity (expected HTTP 200, isError false). Run the other persona to compare."
    }
    Write-Output "PASS module 05 persona checks complete for $Persona."
}
finally {
    $token = $null; $authorized = $null
}
