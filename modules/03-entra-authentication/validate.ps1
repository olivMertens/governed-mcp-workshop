#requires -Version 7.4
<#
.SYNOPSIS
    Module 03 validator: offline repository invariants, then live Microsoft Entra checks after an approved deployment.
.DESCRIPTION
    Offline (default without -TenantId, or with -Offline): no Azure or Entra access.
    Operator mode (-TenantId -SubscriptionId): reads the deployed configuration from Azure Resource Manager and runs
    HTTP checks that need no assigned user: 401 without a token, 401 with the level 0 key alone, Protected Resource
    Metadata (Preview), 401 with a token for another audience (Microsoft Graph).
    Persona mode (-TenantId -Persona Alice|Bob|Eve): run while signed in to Azure CLI as that test account
    (use a separate AZURE_CONFIG_DIR). Alice and Bob must get HTTP 200; Eve must not obtain a token.
    Tokens and keys stay in memory only. They are never printed, logged or written.
#>
[CmdletBinding()]
param(
    [switch]$Offline,
    [guid]$TenantId,
    [guid]$SubscriptionId,
    [ValidateSet('Alice', 'Bob', 'Eve')][string]$Persona,
    [string]$PersonaObjectIdsPath,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$server = Join-Path $root 'src' 'FunctionsMcpServer'
$workload = Join-Path $root 'infra' 'workload'
$entra = Join-Path $root 'infra' 'entra'
$expectedTools = @('create_ticket', 'get_service_health', 'read_report_as_app', 'read_report_as_user', 'whoami')
$webhookSetting = 'AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel'
$knownClients = @('aebc6443-996d-45c2-90f0-388ff96faa56', '04b07795-8ddb-461a-bbee-02f9e1bf7b46')
if (-not $PersonaObjectIdsPath) { $PersonaObjectIdsPath = Join-Path $root '.workshop' 'module03-personas.json' }

function Pass([string]$Message) { Write-Output "PASS $Message" }
function Fail([string]$Message) { throw "FAIL $Message" }
$script:StepNumber = 0
function Step([string]$Title, [string]$Why) {
    $script:StepNumber++
    Write-Output ''; Write-Output "== Step $($script:StepNumber): $Title =="; Write-Output "   Why: $Why"
}
# Strict-mode-safe lookup of a dotted path in nested dictionaries; missing keys return $null.
function Get-Value($Object, [string]$Path) {
    foreach ($name in $Path.Split('.')) {
        if ($Object -isnot [System.Collections.IDictionary] -or -not $Object.Contains($name)) { return $null }
        $Object = $Object[$name]
    }
    return $Object
}
Write-Output 'Module 03 validator - only Microsoft Entra tokens issued for the MCP audience open the server.'

# ---------------------------------------------------------------- offline checks (always run)

Step 'Offline - your copy keeps every gate closed (no Azure call)' 'Proves the code, Terraform and examples tie access to Entra and hold no secret or token.'
$hostJson = Get-Content -LiteralPath (Join-Path $server 'host.json') -Raw | ConvertFrom-Json -AsHashtable
if ($hostJson.extensions?.mcp?.system?.webhookAuthorizationLevel -cne 'System') {
    Fail 'host.json must keep webhookAuthorizationLevel System; module 03 overrides it only through an app setting under built-in authentication (expected HTTP N/A).'
}
Pass 'host.json keeps the level 0 System webhook level; the published package is never anonymous on its own (expected HTTP N/A).'

$workloadTf = @(Get-ChildItem -LiteralPath $workload -Filter *.tf -File)
$overrideFiles = @($workloadTf | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match [regex]::Escape($webhookSetting) })
$authText = Get-Content -LiteralPath (Join-Path $workload 'entra-auth.tf') -Raw
$serverText = Get-Content -LiteralPath (Join-Path $workload 'mcp-server.tf') -Raw
if ($overrideFiles.Count -ne 1 -or $overrideFiles[0].Name -ne 'entra-auth.tf' -or
    $authText -notmatch 'mcp_key_gate_replaced\s*=\s*local\.mcp_auth_enabled\s*&&\s*var\.entra_auth_replace_key_gate' -or
    $authText -notmatch 'local\.mcp_key_gate_replaced\s*\?\s*\{\s*\(local\.mcp_webhook_level_setting\)\s*=\s*"Anonymous"' -or
    $serverText -notmatch 'for_each\s*=\s*local\.mcp_auth_enabled\s*\?\s*\[1\]\s*:\s*\[\]' -or
    $serverText -notmatch 'require_authentication\s*=\s*true' -or $serverText -notmatch 'unauthenticated_action\s*=\s*"Return401"' -or
    $serverText -notmatch '\},\s*local\.mcp_auth_app_settings(,\s*local\.delegated_app_settings)?\)') {
    Fail 'the anonymous webhook override must be tied to enforced built-in authentication with HTTP 401 (expected HTTP 401 without a token).'
}
Pass 'the key gate is removed only together with enforced built-in authentication and Return401 (expected HTTP 401 without a token).'

