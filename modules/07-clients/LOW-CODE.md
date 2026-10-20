# 07 — Optional clients: portal-first low-code

[Français](LOW-CODE.fr.md)

## Goal

Part A is an optional Microsoft Foundry exercise using the governed Model Context Protocol (MCP) gateway.
Part B is a **reading-only** Copilot Studio outline, **not live-validated**.
Complete [module 06 low-code](../06-observe-inventory/LOW-CODE.md) first.

This separated composition has not been revalidated live. The original Foundry flow was tested by the author on
2026-10-20; the dated captures below are real examples, not proof for your subscription. Some show author names from
the other track. Use your own `lc` resource names.

## Why it matters

Changing the client must not change authorization. Each user signs in with OAuth. The gateway checks the MCP audience,
delegated scope and app role. A project managed identity is app-only and cannot act as Alice for On-Behalf-Of (OBO)
tools. Never forward the MCP token to a downstream API.

Approval and authorization differ: Bob can approve a write, but the gateway still refuses it without `Tools.Write`.
Log metadata only: no tokens, prompts, arguments or results.

> [!IMPORTANT]
> Human approval never replaces the gateway's app-role check. Keep both controls in place.

**Question:** Bob approves `create_ticket` in Foundry. Does that give him permission to write?

<details>
<summary>Show answer</summary>

No. Approval confirms his intent; it adds no role to his token. The gateway still refuses the write with HTTP 403
because Bob does not have `Tools.Write`.

</details>

## What you deploy

Part A is optional and billed. Obtain explicit approval for its changes and cost; clean up the same day.

| Item | Boundary |
|---|---|
| Foundry project and `gpt-4.1-mini` model deployment | A **separate** `rg-<name>` group created by the Azure Developer CLI (`azd`) template |
| Dedicated Foundry OAuth client and service principal | Microsoft Entra ID |
| Client pre-authorization and allowed-client entries | Existing MCP API, Function authentication and gateway policies |
| One-day client secret, handed to Foundry only | Existing dedicated-client approach; never paste it into chat or source control |
| Foundry User assignments for Alice and Bob | Exact Foundry project scope |
| Agent identity blueprint | Created automatically by Foundry; resource-group deletion alone does not remove it |

**Preview:** OAuth Identity Passthrough and the new Foundry portal MCP configuration. Screens may change.
Part B deploys nothing.

## Prerequisites and required roles

- Modules 03–06 low-code deployed in your approved non-production tenant; private `.workshop\participant.tfvars.json`
  and `.workshop\test-users.private.json` retained.
- PowerShell 7.4+, Azure CLI and `azd` 1.34+. No infrastructure-state files are needed.
- Participant: Contributor for the dedicated Foundry deployment; permission to assign **Foundry User** on that project.
- Identity administrator: permission to create/manage the dedicated client, pre-authorize it on the MCP API and delete
  its blueprint at cleanup. Do not grant these roles to Alice or Bob.
- Alice and Bob: existing test accounts with their original MCP app roles. Do not grant Bob `Tools.Write`.

## Steps

### 1. Initialize and discover your existing gateway

Open **Azure portal → Subscriptions** and confirm the approved subscription. Use a participant/admin terminal,
not Alice's or Bob's profile. Run all PowerShell blocks from the repository root in the same session:

```powershell
$ErrorActionPreference = 'Stop'
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
$id = "$($p.participant_prefix)lc"; $sfx = $p.resource_suffix.Substring(0, 10)
$rg = if ($p.existing_resource_group_name) { $p.existing_resource_group_name } else { "rg-mcp-$id-$sfx" }
$fn = "func-mcp-$id-$sfx"; $apim = "apim-mcp-$id-$sfx"
$tenant = az account show --query tenantId -o tsv
$sub = az account show --query id -o tsv
az account show --query '{subscription:name,tenant:tenantId}' -o table
$apps = @(az ad app list --display-name "Workshop MCP API ($id-$sfx)" -o json | ConvertFrom-Json)
if ($apps.Count -ne 1) { throw 'Expected exactly one workshop MCP API. Stop and check names/context.' }
$mcpApp = $apps[0].appId
$scopeId = az ad app show --id $mcpApp --query "api.oauth2PermissionScopes[?value=='user_impersonation'].id | [0]" -o tsv
if (-not $scopeId) { throw 'MCP delegated scope not found.' }
$gateway = az apim show -g $rg -n $apim --query gatewayUrl -o tsv
if (-not $gateway) { throw 'Gateway not found.' }
$mcpEndpoint = "$gateway/workshop-mcp/mcp"
$scopes = "api://$mcpApp/user_impersonation offline_access"
"MCP endpoint: $mcpEndpoint"; "Scopes: $scopes"
```

