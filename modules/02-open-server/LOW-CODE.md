# 02 — An open MCP server: portal-first low-code

[Français](LOW-CODE.fr.md)

## Goal

[Terraform + PowerShell guide](README.md)

Deploy the five-tool Model Context Protocol (MCP) server using the Azure portal. Prove that a shared key, not a user identity, opens it. This newly separated guide has not been run end to end live.

## Why it matters

A key cannot distinguish Alice, Bob and Eve. Anyone holding it can run `create_ticket`. Keep this level short-lived. Never expose an anonymous endpoint. Modules 03 and 04 replace this shared gate with identity and a governed gateway.

> [!WARNING]
> HTTP 401 without a key proves only that the shared-key gate works. It does not prove per-user authorization. Keep the exercise short and rotate the key afterward.

## What you deploy

In one dedicated low-code resource group: a Flex Consumption Function App (.NET 10 isolated, 2048 MB), a user-assigned managed identity, Storage (`app-package` container and `tickets` queue), Log Analytics and Application Insights. Private Storage adds a virtual network, two private endpoints and private Domain Name System (DNS) zones.

The five tools are `get_service_health`, `create_ticket`, `whoami`, `read_report_as_user`, `read_report_as_app`. Only `create_ticket` writes synthetic data. The last three are demonstrations until module 05. Logs must contain no key, token, argument or result.

**Cost:** executions, Storage and telemetry; private endpoints have hourly charges. No always-ready instance. Set a 10-instance maximum. Clean up the same day. No Preview feature in this module.

## Prerequisites and required roles

- [Module 00 low-code](../00-prerequisites/LOW-CODE.md) completed for an approved non-production subscription; [module 01](../01-discover-mcp/README.md) completed.
- Repository open in VS Code; PowerShell 7.4+, Azure CLI and .NET 10 SDK. Start commands at the repository root, not in this module.
- Existing ignored `.workshop/participant.tfvars.json`: `participant_prefix`, `resource_suffix`, `owner`, `expiry`. Despite its filename, this guide only reads participant naming data, not Terraform state. Do not regenerate the suffix.
- Contributor on the workshop group, plus permission to assign exactly Storage Blob Data Owner, Storage Queue Data Message Sender and Monitoring Metrics Publisher at the scopes below. Ask for constrained, time-bound Role Based Access Control Administrator, not Owner. No Entra administration required.
- This low-code deployment uses **West Europe (`westeurope`)**, as the existing low-code implementation does. Check Flex .NET 10 availability, policies and quota first. Do not substitute the Terraform example region silently.
- Obtain approval for resource creation and cost before step 2. Stop on a policy denial; do not disable a control.

## Steps

### 1. Prepare the terminal and names

In Azure portal → **Subscriptions** → your test subscription → **Overview**, copy **Subscription ID**. In **Microsoft Entra ID → Overview**, copy **Tenant ID**. Replace the two placeholders below with those GUIDs (identifiers, not secrets).

```powershell
$tenant = '<tenant-id>'
$sub = '<subscription-id>'
az login --tenant $tenant
az account set --subscription $sub
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
$id = "$($p.participant_prefix)lc"; $sfx = $p.resource_suffix.Substring(0, 10); $loc = 'westeurope'
$rg = "rg-mcp-$id-$sfx"; $st = "st$id$sfx"; $fn = "func-mcp-$id-$sfx"; $mi = "id-mcp-$id-$sfx"
$ai = "appi-mcp-$id-$sfx"; $law = "log-mcp-$id-$sfx"; $vn = "vnet-mcp-$id-$sfx"
if ($p.existing_resource_group_name) { $rg = $p.existing_resource_group_name }
$rg; $st; $fn; $mi; $ai; $law; $vn
```

> **Expected result** — seven names containing your prefix, `lc` and the same suffix (except an explicitly provided existing group). Keep this terminal open. These names, not the screenshot names, are used below. Never create or later delete an administrator-owned group.

### 2. Create the group, identity and monitoring in the portal