$entraTf = @(Get-ChildItem -LiteralPath $entra -Filter *.tf -File)
$entraText = ($entraTf | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
if ($entraText -match 'azuread_application_password|azuread_service_principal_password|azuread_application_certificate|azuread_service_principal_certificate|"azuread_user"|\bpassword\s*\{|client_secret') {
    Fail 'infra/entra must create no password, certificate, client secret or user (expected HTTP N/A).'
}
if ($entraText -notmatch 'app_role_assignment_required\s*=\s*true' -or $entraText -notmatch 'sign_in_audience\s*=\s*"AzureADMyOrg"' -or
    $entraText -notmatch 'value\s*=\s*"user_impersonation"' -or $entraText -notmatch '"Tools\.Execute\.All"\s*=\s*\{[^=]*=[^\n]*\n\s*member_types\s*=\s*\["Application"\]') {
    Fail 'infra/entra must keep single tenant, user_impersonation, the three app roles and assignment required (expected HTTP N/A).'
}
$preAuthorized = @([regex]::Matches($entraText, '"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",\s*#') | ForEach-Object { $_.Groups[1].Value })
if ($preAuthorized.Count -ne 2 -or (Compare-Object $preAuthorized $knownClients)) {
    Fail 'default pre-authorized clients must be exactly Visual Studio Code and Azure CLI (expected HTTP N/A).'
}
Pass 'infra/entra: single tenant, user_impersonation, Tools.Read/Tools.Write/Tools.Execute.All, assignment required, no secret or user (expected HTTP N/A).'

$scanned = @($workloadTf) + @($entraTf) + @(Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File -Include *.md, *.json, *.ps1, *.sh)
$secretPatterns = @(
    'eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.', 'AccountKey=', 'SharedAccessSignature=', '[?&]sig=[A-Za-z0-9%]',
    'client_secret', 'ClientSecret', 'x-functions-key"\s*:\s*"[A-Za-z0-9]', '[?&]code=[A-Za-z0-9_\-]{20,}',
    'Bearer\s+[A-Za-z0-9_\-]{20,}\.'
)
foreach ($pattern in $secretPatterns) {
    $hit = @($scanned | Where-Object { $_.FullName -ne $PSCommandPath } | Select-String -Pattern $pattern -CaseSensitive)
    if ($hit.Count -gt 0) { Fail "possible token or secret pattern in module 03 files: $(Split-Path $hit[0].Path -Leaf) (expected HTTP N/A)." }
}
Pass 'no access token, key, SAS or client secret in module 03, infra/entra or workload files (expected HTTP N/A).'

$claims = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'synthetic-claims') -Filter *.json -File)
if ($claims.Count -lt 3) { Fail 'synthetic-claims must contain the Alice, Bob and Eve examples (expected HTTP N/A).' }
foreach ($file in $claims) {
    $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
    if ($doc['synthetic'] -ne $true -or $doc.ContainsKey('signature') -or $doc.ContainsKey('access_token')) {
        Fail "$($file.Name) must be marked synthetic and contain no token or signature (expected HTTP N/A)."
    }
    $payload = $doc['decoded_payload']
    if ($payload) {
        if ($payload.tid -ne '00000000-0000-4000-8000-000000000000' -or $payload.aud -notmatch '^(api://)?44444444-4444-4444-8444-444444444444$' -or
            $payload.oid -notmatch '^[0-9a-f]{8}-0000-4000-8000-0000000000\d\d$') {
            Fail "$($file.Name) must use only the documented synthetic tenant, audience and object IDs (expected HTTP N/A)."
        }
    }
}
Pass "synthetic claim examples use synthetic IDs only and contain no token ($($claims.Count) files, expected HTTP N/A)."

