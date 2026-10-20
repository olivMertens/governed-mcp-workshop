# 07 - Optional: other clients (Microsoft Foundry live, Copilot Studio outline)

[Français](README.fr.md)

## Goal

Call the same governed MCP server from another client: a **Microsoft Foundry agent** (part A, run live) and, as an
outline, **Microsoft Copilot Studio** (part B). The gateway, the app roles and the logs from modules 03 to 06 do not change.

## Why it matters

Governance must hold no matter which client calls the server. Each client has its own way of signing in and of sending the token. The questions to ask are the same every time:

- Which identity is used to call the MCP server (the user, a managed identity, or an agent identity)?
- Which audience does the token have, and is it the MCP server's own audience?
- Is there any token passthrough to a downstream service?

## What you deploy

Part A only (optional, billed). Part B and part C create nothing.

| What | Where | Why |
|---|---|---|
| A Foundry project with a `gpt-4.1-mini` deployment | Its own resource group, from the `azd-ai-starter-basic` template | Hosts the agent |
| A **client app registration** `workshop-mcp-foundry-client-<prefix>` | Microsoft Entra | The OAuth client Foundry signs users in with |
| A **client secret valid for one day** on that client app | Microsoft Entra, handed to Foundry only | Foundry accepts only a confidential client (verified 2026-10-20) |
| The client's pre-authorization for `user_impersonation` | `infra/entra`, private file `.workshop/entra-module07.tfvars.json` | No consent prompt for the MCP scope |
| The client ID in the allowed applications | `infra/workload`, private file `.workshop/module07.tfvars.json` | Gateway policy and Function authentication accept this client |
| **Foundry User** role on the project for each test user | The Foundry project | Each user calls the agent with their own identity |
| An **agent identity blueprint**, created by Foundry for the agent | Microsoft Entra | Created automatically; not removed with the resource group |

> [!NOTE]
> Preview features (label them when you show them):
>
> - **Preview:** OAuth identity passthrough for MCP tools in Microsoft Foundry.
> - **Preview:** the new Foundry portal and its MCP tool configuration.

## Prerequisites and required roles

- Modules 03 to 06 deployed: the gateway URL from module 04 (never the Function URL).
- Contributor on a subscription for the Foundry resource group; Application Administrator (or owner of the client app)
  for the client app registration and its secret; the module 03 identity administrator for `infra/entra`.
- Azure Developer CLI (`azd`) 1.34 or later, and the test accounts Alice and Bob (Eve is refused in module 03 already).

## Steps

### Keep the same authorization boundary





**Build it step by step.** Select **Next** to add one piece at a time; the full diagram follows.

