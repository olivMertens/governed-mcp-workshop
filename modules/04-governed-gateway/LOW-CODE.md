# 04 — One governed gateway: portal-first low-code

[Français](LOW-CODE.fr.md)

## Goal

[Terraform + PowerShell guide](README.md)

Make Azure API Management (APIM) the only public entry point to the Model Context Protocol (MCP) server. Alice can write; Bob can read but cannot write; Eve cannot get a token. This separated guide has not been live-validated end to end.

## Why it matters

Authentication is not authorization. The gateway checks the tenant, audience, scope and app role, then limits calls by caller Object ID. A private endpoint prevents bypass through the Function's public address. The client's MCP token is validated at both gateway and Function for the same MCP audience; it is never reused for Graph or Storage downstream.

> [!IMPORTANT]
> Publish the code and prove private gateway routing before disabling Function public access. Once locked, deployment endpoints are private too. Do not reopen them to work around a failed check.

## What you deploy

**Standard v2**, one unit (not the AI Gateway tier), outbound virtual-network integration, an APIM subnet and network security group, a Function private endpoint with DNS, a gateway managed identity, payload-free Application Insights diagnostics, MCP server and public protected resource metadata (PRM). MCP management API `2025-09-01-preview` is **Preview**. Optional part B exposes a synthetic REST API as MCP.

**Cost:** Standard v2 is billed while provisioned, including idle time. Private endpoints, DNS and telemetry add charges. Check regional price and quota; obtain approval and clean up the same day.

## Prerequisites and required roles

- [Module 02](../02-open-server/LOW-CODE.md) and [both authentication stages of module 03](../03-entra-authentication/LOW-CODE.md) complete on the low-code resources.
- PowerShell 7.4+, Azure CLI, .NET 10 SDK, VS Code/Copilot. Terminal at repository root.
- Contributor on the workshop group including subnet join permission; constrained, time-bound permission to assign Monitoring Metrics Publisher on the Application Insights component only. No new Entra role.
- `Microsoft.ApiManagement`, `Microsoft.Network`, `Microsoft.Web` providers registered through module 00. **West Europe (`westeurope`)** Standard v2 availability and quota confirmed.
- API **Application (client) ID** from **Entra → App registrations → your workshop API → Overview**; Tenant ID and Subscription ID from portal overviews.
- Alice/Bob/Eve and their module 03 assignments; private Object ID file described under Validate.
- Publish the current server package **before disabling Function public access**. If already private, do not reopen it: use an approved private-network publishing environment and stop until that access is available.

## Steps

### 1. Recreate the terminal context

Replace the three placeholders with portal IDs, not resource names:

```powershell
$tenant = '<tenant-id>'; $sub = '<subscription-id>'; $apiClientId = '<api-application-client-id>'
az login --tenant $tenant
az account set --subscription $sub
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
$id = "$($p.participant_prefix)lc"; $sfx = $p.resource_suffix.Substring(0, 10); $loc = 'westeurope'
$rg = "rg-mcp-$id-$sfx"
if ($p.existing_resource_group_name) { $rg = $p.existing_resource_group_name }
$fn = "func-mcp-$id-$sfx"; $ai = "appi-mcp-$id-$sfx"; $law = "log-mcp-$id-$sfx"; $vn = "vnet-mcp-$id-$sfx"
$apim = "apim-mcp-$id-$sfx"; $gwmi = "id-mcp-$id-$sfx-gateway"; $nsg = "nsg-mcp-$id-$sfx-apim"
$svcId = "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.ApiManagement/service/$apim"
$rg; $fn; $apim; $vn; $gwmi; $nsg
```

> **Expected result** — your existing group/Function/network and new gateway names. Names retain the original `lc` suffix convention; do not use the author's screenshot names.

### 2. Publish before locking the Function

These commands are needed because the portal does not build the .NET project:

```powershell
dotnet publish .\src\FunctionsMcpServer --configuration Release --output .\.workshop\lowcode-publish
if ($LASTEXITCODE) { throw 'Build failed; stop.' }
Compress-Archive -Path .\.workshop\lowcode-publish\* -DestinationPath .\.workshop\lowcode.zip -Force
az functionapp deployment source config-zip -g $rg -n $fn --src .\.workshop\lowcode.zip -o none
if ($LASTEXITCODE) { throw 'Publish failed; do not lock public access.' }
```

