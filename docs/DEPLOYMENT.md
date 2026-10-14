# Your tenant. Your subscription. Your decision.

The Model Context Protocol (MCP) server belongs in your approved **non-production** environment.
This page prepares a deployment context. It is not a deployment procedure, and it does not certify your permissions.
Start by [choosing dev container or local tools](GETTING-STARTED.md).
Module 00's read-only preflight, validator and identity request are available.
Terraform contains the resource-group foundation and an optional public App Service; no MCP runtime is implemented.

> [!IMPORTANT]
> A Microsoft Entra tenant holds identities, applications and consent. An Azure subscription holds billed resources.
> A resource group is the workshop's resource boundary. These are different scopes and different administrative responsibilities.

## 1. Agree the boundary before signing in

Choose an approved test tenant and an Azure subscription associated with that directory.
Confirm your participant prefix, resource group, owner, expiry, region, budget and cleanup window.
Do not use production data, another person's session, or an employer's unapproved environment.
Keep tenant/subscription IDs and account details in your private terminal, not this board or the repository.

| Responsibility | Required authority | Not implied |
|---|---|---|
| Deploy workload | Approved resource operations on the workshop resource group | Contributor does not grant role-assignment authority. |
| Configure identities | An identity administrator approves exact apps, app roles, test users and consent | An Azure subscription role does not grant Entra administration. |
| Assign resource access | Separately authorized role assignments at the exact target scope | No subscription-wide Owner request by default. |
| Use a client | Approved public client ID, exact callback and scopes | VS Code preauthorization does not authorize Inspector. |
| Reuse existing IDs | Owner supplies approved identifiers and ownership boundaries | Do not modify or destroy those pre-existing identities. |

## 2. Select and verify in your own terminal

Review the context selector before running it. It uses interactive Azure CLI sign-in, selects your subscription,
then checks both IDs and the subscription state. It never calls a resource-creation or role-assignment command.
It rejects conflicting credential overrides instead of silently mixing authentication flows.
The confirmation is your assertion of approval, not an automatic production-environment detector.

### PowerShell 7

From your existing checkout in a PowerShell terminal:

```powershell
& .\scripts\select-azure-context.ps1
```

Use `&` in the current PowerShell process, **not** a new `pwsh -File` process.
The selector sets `ARM_TENANT_ID` and `ARM_SUBSCRIPTION_ID` only in that process.
It uses `az login --tenant`, `az account set --subscription` and `az account show`.
Follow your organization's browser and multifactor sign-in policy. Do not use a password or client secret.

### bash

```bash
source ./scripts/select-azure-context.sh en
```

Source the script in the same bash terminal. Executing it as `bash script.sh` is refused because environment
variables would disappear with the child process. Authentication and context checks are equivalent to PowerShell.

> [!WARNING]
> A failed check is a stop, not permission to continue with the previous default subscription.
> Re-select the approved context before any Terraform command. Never paste `az account get-access-token` output here.
> These helpers support Azure public cloud. A sovereign-cloud workshop requires a separately reviewed configuration.

## 3. Review the real module before a paid deployment

1. Complete module 00's published prerequisite/permission checks, then module 01's local MCP exercise.
   Context selection alone does not validate either module.
2. Prepare the private participant file using the start guide. Keep its random suffix and the same Terraform state.
   `infra/workload` manages a dedicated group or reads an approved existing group; the public portal is an explicit paid opt-in.
   Neither creates an MCP server.
   Wait for each runtime module's real guide, validation and cleanup. There is no enabled Deploy button in the board.
3. In the same terminal, review the actual `infra/workload` provider configuration and its subscription/tenant.
   Check AzureRM and AzAPI target the selected subscription, and AzureAD targets the approved tenant.
   An explicit provider setting or alias can override environment defaults; inspect every provider and the plan.
4. The identity administrator reviews `infra/entra` separately. Read existing IDs when creation is skipped.
   Use managed identities and federated identity credentials, never a client secret.
5. Review regional availability, quota, organization policy, tags and cost estimate. Standard v2 API Management
   is provisioned capacity. Private endpoints, storage, telemetry, API Center and optional agents can also cost money.
   A randomized group or service name avoids many collisions but does not reset shared subscription/regional quotas.
6. Read the Terraform plan's exact resources and role scopes. Apply only after explicit approval in the deployment
   session. Recheck context if you change terminals, subscriptions, provider configuration or credentials.
7. Run the module's real validator, retain only approved metadata/PASS lines, and do not proceed until it passes.

## 4. Call the server you actually deployed

Use the endpoint from **your deployment outputs**. Module 01 uses local standard input/output (stdio), not HTTPS.
Module 02 is a short-lived system-key demonstration. Module 03 adds the assigned-user identity boundary.
From module 04 onward, only the governed API Management URL is a client endpoint; the Function is private.

Sign in to the correct tenant with the approved client, exact callback and scopes. Use Alice/Bob/Eve only as
synthetic persona labels for dedicated test identities. Never enter tokens, keys or account credentials in the board.
Use **Try your MCP** to prepare client commands, then make and inspect actual calls in the official client.
An HTTP 200 can contain an MCP tool error. Each synthetic write requires an explicit role and individual approval.

> [!TIP]
> Predict the result before calling: missing token means 401; Bob's gateway write means 403; a burst means 429.
> For downstream delegation, inspect the MCP result as well as HTTP. A denial can be the correct demonstration.

## 5. End the cost and preserve shared objects

Follow module 99 after the paid stages; module 07 is optional. Review workload teardown before identity cleanup.
Only workshop-created resources, assignments and test identities may be removed, after explicit approval.
Preserve passed-in identities and shared infrastructure. Check tagged resources, private networking, inventory,
retention and soft-deletion behavior. Stop Inspector and unused codespaces too.

## Sources

- [Azure CLI subscription and tenant selection](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli).
- [Azure CLI interactive sign-in](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively).
- [Azure role assignment authority](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).
- [AzureRM authentication and provider configuration](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs).
- [Build plan](BUILD-PLAN.md), [practice guide](PRACTICE.md) and [source assessment](sources.md).

Last verified: 2026-10-14. No subscription was accessed or resource deployed to write this guidance.