```reveal
{
  "title": "Another client, the same rules",
  "audience": "attendee",
  "width": 760,
  "height": 380,
  "lanes": [
    {"x": 8, "width": 232, "label": "Clients"},
    {"x": 264, "width": 232, "label": "Entra and gateway"},
    {"x": 520, "width": 232, "label": "MCP server"}
  ],
  "nodes": [
    {"id":"vscode","step":0,"tone":"morning","x":30,"y":44,"width":188,"title":"VS Code + Copilot","detail":["modules 03 to 06"]},
    {"id":"apim","step":0,"tone":"governed","x":286,"y":164,"width":188,"icon":"apim","title":"API Management","detail":["same URL","same policies"]},
    {"id":"fn","step":0,"x":542,"y":164,"width":188,"icon":"functions","title":"MCP server","detail":["same tools, roles"]},
    {"id":"entra","step":1,"x":286,"y":44,"width":188,"icon":"entra","title":"Microsoft Entra ID","detail":["new client app","pre-authorized"]},
    {"id":"foundry","step":2,"tone":"preview","x":30,"y":164,"width":188,"icon":"foundry-agent-service","title":"Foundry agent","detail":["Preview","OAuth passthrough"]},
    {"id":"approve","step":3,"tone":"governed","x":286,"y":284,"width":188,"title":"Human approval","detail":["in the Foundry agent","then the role check"]},
    {"id":"studio","step":4,"x":30,"y":284,"width":188,"icon":"copilot-studio","title":"Copilot Studio","detail":["outline only"]}
  ],
  "edges": [
    {"from":"apim","to":"fn","step":0,"tone":"governed","label":"private"},
    {"from":"foundry","to":"entra","step":2,"label":"sign-in"},
    {"from":"foundry","to":"apim","step":2,"tone":"governed","label":"token"},
    {"from":"approve","to":"apim","step":3,"label":"then"},
    {"from":"studio","to":"apim","step":4,"label":""}
  ],
  "steps": [
    {"title": "Same server, same gateway", "simple": "Nothing changes on the server side: the new client uses the same gateway URL.", "say": "The app roles, the rate limit and the logs from modules 03 to 06 apply to every client."},
    {"title": "Register the new client", "simple": "The new client gets its own app registration, allowed in three places.", "say": "Pre-authorized on the API in Entra, allowed by the Function's built-in authentication, and listed in the gateway policies. Missing from one list: refused at that gate."},
    {"title": "The agent acts as the user (Preview)", "simple": "The Foundry agent signs the user in and calls the gateway with that user's token.", "say": "OAuth identity passthrough is **Preview**. The user consents once; never share a consent link."},
    {"title": "A person approves writes", "simple": "Before a write tool runs, a person approves it. The role check still applies after that.", "say": "Approval grants no rights: Bob's approved `create_ticket` still gets HTTP 403 from the gateway."},
    {"title": "Copilot Studio, same rules", "simple": "Copilot Studio would connect to the same URL and meet the same controls.", "say": "Part B is an outline only. The same checklist applies to every client: token audience, app roles, approval, logs."}
  ]
}
```

![Optional clients use the same API Management authorization boundary and private Function.](../../assets/architecture/07.en.svg)

The product changes; the server's authorization does not.

| Hop | Token and check to plan |
|---|---|
| Client to MCP gateway | Token for the MCP audience. Validate issuer, tenant, audience, expiry, scope and role with platform controls |
| Gateway to Function | Same logical MCP resource in this workshop; not an exchange to a downstream audience. Keep Function authentication and private access |
| MCP server to Graph or Storage as user | New token for that API through On-Behalf-Of (OBO); user rights and delegated consent apply |
| MCP server to Storage as app | New Storage token through the managed identity; only the container-scoped application rights apply |
| Local stdio server | No HTTP OAuth token on this transport; process access and operating-system permissions still matter |
| Synthetic calculation inside a tool | No downstream token needed if it makes no downstream call; remote MCP access still requires authentication |

![User-context and application-context tools use different downstream tokens, never the MCP token.](../../assets/architecture/05.en.svg)

> [!IMPORTANT]
> **Compatibility gate:** the gateway requires a delegated scope and the server's OBO tools require a user.
> A Foundry managed identity or agent identity is app-only: assigning an app role alone does **not** make it compatible.
> The working path is **OAuth identity passthrough** (part A): each user signs in, and the token carries their roles.

**Question:** Foundry calls with its managed identity. Can `whoami` act for Alice?

<details>
<summary>Show answer</summary>

No. An application token contains no delegated Alice context. The current gateway refuses this client flow;
OBO tools must also reject app-only callers. Application identity at the client and managed identity for a downstream tool are different choices.

</details>

### Part A — Microsoft Foundry agent with OAuth identity passthrough (Preview)

The author ran every step below on 2026-10-20 in a test tenant. Run them in PowerShell from the repository root, with
`$env:ARM_TENANT_ID` and `$env:ARM_SUBSCRIPTION_ID` set as in module 00.

**A1. Create the Foundry project** (about 4 minutes). The template creates its own resource group `rg-<name>`.

