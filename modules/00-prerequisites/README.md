# 00 - Prepare the approved environment

[Français](README.fr.md)

## Goal

Choose a local terminal or Visual Studio Code dev container. Verify the tools and your explicit
non-production Azure target. Prepare the request for the Microsoft Entra administrator.

## Why it matters

A working command line does not prove deployment rights or capacity. Random participant names avoid
accidental collisions; they do not increase shared subscription quotas. Your terminal, not the public
portal, authenticates to Azure.

See the [step-by-step architecture](../../assets/architecture/STEPS.md) and
[actual implementation status](../../docs/IMPLEMENTATION-STATUS.md).
The diagram is a learning target, not proof that identities or resources have been deployed.

## What you deploy

The preflight deploys **nothing**. It reads context, regions, providers and effective permission grants.
The shared Terraform root can create one isolated resource group, or read an existing approved group
without managing it. [Optional public portal hosting](../../docs/HOSTING.md) adds a paid App Service plan
and website only after an explicit opt-in. No Model Context Protocol (MCP) server exists yet.

## Prerequisites and required roles

Use the [workspace and installation guide](../../docs/GETTING-STARTED.md).
The selected baseline is Terraform 1.16.6, AzureRM 5.9.0, Azure CLI 2.88.0, .NET software development kit
(SDK) 10, PowerShell 7.4+, Node.js 22.19+ and Functions Core Tools v4 >= 4.5.0.
The separate Functions command-line interface (CLI) v5 is **Preview** and is not selected.