> **Expected result** — exit code 0 and five synchronized functions. The package contains module 05's downstream tools, still disabled.

### 3. Prepare the private network and gateway identity in the portal

1. **Virtual networks → `$vn` → IP addresses**: verify address space `10.52.0.0/23`. If module 02 did not need private Storage and the network does not exist, **Create** it in your group/West Europe with this address space, remove the default subnet and add `snet-private-endpoints`, `10.52.1.0/27`, no delegation.
2. **Network security groups → Create**: `$nsg`, same group/region. **Outbound security rules → Add**: source **VirtualNetwork**, source ports `*`, destination **Service Tag → AzureKeyVault**, destination port **443**, protocol **TCP**, action **Allow**, priority **100**, name `AllowKeyVaultOutbound`.
3. Network `$vn` → **Subnets → + Subnet**: `snet-apim`, `10.52.0.0/24`, delegation **Microsoft.Web/serverFarms**, security group `$nsg`. Do not reuse the Function or private-endpoint subnet.
4. Function `$fn` → **Networking → Private endpoints → + Add**: name `pe-<your-function-name>`, same group/region, subresource **sites**, network `$vn`, subnet `snet-private-endpoints`, private DNS integration **Yes**, zone `privatelink.azurewebsites.net`. Create; verify **Approved**.
5. **Private DNS zones → privatelink.azurewebsites.net → Virtual network links**: verify `$vn` is linked, auto-registration off. **Recordsets** must include the Function and its `scm` hostname pointing to the private endpoint.
6. **Managed Identities → Create**: `$gwmi`, same group/region. Application Insights `$ai` → **Access control (IAM) → Add role assignment → Monitoring Metrics Publisher → Managed identity**: choose `$gwmi`, **Review + assign**, scoped only to this component.
7. Apply `workshop=governed-mcp`, `owner`, `expiry` from the participant file and `track=low-code` to new resources.

### 4. Create Standard v2 and integrate its outbound network

1. **API Management services → Create**: subscription/group, name `$apim`, region **West Europe**, organization `Governed MCP workshop`, your approved administrator contact, tier **Standard v2**, capacity **1**. Do not select AI Gateway (Preview).
2. **Managed identity → User assigned**: select `$gwmi` (if not exposed in the wizard, add it on the service's **Managed identities → User assigned → Add** after creation).
3. Create, then wait for **Overview → Status = Online** / provisioning **Succeeded**. Creation can take several minutes.
4. Service → **Deployment + infrastructure → Network → Outbound traffic → Virtual network integration**: choose `$vn` and `snet-apim`, **Apply**. Keep the gateway's public inbound endpoint enabled. Wait for the update to succeed.
5. Verify the displayed gateway URL is `https://<your-apim-name>.azure-api.net`. The Function public network must still be enabled at this stage.

### 5. Apply exact diagnostics, MCP backend and policies

In the portal, inspect **APIs → MCP Servers → + Create MCP server → Expose an existing MCP server**: the source is your Function, transport **Streamable HTTP**, base URL `https://<function-name>.azurewebsites.net/runtime/webhooks`, suffix `workshop-mcp`. The following terminal block applies the exact existing Preview schema, backend binding, policy and public metadata together. It is necessary here to avoid a portal-created API with **Source: API** and an empty tool list, and to set managed-identity diagnostics with zero payload bytes. Do not create a second server with a different name.

The helper writes only non-secret configuration and XML responses under ignored `.workshop`, then deletes its working files. It fails on a nonzero CLI exit:

```powershell
function Put([string]$Path, $Body) {
    $f = Join-Path $PWD '.workshop\lowcode-apim-request.json'
    $reply = "$f.reply"
    [IO.File]::WriteAllText($f, ($Body | ConvertTo-Json -Depth 12 -Compress))
    try {
        az rest --method put --url "https://management.azure.com$svcId/$Path`?api-version=2025-09-01-preview" `
            --body "@$f" --headers 'Content-Type=application/json' --output-file $reply
        if ($LASTEXITCODE) { throw "PUT $Path failed; stop before locking the Function." }
    } finally { Remove-Item $f, $reply -ErrorAction SilentlyContinue }
}
& .\modules\04-governed-gateway\render-policies.ps1 -TenantId $tenant -ApiClientId $apiClientId -GatewayName $apim
$aiInfo = az monitor app-insights component show -g $rg -a $ai --query "{id:id,cs:connectionString}" -o json | ConvertFrom-Json
$gwCid = az identity show -g $rg -n $gwmi --query clientId -o tsv
Put 'loggers/appinsights' @{ properties = @{ loggerType = 'applicationInsights'; resourceId = $aiInfo.id; isBuffered = $true
    credentials = @{ connectionString = $aiInfo.cs; identityClientId = $gwCid } } }