> **Expected result** — your gateway URL, not a Function URL, and the MCP app's scope.

In **Entra admin center → App registrations →
your Workshop MCP API → Expose an API**, confirm `user_impersonation`.

### 2. Create the Foundry project (terminal necessary for the verified template)

The original exercise uses `azd` to initialize and provision a project with the required model. Do not substitute an
unverified portal deployment. The template was verified at commit `5bf59a056c41ff37801dea334ba6a141e2dc5f67` (MIT).
The command below uses its published template URL, as in the original exercise.

```powershell
$name = "mcp07-$id-$sfx"
$dir = Join-Path $PWD ".workshop\foundry-07\$name"
New-Item -ItemType Directory -Force $dir | Out-Null
Push-Location $dir
try {
    $env:AZURE_DEV_USER_AGENT = 'microsoft_foundry_skill'
    azd init -t https://github.com/Azure-Samples/azd-ai-starter-basic -e $name --no-prompt
    azd env set AZURE_LOCATION swedencentral
    azd env set AZURE_SUBSCRIPTION_ID $sub
    azd env set ENABLE_HOSTED_AGENTS false
    azd env set ENABLE_CAPABILITY_HOST false
    azd env set AI_PROJECT_DEPLOYMENTS '[{\"name\":\"gpt-4.1-mini\",\"model\":{\"name\":\"gpt-4.1-mini\",\"format\":\"OpenAI\",\"version\":\"2025-04-14\"},\"sku\":{\"name\":\"GlobalStandard\",\"capacity\":20}}]'
    azd provision --no-prompt
    if ($LASTEXITCODE -ne 0) { throw 'Foundry provision failed. Inspect the dedicated group before retrying.' }
    $endpoint = azd env get-value AZURE_AI_PROJECT_ENDPOINT
} finally { Pop-Location }
az group update -n "rg-$name" --tags workshop=governed-mcp owner=$($p.owner) expiry=$($p.expiry) module=07 -o none
```

> **Expected result** — project and model provisioning succeed, about four minutes in the original run (not a timing guarantee).

Keep the escaped quotes in the model JSON. In **Azure portal → Resource groups → rg-<name>**, confirm the Foundry
account, project and `module=07` tag. This is **not** the workload group.

### 3. Create the dedicated OAuth client (identity administrator)

The script avoids exposing a secret. It creates only the dedicated client and writes its cleanup IDs privately.
Run once; if interrupted, inspect **App registrations** before retrying to avoid duplicate clients.