1. **Resource groups → Create**: select your subscription, enter `$rg`, region **West Europe**. **Tags**: `workshop=governed-mcp`, `owner` and `expiry` from your participant file, `track=low-code`. **Review + create → Create**. For an existing approved group, skip creation and retain its ownership.
2. Search **Managed Identities → Create**: same subscription, group and region; name `$mi`. Add the same tags and create. Its **Overview** has the **Client ID**, **Principal ID** and **Resource ID**; these are different identifiers.
3. Search **Log Analytics workspaces → Create**: same group, region and name `$law`. Add tags and create. Under **Usage and estimated costs → Daily cap**, set **1 GB/day**.
4. Search **Application Insights → Create**: name `$ai`, same region/group; choose `$law` as the workspace. Add tags and create. Under **Properties**, disable local authentication; the Function will use its identity.

Expected: all four resources show successful deployment in **Resource group → Overview**.

### 3. Create Storage and grant only the three required roles

1. **Storage accounts → Create**: same group, name `$st`, **West Europe**, **Standard**, **Locally-redundant storage (LRS)**. **Advanced**: require secure transfer, minimum TLS **1.2**, disable anonymous blob access and storage account key access; enable default Microsoft Entra authorization in the portal. Create with the same tags.
2. Storage → **Data storage → Containers** and **Queues** are where you inspect `app-package` (public access **Private**) and `tickets`. Create them with the management commands below: the data browser may be inaccessible over private networking or without a data-plane role. Do not request a broader data role or use a storage key just to provision these objects.
3. Storage account → **Access control (IAM) → Add → Add role assignment**: role **Storage Blob Data Owner**, member type **Managed identity**, choose `$mi`, **Review + assign**. Scope is this account only.
4. The exact queue scope is not consistently exposed by the portal's role picker. Use the existing management command below to assign **Storage Queue Data Message Sender** to `$mi` on `tickets` only, not the account.
5. Application Insights `$ai` → **Access control (IAM)**: assign **Monitoring Metrics Publisher** to `$mi` on this component only. Allow several minutes for propagation.

Run these existing management-plane operations to provision the container and queue, without a key or data-plane network exception:

```powershell
az storage container-rm create -g $rg --storage-account $st -n app-package -o none
$stId = az storage account show -g $rg -n $st --query id -o tsv
az rest --method put --url "https://management.azure.com$stId/queueServices/default/queues/tickets?api-version=2023-05-01" --body '{}' -o none
```

> **Expected result** — no output, exit code 0; `app-package` and `tickets` exist without using a Storage key.

Create the exact queue role assignment in the terminal:

```powershell
$stId = az storage account show -g $rg -n $st --query id -o tsv
$miPid = az identity show -g $rg -n $mi --query principalId -o tsv
az role assignment create --assignee-object-id $miPid --assignee-principal-type ServicePrincipal --role 'Storage Queue Data Message Sender' --scope "$stId/queueServices/default/queues/tickets" -o none
```

> **Expected result** — no output, exit code 0; the managed identity can send to this queue only. Do not broaden the scope to work around an assignment denial.

### 4. Prepare private Storage when policy requires it

Storage → **Networking → Public access**: if **Disabled**, complete this step before creating the Function. Never turn it on against policy. Otherwise continue to step 5; module 04 will still need a virtual network.

1. **Virtual networks → Create**: same group/region, name `$vn`, address space `10.52.0.0/23`. In **IP addresses**, remove the default subnet. Add `snet-functions`, `10.52.1.32/27`, delegated to **Microsoft.App/environments**; add `snet-private-endpoints`, `10.52.1.0/27`, with no delegation. Create.
2. Storage → **Networking → Private endpoint connections → + Private endpoint**: name `pe-<your-storage-name>-blob`, same group/region; target subresource **blob**; network `$vn`, subnet `snet-private-endpoints`. **DNS**: integrate with private DNS, zone `privatelink.blob.core.windows.net`. Create.
3. Repeat with name `pe-<your-storage-name>-queue`, subresource **queue**, zone `privatelink.queue.core.windows.net`.
4. **Private DNS zones** → each zone → **Virtual network links**: verify a link to `$vn` (auto-registration off). Storage → **Private endpoint connections**: both connections must be **Approved**.