$zero = @{ request = @{ headers = @(); body = @{ bytes = 0 } }; response = @{ headers = @(); body = @{ bytes = 0 } } }
$diag = @{ properties = @{ loggerId = '/loggers/appinsights'; alwaysLog = 'allErrors'; httpCorrelationProtocol = 'W3C'; logClientIp = $false
    verbosity = 'information'; metrics = $true; operationNameFormat = 'Name'; sampling = @{ samplingType = 'fixed'; percentage = 100 }; frontend = $zero; backend = $zero } }
Put 'diagnostics/applicationinsights' $diag
Put 'backends/workshop-mcp-function' @{ properties = @{ description = 'Workshop MCP server on Azure Functions (private endpoint).'
    url = "https://$fn.azurewebsites.net/runtime/webhooks"; protocol = 'http' } }
Put 'apis/workshop-mcp' @{ properties = @{ type = 'mcp'; displayName = 'Workshop MCP server (governed)'; path = 'workshop-mcp'; protocols = @('https')
    serviceUrl = "https://$fn.azurewebsites.net/runtime/webhooks"; backendId = 'workshop-mcp-function'; subscriptionRequired = $false
    mcpProperties = @{ transportType = 'streamable'; endpoints = @{ message = @{ uriTemplate = '/mcp' } } } } }
Put 'apis/workshop-mcp/policies/policy' @{ properties = @{ format = 'rawxml'; value = [IO.File]::ReadAllText("$PWD\.workshop\policy-mcp-server.xml") } }
Put 'apis/workshop-mcp/diagnostics/applicationinsights' $diag
Put 'apis/workshop-mcp-prm' @{ properties = @{ displayName = 'Workshop MCP protected resource metadata'; path = '.well-known/oauth-protected-resource'
    protocols = @('https'); subscriptionRequired = $false } }
Put 'apis/workshop-mcp-prm/operations/get-mcp-metadata' @{ properties = @{ displayName = 'Protected Resource Metadata'; method = 'GET'; urlTemplate = '/workshop-mcp/mcp' } }
Put 'apis/workshop-mcp-prm/operations/get-mcp-metadata/policies/policy' @{ properties = @{ format = 'rawxml'; value = [IO.File]::ReadAllText("$PWD\.workshop\policy-prm.xml") } }
$gw = "https://$apim.azure-api.net"
```

> **Expected result** — five policy files rendered, then successful writes. **MCP Servers → workshop-mcp** must show **Source: MCP server**, not **API**. **Policies** must include token validation, `Tools.Write` for `create_ticket`, and per-caller rate limit (30 calls/60 s). No subscription key. **All APIs → Settings → Diagnostics** and **workshop-mcp → Settings → Diagnostics**: frontend/backend request/response body **0**, no logged headers. Do not raise body logging to debug.

![Real MCP server list](../../assets/screenshots/azure-04-mcp-servers.png)

*Illustrative real capture on the author's resources. Verify your own gateway and workshop-mcp Source = MCP server. The second Source = API entry exists only if you do optional part B.*

### 6. Prove gateway routing, then disable Function public access

First create/check `.workshop/module03-personas.json` in VS Code with the exact Entra user Object IDs: `{"alice":"<alice-object-id>","bob":"<bob-object-id>","eve":"<eve-object-id>"}`. Sign in as **Alice**, not your operator, to prove five tools and a working backend before closing the direct address:

```powershell
$v = @{ TenantId = $tenant; ResourceGroup = $rg; FunctionApp = $fn; GatewayName = $apim; ApiClientId = $apiClientId
    PersonaObjectIdsPath = '.\.workshop\module03-personas.json'; SkipBuild = $true }