```powershell
if (Test-Path .\.workshop\module07.private.json) { throw 'Client record already exists. Inspect it before continuing.' }
$f = Join-Path $PWD '.workshop\foundry-client-request.json'
try {
    @{ resourceAppId = $mcpApp; resourceAccess = @(@{ id = $scopeId; type = 'Scope' }) } |
        ConvertTo-Json -Depth 5 -AsArray | Set-Content $f
    $app = az ad app create --display-name "workshop-mcp-foundry-client-$id-$sfx" --sign-in-audience AzureADMyOrg `
        --required-resource-accesses "@$f" --query '{appId:appId,id:id}' -o json | ConvertFrom-Json
    if (-not $app.appId) { throw 'Client creation failed.' }
    @{ foundry_client_app_id = $app.appId; foundry_client_object_id = $app.id; foundry_resource_group = "rg-$name" } |
        ConvertTo-Json | Set-Content .\.workshop\module07.private.json
    az ad sp create --id $app.appId -o none
    if ($LASTEXITCODE -ne 0) { throw 'Service principal creation failed. Keep the private cleanup record.' }
} finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
```

> **Expected result** — one dedicated client and service principal; the private file contains IDs and a group name, **no secret**.

### 4. Add the client to all three gates

**Identity administrator, portal:** **Entra → App registrations → Workshop MCP API → Expose an API →
Authorized client applications → Add a client application**. Enter `$app.appId`, select `user_impersonation`,
then **Add application**. Preserve Visual Studio Code and Azure CLI.

**Participant, portal:** **Function App → your `$fn` → Settings → Authentication → Microsoft → Edit →
Allowed client applications**. Add `$app.appId` without removing the existing applications; **Save**.
Read the resulting list to render matching gateway policies:

```powershell
$authUrl = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Web/sites/$fn/config/authsettingsV2?api-version=2024-04-01"
$auth = az rest --url $authUrl -o json | ConvertFrom-Json
$ids = @($auth.properties.identityProviders.azureActiveDirectory.validation.defaultAuthorizationPolicy.allowedApplications)
if ($ids -notcontains $app.appId) { throw 'Client missing from Function authentication. Finish the portal edit first.' }
& .\modules\04-governed-gateway\render-policies.ps1 -TenantId $tenant -ApiClientId $mcpApp -GatewayName $apim -AllowedClientIds $ids
```

> **Expected result** — policy XML files in `.workshop`; the client is in the Function allowlist. No policy is deployed by rendering.

In **API Management → your instance → APIs**, paste the complete generated XML at **All operations → Policies →
Code editor**, then **Save**, for each API you actually deployed:

| API | File to open locally |
|---|---|
| `workshop-mcp` | `.workshop\policy-mcp-server.xml` |
| `contoso-tickets-api` (if deployed) | `.workshop\policy-rest-api.xml` |
| `contoso-tickets-mcp` (if deployed) | `.workshop\policy-rest-mcp-server.xml` |

Expected: each policy still checks issuer, audience, scope and roles; the new client is added, not a replacement for
existing IDs. Never remove validation to bypass a refusal.
The renderer uses the module 04 defaults (30 calls per 60 seconds, no optional IP filter). If you changed those controls,
pass your original `-RateLimitCalls`, `-RateLimitPeriod` and `-AllowedIpRanges` values to the renderer before pasting.
Compare the existing policy first; stop if the original settings are unknown rather than widening access.

### 5. Connect the MCP tool in Foundry (Preview)

Open [Foundry](https://ai.azure.com/nextgen), select your project, then **Build → Tools → Connect a tool → Custom →
Model Context Protocol (MCP) → Create**:

| Field | Value from this module |
|---|---|
| Name | `workshop-governed` |
| Remote MCP Server endpoint | `$mcpEndpoint` printed in step 1 |
| Authentication | **OAuth Identity Passthrough** |
| Client ID | `$app.appId` (also in `.workshop\module07.private.json`) |
| Client secret | Leave empty until step 6 hands it directly to the connection |
| Token URL and Refresh URL | `https://login.microsoftonline.com/<your-tenant-id>/oauth2/v2.0/token` |
| Auth URL | `https://login.microsoftonline.com/<your-tenant-id>/oauth2/v2.0/authorize` |
| Scopes | `$scopes` printed in step 1 |

Replace `<your-tenant-id>` with `$tenant`. Select **Connect** and copy only the **Redirect URL** shown by Foundry.
Select **Use in an agent**, name it `workshop-mcp-agent`, remove **Web search** if present, and **Save**.

![Real author capture: MCP connection fields in Foundry](../../assets/screenshots/azure-07-foundry-tool.png)

*Illustrative real capture, 2026-10-20. Check frame 1 is your gateway URL, frame 2 is OAuth Identity Passthrough,
and frame 3 is the redirect URL you register. Author names and replaced IDs are not values to copy.*

### 6. Register the redirect and hand Foundry the one-day secret

Identity administrator: paste the complete block, replacing only the redirect placeholder with step 5's URL.
Do not print `$secret`, enable terminal transcripts, or save secret-bearing output. This is the existing dedicated,
one-day confidential-client handoff, not permission for reusable secrets. It uses an ignored transient request file,
removed in `finally`; it is not literally a memory-only transfer.

