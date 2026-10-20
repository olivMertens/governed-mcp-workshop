# 00 - Prepare the Terraform + PowerShell environment

[Français](README.fr.md)

## Goal

This is the **Terraform + PowerShell** guide. For portal-first preparation, use the separate [low-code guide](LOW-CODE.md).

Choose a local terminal or Visual Studio Code dev container. Verify the tools and your explicit
non-production Azure target. Prepare the request for the Microsoft Entra administrator.

## Why it matters

A working command line does not prove deployment rights or capacity. Random participant names avoid
accidental collisions; they do not increase shared subscription quotas. Your terminal, not the public
portal, authenticates to Azure.

> [!IMPORTANT]
> Use only an approved **non-production** tenant and subscription. Never run the workshop in production
> or in someone else's tenant.

See the [step-by-step architecture](../../assets/architecture/STEPS.md).
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
PowerShell or Functions Core Tools, so keep the baseline above. Run `scripts/check-tools.ps1` afterwards: it must still show Azure CLI 2.88.0 or later. If the Dev Pack install does not meet that minimum, use the standard Azure CLI install instead.

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

Run from the repository root.

> [!TIP]
> Run every check in the terminal you will actually use for the workshop. A check in another terminal
> proves nothing about this one.

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\check-tools.ps1
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry $expiry
& .\scripts\select-azure-context.ps1
& .\modules\00-prerequisites\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

> **Real result** — `check-tools.ps1` and live `validate.ps1` in the author's test subscription, 2026-10-17.
> The lines printed by the preparation and context scripts are described below the box. Names and IDs withheld.
>
> ```text
> PASS git (Git 2+; expected HTTP N/A)
> PASS az (Azure CLI >= 2.88.0; expected HTTP N/A)
> PASS terraform (Terraform >= 1.16.6, < 2; expected HTTP N/A)
> PASS dotnet (.NET SDK 10; expected HTTP N/A)
> PASS node (Node.js >= 22.19.0; expected HTTP N/A)
> PASS func (Functions Core Tools >= 4.5.0, < 5 (not the Preview v5 CLI); expected HTTP N/A)
> PASS PowerShell 7.6.7 (expected HTTP N/A)
> PASS local tools only; Azure context, permissions, quota and deployment remain separate checks.
> ...
> PASS explicit interactive context (expected HTTP N/A; no sign-in, token output or context change)
> PASS subscription region (expected HTTP 200; availability is not a capacity reservation)
> PASS provider Microsoft.Resources (expected HTTP 200; Registered)
> PASS required ARM permission grants (expected HTTP 200; deny assignments, policy and deployment approval remain separate)
> PASS resource group capacity (expected HTTP 200; below the documented 980-group limit)
> PASS foundation preflight only. No resource, registration, permission, login or context was changed. A real plan and separate approval are still required.
> PASS administrator request template present (expected HTTP N/A; approval and identity creation are separate)
> PASS module 00 foundation environment checks. Record only the verified workspace route and stage; this is not MCP runtime validation.
> ```
>
> **What it means for you:** your tools match the baseline, and your explicit test target can be read. Nothing was
> created. Between the two groups, `prepare-workshop.ps1` prints `PASS private participant parameters created with a
> stable random suffix.` (or `PASS existing participant parameters reused unchanged.` on a rerun), and the selector prints
> `PASS context: tenant and subscription verified. ...`. The live validator repeats the tool lines first (elided here).

![Real terminal output: module 00 validator, live and read-only; frame 1 marks your tools, frame 2 your rights and capacity in the subscription, frame 3 the final result](../../assets/screenshots/terminal-00-validate.png)

The same run as a real capture (2026-10-20, author's test tenant). Frame 1: your tools. Frame 2: you may deploy in this
subscription and it has room for a resource group. Frame 3: the line that says you are ready for module 01.

Use your approved region, labels and cleanup date. For an administrator-provided group, supply
`-ExistingResourceGroupName` on the **first** preparation command. Keep the generated suffix and state.
Read the context selector before running it: it asks for the approved target and `NONPROD`,
then signs in interactively and changes the active CLI subscription. Preflight itself never signs in or switches.

> [!WARNING]
> Do not paste account identifiers, tokens or account responses into the portal, a commit or chat.

Initialize the locked provider and run the separate local tests:

```powershell
terraform -chdir=infra/workload init -backend=false -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Provider initialization failed.' }
& .\modules\00-prerequisites\validate.ps1 -Offline
```

> **Real result** — offline run on the authoring host, 2026-10-17. Excerpt; your timings differ.
>
> ```text
> ✔ preflight is read-only and fails closed for context, permission, provider, quota, runtime and evidence errors (2819.2349ms)
> ...
> ℹ tests 19
> ℹ suites 0
> ℹ pass 19
> ℹ fail 0
> ...
> PASS local script/HTTP checks (expected HTTP N/A; no Azure access)
> Success! The configuration is valid.
> ...
> Success! 49 passed, 0 failed.
> PASS Terraform schema and mock-only plans (expected HTTP N/A; no live plan/apply)
> PASS offline checks only. Module 00 is NOT Azure-validated by this result.
> ```
>
> **What it means for you:** the scripts and Terraform code behave as designed against synthetic responses and mocks.
> `terraform init` first prints `Terraform has been successfully initialized!`. The last line is honest: no Azure check ran.

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

> **Expected result** — the same PASS lines as the PowerShell runs above (the wrappers call the same PowerShell scripts).
> The `read` prompt waits for your cleanup date; `source` keeps the `ARM_*` variables in this shell.

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

**Question:** every preflight line says `PASS`. Can you now deploy without asking anyone?

<details>
<summary>Show answer</summary>

No. Preflight only reads grants, providers and capacity. Deny assignments, Azure Policy and shared quota can still block
a deployment, and every real Terraform plan still needs separate review and approval.

</details>

**Question:** your first attempt failed. Why must you keep the same suffix and Terraform state instead of generating new names?

<details>
<summary>Show answer</summary>

The suffix and state are how Terraform and the cleanup scripts find what you created. New names would orphan earlier
resources and do not reset any quota.

</details>

## Validate

Use `validate.ps1` or `validate.sh` above in your approved fresh test subscription.
Also confirm that the administrator request is understood and can be sent privately.
Move on to module 01 only when every check prints `PASS`.


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

> **Real result** — authoring host, 2026-10-17.
>
> ```text
> PASS module 00 preflight cleanup (expected HTTP N/A): checks create no Azure or Entra resources.
> PASS private parameters and state preserved (expected HTTP N/A). Optional paid portal cleanup requires the reviewed Terraform destroy flow in docs/HOSTING.md.
> ```
>
> **What it means for you:** there is nothing to delete for module 00, and your private parameters stay in place for later modules.

```bash
bash ./modules/00-prerequisites/cleanup.sh
```

> **Expected result** — the same two PASS lines as the PowerShell run above.

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

Last verified: 2026-10-14.