$operatorConfig = $env:AZURE_CONFIG_DIR
try {
    $env:AZURE_CONFIG_DIR = Join-Path $PWD '.workshop\az-alice'
    az login --tenant $tenant --allow-no-subscriptions
    if ($LASTEXITCODE) { throw 'Alice login failed; do not lock the Function.' }
    & .\modules\04-governed-gateway\validate.ps1 @v -Persona Alice
    az logout
} finally {
    if ($null -eq $operatorConfig) { Remove-Item Env:\AZURE_CONFIG_DIR -ErrorAction SilentlyContinue }
    else { $env:AZURE_CONFIG_DIR = $operatorConfig }
}
az account set --subscription $sub
```

> **Expected result** — Alice account cross-check, five tools, read 200 and write 200 PASS through APIM. One synthetic ticket is created. Stop if any check fails. The operator profile is restored. The **operator** validator's direct-Function refusal check only passes **after** the lock.

After Alice succeeds, Function → **Networking → Public network access → Disabled → Save**. Keep Entra authentication enabled. Deployment endpoints are now private too. Do not disable public access before package publication, private DNS and gateway routing work.

### 7. Connect VS Code only to the gateway

1. **Ctrl+Shift+P → MCP: Open User Configuration**. Replace the direct Function entry and any key input with:

```json
{
  "servers": {
    "workshop-governed": { "type": "http", "url": "https://<your-apim-name>.azure-api.net/workshop-mcp/mcp" }
  }
}
```

2. Replace the placeholder with `$apim`; **Start → Allow** Microsoft sign-in, select Alice. **Chat → Agent → Configure Tools**: only `workshop-governed`.
3. Ask: `Call create_ticket with service "ticket-queue", severity "medium", summary "Synthetic Contoso ticket".` Read and approve the write **once**. Expected: success.
4. **Profiles: New Profile...** for Bob, repeat configuration and sign in as Bob. Same write: **403**, read `get_service_health` with `service "workshop-api"`: **200**. Eve in a separate profile: `AADSTS50105`.

## What you should see

Gateway no token/wrong audience **401**, public metadata **200**, direct Function **403** after lock, Alice write **200**, Bob write **403**, Bob burst **429**, Eve token refusal **400/AADSTS50105**. Diagnostics: zero body bytes and no headers at both scopes. No exact request counts are promised.

## Validate

In VS Code, ensure `.workshop/module03-personas.json` contains `{"alice":"<alice-object-id>","bob":"<bob-object-id>","eve":"<eve-object-id>"}` using **Entra → Users → each test account → Overview → Object ID**. This file is private and ignored; no passwords/tokens.

Set parameters once in this module's operator terminal:

```powershell
$v = @{ TenantId = $tenant; ResourceGroup = $rg; FunctionApp = $fn; GatewayName = $apim; ApiClientId = $apiClientId
    PersonaObjectIdsPath = '.\.workshop\module03-personas.json'; SkipBuild = $true }
```

> **Expected result** — no output; parameters identify your portal-created resources without state.

After step 6's lock, run operator checks, then all personas:

```powershell
& .\modules\04-governed-gateway\validate.ps1 @v -SubscriptionId $sub -LogAnalyticsWorkspace $law
$operatorConfig = $env:AZURE_CONFIG_DIR
try {
    foreach ($persona in 'Alice', 'Bob', 'Eve') {
        Write-Host "Sign in as $persona"
        $env:AZURE_CONFIG_DIR = Join-Path $PWD ".workshop\az-$($persona.ToLower())"
        az login --tenant $tenant --allow-no-subscriptions
        if ($LASTEXITCODE) { throw "Login failed for $persona" }
        & .\modules\04-governed-gateway\validate.ps1 @v -Persona $persona -Burst:($persona -eq 'Bob')
        az logout
    }
} finally {
    if ($null -eq $operatorConfig) { Remove-Item Env:\AZURE_CONFIG_DIR -ErrorAction SilentlyContinue }
    else { $env:AZURE_CONFIG_DIR = $operatorConfig }
}
az account set --subscription $sub
Start-Sleep -Seconds 300
& .\modules\04-governed-gateway\validate.ps1 @v -SubscriptionId $sub -LogAnalyticsWorkspace $law -CheckTelemetry
```

> **Expected result** — PASS for all statuses above, account/Object ID cross-checks and payload-free tool telemetry. At each browser prompt choose the named account and complete its MFA. `-SkipBuild` skips Terraform mock/build checks only. Alice creates a synthetic ticket; Bob sends 40 calls. The operator profile is restored before telemetry.

![Real Bob validation capture](../../assets/screenshots/terminal-04-bob.png)

*Illustrative existing real capture, not evidence of this guide's execution. Check your own PASS lines for read 200, write 403 and burst 429.*

### 8. Optional part B — REST API exposed as MCP (Preview)

This is separate from the required five-tool server. Finish steps 1–7 first; it reuses this module's terminal, policies and `Put` helper. It creates a mocked REST API with three synthetic tickets, two MCP tools and its own public metadata.

1. Portal **APIM → APIs → + Add API → HTTP**: display name `Contoso Tickets REST API (synthetic, mocked)`, name `contoso-tickets-api`, suffix `contoso-tickets`, web service URL `https://contoso-tickets.invalid`, HTTPS. In **Settings**, subscription required **Off**.
2. **Design → + Add operation**: ID `list-tickets`, GET `/tickets`; add a **200** response, representation **application/json**, example:

