# 00 - Prepare the low-code environment

[Français](LOW-CODE.fr.md)

## Goal

Prepare your own terminal and approved non-production Azure subscription for the **portal-first low-code track**.
You do not need Terraform. Module 01 is shared; from module 02 onwards, keep using the low-code guides.

## Why it matters

The portal and terminal must use the same directory and subscription. A successful sign-in does not prove
that you may create resources. These checks read your environment; they do not grant permission or deploy.

> [!IMPORTANT]
> Get approval for your own non-production tenant and subscription before continuing.
> Never use another participant's environment. No token, password or account output belongs in this repository or chat.

## What you deploy

Nothing. One local, ignored participant file holds stable names and tags for later modules.
It is called `.workshop/participant.tfvars.json` for compatibility with the shared preparation script.
The low-code guides read its JSON values directly; they do not use Terraform.

## Prerequisites and required roles

- Your own checkout of this repository. Start with the clone instructions in the
  [workspace guide](../../docs/GETTING-STARTED.md#0-get-the-repository-onto-your-computer) if needed.
- Git 2+, PowerShell 7.4+, Azure CLI 2.88.0+, .NET software development kit (SDK) 10,
  Node.js 22.19.0+ and Azure Functions Core Tools v4, version 4.5.0 or later, below 5.
  The separate Functions command-line interface (CLI) v5 is **Preview**; do not use it here.
- An approved account and subscription. For a new resource group, group creation and deletion
  must be authorized at subscription scope. A resource-group Contributor cannot create a sibling group.
  Prefer an administrator-provided group rather than requesting broader rights.
- No Microsoft Entra administrator role is needed for these checks. Module 03 has separate administrator actions.

On Windows, install only missing tools using your approved process:

| Tool | Installation |
|---|---|
| Git | `winget install --id Git.Git --exact` |
| PowerShell 7 | `winget install --id Microsoft.PowerShell --exact` |
| Azure CLI | `winget install --id Microsoft.AzureCLI --exact` |
| .NET SDK 10 | `winget install --id Microsoft.DotNet.SDK.10 --exact` |
| Node.js | `winget install --id OpenJS.NodeJS.LTS --exact` |
| Functions Core Tools v4 | Use the [official installer](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools) for your platform |

Close and reopen PowerShell 7 after installing tools. WinGet versions can change: the next check verifies the accepted versions.
Do not bypass workstation restrictions. The optional dev container includes extra tools; it is not required for this track.

## Steps

### 1. Open the correct terminal

In Visual Studio Code, open your checkout, then **Terminal > New Terminal** and choose **PowerShell 7**.
Run from the repository root, where `README.md`, `modules` and `scripts` are visible.
Do not run these commands in Azure Cloud Shell: publishing later uses your local checkout.

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\check-tools.ps1 -Track low-code
```

> **Expected result** — one `PASS` per required tool, followed by
> `PASS local tools only; Azure context, permissions, quota and deployment remain separate checks.`
> There is no Terraform check. Stop at any `FAIL`; fix that tool before continuing.

### 2. Save your participant names once

Choose your assigned participant prefix, approved region, non-sensitive owner label and cleanup date.
The following values are examples; replace them with the choices approved for your workshop.
The expiry tag is a reminder, not automatic deletion.

```powershell
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry $expiry
```

> **Expected result** — `PASS private participant parameters created with a stable random suffix.`
> A rerun with the same settings says `PASS existing participant parameters reused unchanged.`
> The script creates no Azure resource.

If the administrator supplied a resource group, add `-ExistingResourceGroupName` with that group's exact name
to the **first** preparation command. Do not edit the participant file to change names after deploying.

Keep `.workshop` private, in this checkout. Do not copy another participant's file.
New low-code resources add `lc` to the participant prefix; a supplied group keeps its existing name.
Later guides reconstruct these names from this file even after you reopen the terminal.

### 3. Sign in and verify the subscription

Keep the same terminal. Have the approved directory (tenant) ID and subscription ID ready.
Find them in **Azure portal > Subscriptions > your subscription > Overview**.
Use your own IDs locally, never the values shown in someone else's capture.

```powershell
& .\scripts\select-azure-context.ps1
& .\modules\00-prerequisites\validate.ps1 -Track low-code `
    -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

> **Expected result** — the selector asks for your approved target and confirmation `NONPROD`,
> opens interactive sign-in, then prints `PASS context: tenant and subscription verified. ...`.
> The validator prints `PASS` for tools, explicit context, region, provider, required grants and group capacity,
> followed by `PASS module 00 foundation environment checks. ...`. Reads expect HTTP 200; local checks say `N/A`.

In the portal, use the top-right account menu and **Switch directory** if necessary.
Open **Subscriptions**, select the subscription and compare its ID with your approved private value.
Do not continue if the terminal and portal show different targets.

> [!WARNING]
> A `PASS` is not deployment approval. Policies, deny assignments, shared quotas and service capacity can still block later work.
> Ask the administrator about the specific refusal; do not disable a control.

### 4. Prepare the identity administrator request

Open the [identity request](../../docs/requests/identity-request.md).
Send it through your approved private channel before module 03. Ask the administrator to confirm
the API registration, the Alice/Bob/Eve test identities, assignments and consent needed by that module.
Do not create real-user test data or ask for a tenant-wide administrator role for yourself.

### Using bash

PowerShell remains installed because the wrappers use the same checks. Run from the same checkout:

```bash
bash ./scripts/check-tools.sh -Track low-code
read -r -p 'Approved cleanup date (yyyy-MM-dd): ' expiry
bash ./scripts/prepare-workshop.sh -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry "$expiry"
source ./scripts/select-azure-context.sh
bash ./modules/00-prerequisites/validate.sh -Track low-code -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
```

> **Expected result** — the same tool and foundation `PASS` lines, without Terraform.
> `source` keeps the selected context variables in your shell.

## What you should see

Every check prints `PASS`. Nothing appears in **Resource groups** as a result of this module.
Your local participant file exists; your portal and terminal point to the approved target.
An empty resource list is not proof of later cleanup.

**Question:** all checks pass. Can you deploy without approval?

<details>
<summary>Show answer</summary>

No. These checks read context and grants. Approval, capacity and policy checks remain separate.

</details>

## Validate

Use the complete module 00 validator command in step 3.
Do not omit `-Track low-code`: the default is the infrastructure-as-code tool baseline.
Stop on any failure. Once all checks pass and the administrator request is ready, open
[module 01](../01-discover-mcp/README.md), then [low-code module 02](../02-open-server/LOW-CODE.md).

## Troubleshooting

- **Wrong terminal:** open PowerShell 7, not Windows PowerShell 5.1; return to the checkout root.
- **Wrong target or mixed authentication:** use an approved interactive-user terminal. The validator rejects conflicting authentication overrides.
- **Missing provider:** ask the administrator to review the named provider. The check does not register it.
- **Permission refused:** identify the exact action and scope. Prefer the approved existing-group route to broader rights.
- **Core Tools package without a binary:** finish the approved installation. The check does not trigger a first-run download.
- **Container/Codespaces:** run checks inside your chosen workspace. A host check does not validate a container.
  The optional container routes have not been live validated in the author's environment.

## Clean up

This module creates no cloud resources. Keep the private participant file for subsequent modules and cleanup.
If you stop after later modules, use [low-code module 99](../99-cleanup/LOW-CODE.md), even if your deployment failed part-way.
Never delete a shared resource group.

## Go further

Read [MCP concepts](../../docs/MCP-CONCEPTS.md) before your first call.
The [track overview](../../docs/TRACKS.md) lists the remaining low-code guides in order.

## Sources

- [Azure CLI installation](https://learn.microsoft.com/cli/azure/install-azure-cli).
- [PowerShell installation](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
- [.NET 10](https://dotnet.microsoft.com/download/dotnet/10.0).
- [Functions local tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local).
- [Resource-group permissions API](https://learn.microsoft.com/rest/api/authorization/permissions/list-for-resource-group).
- [Subscription limits](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).

Source verification inherited from module 00: 2026-10-14. Guide separated: 2026-10-20; a fresh live participant run remains required.
