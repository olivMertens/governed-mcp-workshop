# 02 - An "open" MCP server (level 0)

[Français](README.fr.md)

## Goal

Deploy the workshop's Model Context Protocol (MCP) server to Azure Functions, protected only by a key.
Prove that a request without the key gets HTTP 401 and a request with the key gets HTTP 200.
Then see the risk: **anyone who holds the key can call the write tool `create_ticket`.**

> [!WARNING]
> Level 0 exists only to show this risk. Keep it short-lived, never make the endpoint anonymous,
> and move on to module 03 (Microsoft Entra ID) and module 04 (API Management) to fix it.

## Why it matters

A key is a shared secret, not an identity. The server cannot tell Alice from Bob or from Eve.
It cannot apply per-user roles, it cannot call a downstream API "as the user", and logs cannot say who did what.
A key can leak through a screenshot, a chat, a saved configuration file or a browser history.

The Azure Functions MCP extension protects `/runtime/webhooks/mcp` with the `mcp_extension` **system key**
when `host.json` sets `webhookAuthorizationLevel` to `System` (the default). The upstream sample sets
`Anonymous` because it adds Microsoft Entra authentication in front. This module has no Entra layer yet,
so it keeps `System`. Never copy `Anonymous` into a key-only server.

## What you deploy

All in your workshop resource group, from `infra/workload` with `enable_mcp_server = true`:

| Resource | Purpose | Security setting |
|---|---|---|
| Flex Consumption plan (`FC1`) and Function App | Hosts the .NET 10 isolated worker MCP server | HTTPS only, TLS 1.2, basic publishing disabled, optional IPv4 allow-list |
| User-assigned managed identity | The app's only identity | No secret; three role assignments below |
| Storage account | Host storage, deployment package and the `tickets` queue | Shared key access **disabled**, Entra authorization by default, no public blobs |
| Log Analytics workspace and Application Insights | Payload-free telemetry | Local authentication disabled; 1 GB/day workspace cap |

Role assignments, each on one exact resource:

| Role | Scope | Why |
|---|---|---|
| Storage Blob Data Owner | The workshop Storage account | Functions host storage and Flex deployment package (identity-based) |
| Storage Queue Data Message Sender | The `tickets` queue only | `create_ticket` sends one synthetic message |
| Monitoring Metrics Publisher | The Application Insights component | Entra-authenticated telemetry |

The five tools (all data is synthetic):

| Tool | Kind | What it does at level 0 |
|---|---|---|
| `get_service_health` | read | Fixed health for `workshop-api` or `ticket-queue` |
| `create_ticket` | **write** | Validates `service`, `severity` and a short `summary`, then queues one synthetic ticket |
| `whoami` | demonstration | Says the caller is unknown: a key identifies no user |
| `read_report_as_user` | demonstration | Labeled synthetic report; the real On-Behalf-Of call arrives in module 05 |
| `read_report_as_app` | demonstration | Labeled synthetic report; the real managed-identity call arrives in module 05 |

Every tool refuses unknown arguments. `create_ticket` writes nothing unless the exact argument shape is valid.
Logs contain the tool name, outcome, latency and invocation ID only: never arguments, results, keys or tokens.

![Level 0 architecture](../../assets/architecture/02.en.svg)

No **Preview** feature is used. Code and infrastructure adapt
[Azure-Samples/remote-mcp-functions-dotnet](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9)
(MIT); see [THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md).

**Cost:** Flex Consumption bills per execution and memory time, plus Storage transactions and telemetry ingestion.
The plan scales to zero and is capped at 10 instances; there is no always-ready instance. Check current prices
for your region before approval. Clean up the same day.

## Prerequisites and required roles

- Module 00 validated for your subscription and module 01 completed.
- Your private parameters and Terraform state from module 00 (`.workshop/participant.tfvars.json`). Do not regenerate them.
- Terraform 1.16.6 or later, Azure CLI, PowerShell 7.4+, the .NET 10 SDK.
- A non-production subscription where Flex Consumption supports .NET 10 in your region (example: `swedencentral`).

Azure roles on the workshop resource group (ask your administrator; do not request Owner):

- **Contributor** to create the resources, read the system key and publish code.
- **Role Based Access Control Administrator**, ideally with a condition that allows only the three roles above,
  to create the three role assignments. Contributor alone cannot assign roles.

No Microsoft Entra change is needed in this module.

## Steps

### PowerShell

Run from the repository root. Stop at any failed command. Steps 3 to 6 change Azure: do them only after approval.

**1. Offline checks (no Azure).**

```powershell
& .\modules\02-open-server\validate.ps1 -Offline
```

**2. Select your approved context.**