```json
[
  {"id":"CT-1001","title":"VPN gateway reports intermittent timeouts","severity":"high","status":"open","service":"network"},
  {"id":"CT-1002","title":"Shared drive close to its quota","severity":"medium","status":"in-progress","service":"storage"},
  {"id":"CT-1003","title":"Expense app slow at month end","severity":"low","status":"resolved","service":"expense-app"}
]
```

3. Add operation ID `get-ticket`, GET `/tickets/{ticketId}`. Template parameter `ticketId`: required string. Response **200/application/json**: copy the **first object only**, not the array. Save both. **All operations → Inbound processing → Code editor**: paste `.workshop/policy-rest-api.xml`; **Save**. It authenticates before returning the mock; the `.invalid` backend is never called.
4. **MCP Servers → + Create MCP server → Expose an API as an MCP server**: API above, select both operations, name/suffix `contoso-tickets-mcp`. Tool names must be exactly `list_tickets` and `get_ticket`. Set `ticketId` description to `Ticket ID, for example CT-1001.` Apply the exact tool mapping and metadata with the existing management API to avoid portal-generated names:

```powershell
Put 'apis/contoso-tickets-mcp' @{ properties = @{ type = 'mcp'; displayName = 'Contoso Tickets (REST API exposed as MCP)'; path = 'contoso-tickets-mcp'
    protocols = @('https'); subscriptionRequired = $false } }
foreach ($m in @(@('list_tickets', 'list-tickets'), @('get_ticket', 'get-ticket'))) {
    Put "apis/contoso-tickets-mcp/tools/$($m[0])" @{ properties = @{ displayName = $m[0]; description = 'Read synthetic Contoso tickets.'
        operationId = "$svcId/apis/contoso-tickets-api/operations/$($m[1])" } }
}
Put 'apis/contoso-tickets-mcp/policies/policy' @{ properties = @{ format = 'rawxml'; value = [IO.File]::ReadAllText("$PWD\.workshop\policy-rest-mcp-server.xml") } }
Put 'apis/contoso-tickets-mcp/diagnostics/applicationinsights' $diag
Put 'apis/workshop-mcp-prm/operations/get-tickets-metadata' @{ properties = @{ displayName = 'Tickets MCP metadata'; method = 'GET'; urlTemplate = '/contoso-tickets-mcp/mcp' } }
Put 'apis/workshop-mcp-prm/operations/get-tickets-metadata/policies/policy' @{ properties = @{ format = 'rawxml'; value = [IO.File]::ReadAllText("$PWD\.workshop\policy-rest-prm.xml") } }
$b = @{ TenantId = $tenant; ResourceGroup = $rg; GatewayName = $apim; ApiClientId = $apiClientId
    PersonaObjectIdsPath = '.\.workshop\module03-personas.json'; SkipBuild = $true }
& .\modules\04-governed-gateway\validate-rest-mcp.ps1 @b -SubscriptionId $sub
```

> **Expected result** — operator PASS: MCP/REST without token 401, wrong audience 401, metadata 200, two operation mappings and zero-byte diagnostics.

5. Verify **Tools** contains exactly two tools; remove any extra portal-generated tool entries before persona validation. Run both accounts:

