#requires -Version 7.4
<#
.SYNOPSIS
    Module 04 validator: offline repository invariants, then live gateway checks after an approved deployment.
.DESCRIPTION
    Offline (default without -TenantId, or with -Offline): no Azure or Entra access. Checks the gateway policies,
    the Terraform opt-in (Standard v2, private path, staged lock, zero body bytes) and runs Terraform format, schema
    and mock tests.
    Operator mode (-TenantId -SubscriptionId): through the gateway, HTTP 401 without a token and with a token for
    another audience, gateway Protected Resource Metadata; the direct Function host is refused (HTTP 403);
    Azure Resource Manager shows public access disabled and zero-byte diagnostics. Add -CheckTelemetry after the
    persona runs to prove Application Insights holds gateway records without payload or Authorization header.
    Persona mode (-TenantId -Persona Alice|Bob|Eve, signed in to Azure CLI as that test account in a separate
    AZURE_CONFIG_DIR): Bob create_ticket 403, Alice create_ticket 200, Bob get_service_health 200, Eve gets no token.
    Add -Burst to prove HTTP 429 for one caller.
    Tokens stay in memory only. They are never printed, logged or written.
#>
[CmdletBinding()]
param(
    [switch]$Offline,
    [guid]$TenantId,
    [guid]$SubscriptionId,
    [ValidateSet('Alice', 'Bob', 'Eve')][string]$Persona,
    [string]$PersonaObjectIdsPath,
    [switch]$Burst,
    [switch]$CheckTelemetry,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$workload = Join-Path $root 'infra' 'workload'
$entra = Join-Path $root 'infra' 'entra'
$policies = Join-Path $PSScriptRoot 'policies'
$expectedTools = @('create_ticket', 'get_service_health', 'read_report_as_app', 'read_report_as_user', 'whoami')
$apimApiVersion = '2025-09-01-preview'
if (-not $PersonaObjectIdsPath) { $PersonaObjectIdsPath = Join-Path $root '.workshop' 'module03-personas.json' }

function Pass([string]$Message) { Write-Output "PASS $Message" }
function Fail([string]$Message) { throw "FAIL $Message" }
function Get-Value($Object, [string]$Path) {
    foreach ($name in $Path.Split('.')) {
        if ($Object -isnot [System.Collections.IDictionary] -or -not $Object.Contains($name)) { return $null }
        $Object = $Object[$name]
    }
    return $Object
}
function Test-All([string]$Text, [string[]]$Patterns) {
    foreach ($pattern in $Patterns) { if ($Text -notmatch $pattern) { return $false } }
    return $true
}
$script:StepNumber = 0
function Step([string]$Title, [string]$Why) {
    $script:StepNumber++
    Write-Output ''; Write-Output "== Step $($script:StepNumber): $Title =="; Write-Output "   Why: $Why"
}
Write-Output 'Module 04 validator - Azure API Management is the only way in, and it checks every tool call against your role.'

# ---------------------------------------------------------------- offline checks (always run)

Step 'Offline - your copy keeps every gate closed (no Azure call)' 'Proves policies, network and logging settings enforce token, role, rate limit and zero body bytes.'
$policyText = Get-Content -LiteralPath (Join-Path $policies 'mcp-server.xml') -Raw
$prmText = Get-Content -LiteralPath (Join-Path $policies 'protected-resource-metadata.xml') -Raw
$required = @(
    '<validate-azure-ad-token tenant-id="\$\{tenant_id\}"', 'output-token-variable-name="mcp-jwt"',
    '%\{ for audience in audiences ~\}\s*<audience>\$\{audience\}</audience>', '<application-id>\$\{client_id\}</application-id>',
    '<claim name="scp" match="any" separator=" ">\s*<value>user_impersonation</value>',
    'As<JObject>\(preserveContent: true\)', 'if \(tool == "create_ticket"\) \{ return "Tools\.Write\|create_ticket"; \}',
    'return "Tools\.Read\|" \+ tool;', 'return "deny:400\|malformed";', 'return "deny:403\|unknown-tool";', 'return "deny:403\|unsupported-method";',
    'Array\.IndexOf\(roles, required\) == -1', '<rate-limit-by-key calls="\$\{rate_limit_calls\}" renewal-period="\$\{rate_limit_period\}" counter-key="@\("workshop-mcp-oid-" \+ \(string\)context\.Variables\["mcp-caller-oid"\]\)"',
    '%\{ if length\(ip_ranges\) > 0 ~\}\s*<!--[^>]*-->\s*<ip-filter action="allow">', 'resource_metadata="\$\{resource_metadata_url\}"',
    'context\.LastError\.Source == "validate-azure-ad-token"', '<set-header name="X-MS-CLIENT-PRINCIPAL" exists-action="delete" />'
)
if (-not (Test-All $policyText $required) -or $policyText -match 'context\.Response\.Body|Ocp-Apim-Subscription-Key|subscription-key|<validate-jwt|AsJwt\(|<audience>https?://' -or
    ([regex]::Matches($policyText, '<audience>')).Count -ne 1) {
    Fail 'the gateway policy must validate the Entra token for the MCP audience only, check per-tool roles from the preserved JSON-RPC body, rate-limit per oid and challenge with gateway PRM (expected HTTP 401/403/429).'
}
Pass 'gateway policy: Entra token for the MCP audience only, create_ticket requires Tools.Write, other tools Tools.Read, malformed or unknown calls denied, per-oid rate limit, optional ip-filter, gateway PRM challenge (expected HTTP 401/403/429).'

if (-not (Test-All $prmText @('"resource":"\$\{resource\}"', '"authorization_servers":\["\$\{issuer\}"\]', '"scopes_supported":\["\$\{scope\}"\]', '<return-response>')) -or
    $prmText -match 'azurewebsites|validate-azure-ad-token') {
    Fail 'Protected Resource Metadata must be served by the gateway with the tenant issuer and MCP scope only (expected HTTP 200).'
}
Pass 'Protected Resource Metadata is answered by the gateway itself and never names the private Function host (expected HTTP 200).'

$gatewayTf = Get-Content -LiteralPath (Join-Path $workload 'gateway.tf') -Raw
$networkTf = Get-Content -LiteralPath (Join-Path $workload 'network.tf') -Raw
$diagnosticsTf = Get-Content -LiteralPath (Join-Path $workload 'diagnostics.tf') -Raw
$serverTf = Get-Content -LiteralPath (Join-Path $workload 'mcp-server.tf') -Raw
$variablesTf = Get-Content -LiteralPath (Join-Path $workload 'variables.tf') -Raw
if (-not (Test-All $gatewayTf @('type\s*=\s*"Microsoft\.ApiManagement/service/apis@2025-09-01-preview"', 'type\s*=\s*"mcp"', 'transportType\s*=\s*"streamable"',
        'uriTemplate\s*=\s*"/mcp"', '/runtime/webhooks"', 'subscriptionRequired\s*=\s*false', 'sku_name\s*=\s*"StandardV2_1"', 'virtual_network_type\s*=\s*"External"',
        'audiences\s*=\s*local\.mcp_auth_audiences')) -or
    -not (Test-All $networkTf @('"Microsoft\.Web/serverFarms"', 'privatelink\.azurewebsites\.net', 'subresource_names\s*=\s*\["sites"\]', 'destination_address_prefix\s*=\s*"AzureKeyVault"',
        'gateway_function_locked\s*=\s*local\.gateway_enabled\s*&&\s*var\.gateway_lock_function')) -or
    $serverTf -notmatch 'public_network_access_enabled\s*=\s*!local\.gateway_function_locked' -or
    $variablesTf -notmatch '!var\.gateway_lock_function \|\| var\.enable_governed_gateway' -or
    $variablesTf -notmatch 'var\.enable_entra_auth && var\.entra_auth_replace_key_gate' -or
    $gatewayTf -match 'subscriptionRequired\s*=\s*true|azurerm_api_management_subscription') {
    Fail 'infra/workload must expose the Function only through Standard v2 outbound integration and a private endpoint, lock it in a separate stage, and use no subscription key (expected HTTP 403 on the direct host).'
}
Pass 'Terraform: Standard v2 public gateway, outbound integration, Function private endpoint and private DNS, public access disabled only in stage 2, MCP API Preview with no subscription key (expected HTTP 403 on the direct host).'

$bodyBytes = [regex]::Matches($diagnosticsTf, 'body_bytes\s*=\s*0').Count
if ($bodyBytes -ne 4 -or $diagnosticsTf -match 'body_bytes\s*=\s*[1-9]' -or ([regex]::Matches($diagnosticsTf, 'headers_to_log\s*=\s*\[\]')).Count -ne 4 -or
    $gatewayTf -notmatch 'request\s*=\s*\{\s*headers\s*=\s*\[\],\s*body\s*=\s*\{\s*bytes\s*=\s*0\s*\}\s*\}' -or
    $gatewayTf -notmatch 'response\s*=\s*\{\s*headers\s*=\s*\[\],\s*body\s*=\s*\{\s*bytes\s*=\s*0\s*\}\s*\}' -or
    $diagnosticsTf -notmatch 'frontend\s*=\s*local\.gateway_payload_free' -or $diagnosticsTf -notmatch 'backend\s*=\s*local\.gateway_payload_free' -or
    $diagnosticsTf -notmatch 'log_client_ip\s*=\s*false') {
    Fail 'gateway diagnostics must log 0 body bytes and no header at the all-APIs and MCP API scopes (expected HTTP N/A).'
}
Pass 'diagnostics: 0 body bytes for frontend/backend requests/responses at both scopes, no header logged (no Authorization), no client IP (expected HTTP N/A).'

$scanned = @(Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File -Include *.md, *.xml, *.ps1, *.sh, *.json) +
    @(Get-ChildItem -LiteralPath $workload -Filter *.tf -File) + @(Get-Item -LiteralPath (Join-Path $workload 'tests' 'governed_gateway.tftest.hcl'))
$secretPatterns = @(
    'eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.', 'AccountKey=', 'SharedAccessSignature=', '[?&]sig=[A-Za-z0-9%]',
    'client_secret', 'ClientSecret', 'x-functions-key"\s*:\s*"[A-Za-z0-9]', '[?&]code=[A-Za-z0-9_\-]{20,}',
    'Bearer\s+[A-Za-z0-9_\-]{20,}\.', 'Ocp-Apim-Subscription-Key"\s*:\s*"[A-Za-z0-9]'
)
foreach ($pattern in $secretPatterns) {
    $hit = @($scanned | Where-Object { $_.FullName -ne $PSCommandPath } | Select-String -Pattern $pattern -CaseSensitive)
    if ($hit.Count -gt 0) { Fail "possible token, key or secret pattern in module 04 files: $(Split-Path $hit[0].Path -Leaf) (expected HTTP N/A)." }
}
Pass 'no access token, subscription key, function key, SAS or client secret in module 04 or workload files (expected HTTP N/A).'

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
    Write-Output 'PASS offline checks only. Module 04 is NOT deployed or validated by this result.'
    return
}

