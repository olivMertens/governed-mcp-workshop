# 03 — Microsoft Entra authentication: portal-first low-code

[Français](LOW-CODE.fr.md)

## Goal

[Terraform + PowerShell guide](README.md)

Replace the shared-key-only gate with Microsoft Entra authentication. Alice and Bob can connect; Eve cannot obtain a token. This separated guide has not been live-validated end to end.

## Why it matters

A token names its audience (the intended API), delegated scope (`scp`) and assigned app roles (`roles`). A valid Microsoft Graph token is not valid for this MCP server. One token per hop; never forward the client's token to another API.

The safe order is **Entra in front of the existing key → verify anonymous HTTP 401 → replace the key gate**. Never reverse it. Per-tool role enforcement arrives in module 04; module 03 only admits assigned users.

> [!IMPORTANT]
> A genuine token is not sufficient: it must target this MCP API and the allowed tenant. A Microsoft Graph token must still be refused. Never remove the key gate before required Entra authentication is confirmed.

## What you deploy

One single-tenant app registration, its enterprise application, delegated scope `user_impersonation`, user roles `Tools.Read` and `Tools.Write`, application role `Tools.Execute.All`, two pre-authorized clients and three role assignments. No secret, certificate or new user is created by this guide.

The existing Function gets built-in authentication and Protected Resource Metadata (PRM, **Preview**), which tells MCP clients where to sign in. No new metered compute; the module 02 resources keep their existing charges.

## Prerequisites and required roles

- [Module 02 low-code](../02-open-server/LOW-CODE.md) deployed and its five-tool code published. Keep its participant file and names.
- PowerShell 7.4+, Azure CLI, VS Code with GitHub Copilot; repository root as terminal directory.
- Participant: Contributor on the workshop group. No additional Azure role assignment.
- **Identity administrator, separate session/person:** Cloud Application Administrator or Application Administrator for the workshop app, pre-authorization and assignments. No Global Administrator or admin consent is requested in this module.
- Three existing dedicated test users in the same approved non-production tenant: Alice, Bob and Eve. User Administrator is needed only if an authorized administrator must provision those accounts outside this exercise. Users register required multifactor authentication (MFA) normally; never weaken Conditional Access.
- Administrator shares only the API Client ID, Tenant ID and test user Object IDs privately. No passwords or tokens in chat, files or screenshots. Obtain approval before changing identity or Function settings.

## Steps

### 1. Participant: establish this module's terminal context

Azure portal → **Subscriptions → your subscription → Overview**: Subscription ID. **Microsoft Entra ID → Overview**: Tenant ID. Replace placeholders with those GUIDs:

```powershell
$tenant = '<tenant-id>'
$sub = '<subscription-id>'
az login --tenant $tenant
az account set --subscription $sub
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
$id = "$($p.participant_prefix)lc"; $sfx = $p.resource_suffix.Substring(0, 10)
$rg = "rg-mcp-$id-$sfx"; $fn = "func-mcp-$id-$sfx"
if ($p.existing_resource_group_name) { $rg = $p.existing_resource_group_name }
$vscode = 'aebc6443-996d-45c2-90f0-388ff96faa56'
$azcli = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'
"Workshop MCP API ($id-$sfx)"; $rg; $fn
```

> **Expected result** — app display name and your existing low-code group/Function names. Keep this terminal; no previous module variables are needed. Tell the administrator the displayed app name.

### 2. Identity administrator: create the API, scope and roles in the portal

1. In the correct directory, **Microsoft Entra ID → App registrations → New registration**. Name `Workshop MCP API (<id>-<sfx>)`, using the participant's displayed name. Select **Accounts in this organizational directory only**, no redirect URI, **Register**.
2. **Overview**: copy **Application (client) ID** and **Directory (tenant) ID**. Do not substitute the app's Object ID. Send these non-secret IDs to the participant privately.
3. **Expose an API → Application ID URI → Add**: accept `api://<application-client-id>`, **Save**.
4. **Add a scope**: name `user_impersonation`, consent **Admins and users**, admin and user display name `Access the workshop MCP server`, descriptions explaining access for the signed-in user; state **Enabled**, **Add scope**.
5. **App roles → Create app role** three times:

| Display name | Allowed member types | Value | Description |
|---|---|---|---|
| Read workshop tools | Users/Groups | `Tools.Read` | Call read-only workshop MCP tools |
| Write with workshop tools | Users/Groups | `Tools.Write` | Call workshop tools that change synthetic data |
| Execute workshop tools as an application | Applications | `Tools.Execute.All` | App-only access for a separately approved client |

Enable each role. No application is assigned the app-only role here.

6. **Manifest**: in the `api` object set `requestedAccessTokenVersion` to **2**, **Save**. Do not replace the whole manifest or change existing IDs. Confirm the three roles and one scope remain.

![Real app roles capture](../../assets/screenshots/azure-03-app-roles.png)

*Illustrative real capture; author's resource names differ. On your app check the exact role values and allowed member types, not only display names.*

### 3. Identity administrator: pre-authorize clients and assign users

