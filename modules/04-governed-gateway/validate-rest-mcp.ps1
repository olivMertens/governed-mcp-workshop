#requires -Version 7.4
<#
.SYNOPSIS
    Module 04 optional part B validator: a REST API managed by API Management, exposed as an MCP server (API-first).
.DESCRIPTION
    Offline (default without -TenantId, or with -Offline): no Azure or Entra access. Checks the part B policies and
    Terraform (Preview MCP server type, tools mapped to the backing operations, the MCP audience only, required scope,
    app role, per-oid rate limit, payload-free trace, mock-response, no subscription key) and runs Terraform format,
    schema and the part B mock tests.
    Operator mode (-TenantId [-SubscriptionId]): HTTP 401 with a resource_metadata challenge without a token, metadata
    HTTP 200, the backing REST API HTTP 401 without a token, a Microsoft Graph token HTTP 401. With -SubscriptionId,
    Azure Resource Manager shows the MCP server, its two tools and zero-byte diagnostics.
    Persona mode (-TenantId -Persona Alice|Bob, signed in to Azure CLI as that test account in a separate
    AZURE_CONFIG_DIR): initialize, tools/list (exactly list_tickets and get_ticket), list_tickets and get_ticket CT-1001.
    Tokens stay in memory only. They are never printed, logged or written.