# ---------------------------------------------------------------- live checks (approved deployment only)

. (Join-Path $root 'scripts' 'context-common.ps1')
Assert-WorkshopInteractiveEnvironment
$outputs = & terraform "-chdir=$workload" output -json | ConvertFrom-Json -AsHashtable
if ($LASTEXITCODE -ne 0 -or $null -eq $outputs) { Fail 'Terraform outputs unavailable; use the same private workload state as the deployment (expected HTTP N/A).' }
$gateway = $outputs.gateway_mcp_endpoint?.value
$metadataUrl = $outputs.gateway_resource_metadata_url?.value
$direct = $outputs.mcp_endpoint?.value
$audience = $outputs.mcp_auth_audience?.value
$scope = $outputs.mcp_auth_scope?.value
$issuer = $outputs.mcp_auth_issuer?.value
if (-not $outputs.gateway_enabled?.value -or -not $gateway -or -not $metadataUrl -or -not $direct -or -not $audience -or -not $scope -or -not $issuer) {
    Fail 'module 04 is not deployed in this state (enable_governed_gateway is false). Apply it first, or use -Offline.'
}
if (-not $outputs.gateway_function_public_access_disabled?.value) {
    Fail 'stage 1 only: the Function is still public. Apply stage 2 (gateway_lock_function = true) before validating (expected HTTP 403 on the direct host).'
}
if ($issuer -ne "https://login.microsoftonline.com/$TenantId/v2.0") { Fail 'the deployed issuer is not the explicit tenant (expected HTTP N/A).' }
$gatewayBase = ([uri]$gateway).GetLeftPart([UriPartial]::Authority)