```powershell
$redirect = '<redirect-url-from-step-5>'
$s = Get-Content .\.workshop\module07.private.json -Raw | ConvertFrom-Json
$f = Join-Path $PWD '.workshop\foundry-connection.private.json'
try {
    @{ web = @{ redirectUris = @($redirect) } } | ConvertTo-Json -Depth 4 | Set-Content $f
    az rest --method patch --url "https://graph.microsoft.com/v1.0/applications/$($s.foundry_client_object_id)" --body "@$f" --headers 'Content-Type=application/json'
    if ($LASTEXITCODE -ne 0) { throw 'Redirect update failed.' }
    $end = (Get-Date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $secret = az ad app credential reset --id $s.foundry_client_app_id --append --display-name 'foundry-module07-short-lived' --end-date $end --query password -o tsv --only-show-errors
    if (-not $secret) { throw 'Secret creation failed.' }
    $proj = az resource list -g $s.foundry_resource_group --resource-type Microsoft.CognitiveServices/accounts/projects --query '[0].id' -o tsv
    $url = "https://management.azure.com$proj/connections/workshop-governed?api-version=2025-06-01"
    $c = (az rest --url $url -o json | ConvertFrom-Json).properties
    $body = @{ properties = @{ authType = 'OAuth2'; category = $c.category; group = $c.group; target = $c.target; authorizationUrl = $c.authorizationUrl
        tokenUrl = $c.tokenUrl; refreshUrl = $c.refreshUrl; scopes = $c.scopes; connectorName = $c.connectorName
        isSharedToAll = $false; metadata = $c.metadata; credentials = @{ clientId = $s.foundry_client_app_id; clientSecret = $secret } } }
    [IO.File]::WriteAllText($f, ($body | ConvertTo-Json -Depth 6 -Compress))
    az rest --method put --url $url --body "@$f" --headers 'Content-Type=application/json' -o none
    if ($LASTEXITCODE -ne 0) { throw 'Connection update failed. Clean up the dedicated client before retrying.' }
} finally { Remove-Item $f -Force -ErrorAction SilentlyContinue; $secret = $null; $body = $null }
```

> **Expected result** — no secret printed; the connection update returns no output.

In **Entra → dedicated client → Certificates & secrets**, check the description
`foundry-module07-short-lived` and one-day expiry, not its value. Original author test: a public client signed Alice in,
but Foundry could not redeem the code; a one-day confidential client worked. Do not switch to anonymous/API-key auth.

### 7. Give test users project access, then test in the portal

Participant/admin: **Azure portal → Foundry project → Access control (IAM) → Add role assignment → Foundry User →
Members → Select members**. Select only Alice and Bob using `.workshop\test-users.private.json`; **Review + assign**.
Scope is this project, not the subscription. Wait two to three minutes for propagation.
The original direct-project test needed **Foundry User**; **Foundry Agent Consumer** returned HTTP 403.

Alice: open a separate browser profile, sign in as Alice, open your project → **Build → Agents → workshop-mcp-agent →
Playground**. Enter:

```prompt
Use the workshop MCP tool to call get_service_health with service "workshop-api". Summarise the result. Do not call any write tool.
```

Open **your own** consent link if prompted, select **Allow access**, sign in as Alice, then retry the prompt.
Inspect the tool and select **Approve once**. Expected: synthetic `healthy` response.

Bob: in a different browser profile signed in as Bob, use the same playground and enter:

```prompt
Use the workshop MCP tool. Call create_ticket with service "ticket-queue", severity "medium" and summary "Synthetic ticket - Contoso workshop". Show the tool result, or the exact error if the call is refused.
```

Bob opens only his own consent link and approves his own write attempt. Expected: gateway **HTTP 403**, no ticket created.
Never share consent links: the agent can otherwise act with the wrong person's token.

![Real author capture: Foundry tool approval](../../assets/screenshots/azure-07-foundry-approve.png)

*Illustrative real capture, 2026-10-20. Frame 1 is the pending call, frame 2 **Approve once**, frame 3 the only tool,
your governed gateway. Human approval is not an app role.*

![Real author capture: approved synthetic read result](../../assets/screenshots/azure-07-foundry-result.png)

*Illustrative real capture, 2026-10-20. Check approval, synthetic answer and answering tool. Do not put prompt,
argument or result captures into telemetry. Use only synthetic data for any local learning capture.*

### Part B — Copilot Studio overview (reading only, not live-validated)

No action is required. Plan **Agent → Tools → Add a tool → New tool → Model Context Protocol**, a server name,
description and gateway URL. Choose **OAuth 2.0**, not **None** or **API key**. The documented Manual setup requests a
client secret; only the dedicated one-day handoff approach above is acceptable here. Dynamic client registration is
not implemented. Only **Streamable** transport is supported; SSE is no longer supported.
Consult the current source before any separate experiment. This outline is not a claim of working Copilot Studio setup.

## What you should see