#>
[CmdletBinding()]
param(
    [switch]$Offline,
    [guid]$TenantId,
    [guid]$SubscriptionId,
    [ValidateSet('Alice', 'Bob')][string]$Persona,
    [string]$PersonaObjectIdsPath,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$workload = Join-Path $root 'infra' 'workload'
$policies = Join-Path $PSScriptRoot 'policies'
$expectedTools = @('get_ticket', 'list_tickets')
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
Write-Output 'Module 04 part B validator - a REST API becomes MCP tools on the same gateway, with the same token, role and logging rules.'

# ---------------------------------------------------------------- offline checks (always run)

Step 'Offline - part B files keep every gate closed (no Azure call)' 'Proves the REST API and its MCP server need an Entra token for the MCP API, an app role, and log no payload.'
$files = @(
    (Join-Path $workload 'rest-mcp.tf'), (Join-Path $workload 'tests' 'rest_mcp.tftest.hcl'), (Join-Path $policies 'rest-api.xml'),
    (Join-Path $policies 'rest-mcp-server.xml'), (Join-Path $PSScriptRoot 'validate-rest-mcp.sh')
)
$absent = @($files | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($absent.Count -gt 0) { Fail "part B file missing: $(Split-Path $absent[0] -Leaf) (expected HTTP N/A)." }
Pass 'part B files exist: rest-mcp.tf, its mock tests, both policies and the bash wrapper (expected HTTP N/A).'

$restApiText = Get-Content -LiteralPath (Join-Path $policies 'rest-api.xml') -Raw
$restMcpText = Get-Content -LiteralPath (Join-Path $policies 'rest-mcp-server.xml') -Raw
$tokenRules = @(
    '<validate-azure-ad-token tenant-id="\$\{tenant_id\}"', '%\{ for audience in audiences ~\}\s*<audience>\$\{audience\}</audience>',
    '<application-id>\$\{client_id\}</application-id>', '<claim name="scp" match="any" separator=" ">\s*<value>user_impersonation</value>'
)
$forbidden = 'context\.Response\.Body|Ocp-Apim-Subscription-Key|subscription-key|<validate-jwt|AsJwt\(|<audience>https?://'
if (-not (Test-All $restApiText ($tokenRules + @('<mock-response status-code="200" content-type="application/json" />'))) -or
    $restApiText -match $forbidden -or ([regex]::Matches($restApiText, '<audience>')).Count -ne 1 -or
    $restApiText.IndexOf('<validate-azure-ad-token') -gt $restApiText.IndexOf('<mock-response')) {
    Fail 'the REST API policy must validate the Entra token for the MCP audience only before mock-response, with no subscription key (expected HTTP 401 without a token).'
}
Pass 'REST API policy: Entra token for the MCP audience only and user_impersonation before mock-response, no subscription key (expected HTTP 401 without a token).'

$mcpRules = $tokenRules + @(
    'output-token-variable-name="mcp-jwt"', 'claims\.ContainsKey\("oid"\)',
    '<rate-limit-by-key calls="\$\{rate_limit_calls\}" renewal-period="\$\{rate_limit_period\}" counter-key="@\("workshop-rest-mcp-oid-" \+ \(string\)context\.Variables\["mcp-caller-oid"\]\)"',
    'Array\.IndexOf\(roles, "Tools\.Read"\) >= 0 \|\| Array\.IndexOf\(roles, "Tools\.Write"\) >= 0', '<trace source="workshop-rest-mcp"',
    '<metadata name="caller-oid" value="@\(\(string\)context\.Variables\["mcp-caller-oid"\]\)" />',
    'resource_metadata="\$\{resource_metadata_url\}"', 'context\.LastError\.Source == "validate-azure-ad-token"'
)
$metadataNames = @([regex]::Matches($restMcpText, '<metadata name="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if (-not (Test-All $restMcpText $mcpRules) -or $restMcpText -match $forbidden -or $restMcpText -match 'context\.Request\.Body' -or
    ([regex]::Matches($restMcpText, '<audience>')).Count -ne 1 -or ($metadataNames -join ',') -ne 'caller-oid') {
    Fail 'the MCP server policy must validate the token for the MCP audience only, require Tools.Read or Tools.Write, rate-limit per oid, trace the caller oid only and challenge with PRM (expected HTTP 401/403/429).'
}
Pass 'MCP server policy: Entra token for the MCP audience only, Tools.Read or Tools.Write, per-oid rate limit, trace with caller oid only, PRM challenge, no body access (expected HTTP 401/403/429).'

$restTf = Get-Content -LiteralPath (Join-Path $workload 'rest-mcp.tf') -Raw
$variablesTf = Get-Content -LiteralPath (Join-Path $workload 'variables.tf') -Raw
$diagnosticsTf = Get-Content -LiteralPath (Join-Path $workload 'diagnostics.tf') -Raw
$restRules = @(
    'rest_mcp_enabled\s*=\s*local\.gateway_enabled\s*&&\s*var\.enable_rest_mcp_demo', 'type\s*=\s*"mcp"',
    'type\s*=\s*"Microsoft\.ApiManagement/service/apis/tools@2025-09-01-preview" # Preview',
    'operationId\s*=\s*"\$\{azapi_resource\.rest_api\[0\]\.id\}/operations/\$\{each\.value\}"',
    'list_tickets\s*=\s*"list-tickets",\s*get_ticket\s*=\s*"get-ticket"', 'urlTemplate\s*=\s*"/tickets/\{ticketId\}"',
    'urlTemplate\s*=\s*"/\$\{local\.rest_mcp_path\}/mcp"', 'audiences\s*=\s*local\.mcp_auth_audiences',
    'parent_id\s*=\s*azapi_resource\.prm_api\[0\]\.id'
)
if (-not (Test-All $restTf $restRules) -or ([regex]::Matches($restTf, 'subscriptionRequired\s*=\s*false')).Count -ne 2 -or
    $restTf -match 'subscriptionRequired\s*=\s*true|azurerm_api_management_subscription|body_bytes|bytes\s*=\s*[1-9]|apis/diagnostics' -or
    $variablesTf -notmatch '!var\.enable_rest_mcp_demo \|\| var\.enable_governed_gateway' -or
    ([regex]::Matches($diagnosticsTf, 'body_bytes\s*=\s*0')).Count -ne 4 -or $diagnosticsTf -match 'body_bytes\s*=\s*[1-9]') {
    Fail 'infra/workload/rest-mcp.tf must be opt-in behind the gateway, map list_tickets and get_ticket to their operations, use no subscription key and no API-scope logging override (expected HTTP N/A).'
}
Pass 'Terraform: opt-in behind the gateway, MCP server (Preview) with list_tickets and get_ticket mapped to their operations, no subscription key, all-APIs diagnostic at 0 body bytes (expected HTTP N/A).'

$secretPatterns = @(
    # Split literals so this file does not match its own patterns in the module 04 secret scan.
    'eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.', ('Account' + 'Key='), ('SharedAccess' + 'Signature='), '[?&]sig=[A-Za-z0-9%]',
    ('client' + '_secret'), ('Client' + 'Secret'), '[?&]code=[A-Za-z0-9_\-]{20,}', 'Bearer\s+[A-Za-z0-9_\-]{20,}\.', 'Ocp-Apim-Subscription-Key"\s*:\s*"[A-Za-z0-9]'
)
foreach ($pattern in $secretPatterns) {
    $hit = @($files | Where-Object { $_ -ne $PSCommandPath } | Select-String -Pattern $pattern -CaseSensitive)
    if ($hit.Count -gt 0) { Fail "possible token, key or secret pattern in part B files: $(Split-Path $hit[0].Path -Leaf) (expected HTTP N/A)." }
}
Pass 'no access token, subscription key, SAS or client secret in part B files (expected HTTP N/A).'

if (-not $SkipBuild) {
    Step 'Offline - Terraform format, schema and part B mock plans' 'Proves the workload root is valid and part B renders as expected without creating anything.'
    if (-not (Test-Path -LiteralPath (Join-Path $workload '.terraform'))) {
        & terraform "-chdir=$workload" init -lockfile=readonly -input=false -no-color | Out-Null
        if ($LASTEXITCODE -ne 0) { Fail 'Terraform init for workload (expected HTTP N/A). Use Terraform 1.16.6+ and registry access.' }
    }
    foreach ($arguments in @(@('fmt', '-check', '-recursive'), @('validate', '-no-color'), @('test', '-no-color', "-filter=$(Join-Path 'tests' 'rest_mcp.tftest.hcl')"))) {
        $output = & terraform "-chdir=$workload" @arguments 2>&1
        if ($LASTEXITCODE -ne 0 -or ($arguments[0] -eq 'test' -and ($output -join "`n") -notmatch '[1-9]\d* passed, 0 failed')) {
            $output | Select-Object -Last 15 | ForEach-Object { Write-Warning $_ }
            Fail "Terraform $($arguments[0]) for workload (expected HTTP N/A)."
        }
    }
    Pass 'Terraform format, schema and part B mock-only plans for infra/workload (expected HTTP N/A; no live plan/apply).'
}

if ($Offline -or -not $TenantId -or $TenantId -eq [guid]::Empty) {
    Write-Output 'NOT DEPLOYED CHECKS SKIPPED: supply -TenantId (and -SubscriptionId) as operator, or -TenantId -Persona as a test account, after an approved deployment.'
    Write-Output 'PASS offline checks only. Module 04 part B is NOT deployed or validated by this result.'
    return
}

# ---------------------------------------------------------------- live checks (approved deployment only)

. (Join-Path $root 'scripts' 'context-common.ps1')
Assert-WorkshopInteractiveEnvironment
$outputs = & terraform "-chdir=$workload" output -json | ConvertFrom-Json -AsHashtable
if ($LASTEXITCODE -ne 0 -or $null -eq $outputs) { Fail 'Terraform outputs unavailable; use the same private workload state as the deployment (expected HTTP N/A).' }
$endpoint = $outputs.rest_mcp_endpoint?.value
$metadataUrl = $outputs.rest_mcp_resource_metadata_url?.value
$restBase = $outputs.rest_api_endpoint?.value
$audience = $outputs.mcp_auth_audience?.value
$scope = $outputs.mcp_auth_scope?.value
$issuer = $outputs.mcp_auth_issuer?.value
if (-not $outputs.rest_mcp_enabled?.value -or -not $endpoint -or -not $metadataUrl -or -not $restBase -or -not $audience -or -not $scope -or -not $issuer) {
    Fail 'module 04 part B is not deployed in this state (enable_rest_mcp_demo is false). Apply it first, or use -Offline.'
}
if ($issuer -ne "https://login.microsoftonline.com/$TenantId/v2.0") { Fail 'the deployed issuer is not the explicit tenant (expected HTTP N/A).' }

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
# Joins the text content of a tool result. The content is synthetic ticket data, checked here and never printed.
# MCP lets a server omit isError when the call succeeded (absent means false); API Management does so.
function Test-ToolError($Result) { return $Result -is [System.Collections.IDictionary] ? [bool]$Result['isError'] : [bool]($Result.PSObject.Properties['isError']?.Value) }
function Get-ToolText($Result) {
    return (@(${Result}?.content | Where-Object { $_ -is [System.Collections.IDictionary] -and $_['type'] -eq 'text' } | ForEach-Object { [string]$_['text'] }) -join "`n")
}
$initialize = @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{
    protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'workshop-validator'; version = '0.4.1' } } }

$other = $null; $token = $null; $authorized = $null
try {
    if (-not $Persona) {
        Step 'Live - the REST-backed MCP server and its REST API refuse missing or wrong tokens' 'Proves turning an API into tools did not open a new anonymous door.'
        $anonymous = Invoke-Mcp $endpoint $initialize $base
        $challenge = "$($anonymous.Headers['WWW-Authenticate'])"
        if ($anonymous.Status -ne 401) { Fail "part B MCP request without a token returned HTTP $($anonymous.Status) (expected HTTP 401)." }
        if ($challenge -notmatch 'resource_metadata="([^"]+)"' -or $Matches[1] -ne $metadataUrl) {
            Fail 'the part B 401 challenge must name its own Protected Resource Metadata URL (expected HTTP 401).'
        }
        Pass 'part B MCP request without a token is refused with a challenge naming its metadata URL (expected HTTP 401).'

        $prm = Invoke-WebRequest -Uri $metadataUrl -Method Get -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 30
        $metadata = $null; try { $metadata = [string]$prm.Content | ConvertFrom-Json -AsHashtable } catch { $metadata = $null }
        if ([int]$prm.StatusCode -ne 200 -or $null -eq $metadata -or (Get-Value $metadata 'resource') -ne $endpoint -or
            @(Get-Value $metadata 'authorization_servers') -notcontains $issuer -or @(Get-Value $metadata 'scopes_supported') -notcontains $scope) {
            Fail "part B Protected Resource Metadata returned HTTP $($prm.StatusCode) without the part B resource, tenant issuer and scope (expected HTTP 200)."
        }
        Pass 'part B Protected Resource Metadata names its resource, the tenant authorization server and the user_impersonation scope (expected HTTP 200).'

        $direct = Invoke-WebRequest -Uri "$restBase/tickets" -Method Get -Headers @{ Accept = 'application/json' } -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 30
        if ([int]$direct.StatusCode -ne 401) { Fail "the backing REST API without a token returned HTTP $($direct.StatusCode); it must never be anonymous (expected HTTP 401)." }
        Pass 'the backing REST API /contoso-tickets/tickets without a token is refused (expected HTTP 401).'

        $other = Get-Token 'https://graph.microsoft.com'
        if (-not $other.Ok) { Fail 'could not obtain a Microsoft Graph token for the wrong-audience check (expected HTTP 200 from the token endpoint).' }
        $wrongHeaders = $base + @{ Authorization = "Bearer $($other.Value)" }
        $other = $null
        $wrong = Invoke-Mcp $endpoint $initialize $wrongHeaders
        $wrongRest = Invoke-WebRequest -Uri "$restBase/tickets" -Method Get -Headers $wrongHeaders -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 30
        $wrongHeaders = $null
        if ($wrong.Status -ne 401 -or [int]$wrongRest.StatusCode -ne 401) {
            Fail "a Microsoft Graph token returned HTTP $($wrong.Status) on the MCP server and HTTP $($wrongRest.StatusCode) on the REST API (expected HTTP 401 on both)."
        }
        Pass 'a valid token for another audience (Microsoft Graph) is refused by the part B MCP server and its REST API (expected HTTP 401).'

        if ($SubscriptionId -and $SubscriptionId -ne [guid]::Empty) {
            Step 'Azure configuration matches Terraform' 'Proves the MCP server is the Preview REST-backed type with exactly two tools and payload-free logs.'
            Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
            Pass 'explicit Azure context matches the approved test target (expected HTTP 200 from Azure Resource Manager).'
            $group = $outputs.resource_group_name?.value
            $service = $outputs.gateway_name?.value
            $mcpName = $outputs.rest_mcp_api_name?.value
            $restName = $outputs.rest_api_name?.value
            $serviceBase = "/subscriptions/$SubscriptionId/resourceGroups/$group/providers/Microsoft.ApiManagement/service/$service"
            $server = Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--uri', "$serviceBase/apis/$($mcpName)?api-version=$apimApiVersion")
            $tools = Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--uri', "$serviceBase/apis/$mcpName/tools?api-version=$apimApiVersion")
            $toolNames = @(@(Get-Value $tools 'value') | ForEach-Object { $_['name'] } | Sort-Object)
            $mapped = @(@(Get-Value $tools 'value') | Where-Object {
                    $operation = [string](Get-Value $_ 'properties.operationId')
                    $operation -match "/apis/$([regex]::Escape($restName))/operations/(list-tickets|get-ticket)$" -and
                    $Matches[1] -eq ($(if ($_['name'] -eq 'list_tickets') { 'list-tickets' } else { 'get-ticket' }))
                })
            if ((Get-Value $server 'properties.type') -ne 'mcp' -or (Get-Value $server 'properties.subscriptionRequired') -ne $false -or
                ($toolNames -join ',') -ne ($expectedTools -join ',') -or $mapped.Count -ne 2) {
                Fail 'the part B MCP server must be type mcp, without subscription key, with exactly list_tickets and get_ticket mapped to their operations (expected HTTP 200 from Azure Resource Manager).'
            }
            Pass 'the part B MCP server is type mcp, needs no subscription key and maps list_tickets and get_ticket to their REST operations (expected HTTP 200 from Azure Resource Manager).'
            $diagnostics = [System.Collections.Generic.List[object]]::new()
            $diagnostics.Add((Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--uri', "$serviceBase/diagnostics/applicationinsights?api-version=$apimApiVersion")))
            foreach ($api in @($mcpName, $restName)) {
                $scoped = Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--uri', "$serviceBase/apis/$api/diagnostics?api-version=$apimApiVersion")
                foreach ($item in @(Get-Value $scoped 'value')) { if ($item) { $diagnostics.Add($item) } }
            }
            foreach ($diagnostic in $diagnostics) {
                foreach ($side in 'frontend', 'backend') {
                    foreach ($direction in 'request', 'response') {
                        $bytes = Get-Value $diagnostic "properties.$side.$direction.body.bytes"
                        $headers = @(Get-Value $diagnostic "properties.$side.$direction.headers" | Where-Object { $_ })
                        if ($null -eq $bytes -or [int]$bytes -ne 0 -or $headers.Count -gt 0) {
                            Fail "diagnostic $side $direction must log 0 body bytes and no header for part B (expected HTTP 200 from Azure Resource Manager)."
                        }
                    }
                }
            }
            Pass "deployed diagnostics covering part B log 0 body bytes and no header ($($diagnostics.Count) scope(s) read) (expected HTTP 200 from Azure Resource Manager)."
        }
        Write-Output 'INFO persona checks skipped. Sign in as Alice or Bob in a separate AZURE_CONFIG_DIR and rerun with -Persona.'
        Write-Output 'PASS module 04 part B operator checks complete. Persona checks are still required for validation.'
        return
    }

    Step "Persona - $Persona calls the REST-backed tools through the gateway" 'Proves a user with Tools.Read gets the API operations as MCP tools, and nothing else.'
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
    if (-not $token.Ok) { $token = $null; Fail "$Persona could not obtain a token for the MCP API. Check the app role assignment (expected HTTP 200 from the token endpoint)." }
    $authorized = $base + @{ Authorization = "Bearer $($token.Value)" }
    $token = $null

    $init = Invoke-Mcp $endpoint $initialize $authorized
    $version = $init.Payload?.result?.protocolVersion
    if ($init.Status -ne 200 -or -not $version) { Fail "$Persona initialize on the part B MCP server returned HTTP $($init.Status) (expected HTTP 200 with a protocol version)." }
    Pass "$Persona initialize on the part B MCP server succeeds; negotiated protocol $version (expected HTTP 200)."
    $session = "$($init.Headers['Mcp-Session-Id'])"
    if ($session) { $authorized['Mcp-Session-Id'] = $session }
    $authorized['MCP-Protocol-Version'] = $version
    $null = Invoke-Mcp $endpoint @{ jsonrpc = '2.0'; method = 'notifications/initialized' } $authorized

    $list = Invoke-Mcp $endpoint @{ jsonrpc = '2.0'; id = 2; method = 'tools/list'; params = @{} } $authorized
    $names = @($list.Payload?.result?.tools | ForEach-Object { $_.name } | Sort-Object)
    if ($list.Status -ne 200 -or ($names -join ',') -ne ($expectedTools -join ',')) {
        Fail "$Persona tools/list returned HTTP $($list.Status) and $($names.Count) tool(s) (expected HTTP 200 with exactly list_tickets and get_ticket)."
    }
    Pass "$Persona tools/list returns exactly list_tickets and get_ticket, one tool per exposed REST operation (expected HTTP 200)."

    $all = Invoke-Mcp $endpoint @{ jsonrpc = '2.0'; id = 3; method = 'tools/call'; params = @{ name = 'list_tickets'; arguments = @{} } } $authorized
    $ids = @([regex]::Matches((Get-ToolText $all.Payload?.result), 'CT-\d{4}') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    if ($all.Status -ne 200 -or $null -eq $all.Payload?.result -or (Test-ToolError $all.Payload.result) -or $ids.Count -ne 3) {
        Fail "$Persona list_tickets returned HTTP $($all.Status), a tool error or $($ids.Count) ticket(s) (expected HTTP 200, isError false, 3 synthetic tickets)."
    }
    Pass "$Persona list_tickets returns the 3 synthetic Contoso tickets, isError false (expected HTTP 200)."

    $one = Invoke-Mcp $endpoint @{ jsonrpc = '2.0'; id = 4; method = 'tools/call'; params = @{ name = 'get_ticket'; arguments = @{ ticketId = 'CT-1001' } } } $authorized
    if ($one.Status -ne 200 -or $null -eq $one.Payload?.result -or (Test-ToolError $one.Payload.result) -or (Get-ToolText $one.Payload.result) -notmatch 'CT-1001') {
        Fail "$Persona get_ticket CT-1001 returned HTTP $($one.Status) or a tool error (expected HTTP 200, isError false, ticket CT-1001)."
    }
    Pass "$Persona get_ticket CT-1001 returns the synthetic ticket, isError false (expected HTTP 200)."
    Write-Output "PASS module 04 part B persona checks complete for $Persona."
}
finally {
    $token = $null; $other = $null; $authorized = $null
}