```powershell
$operatorConfig = $env:AZURE_CONFIG_DIR
try {
    foreach ($persona in 'Alice', 'Bob') {
        Write-Host "Sign in as $persona"
        $env:AZURE_CONFIG_DIR = Join-Path $PWD ".workshop\az-$($persona.ToLower())"
        az login --tenant $tenant --allow-no-subscriptions
        if ($LASTEXITCODE) { throw "Login failed for $persona" }
        & .\modules\04-governed-gateway\validate-rest-mcp.ps1 @b -Persona $persona
        az logout
    }
} finally {
    if ($null -eq $operatorConfig) { Remove-Item Env:\AZURE_CONFIG_DIR -ErrorAction SilentlyContinue }
    else { $env:AZURE_CONFIG_DIR = $operatorConfig }
}
az account set --subscription $sub
```

> **Expected result** — each selected account matches its private Object ID; exactly two tools, list of three tickets and CT-1001 read all PASS with HTTP 200; operator profile restored.

6. In VS Code add server `contoso-tickets`, type `http`, URL `https://<your-apim-name>.azure-api.net/contoso-tickets-mcp/mcp`; start, authenticate as Alice/Bob and ask `List tickets, then get ticket CT-1001`. Expected: exactly `list_tickets` and `get_ticket`, three tickets, then CT-1001. REST without a token **401**, wrong audience **401**, PRM **200**, valid MCP calls **200**. No write tool.

![Real REST MCP tools capture](../../assets/screenshots/azure-04b-mcp-tools.png)

*Illustrative real capture; gateway names differ. Verify your server's two selected operations. Source is API for part B, unlike part A.*

## Troubleshooting

- **Policy inputs refused:** use 5–1,000 calls per 10–300 seconds. The 300-second ceiling is an API Management limit.
  The workshop also limits the optional IP allow-list to 10 canonical IPv4 CIDR ranges from `/8` to `/32`.
  An empty list omits the IP filter; tenant, audience, client and role checks remain active. Empty GUIDs and an empty
  client allow-list are refused. Rate limiting is approximate and v2 gateways use a token bucket, not a precise request counter.
- **Empty tools/list:** verify part A Source **MCP server**, backend `workshop-mcp-function` and `backendId`; do not turn it into REST operation mapping.
- **502/backend unreachable:** verify APIM outbound integration, subnet delegation/security group, private-endpoint approval and DNS links/records. Do not reopen the Function.
- **401:** verify tenant, audience, allowed client and PRM gateway URL. No subscription key or token in a URL.
- **Bob write 200:** stop; inspect the generated role policy. Never treat this as a successful exercise.
- **Telemetry missing:** wait for ingestion, confirm the gateway identity's component-scoped role and both diagnostics. Never enable body/header capture.

## Clean up

Retain resources only to continue immediately to [module 05 low-code](../05-delegated-and-app-only/LOW-CODE.md). Otherwise use [module 99 low-code cleanup](../99-cleanup/LOW-CODE.md), review tags/ownership before approved deletion, and purge only your soft-deleted APIM instance if the name must be released. Delete only workshop-owned resources, never a supplied group or users. No Terraform cleanup. Remove gateway and optional REST entries from VS Code.

## Go further

**Question:** Bob's write is refused by APIM, but he can still call the Function directly. Is the gateway the only entry point?

<details>
<summary>Show answer</summary>

No. The direct path bypasses gateway policy. The exercise is complete only when the public Function address is refused and valid calls still work through APIM over the private endpoint.

</details>

Compare a gateway role refusal (HTTP 403) with module 05's downstream refusal inside an HTTP 200 MCP response.

## Sources

- [Expose an existing MCP server](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server).
- [Secure MCP servers](https://learn.microsoft.com/azure/api-management/secure-mcp-servers).
- [MCP overview and limitations](https://learn.microsoft.com/azure/api-management/mcp-server-overview).
- [MCP management API (Preview)](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api).
- [Entra token policy](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy).
- [REST API as MCP](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server).
- [Official AI Gateway labs](https://github.com/Azure-Samples/AI-Gateway).
- [Rate-limit-by-key limits and v2 behavior](https://learn.microsoft.com/azure/api-management/rate-limit-by-key-policy).
- [IP filter policy](https://learn.microsoft.com/azure/api-management/ip-filter-policy).

Last verified: 2026-10-21 (policy limits checked against Microsoft Learn and tested offline; this separated guide not live-validated).