- Alice approves and reads synthetic health; Bob's approved write is refused with HTTP 403.
- The gateway remains the only entry point; all three gates include the client ID.
- [Module 06 low-code](../06-observe-inventory/LOW-CODE.md) shows metadata-only calls, with status and duration.

## Validate

PowerShell first; offline checks do not query Azure and do not prove this new composition works live:

```powershell
pwsh .\modules\07-clients\validate.ps1 -Offline
```

> **Expected result** — offline `PASS` lines and exit code 0, not proof of a working live connection.

bash alternative (same offline validator):

```bash
bash ./modules/07-clients/validate.sh --offline
```

> **Expected result** — the same offline `PASS` lines and exit code 0.

Expected: `PASS` lines and exit code 0. This validator checks the original module files, not every low-code portal click.
Live validation is manual: repeat step 7 as the two distinct users, confirm Alice's read and Bob's 403, then use the
module 06 KQL queries. Empty telemetry is not proof of success. Part B has no live validation result.

## Troubleshooting

- **403 enumerating tools:** check all three allowed-client lists and the unchanged `server/discover` policy from module 04.
- **Consent error with successful Entra sign-in:** retry once; Foundry sometimes has stored the token anyway.
- **No client sign-in:** check Web redirect and the dedicated one-day secret. Never bypass authentication.
- **AADSTS50105:** the user lacks an MCP app role. Use Alice/Bob, not the participant administrator.
- **403 before tool call:** check project **Foundry User** assignment and propagation.
- **JSON parse error during provisioning:** retain the escaped quotes in step 2.
- **Portal cannot create the empty-secret connection:** stop before creating another secret. The original portal allowed
  step 5; a changed required-field behavior needs revalidation, not a key or anonymous workaround.

## Clean up

Use a participant/identity-administrator terminal, not Alice/Bob's profile. Initialize context even in a fresh session:

```powershell
$tenant = az account show --query tenantId -o tsv
$sub = az account show --query id -o tsv
az account show --query '{subscription:name,tenant:tenantId}' -o table
pwsh .\modules\07-clients\cleanup.ps1 -TenantId $tenant -SubscriptionId $sub -LowCodeTrack
# After explicit approval and review of every PLAN:
pwsh .\modules\07-clients\cleanup.ps1 -TenantId $tenant -SubscriptionId $sub -LowCodeTrack -Apply
```

> **Expected result** — report first, then deletion of the dedicated client/secret, blueprint, tagged Foundry group and soft-deleted
> Foundry account, with `PASS` lines and final `DONE`.

The script uses `.workshop\module07.private.json`; keep it until successful cleanup.
**Always pass `-LowCodeTrack`: this branch never invokes the infrastructure-state tool.**
It does not remove the now-stale client entries from MCP pre-authorization, Function authentication or gateway policies.
**Continue immediately to [module 99 low-code](../99-cleanup/LOW-CODE.md)** to delete the owned workload/API and those lists.
Do not leave the workload running with a stale-client checklist unfinished. Preserve Alice, Bob and shared resources.

If part A was skipped, no module 07 resources exist. If provisioning stopped before the private record was written,
inspect the dedicated `rg-<name>` in the portal and report its contents; module 99 explains ownership-first deletion.

bash users can invoke PowerShell without omitting the track switch:

```bash
tenant=$(az account show --query tenantId -o tsv); sub=$(az account show --query id -o tsv)
pwsh ./modules/07-clients/cleanup.ps1 -TenantId "$tenant" -SubscriptionId "$sub" -LowCodeTrack
```

> **Expected result** — a report only; no Azure or identity changes.

Add `-Apply` only after approval.

## Go further

Compare published-agent **Foundry Agent Consumer** access with direct project access in a separate approved experiment.
Track Preview changes; never replace delegated context with a project managed identity to make OBO appear to work.

## Sources

- [Foundry MCP authentication](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication).
- [Functions MCP with Foundry](https://learn.microsoft.com/azure/azure-functions/functions-mcp-foundry-tools).
- [azd-ai-starter-basic, MIT, verified commit 5bf59a056c41ff37801dea334ba6a141e2dc5f67](https://github.com/Azure-Samples/azd-ai-starter-basic).
- [Copilot Studio MCP setup](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent).
- [MCP server/discover, specification 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/server/discover).

Last verified: 2026-10-20 (original source review and author flow; separated guide not live-revalidated).