```powershell
& .\scripts\select-azure-context.ps1
```

**3. Opt in privately, then plan.** The opt-in file is ignored by Git. Add your public IPv4 range to
`mcp_allowed_ip_ranges` (for example `"203.0.113.10/32"`) to restrict callers; keep the list empty to show the open level.

```powershell
'{ "enable_mcp_server": true, "mcp_allowed_ip_ranges": [] }' | Set-Content -LiteralPath .\.workshop\module02.tfvars.json
terraform -chdir=infra/workload init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-var-file=..\..\.workshop\module02.tfvars.json' '-out=..\..\.workshop\module02.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
```

Review the plan: it must only **add** the eleven module 02 resources. Keep passing both var files in every later plan,
otherwise Terraform proposes to delete the server.

**4. Apply the reviewed plan (after approval).**

```powershell
terraform '-chdir=infra\workload' apply '..\..\.workshop\module02.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform apply failed.' }
```

**5. Publish the server code.** Azure CLI uses your Microsoft Entra sign-in; no publishing password exists.

```powershell
$group = terraform -chdir=infra/workload output -raw resource_group_name
$app = terraform -chdir=infra/workload output -raw mcp_function_app_name
dotnet publish .\src\FunctionsMcpServer --configuration Release --output .\.workshop\module02-publish
if ($LASTEXITCODE -ne 0) { throw 'Publish failed.' }
Compress-Archive -Path .\.workshop\module02-publish\* -DestinationPath .\.workshop\module02.zip -Force
az functionapp deployment source config-zip --resource-group $group --name $app --src .\.workshop\module02.zip --output none
if ($LASTEXITCODE -ne 0) { throw 'Code deployment failed.' }
```

**6. Connect VS Code without saving the key.** Add this server to your **user** MCP configuration
(not to a committed file). VS Code prompts for the key and stores it in its secret storage.

```json
{
  "inputs": [
    { "type": "promptString", "id": "workshop-mcp-key", "description": "mcp_extension system key", "password": true }
  ],
  "servers": {
    "workshop-open": {
      "type": "http",
      "url": "https://<function-app-host>/runtime/webhooks/mcp",
      "headers": { "x-functions-key": "${input:workshop-mcp-key}" }
    }
  }
}
```

Get the endpoint with `terraform -chdir=infra/workload output -raw mcp_endpoint`.
Read the key only when VS Code asks, then clear the clipboard:

```powershell
az functionapp keys list --resource-group $group --name $app --query systemKeys.mcp_extension --output tsv | Set-Clipboard
```

After pasting it into the VS Code prompt, run `Set-Clipboard -Value $null`.
Never put the key in a URL (`?code=`), a file, a chat or a screenshot.

**7. Validate and show the risk.**

```powershell
& .\modules\02-open-server\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -DemonstrateWrite
```

In VS Code, ask the agent to call `create_ticket` with synthetic values. It works for anyone who holds the key.

**8. Rotate the key after the exercise.** This invalidates every copy that may have leaked.

```powershell
az functionapp keys set --resource-group $group --name $app --key-type systemKeys --key-name mcp_extension --output none
```

### Bash

```bash
bash ./modules/02-open-server/validate.sh -Offline
source ./scripts/select-azure-context.sh
printf '%s\n' '{ "enable_mcp_server": true, "mcp_allowed_ip_ranges": [] }' > .workshop/module02.tfvars.json
terraform -chdir=infra/workload init -lockfile=readonly &&
terraform -chdir=infra/workload plan -var-file=../../.workshop/participant.tfvars.json \
  -var-file=../../.workshop/module02.tfvars.json -out=../../.workshop/module02.tfplan
# Review, then after approval:
terraform -chdir=infra/workload apply ../../.workshop/module02.tfplan
group="$(terraform -chdir=infra/workload output -raw resource_group_name)"
app="$(terraform -chdir=infra/workload output -raw mcp_function_app_name)"
dotnet publish ./src/FunctionsMcpServer --configuration Release --output ./.workshop/module02-publish &&
(cd ./.workshop/module02-publish && zip -qr ../module02.zip .) &&
az functionapp deployment source config-zip --resource-group "$group" --name "$app" --src ./.workshop/module02.zip --output none
bash ./modules/02-open-server/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -DemonstrateWrite
az functionapp keys set --resource-group "$group" --name "$app" --key-type systemKeys --key-name mcp_extension --output none
```

Use the same VS Code configuration as in step 6.

## What you should see