```powershell
$name = 'mcp07-<prefix>'                                  # letters, digits and hyphens
$dir = Join-Path $env:TEMP "foundry-07\$name"; New-Item -ItemType Directory -Force $dir | Out-Null; Push-Location $dir
$env:AZURE_DEV_USER_AGENT = 'microsoft_foundry_skill'
azd init -t https://github.com/Azure-Samples/azd-ai-starter-basic -e $name --no-prompt
azd env set AZURE_LOCATION swedencentral
azd env set AZURE_SUBSCRIPTION_ID $env:ARM_SUBSCRIPTION_ID
azd env set ENABLE_HOSTED_AGENTS false; azd env set ENABLE_CAPABILITY_HOST false
azd env set AI_PROJECT_DEPLOYMENTS '[{\"name\":\"gpt-4.1-mini\",\"model\":{\"name\":\"gpt-4.1-mini\",\"format\":\"OpenAI\",\"version\":\"2025-04-14\"},\"sku\":{\"name\":\"GlobalStandard\",\"capacity\":20}}]'
azd provision --no-prompt
$endpoint = azd env get-value AZURE_AI_PROJECT_ENDPOINT; Pop-Location
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
az group update -n "rg-$name" --tags workshop=governed-mcp owner=$($p.owner) expiry=$($p.expiry) module=07 -o none
```

> **Real result** — 2026-10-20, author's test tenant. Names and IDs withheld.
>
> ```text
>   (✓) Done: Foundry: ai-account-<id> (1m50.42s)
>   (✓) Done: Azure AI Services Model Deployment: ai-account-<id>/gpt-4.1-mini (4.36s)
>   (✓) Done: Foundry project: ai-account-<id>/ai-project-mcp07-p01 (8.454s)
> SUCCESS: Your application was provisioned in Azure in 3 minutes 21 seconds.
> ```
>
> The JSON value needs `\"` around each name: `azd` inserts it inside a JSON string. Without them, `azd provision` stops
> with `invalid character 'n' after object key:value pair`.

**A2. Create the client app registration** (no secret yet) and record its IDs in a private file.

```powershell
$mcpApp = terraform -chdir=infra/entra output -raw application_client_id
$scopeId = az ad app show --id $mcpApp --query "api.oauth2PermissionScopes[?value=='user_impersonation'].id | [0]" -o tsv
$f = New-TemporaryFile
@{ resourceAppId = $mcpApp; resourceAccess = @(@{ id = $scopeId; type = 'Scope' }) } | ConvertTo-Json -Depth 5 -AsArray | Set-Content $f
$app = az ad app create --display-name "workshop-mcp-foundry-client-$($p.participant_prefix)" --sign-in-audience AzureADMyOrg `
    --required-resource-accesses "@$f" --query "{appId:appId,id:id}" -o json | ConvertFrom-Json
Remove-Item $f; az ad sp create --id $app.appId -o none
@{ foundry_client_app_id = $app.appId; foundry_client_object_id = $app.id; foundry_resource_group = "rg-$name" } |
    ConvertTo-Json | Set-Content .\.workshop\module07.private.json
```

> **Expected result** — no output. `Get-Content .\.workshop\module07.private.json` shows the two IDs and the resource
> group name. The new app registration has no secret and no certificate yet.

**A3. Allow this client in Terraform** (identity administrator for `infra/entra`, then you for `infra/workload`). The
lists keep Visual Studio Code and Azure CLI. Review each plan: one pre-authorization added, then in-place updates of the
gateway policies and the Function authentication, nothing destroyed.

```powershell
$ids = @(@(terraform -chdir=infra/entra output -json pre_authorized_client_ids | ConvertFrom-Json) + $app.appId | Select-Object -Unique)   # VS Code, Azure CLI, Foundry client
@{ pre_authorized_client_ids = $ids } | ConvertTo-Json | Set-Content .\.workshop\entra-module07.tfvars.json
@{ mcp_allowed_client_ids = $ids } | ConvertTo-Json | Set-Content .\.workshop\module07.tfvars.json
terraform '-chdir=infra\entra' plan '-var-file=..\..\.workshop\entra.tfvars.json' '-var-file=..\..\.workshop\entra-module05.tfvars.json' `
    '-var-file=..\..\.workshop\entra-module07.tfvars.json' '-out=..\..\.workshop\entra07.tfplan'
terraform '-chdir=infra\entra' apply '..\..\.workshop\entra07.tfplan'
$vars07 = $vars + '-var-file=..\..\.workshop\module05.tfvars.json', '-var-file=..\..\.workshop\module07.tfvars.json'   # $vars from module 04
terraform '-chdir=infra\workload' plan @vars07 '-out=..\..\.workshop\module07.tfplan'
terraform '-chdir=infra\workload' apply '..\..\.workshop\module07.tfplan'
```

