# Inspect your low-code environment

[Français](fr/LOW-CODE-DEPLOYMENT.md)

## 1. Check the terminal and portal context

Use PowerShell 7 at the root of your original checkout.
These commands read your target and resources; they do not deploy, switch subscriptions or call an MCP tool.
If you reopened the terminal, first run the context selector:

```powershell
& .\scripts\select-azure-context.ps1
```

> **Expected result** — after your approved IDs and `NONPROD` confirmation, interactive sign-in completes
> and the selector prints `PASS context: tenant and subscription verified. ...`.

In [Azure portal](https://portal.azure.com/), use the top-right account menu to select the same directory.
Open **Subscriptions > your subscription > Overview** and compare its ID with your approved private value.
Do not copy IDs or account output into the website or chat.

## 2. Find your exact group and tag

The saved participant file determines your names, even after you reopen the terminal.
A group supplied by the administrator keeps its original name.

```powershell
$ErrorActionPreference = 'Stop'
. .\scripts\context-common.ps1
Assert-WorkshopAzureContext -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
$p = Read-WorkshopParameters -Path .\.workshop\participant.tfvars.json
$prefix = "$($p.participant_prefix)lc"
$workshopTag = "mcp-$prefix-$($p.resource_suffix)"
$resourceGroup = if ($p.existing_resource_group_name) { $p.existing_resource_group_name } else { "rg-$workshopTag" }
$resourceGroup
$workshopTag
```

> **Expected result** — your group name and participant tag. Nothing was created.
> A missing file or context mismatch stops the command. Do not create replacement parameters for an existing deployment.

In the portal, open **Resource groups > the printed group > Overview**.
Check the subscription, **Tags**, and `workshop` value. A shared group's own tags may belong to the administrator:
check the tags on **your child resources** instead.

## 3. List only your resources

Keep this terminal; the command uses the variables from step 2.

```powershell
Assert-WorkshopAzureContext -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
az resource list --subscription $env:ARM_SUBSCRIPTION_ID --resource-group $resourceGroup `
    --query "[?tags.workshop=='$workshopTag'].{Name:name,Type:type,Location:location}" --output table --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Resource inspection failed. Check the target and scoped read permissions.' }
```

> **Expected result** — a table containing only resources with your tag in the selected group.
> No token or message body is read. An error is a failure, not an empty successful result.

Do not remove the group or tag filter to find more results. An empty table does **not** prove complete cleanup:
Microsoft Entra objects, soft-deleted services and optional Foundry groups are separate.
Use [low-code module 99](../modules/99-cleanup/LOW-CODE.md) to check them.

## 4. Check identity and behavior separately

In [Microsoft Entra admin center](https://entra.microsoft.com/), select the same directory.
Open **Identity > Applications > App registrations** and the exact API application identified in your private module 03 setup.
Under **App roles**, inspect `Tools.Read` and `Tools.Write`.
Under **Enterprise applications**, inspect its assignments to Alice and Bob; Eve must remain unassigned.
An application existing does not prove that authentication, authorization or client approval works.
Use the complete validator command in the low-code guide for the module you just deployed.

## Sources

- [Azure CLI resource list](https://learn.microsoft.com/cli/azure/resource#az-resource-list).
- [Azure portal directories and subscriptions](https://learn.microsoft.com/azure/azure-portal/set-preferences).
- [Module 00 source baseline](../modules/00-prerequisites/LOW-CODE.md#sources).

Last verified: 2026-10-20 for the resource-list command and portal directory settings.
No new live deployment is claimed.