**Optional shortcut:** the [Microsoft Foundry Dev Pack](https://devblogs.microsoft.com/foundry/foundry-devpack-announcement/)
can install Azure CLI, Azure Developer CLI (`azd`) and the Foundry extension in one step
(Windows: `winget install Microsoft.FoundryDevPack`). It does **not** install Terraform, the .NET SDK, Node.js,
PowerShell or Functions Core Tools, so keep the baseline above. Run `scripts/check-tools.ps1` afterwards: it must still showAzure CLI 2.88.0 or later. If the Dev Pack install does not meet that minimum, use the standard Azure CLI install instead.

For a new group, the explicit subscription scope needs resource-group read/write/delete grants.
For an existing group, use that group's scoped permissions; do not obtain subscription Owner just for this lab.
The script evaluates Azure Resource Manager (ARM) `actions` minus `notActions` within each permission record,
then combines grants. A separate grant can authorize an action excluded from another record.
It follows same-scope HTTPS pagination and refuses redirected permission hosts.
Deny assignments and Azure Policy can still block deployment; grants alone are not full authorization.

No Entra administration is required to run this module. The identity administrator reviews the
[exact request](../../docs/requests/identity-request.md) separately before module 03.
Provider registration and role grants are administrator actions, never side effects of preflight.

## Steps

### PowerShell

Run from the repository root. Use the route you will actually use for the workshop.

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\check-tools.ps1
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry $expiry
& .\scripts\select-azure-context.ps1
& .\modules\00-prerequisites\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

Use your approved region, labels and cleanup date. For an administrator-provided group, supply
`-ExistingResourceGroupName` on the **first** preparation command. Keep the generated suffix and state.
Read the context selector before running it: it asks for the approved target and `NONPROD`,
then signs in interactively and changes the active CLI subscription. Preflight itself never signs in or switches.
Do not paste account identifiers, tokens or account responses into the portal, a commit or chat.

Initialize the locked provider and run the separate local tests:

```powershell
terraform -chdir=infra/workload init -backend=false -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Provider initialization failed.' }
& .\modules\00-prerequisites\validate.ps1 -Offline
```

### bash

PowerShell is also installed inside the dev container. The wrappers run the same checks.

```bash
bash ./scripts/check-tools.sh
read -r -p 'Approved cleanup date (yyyy-MM-dd): ' expiry
bash ./scripts/prepare-workshop.sh -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry "$expiry"
source ./scripts/select-azure-context.sh
bash ./modules/00-prerequisites/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
terraform -chdir=infra/workload init -backend=false -lockfile=readonly &&
bash ./modules/00-prerequisites/validate.sh -Offline
```

For a later billable stage, use `-Stage portal` or `-Stage mcp` and `-CapacityReviewPath` pointing to
private evidence described in [hosting](../../docs/HOSTING.md). The `mcp` checks are a future baseline,
not a declaration that later Terraform modules, every nested operation or runtime checks already exist.
That baseline includes role-assignment authority: arrange separate scoped administrator execution rather
than giving every participant a wider role. Actual future modules must refine their required operations.

## What you should see

Each environment check prints `PASS` or stops with an error. HTTP means Hypertext Transfer Protocol.
Cloud reads expect HTTP 200; local checks say `N/A`. Azure CLI failures are reported without dumping
account responses. The foundation stage checks the documented 980-resource-group subscription limit.
An existing-group route does not require capacity for a new group.

Offline checks use synthetic Azure responses and provider mocks. Their final line explicitly says that
module 00 is **not Azure-validated**. A host tool check does not validate the container.
Container/Codespaces execution remains unverified in the authoring environment until an approved engine is available.

## Validate

Use `validate.ps1` or `validate.sh` above in your approved fresh test subscription.
Record the stage, terminal route, date and non-sensitive PASS lines in `docs/PROGRESS.md`.
Before marking this module validated, confirm the administrator request is understood and can be submitted
privately. Do not mark future service capacity or another workspace route validated by implication.
Only after real module 00 validation may you begin module 01.

## Troubleshooting

- Wrong context or authentication override: use an approved, separate interactive-user terminal.
  Preflight rejects mixed service-principal, certificate, federation and managed-identity overrides.
- Missing provider: ask the administrator to review registration of the **named** provider. Do not run automatic registration.
- Permission failure: verify the action and scope. Prefer an existing approved group over increasing subscription rights.
- Capacity failure: names do not change quotas. Review the portal quota, planned maximum instances and shared cohort demand.
- Core Tools npm shim without its binary: finish the approved installation. The checker refuses to trigger a first-run download.
- Policy/deny failure during the real plan: resolve it with the administrator; do not disable the control.

## Clean up

```powershell
& .\modules\00-prerequisites\cleanup.ps1
```

```bash
bash ./modules/00-prerequisites/cleanup.sh
```

Preflight creates no resources. Cleanup preserves private parameters and state. If you separately applied
the group/optional portal Terraform, use its [reviewed destroy flow](../../docs/HOSTING.md#clean-up).
Stopping an App Service is not the same as deleting its paid plan. Never delete a shared group as a shortcut.

## Go further

Review [governance](../../docs/LEARNING-GUIDE.md), [identity ownership](../../docs/requests/identity-request.md)
and the [planned architecture](../../assets/architecture/00.en.svg).
The optional portal is public documentation only, not an authenticated internal site or cross-tenant control plane.

## Sources

- [Azure CLI installation](https://learn.microsoft.com/cli/azure/install-azure-cli).
- [Terraform on Azure](https://learn.microsoft.com/azure/developer/terraform/overview).
- [PowerShell installation](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
- [.NET 10](https://dotnet.microsoft.com/download/dotnet/10.0).
- [Functions local tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local).
- [Resource-group permissions API](https://learn.microsoft.com/rest/api/authorization/permissions/list-for-resource-group).
- [Subscription limits](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).
- [Flex capacity and runtimes](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan).
- [VS Code containers](https://code.visualstudio.com/docs/devcontainers/containers).
- [Pinned choices and upstream sample](../../docs/sources.md).
- [Foundry Dev Pack announcement](https://devblogs.microsoft.com/foundry/foundry-devpack-announcement/) (optional installer shortcut).

Last verified: 2026-10-14. Local tests are not a live Azure deployment or container validation.