> **Real result** — 2026-10-20, author's test tenant (excerpt).
>
> ```text
> # azuread_application_pre_authorized.clients["<foundry-client-id>"] will be created
> Plan: 1 to add, 0 to change, 0 to destroy.
> ...
> Plan: 0 to add, 6 to change, 0 to destroy.
> Apply complete! Resources: 0 added, 6 changed, 0 destroyed.
> ```

**A2 and A3 in the low-code track** ([how to choose](../../docs/TRACKS.md)). A1 and A4 to A7 are the same in both tracks.
Run A2 with the first two lines below instead of its `terraform` line. Then, instead of the A3 Terraform plans, add the
Foundry client to the three gates by hand: the API's pre-authorized clients (Entra), the Function's allowed applications
(built-in authentication), and the gateway policies (re-rendered with the same templates as Terraform).

```powershell
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json; $id = "$($p.participant_prefix)lc"; $sfx = $p.resource_suffix.Substring(0, 10)
$mcpApp = az ad app list --display-name "Workshop MCP API ($id-$sfx)" --query "[0].appId" -o tsv   # replaces the A2 terraform line
# --- after A2: $app holds the Foundry client ---
$rg = "rg-mcp-$id-$sfx"; $fn = "func-mcp-$id-$sfx"; $apim = "apim-mcp-$id-$sfx"
$tenant = az account show --query tenantId -o tsv; $sub = az account show --query id -o tsv
$scopeId = az ad app show --id $mcpApp --query "api.oauth2PermissionScopes[?value=='user_impersonation'].id | [0]" -o tsv
# 1. Entra (identity administrator): pre-authorize the Foundry client, keep VS Code and Azure CLI.
$h = @{ Authorization = "Bearer $(az account get-access-token --resource-type ms-graph --query accessToken -o tsv)" }; $g = 'https://graph.microsoft.com/v1.0'
$api = Invoke-RestMethod "$g/applications(appId='$mcpApp')?`$select=id,api" -Headers $h
$pre = @($api.api.preAuthorizedApplications | Where-Object appId -ne $app.appId) + @(@{ appId = $app.appId; delegatedPermissionIds = @($scopeId) })
Invoke-RestMethod -Method Patch "$g/applications/$($api.id)" -Headers $h -ContentType 'application/json' -Body (@{ api = @{ preAuthorizedApplications = $pre } } | ConvertTo-Json -Depth 5) | Out-Null
# 2. Function built-in authentication: add the client to the allowed applications.
$authUrl = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Web/sites/$fn/config/authsettingsV2?api-version=2024-04-01"
$auth = az rest --url $authUrl -o json | ConvertFrom-Json
$pol = $auth.properties.identityProviders.azureActiveDirectory.validation.defaultAuthorizationPolicy
$ids = @(@($pol.allowedApplications) + $app.appId | Select-Object -Unique); $pol.allowedApplications = $ids
$f = New-TemporaryFile; [IO.File]::WriteAllText($f, (@{ properties = $auth.properties } | ConvertTo-Json -Depth 12 -Compress))
az rest --method put --url $authUrl --body "@$f" --headers 'Content-Type=application/json' -o none; Remove-Item $f
# 3. Gateway: re-render the policies with the new list, then paste them (portal: each API → Policies), or first paste the
#    module 04 L1 helper (the $svcId line and the Put function) and run the loop.
& .\modules\04-governed-gateway\render-policies.ps1 -TenantId $tenant -ApiClientId $mcpApp -GatewayName $apim -AllowedClientIds $ids
foreach ($m in @(@('workshop-mcp', 'mcp-server'), @('contoso-tickets-api', 'rest-api'), @('contoso-tickets-mcp', 'rest-mcp-server'))) {
    Put "apis/$($m[0])/policies/policy" @{ properties = @{ format = 'rawxml'; value = [IO.File]::ReadAllText("$PWD\.workshop\policy-$($m[1]).xml") } }
}
"pre-authorized: $($pre.Count); function allowed: $($ids.Count)"
```

> **Real result** — low-code track, 2026-10-20, author's test tenant. Then the module 04 low-code validator still passes.
>
> ```text
> pre-authorized: 3; function allowed: 3
> PASS a valid token for another audience (Microsoft Graph) is refused by the gateway (expected HTTP 401).
> PASS module 04 operator checks complete. Persona checks are still required for validation.
> ```
>
> **What it means for you:** three lists, three IDs each (VS Code, Azure CLI, Foundry client). A client missing from any
> one of them is refused at that gate. In A4, use `https://<apim>.azure-api.net/workshop-mcp/mcp` as the endpoint and
> `api://<mcpApp>/user_impersonation offline_access` as the scopes.