if (-not $SkipBuild) {
    Step 'Offline - Terraform format, schema and mock plans' 'Proves both Terraform roots are valid without creating anything in Azure or Entra.'
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
    Write-Output 'PASS offline checks only. Module 03 is NOT deployed or Entra-validated by this result.'
    return
}

# ---------------------------------------------------------------- live checks (approved deployment only)

. (Join-Path $root 'scripts' 'context-common.ps1')
Assert-WorkshopInteractiveEnvironment
$outputs = & terraform "-chdir=$workload" output -json | ConvertFrom-Json -AsHashtable
if ($LASTEXITCODE -ne 0 -or $null -eq $outputs) { Fail 'Terraform outputs unavailable; use the same private workload state as the deployment (expected HTTP N/A).' }
$endpoint = $outputs.mcp_endpoint?.value
$audience = $outputs.mcp_auth_audience?.value
$scope = $outputs.mcp_auth_scope?.value
$issuer = $outputs.mcp_auth_issuer?.value
if (-not $outputs.mcp_auth_enabled?.value -or -not $endpoint -or -not $audience -or -not $scope -or -not $issuer) {
    Fail 'module 03 is not deployed in this state (enable_entra_auth is false). Apply it first, or use -Offline.'
}
if (-not $outputs.mcp_key_gate_replaced?.value) {
    Fail 'stage 1 only: Entra is enforced in front of the key. Apply stage 2 (entra_auth_replace_key_gate = true) before validating (expected HTTP N/A).'
}
if ($issuer -ne "https://login.microsoftonline.com/$TenantId/v2.0") { Fail 'the deployed issuer is not the explicit tenant (expected HTTP N/A).' }
$siteBase = ([uri]$endpoint).GetLeftPart([UriPartial]::Authority)

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
function Get-Token([string]$Resource) {
    $text = (& az account get-access-token --tenant $TenantId --resource $Resource --query accessToken --output tsv --only-show-errors 2>&1 | Out-String).Trim()
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0 -and $text -match '^[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*$'); Value = $text }
}
$initialize = @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{
    protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'workshop-validator'; version = '0.3.0' } } }

# Checks that need no assigned user (both modes).
Step 'Live - the server refuses callers without the right token' 'Proves no token, or a token for another audience, gets HTTP 401 while metadata guides clients.'
$anonymous = Invoke-Mcp $initialize $base
$challenge = "$($anonymous.Headers['WWW-Authenticate'])"
if ($anonymous.Status -ne 401) { Fail "request without a token returned HTTP $($anonymous.Status) (expected HTTP 401)." }
Pass 'MCP request without a token is refused by built-in authentication (expected HTTP 401).'

$metadataUrl = if ($challenge -match 'resource_metadata="([^"]+)"') { $Matches[1] } else { "$siteBase/.well-known/oauth-protected-resource" }
if (([uri]$metadataUrl).GetLeftPart([UriPartial]::Authority) -ne $siteBase) { Fail 'the metadata URL must be on the MCP server host (expected HTTP 200).' }
$prm = Invoke-WebRequest -Uri $metadataUrl -Method Get -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 30
$metadata = $null; try { $metadata = [string]$prm.Content | ConvertFrom-Json -AsHashtable } catch { $metadata = $null }
if ([int]$prm.StatusCode -ne 200 -or $null -eq $metadata -or -not (Get-Value $metadata 'resource') -or
    @(Get-Value $metadata 'authorization_servers') -notcontains $issuer -or @(Get-Value $metadata 'scopes_supported') -notcontains $scope) {
    Fail "Protected Resource Metadata returned HTTP $($prm.StatusCode) without the tenant issuer and the user_impersonation scope (expected HTTP 200; Preview)."
}
Pass 'Protected Resource Metadata (Preview) names the tenant authorization server and the user_impersonation scope (expected HTTP 200).'