| Action | Expected result | Meaning |
|---|---|---|
| MCP request without `x-functions-key` | HTTP 401 | The webhook is not anonymous. |
| Request with a wrong key | HTTP 401 | Only the system key works. |
| `initialize`, then `tools/list` with the key | HTTP 200, five tools | The server works over Streamable HTTP. |
| `create_ticket` with the key | HTTP 200, `status: queued`, a `warning` | **The risk:** no user, no role, no approval on the server. |
| `whoami` | `caller: unknown` | A key carries no identity. |
| `read_report_as_*` | `source: synthetic-demonstration` | Real downstream access is module 05. |

The live validator prints, among others:

```text
PASS MCP request without the mcp_extension key is refused (expected HTTP 401).
PASS anonymous access disabled: a random wrong key is refused (expected HTTP 401).
PASS MCP initialize with the key succeeds; negotiated protocol <version> (expected HTTP 200).
PASS tools/list with the key returns exactly the five workshop tools (expected HTTP 200).
PASS RISK SHOWN: create_ticket succeeds with only the key; no user or role was checked (expected HTTP 200).
```

## Validate

`validate.ps1` (or `validate.sh`) always runs offline checks first: `host.json` webhook level is `System`,
no anonymous level in code, no key or secret pattern in module files, Terraform keeps shared keys disabled and
outputs no key, locked build and unit tests, and Terraform mock tests. With `-Offline`, or without a tenant and
subscription, it stops there and says the module is **not** deployed or validated.

With `-TenantId` and `-SubscriptionId`, it checks the context, reads the endpoint from your Terraform state and the key
from Azure CLI **in memory only**, and runs the HTTP checks above. Every check prints one PASS or FAIL line.
The module is done only when the live checks pass on a fresh subscription right after modules 00 and 01.

## Troubleshooting

| Symptom | Check |
|---|---|
| HTTP 401 with the key | Use the `mcp_extension` **system** key, in the `x-functions-key` header. A function or host key is different. |
| Key is empty | The code is not published yet, or the host has not started. Publish (step 5), wait one minute, retry. |
| HTTP 403 | Your IP is not in `mcp_allowed_ip_ranges`. Update the private file and plan again. |
| HTTP 404 on `/runtime/webhooks/mcp` | Publish failed or used the wrong package folder. Check the deployment status in the portal. |
| Host does not start / storage errors | Role assignments can take a few minutes. Check the three assignments; never enable shared keys. |
| Plan proposes to delete the server | You forgot `-var-file=..\..\.workshop\module02.tfvars.json`. |
| `Unexpected argument` tool error | The tools accept only their documented arguments. This is intended. |

## Clean up

Run the clean-up after the exercise. It plans with the module disabled and refuses to continue unless every change
is a deletion of a module 02 resource. Run it once to review, then again with `-Apply`.
It is idempotent: when nothing remains, it says so and changes nothing.

```powershell
& .\modules\02-open-server\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
& .\modules\02-open-server\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
Remove-Item -LiteralPath .\.workshop\module02.tfvars.json, .\.workshop\module02.zip -ErrorAction SilentlyContinue
Remove-Item -LiteralPath .\.workshop\module02-publish -Recurse -ErrorAction SilentlyContinue
```

```bash
bash ./modules/02-open-server/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -Apply
```

The resource group, your private parameters and state stay for the next modules. Remove the `workshop-open`
server from your VS Code user configuration. If you continue to module 03 immediately, you may keep the server and
skip clean-up; module 03 replaces the key with Microsoft Entra authentication.

## Go further

- Restrict callers with `mcp_allowed_ip_ranges` and observe HTTP 403 from another network.
- Rotate the key and watch the old VS Code session fail with HTTP 401.
- Read the [threat model](../../docs/concepts/mcp-threat-model.md): which threats does a key not address?
- Next: [module 03 plan](../../docs/BUILD-PLAN.md#03--identity-with-microsoft-entra-level-1).

## Sources

- [Functions MCP bindings: host.json, endpoint, system key](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp)
- [MCP tool trigger](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp-tool-trigger)
- [Custom remote MCP server on Functions](https://learn.microsoft.com/azure/azure-functions/scenario-custom-remote-mcp-server)
- [Flex Consumption plan](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan)
- [Function access keys](https://learn.microsoft.com/azure/azure-functions/function-keys-how-to)
- [Identity-based connections and minimum host storage role](https://learn.microsoft.com/azure/azure-functions/functions-identity-based-connections-tutorial)
- [Azure-Samples/remote-mcp-functions-dotnet at 468c518](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9)
- [AzureRM 5.9.0 Flex Consumption resource](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/function_app_flex_consumption.html.markdown)
- [VS Code MCP configuration and inputs](https://code.visualstudio.com/docs/agent-customization/mcp-servers)

Last verified: 2026-10-14. Authored and checked offline only; not yet deployed or validated in Azure.