$base = @{ Accept = 'application/json, text/event-stream' }
function Invoke-Mcp([string]$Uri, [hashtable]$Body, [hashtable]$Headers) {
    $json = $Body | ConvertTo-Json -Depth 10 -Compress
    $response = Invoke-WebRequest -Uri $Uri -Method Post -Body $json -ContentType 'application/json' -Headers $Headers `
        -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 60
    $payload = $null
    $text = [string]$response.Content
    if ($text) {
        if ("$($response.Headers['Content-Type'])" -match 'text/event-stream') {
            $text = ($text -split "`n" | Where-Object { $_ -like 'data:*' } | ForEach-Object { $_.Substring(5).Trim() } | Select-Object -Last 1)
        }
        try { $payload = $text | ConvertFrom-Json -AsHashtable -Depth 20 } catch { $payload = $null }
    }
    return [pscustomobject]@{ Status = [int]$response.StatusCode; Headers = $response.Headers; Payload = $payload; Text = [string]$response.Content }
}
function Get-Token([string]$Resource) {
    $text = (& az account get-access-token --tenant $TenantId --resource $Resource --query accessToken --output tsv --only-show-errors 2>&1 | Out-String).Trim()
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0 -and $text -match '^[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*$'); Value = $text }
}
$initialize = @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{
    protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'workshop-validator'; version = '0.4.0' } } }