![Storage public access, real capture](../../assets/screenshots/azure-02-storage-public-access.png)

*Illustrative real capture on the author's resources; your names differ. Verify your own Storage account and Public network access = Disabled when policy requires it.*

![Storage private endpoints, real capture](../../assets/screenshots/azure-02-storage-private-endpoints.png)

*Verify two Approved connections on your account: one blob, one queue. An Approved connection alone does not prove DNS is linked to your network.*

### 5. Create and configure the Function

1. **Create a resource → Function App → Flex Consumption → Create**. Select your group, name `$fn`, **West Europe**, runtime **.NET**, version **10 isolated**, instance memory **2048 MB**.
2. **Storage**: select `$st`, deployment container `app-package`, authentication **User-assigned managed identity**, select `$mi`. Use the same identity for host storage.
3. If step 4 was needed: **Networking → Enable virtual network integration**, select `$vn` and `snet-functions`. Do not put the Function in the private-endpoint subnet.
4. **Monitoring**: use existing Application Insights `$ai`. Add the same tags; review and create.
5. Function → **Settings → Identity → User assigned**: verify `$mi` is attached. **Settings → Configuration → General settings**: HTTPS only **On**, minimum TLS **1.2**, SCM and FTP basic publishing authentication **Off**. Under **Scale and concurrency**, set maximum instances **10**, no always-ready instances.
6. **Settings → Environment variables → App settings**: remove `AzureWebJobsStorage` if it contains a connection string. Add the settings below, substituting the Client ID from `$mi` → **Overview** and your Storage name. Keep the existing Application Insights connection string (it is an endpoint configuration, not a storage key). **Apply → Confirm**.

| Name | Value |
|---|---|
| `AzureWebJobsStorage__credential` | `managedidentity` |
| `AzureWebJobsStorage__clientId` | `<managed-identity-client-id>` |
| `AzureWebJobsStorage__blobServiceUri` | `https://<storage-name>.blob.core.windows.net/` |
| `AzureWebJobsStorage__queueServiceUri` | `https://<storage-name>.queue.core.windows.net/` |
| `APPLICATIONINSIGHTS_AUTHENTICATION_STRING` | `ClientId=<managed-identity-client-id>;Authorization=AAD` |
| `TICKET_QUEUE_SERVICE_URI` | `https://<storage-name>.queue.core.windows.net/` |
| `TICKET_QUEUE_NAME` | `tickets` |
| `WORKSHOP_IDENTITY_CLIENT_ID` | `<managed-identity-client-id>` |

Do not add an Anonymous webhook override. The repository's `host.json` keeps the MCP system-key gate.

### 6. Publish the existing code — terminal required

The portal does not build the repository's .NET project. Use the terminal from step 1:

```powershell
dotnet publish .\src\FunctionsMcpServer --configuration Release --output .\.workshop\lowcode-publish
if ($LASTEXITCODE) { throw 'Publish failed; stop.' }
Compress-Archive -Path .\.workshop\lowcode-publish\* -DestinationPath .\.workshop\lowcode.zip -Force
az functionapp deployment source config-zip -g $rg -n $fn --src .\.workshop\lowcode.zip -o none
if ($LASTEXITCODE) { throw 'Azure deployment failed; stop.' }
```

> **Expected result** — successful build and deployment (exit code 0); Function → **Functions** lists five functions after trigger synchronization. This version already contains module 05 code, disabled until its settings are enabled. Publish it before module 04 makes deployment endpoints private.

### 7. Connect VS Code without saving a key

1. Function → **Overview**: copy **Default domain**. Replace `<function-host>` below with that domain, without adding a second `https://`.
2. VS Code → **Ctrl+Shift+P → MCP: Open User Configuration**. Paste this configuration; it belongs in your user settings, not the repository.