$other = $null; $token = $null; $key = $null; $authorized = $null
try {
    $other = Get-Token 'https://graph.microsoft.com'
    if (-not $other.Ok) { Fail 'could not obtain a Microsoft Graph token for the wrong-audience check (expected HTTP 200 from the token endpoint).' }
    $wrong = Invoke-Mcp $initialize ($base + @{ Authorization = "Bearer $($other.Value)" })
    $other = $null
    if ($wrong.Status -ne 401) { Fail "a token for another audience (Microsoft Graph) returned HTTP $($wrong.Status) (expected HTTP 401)." }
    Pass 'a valid token for another audience (Microsoft Graph) is refused (expected HTTP 401).'

    if ($SubscriptionId -and $SubscriptionId -ne [guid]::Empty) {
        Step 'Azure configuration matches Terraform' 'Proves built-in authentication and app settings are deployed as the code describes, and the key alone fails.'
        Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
        Pass 'explicit Azure context matches the approved test target (expected HTTP 200 from Azure Resource Manager).'
        $group = $outputs.resource_group_name?.value
        $app = $outputs.mcp_function_app_name?.value
        $auth = Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--uri',
            "/subscriptions/$SubscriptionId/resourceGroups/$group/providers/Microsoft.Web/sites/$app/config/authsettingsV2?api-version=2024-04-01")
        $expectedAudiences = @($audience, ($audience -replace '^api://', '')) | Select-Object -Unique
        if (-not (Get-Value $auth 'properties.platform.enabled') -or -not (Get-Value $auth 'properties.globalValidation.requireAuthentication') -or
            (Get-Value $auth 'properties.globalValidation.unauthenticatedClientAction') -ne 'Return401' -or
            (Get-Value $auth 'properties.identityProviders.azureActiveDirectory.registration.openIdIssuer') -ne $issuer -or
            (Get-Value $auth 'properties.identityProviders.azureActiveDirectory.registration.clientSecretSettingName') -or
            (Compare-Object @(Get-Value $auth 'properties.identityProviders.azureActiveDirectory.validation.allowedAudiences') $expectedAudiences)) {
            Fail 'deployed built-in authentication must require authentication, return 401, trust only the tenant issuer and the MCP audience, without a secret setting (expected HTTP 200 from Azure Resource Manager).'
        }
        Pass 'deployed authsettingsV2: required, Return401, tenant issuer, MCP audience only, no secret setting (expected HTTP 200 from Azure Resource Manager).'
        $settings = Invoke-WorkshopAzureJson -Arguments @('functionapp', 'config', 'appsettings', 'list', '--resource-group', $group, '--name', $app,
            '--query', "[?name=='$webhookSetting' || name=='WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES'].{name:name,value:value}")
        $map = @{}; foreach ($entry in @($settings)) { $map[$entry.name] = $entry.value }
        if ($map[$webhookSetting] -ne 'Anonymous' -or $map['WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES'] -ne $scope) {
            Fail 'app settings must hand the gate to built-in authentication and publish the user_impersonation scope (expected HTTP 200 from Azure Resource Manager).'
        }
        Pass 'app settings: webhook key gate replaced by Entra, PRM scope set (Preview) (expected HTTP 200 from Azure Resource Manager).'

        $key = (& az functionapp keys list --resource-group $group --name $app --query 'systemKeys.mcp_extension' --output tsv --only-show-errors 2>$null | Out-String).Trim()
        if ($key) {
            $keyOnly = Invoke-Mcp $initialize ($base + @{ 'x-functions-key' = $key })
            $key = $null
            if ($keyOnly.Status -ne 401) { Fail "the level 0 system key alone returned HTTP $($keyOnly.Status) (expected HTTP 401)." }
            Pass 'the level 0 system key alone no longer opens the server (expected HTTP 401).'
        } else {
            Write-Output 'INFO no mcp_extension key readable; key-only check skipped.'
        }
    }

    if (-not $Persona) {
        Write-Output 'INFO persona checks skipped. Sign in as each test account in a separate AZURE_CONFIG_DIR and rerun with -Persona Alice, Bob, then Eve.'
        Write-Output 'PASS module 03 operator checks complete. Persona checks are still required for validation.'
        return
    }

    if ($Persona -eq 'Eve') {
        Step 'Persona - Eve is refused a token' 'Proves a user without an app role assignment cannot even get a token for the MCP server.'
    } else {
        Step "Persona - $Persona signs in and lists the tools" 'Proves an assigned user gets a token for the MCP audience and sees the five tools.'
    }
    $account = Invoke-WorkshopAzureJson -Arguments @('account', 'show', '--query', '{tenantId:tenantId,userType:user.type}')
    if ($account.tenantId -ne $TenantId.ToString() -or $account.userType -ne 'user') {
        Fail 'Azure CLI must be signed in interactively as the test account in the explicit tenant (expected HTTP N/A).'
    }
    if (Test-Path -LiteralPath $PersonaObjectIdsPath) {
        $expected = (Get-Content -LiteralPath $PersonaObjectIdsPath -Raw | ConvertFrom-Json -AsHashtable)[$Persona.ToLowerInvariant()]
        $actual = (& az ad signed-in-user show --query id --output tsv --only-show-errors 2>$null | Out-String).Trim()
        if (-not $expected -or $actual -ne $expected) { Fail "the signed-in account is not the recorded $Persona test account (expected HTTP 200 from Microsoft Graph)." }
        Pass "signed-in account matches the private $Persona object ID (expected HTTP 200 from Microsoft Graph)."
    } else {
        Write-Output "INFO no private persona file; the signed-in account was not cross-checked against $Persona."
    }

    $token = Get-Token $audience
    if ($Persona -eq 'Eve') {
        if ($token.Ok) { $token = $null; Fail 'Eve obtained a token for the MCP API; assignment required is not enforced (expected token endpoint error AADSTS50105).' }
        $refusedForAssignment = $token.Value -match 'AADSTS50105'
        $token = $null
        if (-not $refusedForAssignment) { Fail 'Eve was refused, but not because of a missing assignment (expected AADSTS50105).' }
        Pass 'Eve cannot obtain a token: she is not assigned to the enterprise application (expected HTTP 400 from the token endpoint, AADSTS50105).'
        Write-Output 'PASS module 03 persona check complete for Eve.'
        return
    }
    if (-not $token.Ok) { $token = $null; Fail "$Persona could not obtain a token for the MCP API. Check the app role assignment (expected HTTP 200 from the token endpoint)." }
    $authorized = $base + @{ Authorization = "Bearer $($token.Value)" }
    $token = $null
    $init = Invoke-Mcp $initialize $authorized
    $version = $init.Payload?.result?.protocolVersion
    if ($init.Status -ne 200 -or -not $version) { Fail "$Persona initialize returned HTTP $($init.Status) (expected HTTP 200 with a protocol version)." }
    Pass "$Persona initialize with a token for the MCP audience succeeds; negotiated protocol $version (expected HTTP 200)."
    $session = "$($init.Headers['Mcp-Session-Id'])"
    if ($session) { $authorized['Mcp-Session-Id'] = $session }
    $authorized['MCP-Protocol-Version'] = $version
    $null = Invoke-Mcp @{ jsonrpc = '2.0'; method = 'notifications/initialized' } $authorized
    $list = Invoke-Mcp @{ jsonrpc = '2.0'; id = 2; method = 'tools/list'; params = @{} } $authorized
    $names = @($list.Payload?.result?.tools | ForEach-Object { $_.name } | Sort-Object)
    if ($list.Status -ne 200 -or $names.Count -ne 5 -or (Compare-Object $names $expectedTools)) {
        Fail "$Persona tools/list returned HTTP $($list.Status) and an unexpected tool set (expected HTTP 200 with five tools)."
    }
    Pass "$Persona tools/list returns exactly the five workshop tools (expected HTTP 200)."
    Write-Output "PASS module 03 persona checks complete for $Persona. Per-tool roles (Bob cannot write) are enforced in module 04."
}
finally {
    $token = $null; $other = $null; $key = $null; $authorized = $null
}