Step 'Live - the gateway is the only way in and refuses wrong tokens' 'Proves no token or a wrong-audience token gets HTTP 401, and the Function host is closed.'
$anonymous = Invoke-Mcp $gateway $initialize $base
$challenge = "$($anonymous.Headers['WWW-Authenticate'])"
if ($anonymous.Status -ne 401) { Fail "gateway request without a token returned HTTP $($anonymous.Status) (expected HTTP 401)." }
if ($challenge -notmatch 'resource_metadata="([^"]+)"' -or $Matches[1] -ne $metadataUrl -or $challenge -match 'azurewebsites') {
    Fail 'the gateway 401 challenge must name the gateway Protected Resource Metadata URL, never the Function host (expected HTTP 401).'
}
Pass 'gateway request without a token is refused with a challenge naming the gateway metadata (expected HTTP 401).'

$prm = Invoke-WebRequest -Uri $metadataUrl -Method Get -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 30
$metadata = $null; try { $metadata = [string]$prm.Content | ConvertFrom-Json -AsHashtable } catch { $metadata = $null }
if ([int]$prm.StatusCode -ne 200 -or $null -eq $metadata -or (Get-Value $metadata 'resource') -ne $gateway -or
    @(Get-Value $metadata 'authorization_servers') -notcontains $issuer -or @(Get-Value $metadata 'scopes_supported') -notcontains $scope -or
    [string]$prm.Content -match 'azurewebsites') {
    Fail "gateway Protected Resource Metadata returned HTTP $($prm.StatusCode) without the gateway resource, tenant issuer and scope (expected HTTP 200)."
}
Pass 'gateway Protected Resource Metadata names the gateway resource, the tenant and the user_impersonation scope (expected HTTP 200).'