1. App registration → **Expose an API → Authorized client applications → Add a client application**. Client ID `aebc6443-996d-45c2-90f0-388ff96faa56` (VS Code); select `user_impersonation`; **Add application**.
2. Repeat for Azure CLI: `04b07795-8ddb-461a-bbee-02f9e1bf7b46`, same scope. Do not add unknown clients.
3. **Microsoft Entra ID → Enterprise applications → All applications**: search the API by its Application ID; open it → **Properties → Assignment required? → Yes → Save**.
4. **Users and groups → Add user/group**: select Alice, role **Read workshop tools**, **Assign**. Repeat Alice with **Write with workshop tools**, then Bob with **Read workshop tools**. Leave Eve unassigned. Verify three assignments.
5. **Microsoft Entra ID → Users → All users → each test account → Overview**: copy each **Object ID**. Share these privately, not their credentials.

![Real assignment-required capture](../../assets/screenshots/azure-03-enterprise-app-properties.png)

*Illustrative real capture on another resource name. Confirm Assignment required = Yes on your API's enterprise application. This is what prevents Eve from getting a token.*

### 4. Participant: enable authentication while keeping the key

1. Function → **Settings → Authentication → Add identity provider → Microsoft**. Inspect the existing-registration option for this tenant: authentication required, unauthenticated requests **HTTP 401**, token store **Off**. Do not save wizard defaults that create a secret or a new registration. Close the wizard and use the exact configuration below to create the provider without a secret.
2. Use the terminal below to apply the existing exact advanced configuration. This avoids portal defaults that add a client secret, accept other tenants or omit the client allow-list. Replace `$apiClientId` with the **Application (client) ID** received from step 2. The JSON file contains configuration IDs only, never a token or secret.

```powershell
$apiClientId = '<api-application-client-id>'
$authFile = Join-Path $PWD '.workshop\lowcode-authsettings.json'
@{ properties = @{
    platform = @{ enabled = $true; runtimeVersion = '~1' }
    globalValidation = @{ requireAuthentication = $true; unauthenticatedClientAction = 'Return401' }
    httpSettings = @{ requireHttps = $true; routes = @{ apiPrefix = '/.auth' }; forwardProxy = @{ convention = 'NoProxy' } }
    login = @{ tokenStore = @{ enabled = $false } }
    identityProviders = @{ azureActiveDirectory = @{ enabled = $true
        registration = @{ clientId = $apiClientId; openIdIssuer = "https://login.microsoftonline.com/$tenant/v2.0" }
        validation = @{ allowedAudiences = @("api://$apiClientId", $apiClientId)
            defaultAuthorizationPolicy = @{ allowedApplications = @($vscode, $azcli) } } } }
} } | ConvertTo-Json -Depth 8 | Set-Content $authFile
try {
    az rest --method put --url "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Web/sites/$fn/config/authsettingsV2?api-version=2024-04-01" --body "@$authFile" --headers 'Content-Type=application/json' -o none
    if ($LASTEXITCODE) { throw 'Authentication configuration failed; keep the key gate.' }
} finally { Remove-Item $authFile -ErrorAction SilentlyContinue }
```

> **Expected result** — silent successful write, exit code 0; required tenant-specific authentication, API audience and two allowed clients are configured. The key gate remains in place.

3. Function → **Settings → Environment variables → App settings → Add**:
   - `WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES` = `api://<api-application-client-id>/user_impersonation` (**Preview**).
   - `WEBSITE_AUTH_AAD_ALLOWED_TENANTS` = your Tenant ID.
   **Apply → Confirm**.
4. Confirm **Authentication** shows Require authentication, HTTP 401 and token store disabled. Do not yet change the webhook gate.

![Real Function authentication capture](../../assets/screenshots/azure-03-function-authentication.png)

*Illustrative real capture. Your Function name differs; verify all three controls on your own app before proceeding.*

```powershell
$r = Invoke-WebRequest "https://$fn.azurewebsites.net/runtime/webhooks/mcp" -Method Post -ContentType 'application/json' -SkipHttpErrorCheck `
    -Body '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"workshop","version":"1"}}}'