**A4. Add the MCP tool in the Foundry portal.** Open [Foundry](https://ai.azure.com/nextgen), select your project, then
**Build** → **Tools** → **Connect a tool** → **Custom** → **Model Context Protocol (MCP)** → **Create**. Fill in:

| Field | Value |
|---|---|
| Name | `workshop-governed` |
| Remote MCP Server endpoint | `terraform -chdir=infra/workload output -raw gateway_mcp_endpoint` |
| Authentication | **OAuth Identity Passthrough** |
| Client ID | the `foundry_client_app_id` from A2 |
| Client secret | leave empty for now (step A5 adds it) |
| Token URL and Refresh URL | `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token` |
| Auth URL | `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize` |
| Scopes | `terraform -chdir=infra/entra output -raw user_impersonation_scope`, a space, then `offline_access` |

Select **Connect**, then copy the **Redirect URL** that Foundry shows. Then select **Use in an agent**, name it
`workshop-mcp-agent`, and keep only this MCP tool (remove **Web search** if it is listed, then **Save**).

![Real capture: the workshop-governed tool in Foundry; frame 1 marks the gateway endpoint, frame 2 OAuth Identity Passthrough, frame 3 the redirect URL to register](../../assets/screenshots/azure-07-foundry-tool.png)

*Real capture, 2026-10-20, author's test tenant. Names pseudonymised, IDs replaced.*

**A5. Register the redirect URL and hand Foundry a one-day secret.** Run this block as one paste: the secret exists only
in memory, goes straight into the Foundry connection, and is never printed.

```powershell
$redirect = '<redirect-url-from-A4>'
$s = Get-Content .\.workshop\module07.private.json -Raw | ConvertFrom-Json
$f = New-TemporaryFile
@{ web = @{ redirectUris = @($redirect) } } | ConvertTo-Json -Depth 4 | Set-Content $f
az rest --method patch --url "https://graph.microsoft.com/v1.0/applications/$($s.foundry_client_object_id)" --body "@$f" --headers 'Content-Type=application/json'
$end = (Get-Date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
$secret = az ad app credential reset --id $s.foundry_client_app_id --append --display-name 'foundry-module07-short-lived' --end-date $end --query password -o tsv --only-show-errors
$proj = az resource list -g $s.foundry_resource_group --resource-type Microsoft.CognitiveServices/accounts/projects --query "[0].id" -o tsv
$url = "https://management.azure.com$proj/connections/workshop-governed?api-version=2025-06-01"
$c = (az rest --url $url -o json | ConvertFrom-Json).properties
$body = @{ properties = @{ authType = 'OAuth2'; category = $c.category; group = $c.group; target = $c.target; authorizationUrl = $c.authorizationUrl
    tokenUrl = $c.tokenUrl; refreshUrl = $c.refreshUrl; scopes = $c.scopes; connectorName = $c.connectorName; redirectUrl = $c.redirectUrl
    isSharedToAll = $false; metadata = $c.metadata; credentials = @{ clientId = $s.foundry_client_app_id; clientSecret = $secret } } }
[IO.File]::WriteAllText($f, ($body | ConvertTo-Json -Depth 6 -Compress))
try { az rest --method put --url $url --body "@$f" --headers 'Content-Type=application/json' -o none } finally { Remove-Item $f -Force; $secret = $null; $body = $null }
```

> **Real result** — 2026-10-20: no output. Reading the connection again shows `"credentials": null`: Foundry never returns
> the secret. In Microsoft Entra, the client app lists one secret named `foundry-module07-short-lived`, valid for one day.

> **Why a secret?** The author first tried without one (a public client, as Visual Studio Code uses). Alice's sign-in
> succeeded in Microsoft Entra, but the Foundry credential manager then failed to redeem the code. The portal also marks
> **Client secret** as required. So the rule is: one dedicated client app, a secret valid for one day, never printed or
> stored, deleted by the clean-up. The secret identifies the **client app**; each user still signs in as themselves.

**A6. Give each test user the Foundry User role on the project**, so they call the agent as themselves:

```powershell
$users = Get-Content .\.workshop\test-users.private.json -Raw | ConvertFrom-Json
foreach ($u in 'alice', 'bob') {
    az role assignment create --assignee-object-id $users.$u.objectId --assignee-principal-type User --role 'Foundry User' --scope $proj -o none
}
```

> **Expected result** — no output. Wait 2 to 3 minutes: before the role applies, Foundry answers HTTP 403.

The documentation recommends **Foundry Agent Consumer** for published agents. For direct calls to the project, as here,
it returned HTTP 403 in the author's test; **Foundry User** worked.

**A7. Call the agent as Alice, sign in once, approve the read.** Use Alice's own Azure CLI profile (module 03):

```powershell
$env:AZURE_CONFIG_DIR = Join-Path $PWD '.workshop\az-alice'
$prompt = 'Use the workshop MCP tool to call get_service_health with service "workshop-api". Summarise the result. Do not call any write tool.'
pwsh ./modules/07-clients/invoke-foundry-agent.ps1 -ProjectEndpoint $endpoint -Prompt $prompt
# CONSENT: open the printed link in a browser signed in as Alice, select "Allow access", sign in, then run the same command again.
# APPROVAL: read the tool name and arguments, then:
pwsh ./modules/07-clients/invoke-foundry-agent.ps1 -ProjectEndpoint $endpoint -PreviousResponseId <resp_id> -Approve
```

> **Real result** — Alice, 2026-10-20, after her consent (response IDs shortened).
>
> ```text
> TOOLS create_ticket, get_service_health, read_report_as_app, read_report_as_user, whoami
> APPROVAL get_service_health {"service":"workshop-api"}. Approve with: -PreviousResponseId resp_00442ff3... -Approve (or -Deny)
> CALL get_service_health -> {"service":"workshop-api","status":"healthy","source":"synthetic","level":"0-open"}
> ```

Then the same as Bob with a write (`$env:AZURE_CONFIG_DIR` set to `.workshop\az-bob`):

```prompt
Use the workshop MCP tool. Call create_ticket with service "ticket-queue", severity "medium" and summary "Synthetic ticket - Contoso workshop". Show the tool result, or the exact error if the call is refused.
```

![Real terminal output: frame 1 marks the approval Foundry asks before get_service_health, frame 2 Alice's result through the gateway, frame 3 Bob's approved create_ticket refused by the gateway with HTTP 403](../../assets/screenshots/terminal-07-foundry.png)

The same flow in the portal playground: Foundry shows the tool and its arguments, and waits for **Approve** or **Deny**.

![Real capture: Foundry playground; frame 1 marks the tool call waiting for approval, frame 2 the Approve once option, frame 3 the only tool, the governed gateway](../../assets/screenshots/azure-07-foundry-approve.png)

![Real capture: Foundry playground after approval; frame 1 marks Request has been approved, frame 2 the agent's answer from the synthetic tool, frame 3 the tool that answered](../../assets/screenshots/azure-07-foundry-result.png)

*Real captures, 2026-10-20, author's test tenant. Names pseudonymised, IDs replaced.*

> [!WARNING]
> A consent link belongs to the Foundry user who received it. If someone else opens it and signs in, the first user's
> agent then acts with the second user's token. Never share a consent link; each user opens their own.

**Question:** Bob selects **Approve** in Foundry for `create_ticket`. Who refuses the call, and why does approval not help?

<details>
<summary>Show answer</summary>

The gateway refuses it with HTTP 403. Approval is Bob's agreement to run the tool; it adds nothing to his token. The
gateway checks the `roles` claim for `Tools.Write`, which Bob does not have, so the Function never sees the call.

</details>

### Part B — Microsoft Copilot Studio (outline)

1. In the agent, open **Tools**, then **Add a tool**, then **New tool**, then **Model Context Protocol**.
2. Enter a **Server name**, a **Server description** and the **Server URL** (gateway URL).
3. Choose **OAuth 2.0**, never **None**. The documented **Manual** setup asks for a **Client secret**. The workshop rule
   allows it only as in part A: a dedicated client app registration, a secret valid for one day, handed over without
   printing or storing it, and deleted at clean-up. The workshop does not implement dynamic client registration. Never
   switch to **API key** to bypass this.
4. Only the **Streamable** transport is supported. SSE is no longer supported.
5. Test a read tool first, with the correct MCP audience, delegated scope and roles. This outline was **not** run live by
   the author: only part A (Foundry) was.

> [!CAUTION]
> Never switch to **None** or **API key** to make a Copilot Studio connection work: that removes the identity check
> this workshop builds. A client secret is acceptable only short-lived, on a dedicated client app, and deleted after.

> The exact screen labels can change. Check the source page below before the session.

**Question:** the Copilot Studio Manual OAuth setup asks for a client secret. Why not switch to **API key** instead?

<details>
<summary>Show answer</summary>

An API key identifies no user. The gateway could no longer check a token for the MCP audience, a delegated scope or
Alice's and Bob's app roles, so per-user authorization would be gone. A short-lived client secret on a dedicated client
app keeps each user's sign-in: the secret identifies the client app, not the user.

</details>

### Part C — Checklist for every client

- [ ] The token audience is the MCP server's own audience (not Microsoft Graph, not a downstream API).
- [ ] The client signs each user in (OAuth); never **None** or an API key.
- [ ] Any client secret is short-lived, on a dedicated client app, never printed or stored, and deleted at clean-up.
- [ ] Write tools require an explicit role and a human approval.
- [ ] The gateway logs show the call with a correlation ID and no request body (module 06).

## What you should see

- Alice: Foundry lists the five tools, asks for approval, then returns the synthetic `healthy` result.
- Bob: approval is asked for `create_ticket`, then the gateway answers **HTTP 403**; the tool never runs.
- Module 06 query: the Foundry calls appear with tool name, status and duration, and no body.

## Validate

**Offline** (always): the folder is complete, part A is documented with its clean-up, and no secret value is written down.

```powershell
pwsh ./modules/07-clients/validate.ps1 -Offline
```

> **Real result** — offline validator, author's workstation, 2026-10-20 (excerpt).
>
> ```text
> PASS README sections present in contract order (offline)
> PASS lists what part A deploys and how to delete it (offline)
> PASS marks Preview features (offline)
> PASS never recommends the anonymous None option for Copilot Studio (offline)
> PASS client secrets are short-lived, never printed and deleted (offline)
> PASS no GUIDs or client secret values in module files (offline)
>
> RESULT: all offline checks passed
> ```

**Live** (part A deployed): run step A7 for Alice and Bob. Expected: `CALL get_service_health -> {... "status":"healthy" ...}`
for Alice, and `REFUSED ... the MCP server answered HTTP 403` for Bob after his approval.

```bash
bash ./modules/07-clients/validate.sh --offline
```

> **Expected result** — the same PASS/FAIL lines as the PowerShell run above.

**Question:** every offline check passes. Does that prove Foundry can call your server?

<details>
<summary>Show answer</summary>

No. Offline checks prove the folder is complete and the rules are written down. Only step A7 proves the live path:
Alice's read succeeds after approval, and Bob's approved write gets HTTP 403 from the gateway.

</details>

## Troubleshooting

| Symptom | Check |
|---|---|
| `Access denied ... while enumerating tools (HTTP 403 Forbidden)` | The gateway allow-list must include `server/discover` (MCP 2026-07-28), which Foundry calls first. Your copy of `policies/mcp-server.xml` accepts it with `Tools.Read`. Otherwise: the client ID is missing from `mcp_allowed_client_ids` (step A3). |
| The consent window ends with "we couldn't authenticate", and no sign-in appears for the client app | The client app has no secret, or the redirect URL is not on the **Web** platform (step A5). |
| The same message, but Entra shows a successful sign-in | Close the window and call the agent again: the token is often stored anyway. |
| Your Foundry account gets AADSTS50105 in the consent window | Expected: only users assigned an app role (module 03) can sign in to the MCP API. Use Alice or Bob. |
| HTTP 403 from Foundry before any tool call | The user lacks **Foundry User** on the project, or the role is still propagating (wait 2 to 3 minutes). |
| `invalid character 'n' after object key:value pair` from `azd provision` | Escape the quotes in `AI_PROJECT_DEPLOYMENTS` (step A1). |
| The client cannot reach the server | Use the gateway URL (module 04). The Function URL is locked by design. |
| SSE transport fails | Use Streamable. SSE is no longer supported. |

## Clean up

Report first, then apply. The script restores the allowed applications through guarded Terraform plans, then deletes
the Foundry resource group (only if tagged `module=07`) and the client app registration with its secret.

```powershell
pwsh ./modules/07-clients/cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
pwsh ./modules/07-clients/cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
```

> **Real result** — `-Apply`, run by module 99 on 2026-10-20, author's test tenant. Names and IDs withheld.
>
> ```text
> PLAN update azapi_resource.mcp_api_policy[0] (remove the Foundry client from the allowed applications)
> ...
> PASS 'remove the Foundry client from the allowed applications' applied (expected HTTP 200).
> PLAN delete azuread_application_pre_authorized.clients["<foundry-client-id>"] (remove the Foundry client pre-authorization)
> PASS 'remove the Foundry client pre-authorization' applied (expected HTTP 200).
> PASS Foundry resource group deleted and accounts purged (expected HTTP 200 from Azure Resource Manager).
> PASS Foundry client app registration and secret deleted (expected HTTP 204 from Microsoft Graph).
> DONE module 07 part A removed. Private module 07 files deleted.
> ```
>
> **What it means for you:** the gateway and the Function accept only Visual Studio Code and Azure CLI again, and no
> secret remains. The author's run then found the Foundry **agent identity blueprint** still in Microsoft Entra: deleting
> the resource group does not remove it. The script now deletes it too, before the resource group.

```bash
bash ./modules/07-clients/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
```

> **Expected result** — the same lines as the PowerShell report; add `--apply` to delete.

## Go further

- Publish the agent and compare **Foundry Agent Consumer** with **Foundry User** for its users.
- Track when OAuth identity passthrough becomes generally available, and whether a public client becomes possible.

## Sources

- Microsoft Foundry — Set up authentication for MCP tools: https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication
- Azure Functions — Connect an MCP server on Azure Functions to a Foundry Agent Service agent: https://learn.microsoft.com/azure/azure-functions/functions-mcp-foundry-tools
- MCP specification 2026-07-28 — `server/discover`: https://modelcontextprotocol.io/specification/2026-07-28/server/discover
- Azure-Samples/azd-ai-starter-basic (MIT), verified at commit `5bf59a056c41ff37801dea334ba6a141e2dc5f67`: https://github.com/Azure-Samples/azd-ai-starter-basic
- Microsoft Copilot Studio — Add an existing MCP server to an agent: https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent

Last verified: 2026-10-20.