$directStatus = 0
try {
    $directResponse = Invoke-WebRequest -Uri $direct -Method Post -Body ($initialize | ConvertTo-Json -Depth 10 -Compress) -ContentType 'application/json' `
        -Headers $base -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 30
    $directStatus = [int]$directResponse.StatusCode
} catch { $directStatus = 0 }
if ($directStatus -ne 403 -and $directStatus -ne 0) {
    Fail "the Function host answered HTTP $directStatus from the internet; only the gateway may reach it (expected HTTP 403 or no connection)."
}
Pass "direct call to the Function host is refused from the internet: $(if ($directStatus) { "HTTP $directStatus" } else { 'no connection' }) (expected HTTP 403)."

$other = $null; $token = $null; $authorized = $null
try {
    $other = Get-Token 'https://graph.microsoft.com'
    if (-not $other.Ok) { Fail 'could not obtain a Microsoft Graph token for the wrong-audience check (expected HTTP 200 from the token endpoint).' }
    $wrong = Invoke-Mcp $gateway $initialize ($base + @{ Authorization = "Bearer $($other.Value)" })
    $other = $null
    if ($wrong.Status -ne 401) { Fail "a token for another audience (Microsoft Graph) returned HTTP $($wrong.Status) at the gateway (expected HTTP 401)." }
    Pass 'a valid token for another audience (Microsoft Graph) is refused by the gateway (expected HTTP 401).'

    if ($SubscriptionId -and $SubscriptionId -ne [guid]::Empty) {
        Step 'Azure configuration matches Terraform' 'Proves the Function is private and gateway logs keep zero body bytes and no headers.'
        Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
        Pass 'explicit Azure context matches the approved test target (expected HTTP 200 from Azure Resource Manager).'
        $group = $outputs.resource_group_name?.value
        $app = $outputs.mcp_function_app_name?.value
        $service = $outputs.gateway_name?.value
        $api = $outputs.gateway_mcp_api_name?.value
        $site = Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--uri',
            "/subscriptions/$SubscriptionId/resourceGroups/$group/providers/Microsoft.Web/sites/$($app)?api-version=2024-04-01")
        if ((Get-Value $site 'properties.publicNetworkAccess') -ne 'Disabled') {
            Fail 'the Function App still allows public network access (expected HTTP 200 from Azure Resource Manager with publicNetworkAccess Disabled).'
        }
        Pass 'Function App publicNetworkAccess is Disabled; only its private endpoint remains (expected HTTP 200 from Azure Resource Manager).'
        $serviceBase = "/subscriptions/$SubscriptionId/resourceGroups/$group/providers/Microsoft.ApiManagement/service/$service"
        foreach ($scopePath in @("$serviceBase/diagnostics/applicationinsights", "$serviceBase/apis/$api/diagnostics/applicationinsights")) {
            $diagnostic = Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--uri', "$($scopePath)?api-version=$apimApiVersion")
            foreach ($side in 'frontend', 'backend') {
                foreach ($direction in 'request', 'response') {
                    $bytes = Get-Value $diagnostic "properties.$side.$direction.body.bytes"
                    $headers = @(Get-Value $diagnostic "properties.$side.$direction.headers" | Where-Object { $_ })
                    if ($null -eq $bytes -or [int]$bytes -ne 0 -or $headers.Count -gt 0) {
                        Fail "diagnostic $side $direction must log 0 body bytes and no header (expected HTTP 200 from Azure Resource Manager)."
                    }
                }
            }
        }
        Pass 'deployed diagnostics log 0 body bytes and no header at the all-APIs and MCP API scopes (expected HTTP 200 from Azure Resource Manager).'

        if ($CheckTelemetry) {
            $names = $outputs.resource_names?.value
            $workspace = Invoke-WorkshopAzureJson -Arguments @('monitor', 'log-analytics', 'workspace', 'show', '--resource-group', $group,
                '--workspace-name', $names.log_analytics, '--query', '{customerId:customerId}')
            $query = "AppRequests | where TimeGenerated > ago(4h) | where Url has '/mcp' and AppRoleName has '$service' " +
                "| extend p = tostring(Properties) | summarize total = count(), payload = countif(p has 'Request-Body' or p has 'Response-Body' or p has 'arguments'), " +
                "credential = countif(p has_cs 'Authorization' or p has 'Bearer ')"
            $requests = (Invoke-WorkshopAzureJson -Arguments @('monitor', 'log-analytics', 'query', '--workspace', $workspace.customerId, '--analytics-query', $query))
            $traceQuery = "AppTraces | where TimeGenerated > ago(4h) and Message == 'mcp-request' | extend p = tostring(Properties) " +
                "| summarize total = count(), labelled = countif(p has 'mcp-tool' and p has 'caller-oid'), payload = countif(p has 'arguments' or p has 'Bearer ')"
            $traces = (Invoke-WorkshopAzureJson -Arguments @('monitor', 'log-analytics', 'query', '--workspace', $workspace.customerId, '--analytics-query', $traceQuery))
            $r = $requests | Select-Object -First 1; $t = $traces | Select-Object -First 1
            if ($null -eq $r -or [int]$r.total -eq 0 -or $null -eq $t -or [int]$t.total -eq 0) {
                Fail 'no gateway records in Application Insights yet. Run the persona checks, wait about 5 minutes, then rerun with -CheckTelemetry (expected HTTP 200 from Log Analytics).'
            }
            if ([int]$r.payload -ne 0 -or [int]$r.credential -ne 0 -or [int]$t.payload -ne 0 -or [int]$t.labelled -ne [int]$t.total) {
                Fail 'Application Insights holds a body, an argument or an Authorization value; payload-free logging is broken (expected HTTP 200 from Log Analytics).'
            }
            Pass "Application Insights: $($r.total) gateway requests and $($t.total) tool traces with tool label and caller oid, no body, argument or token (expected HTTP 200 from Log Analytics)."
        } else {
            Write-Output 'INFO telemetry check skipped. After the persona runs, wait about 5 minutes and rerun with -CheckTelemetry.'
        }
    }

    if (-not $Persona) {
        Write-Output 'INFO persona checks skipped. Sign in as each test account in a separate AZURE_CONFIG_DIR and rerun with -Persona Alice, Bob (add -Burst once), then Eve.'
        Write-Output 'PASS module 04 operator checks complete. Persona checks are still required for validation.'
        return
    }

    if ($Persona -eq 'Eve') {
        Step 'Persona - Eve is refused a token' 'Proves a user without an app role assignment never reaches the gateway.'
    } else {
        Step "Persona - $Persona calls tools through the gateway" 'Proves each tool call is checked against your app role: Tools.Read to read, Tools.Write to write.'
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
        $refused = $token.Value -match 'AADSTS50105'
        $token = $null
        if (-not $refused) { Fail 'Eve was refused, but not because of a missing assignment (expected AADSTS50105).' }
        Pass 'Eve cannot obtain a token, so she never reaches the gateway (expected HTTP 400 from the token endpoint, AADSTS50105).'
        Write-Output 'PASS module 04 persona check complete for Eve.'
        return
    }
    if (-not $token.Ok) { $token = $null; Fail "$Persona could not obtain a token for the MCP API. Check the app role assignment (expected HTTP 200 from the token endpoint)." }
    $authorized = $base + @{ Authorization = "Bearer $($token.Value)" }
    $token = $null

    $init = Invoke-Mcp $gateway $initialize $authorized
    $version = $init.Payload?.result?.protocolVersion
    if ($init.Status -ne 200 -or -not $version) { Fail "$Persona initialize through the gateway returned HTTP $($init.Status) (expected HTTP 200 with a protocol version)." }
    Pass "$Persona initialize through the gateway succeeds; negotiated protocol $version (expected HTTP 200)."
    $session = "$($init.Headers['Mcp-Session-Id'])"
    if ($session) { $authorized['Mcp-Session-Id'] = $session }
    $authorized['MCP-Protocol-Version'] = $version
    $null = Invoke-Mcp $gateway @{ jsonrpc = '2.0'; method = 'notifications/initialized' } $authorized
    $list = Invoke-Mcp $gateway @{ jsonrpc = '2.0'; id = 2; method = 'tools/list'; params = @{} } $authorized
    $names = @($list.Payload?.result?.tools | ForEach-Object { $_.name } | Sort-Object)
    if ($list.Status -ne 200 -or $names.Count -ne 5 -or (Compare-Object $names $expectedTools)) {
        Fail "$Persona tools/list through the gateway returned HTTP $($list.Status) and an unexpected tool set (expected HTTP 200 with five tools)."
    }
    Pass "$Persona tools/list through the gateway returns the five workshop tools (expected HTTP 200)."

    $health = Invoke-Mcp $gateway @{ jsonrpc = '2.0'; id = 3; method = 'tools/call'; params = @{ name = 'get_service_health'; arguments = @{ service = 'workshop-api' } } } $authorized
    if ($health.Status -ne 200 -or $null -eq $health.Payload?.result -or $health.Payload.result.isError) {
        Fail "$Persona get_service_health returned HTTP $($health.Status) or a tool error (expected HTTP 200, Tools.Read)."
    }
    Pass "$Persona get_service_health is allowed with Tools.Read (expected HTTP 200)."

    $ticket = Invoke-Mcp $gateway @{ jsonrpc = '2.0'; id = 4; method = 'tools/call'; params = @{ name = 'create_ticket'; arguments = @{
                service = 'workshop-api'; severity = 'low'; summary = 'Synthetic gateway validation ticket' } } } $authorized
    if ($Persona -eq 'Bob') {
        if ($ticket.Status -ne 403) { Fail "Bob create_ticket returned HTTP $($ticket.Status); the gateway must deny a write without Tools.Write (expected HTTP 403)." }
        Pass 'Bob create_ticket is denied by the gateway: Tools.Write is missing (expected HTTP 403).'
    } else {
        if ($ticket.Status -ne 200 -or $null -eq $ticket.Payload?.result -or $ticket.Payload.result.isError) {
            Fail "Alice create_ticket returned HTTP $($ticket.Status) or a tool error (expected HTTP 200 with Tools.Write)."
        }
        Pass 'Alice create_ticket is allowed with Tools.Write and queues one synthetic ticket (expected HTTP 200).'
    }

    $unknown = Invoke-Mcp $gateway @{ jsonrpc = '2.0'; id = 5; method = 'tools/call'; params = @{ name = 'not_a_workshop_tool'; arguments = @{} } } $authorized
    $malformed = Invoke-Mcp $gateway @{ jsonrpc = '2.0'; id = 6 } $authorized
    if ($unknown.Status -ne 403 -or $malformed.Status -ne 400) {
        Fail "unknown tool returned HTTP $($unknown.Status) and a request without method HTTP $($malformed.Status) (expected HTTP 403 and 400)."
    }
    Pass 'an unknown tool and a JSON-RPC message without a method are denied safely (expected HTTP 403 and HTTP 400).'

    if ($Burst) {
        $limit = $outputs.gateway_rate_limit?.value
        $count = [int]$limit.calls + 10
        $statuses = @(for ($i = 0; $i -lt $count; $i++) { (Invoke-Mcp $gateway @{ jsonrpc = '2.0'; id = 100 + $i; method = 'ping' } $authorized).Status })
        if ($statuses -notcontains 429) { Fail "$count rapid calls from one caller returned no HTTP 429; rate-limit-by-key on the caller oid is not enforced (expected HTTP 429)." }
        Pass "$Persona burst of $count calls is throttled per caller object ID (expected HTTP 429)."
    }
    Write-Output "PASS module 04 persona checks complete for $Persona."
}
finally {
    $token = $null; $other = $null; $authorized = $null
}