if ($r.StatusCode -ne 401) { throw "Expected HTTP 401 before replacing the key, got $($r.StatusCode)" }
$r.StatusCode
```

> **Expected result** — **401**. If anything else is returned, stop and repair authentication, not the key gate.

### 5. Participant: replace the key gate only after step 4 passes

Function → **Settings → Environment variables → App settings → Add**:

`AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel` = `Anonymous`.

**Apply → Confirm**. This setting makes only the internal webhook key gate anonymous; built-in Entra authentication must remain required in front of it. An unauthenticated public call must still return 401. Never put this setting in module 02's published package.

### 6. Connect VS Code with a selected test account

1. Function → **Overview → Default domain**: replace `<function-host>` below with that domain.
2. VS Code → **Ctrl+Shift+P → MCP: Open User Configuration**. Remove the old `workshop-open` entry and key input; add:

```json
{
  "servers": {
    "workshop-entra": { "type": "http", "url": "https://<function-host>/runtime/webhooks/mcp" }
  }
}
```

3. Select **Start** above the entry → **Allow** Microsoft authentication → sign in as **Alice**. Complete normal MFA registration if requested.
4. **Chat → Agent → Configure Tools**: select only this server. Ask: `List the workshop-entra tools, then call get_service_health with service "workshop-api".` Read and approve the requested tool once.
5. Expected: **Running**, **Discovered 5 tools**, health result. To test Bob or Eve, use **Profiles: New Profile...**, give it that account's name, repeat the configuration and sign-in in that separate window. Eve should be refused with `AADSTS50105`; do not assign her to fix the refusal.

![Real VS Code connection capture](../../assets/screenshots/client-03-vscode.png)

*Illustrative real capture from the author's environment. Verify your own URL, Running status and Discovered 5 tools; names in the capture may differ.*

## What you should see

No token, wrong audience, or the old key alone: HTTP **401**. PRM: **200** naming your tenant and scope. Alice/Bob: initialize and five tools **200**. Eve: token refusal `AADSTS50105` (token endpoint **400**). Bob's write restriction is not yet enforced per tool until module 04.

## Validate

Create an ignored `.workshop/module03-personas.json` in VS Code, with the exact user **Object IDs** from step 3 (not client IDs). No token/password:

```json
{
  "alice": "<alice-object-id>",
  "bob": "<bob-object-id>",
  "eve": "<eve-object-id>"
}
```

Run operator checks in the step 1 terminal:

```powershell
$v = @{ TenantId = $tenant; ResourceGroup = $rg; FunctionApp = $fn; ApiClientId = $apiClientId; SkipBuild = $true
    PersonaObjectIdsPath = '.\.workshop\module03-personas.json' }
& .\modules\03-entra-authentication\validate.ps1 @v -SubscriptionId $sub
```

> **Expected result** — PASS missing token 401, wrong audience 401, PRM 200 (**Preview**), required auth configuration 200 from management, old key alone 401. `-SkipBuild` omits the shared Terraform build/mock checks; named resources avoid state lookup.

Then run all three test accounts. At **each** browser prompt, select the named persona, not your operator. These isolated profiles keep the operator's credentials untouched and restore its configuration even after failure:

```powershell
$operatorConfig = $env:AZURE_CONFIG_DIR
try {
    foreach ($persona in 'Alice', 'Bob', 'Eve') {
        Write-Host "Sign in as $persona"
        $env:AZURE_CONFIG_DIR = Join-Path $PWD ".workshop\az-$($persona.ToLower())"
        az login --tenant $tenant --allow-no-subscriptions
        if ($LASTEXITCODE) { throw "Login failed for $persona" }
        & .\modules\03-entra-authentication\validate.ps1 @v -Persona $persona
        az logout
    }
} finally {
    if ($null -eq $operatorConfig) { Remove-Item Env:\AZURE_CONFIG_DIR -ErrorAction SilentlyContinue }
    else { $env:AZURE_CONFIG_DIR = $operatorConfig }
}
az account set --subscription $sub
```

> **Expected result** — account/Object ID cross-check PASS, Alice/Bob initialize and five tools 200, Eve refused before reaching the Function. A refused Eve token is success for this check.

## Troubleshooting

- **Alice AADSTS50105:** administrator checks her assignments on this API's enterprise application and waits for propagation. Do not add Eve.
- **AADSTS65001/consent:** verify both pre-authorized client IDs and the selected scope; this module does not need a tenant-wide admin-consent workaround.
- **401 for Alice:** check tenant, API Client ID, v2 token version, allowed clients and PRM scope. A Graph token must still fail.
- **Key required after sign-in:** verify step 5's exact setting name, only after required Entra authentication is confirmed.
- **CLI wrong account:** isolated profile and private Object ID check catch this; sign out of that profile and rerun as the right test account.

## Clean up

Keep resources only if continuing immediately to [module 04 low-code](../04-governed-gateway/LOW-CODE.md). Otherwise follow [module 99 low-code cleanup](../99-cleanup/LOW-CODE.md): review group ownership and tags, delete only workshop-owned Azure resources; the identity administrator deletes only this workshop API registration and enterprise application. Keep provided apps/users/groups. Do not use Terraform cleanup on portal resources. Remove VS Code entries and sign out isolated persona profiles.

## Go further

**Question:** Alice has a valid Microsoft Graph token from this tenant. Should this MCP server accept it?

<details>
<summary>Show answer</summary>

No: HTTP 401 is expected. Its audience is Microsoft Graph, not this MCP API. Being signed in to the correct tenant does not make a token valid for every API.

</details>

Explain why a scope permits a client to act for a user while an app role describes that user's allowed tools. Next, [enforce roles at the gateway](../04-governed-gateway/LOW-CODE.md).

## Sources

- [MCP authentication and PRM (Preview)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).
- [VS Code and App Service MCP sign-in](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode).
- [Functions MCP authentication tutorial](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial).
- [App roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).

Last verified: 2026-10-20 (existing implementation and documentation; newly separated guide not live-validated).