```json
{
  "inputs": [
    { "type": "promptString", "id": "workshop-mcp-key", "description": "mcp_extension system key", "password": true }
  ],
  "servers": {
    "workshop-open": {
      "type": "http",
      "url": "https://<function-host>/runtime/webhooks/mcp",
      "headers": { "x-functions-key": "${input:workshop-mcp-key}" }
    }
  }
}
```

3. Select **Start** above `workshop-open`. When VS Code prompts for the key, copy it straight to your clipboard:

```powershell
az functionapp keys list -g $rg -n $fn --query systemKeys.mcp_extension -o tsv | Set-Clipboard
```

> **Expected result** — no key on screen; the system key is in the clipboard only. An empty clipboard means the host/key is not ready.

4. Paste only into VS Code's secret prompt, then run `Set-Clipboard -Value $null`. Never put it in a URL, file or screenshot.
5. **Chat → Agent → Configure Tools**: select only `workshop-open`. Ask: `Call create_ticket with service "workshop-api", severity "low", summary "Synthetic Contoso test". Then call whoami.`
6. Read the write-tool arguments and approve **once**, not automatically. Expected: a synthetic ticket and `caller: unknown`. Approval is a client control, not user authorization on this server.

## What you should see

Running, HTTPS-only Function; five tools; HTTP 401 without a key or with a wrong key; HTTP 200 with the system key. Anyone with that key can write. No per-user identity is established.

## Validate

In the operator terminal from step 1:

```powershell
& .\modules\02-open-server\validate.ps1 -TenantId $tenant -SubscriptionId $sub -ResourceGroup $rg -FunctionApp $fn -DemonstrateWrite -SkipBuild
```

> **Expected result** — PASS running and HTTPS-only (management HTTP 200), missing/wrong key **401**, initialize **200**, five tools **200**, key-only `create_ticket` **200** (one synthetic write). `-SkipBuild` skips the shared Terraform build/mock suite, not HTTP checks. Explicit names avoid state. The write does not prove secure user authorization.

Rotate the key after the demonstration. No key value is printed:

```powershell
az functionapp keys set -g $rg -n $fn --key-type systemKeys --key-name mcp_extension -o none
```

> **Expected result** — exit code 0; old client keys now get 401. Stop the VS Code server.

## Troubleshooting

- **Storage publish 403:** verify approved blob/queue private endpoints, DNS links, `snet-functions` integration and identity roles. Do not enable shared keys or remove network rules.
- **No system key yet:** wait for trigger sync; check host settings and identity role propagation. A normal function key is not the MCP system key.
- **Missing quota or unsupported runtime:** stop before creating more resources; use the region and quota process from module 00. Random new names do not reset quotas.
- **Expected refusal differs:** stop and diagnose; never make the webhook anonymous.

## Clean up

If continuing immediately, retain the resources for [module 03 low-code](../03-entra-authentication/LOW-CODE.md). Otherwise use [module 99 low-code cleanup](../99-cleanup/LOW-CODE.md) after approval: review group resources and `track=low-code`, then delete only workshop-owned resources. Never use the Terraform cleanup scripts for portal-created resources, and never delete an administrator-provided group. Remove the VS Code server and its stored key.

## Go further

**Question:** If Bob obtains the same key as Alice, can this server prevent only Bob from creating a ticket?

<details>
<summary>Show answer</summary>

No. The key identifies neither user. Both can call the write tool. Rotating the key revokes all old copies at once, not one person's access. The following modules add user identity and role checks.

</details>

Explain why HTTP 401 alone does not prove per-user security. Continue with [identity authentication](../03-entra-authentication/LOW-CODE.md).

## Sources

- [Functions custom remote MCP server](https://learn.microsoft.com/azure/azure-functions/scenario-custom-remote-mcp-server).
- [Pinned upstream sample, MIT](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9) and [notices](../../THIRD-PARTY-NOTICES.md).
- [Flex Consumption](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan).

Last verified: 2026-10-20 (documentation and existing repository implementation; this separated guide was not live-validated).
