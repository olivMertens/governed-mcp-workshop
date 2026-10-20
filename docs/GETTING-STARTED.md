# Get started

**Participant:** use the portal link your presenter sends, choose EN/FR and your deployment track, then start at module 00.
There is no workspace selection step in the portal. Run commands in your terminal.
The site uses PowerShell 7 throughout, on Windows, macOS and Linux. There is no shell to choose.
Bash alternatives remain in the repository guides and scripts, not in the site's lessons or PDF exports.
The optional container and Codespaces setup details below are reference material, not another required choice.
You do not need another App Service or the presenter's administrator account.
Without a portal, follow these Markdown guides.
**Presenter:** use the separate [publishing how-to](PRESENTER.md).

**Try MCP without Azure first:** after cloning and installing .NET 10/PowerShell 7,
use [module 01](../modules/01-discover-mcp/README.md). The presenter portal is optional documentation hosting.

Use **Visual Studio Code (VS Code)** with a dev container, or use your own terminal.
These workspace choices are independent of your deployment track.
Visual Studio IDE is a different product; the container instructions here use the VS Code Dev Containers extension.
No Copilot subscription or canvas is required to read the Markdown guides or run the scripts.

**Choose your deployment track separately:** after cloning below, use
[low-code module 00](../modules/00-prerequisites/LOW-CODE.md) for the portal-first tool list and checks,
or [Terraform module 00](../modules/00-prerequisites/README.md).
The low-code guide is self-contained: you do not need the Terraform installation or commands below.

## 0. Get the repository onto your computer

For a local terminal or VS Code dev container, start with a checkout.
For Codespaces, skip to the workspace choice below.

**On Windows, if Git and PowerShell 7 are missing**, run these commands one at a time
in your terminal, using your organization's approved installation process:

```powershell
winget install --id Git.Git --exact
winget install --id Microsoft.PowerShell --exact
```

Close the terminal and open **PowerShell 7** (`pwsh`), not Windows PowerShell 5.1.
If WinGet is unavailable or blocked, use the official installers linked below.
Do not bypass workstation policies.

**Clone `main`** into a folder under your user profile:

```powershell
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path "$HOME\source" -Force | Out-Null
Set-Location "$HOME\source"
git clone --branch main https://github.com/olivMertens/governed-mcp-workshop.git
if ($LASTEXITCODE -ne 0) { throw 'Clone failed. Do not continue in another directory.' }
Set-Location .\governed-mcp-workshop
```

Or, using bash in a folder where you keep projects:

```bash
git clone --branch main https://github.com/olivMertens/governed-mcp-workshop.git && \
  cd governed-mcp-workshop
```

**Expected:** `README.md`, `scripts` and `infra` are in the current folder.
Run the following commands from this folder. If VS Code is installed, open it with `code .`.
Each participant needs their own checkout. The repository is public: cloning needs no GitHub account or GitHub CLI.

<details>
<summary>Already have a checkout? Find it and update it</summary>

Return to **your original checkout**, especially if you have deployed resources.
Use `git branch --show-current` to confirm that you are on `main`.
When tracked files have no local changes:

```powershell
if (git status --porcelain) { throw 'Preserve your local changes before updating.' }
git pull --ff-only
if ($LASTEXITCODE -ne 0) { throw 'Update refused. Do not force a merge.' }
```

Keep `.workshop` and Terraform state private. Do not delete them, clone again to
"start over", or use `git clean` to fix an update problem.

</details>

## 1. Pick one route

| Route | What you need | Start here |
|---|---|---|
| VS Code dev container | VS Code, Dev Containers extension, approved reachable Linux container engine, internet for public packages | Open this checkout with `code .`, then **Dev Containers: Reopen in Container**. |
| Local terminal | Git, PowerShell 7.4+, Azure CLI, .NET SDK, Node.js, Functions Core Tools; Terraform only for its track | Keep the checkout local. Install your track's tools using your organization's approved process. |
| Codespaces (optional) | GitHub access, quota and cost approval | [Choose branch and machine](https://codespaces.new/olivMertens/governed-mcp-workshop). It uses the same `.devcontainer`, but only after these files are published. |

The container mounts the checkout. It does **not** mount your host Azure credential directory or engine socket,
sign you into Azure, or provision resources. Review feature install scripts and VS Code's Git credential sharing
before trusting a repository. The engine itself is a privileged trust boundary.
Keep Inspector ports private; use VS Code desktop/private forwarding, never public forwarded ports.

### Dev container details

The Ubuntu 24.04 base and official Dev Container Features are pinned by digest in
`.devcontainer/devcontainer.json`. Tool selections are Azure CLI 2.88.0, Terraform 1.16.6,
.NET SDK 10.0.402, PowerShell 7.6.6, Node.js 22.22.0 and Functions Core Tools 4.14.0.
The creation hook installs the pinned Core Tools package and runs the **same** `check-tools.ps1` as the local route.
Package repositories, package dependencies and editor extensions can change; image/feature digests do not make
every downloaded dependency immutable. Review pins regularly and rebuild deliberately.

Docker must answer `docker version` and `docker info`, not merely be installed.
For Podman 5+, use the [VS Code alternative-engine guidance](https://code.visualstudio.com/remote/advancedcontainers/docker-options):
verify `podman version`, `podman info` and, on Windows/macOS, `podman machine list`;
then set **Dev Containers: Docker Path** to `podman` yourself. Do not create a new machine, change sockets,
or expose a TCP API as a workaround. VS Code does not officially support every Docker-compatible CLI.
The container does not use Compose or nested containers.

**Verification boundary:** configuration and public registry pins were checked, but no reachable container engine
was available on the authoring machine. A container build, both Linux architectures and Codespaces runtime still
need the module 00 validation gate. A file being present is not proof that your engine or corporate network works.
If the build fails, inspect **Dev Containers: Show Container Log**. Resolve the actual registry/proxy/platform error;
do not bypass certificate validation or quietly switch tools/engines. Use the local route if approved.

### Local installation guidance

The dev container and Codespaces provide their own installation path; do not install everything twice.
On Windows, install only missing or outdated tools. Run each command separately, check its result,
and follow your organization's approval process.

| Tool | Windows command or installer |
|---|---|
| Azure CLI, to connect to Azure | `winget install --id Microsoft.AzureCLI --exact` |
| Terraform, only for the Terraform track | `winget install --id Hashicorp.Terraform --exact` |
| .NET SDK 10, for the C# server | `winget install --id Microsoft.DotNet.SDK.10 --exact` |
| Node.js, a supported LTS release | `winget install --id OpenJS.NodeJS.LTS --exact` |
| Azure Functions Core Tools **v4** | [Official Windows installers](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools): choose the version for your platform. |

After installation, close and reopen **PowerShell 7**, then return to the repository folder.
WinGet installs versions from its catalog; step 2 checks the accepted minimums below.
If a version is too old, use the official installer or ask your administrator.
On macOS/Linux, use the official installation guide for your operating system.

| Tool | Accepted by the shared check | Official installation guide |
|---|---|---|
| Git | 2+ | [Git downloads](https://git-scm.com/downloads) |
| PowerShell | 7.4+ | [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| Azure CLI | 2.88.0+ | [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Terraform (Terraform track only) | 1.16.6+, below 2 | [Install Terraform](https://developer.hashicorp.com/terraform/install) |
| .NET SDK | 10 installed | [.NET download](https://dotnet.microsoft.com/download/dotnet/10.0) |
| Node.js | 22.19.0+ | [Node.js download](https://nodejs.org/en/download) |
| Functions Core Tools | 4.5.0+, below 5 | [Core Tools installation](https://learn.microsoft.com/azure/azure-functions/functions-run-local) |

Use Core Tools v4, not the separate **Preview** Functions CLI v5. Some npm Core Tools wrappers download their
binary on the first invocation. The checker refuses incomplete known npm shims instead of starting a download.
Finish the approved installation separately; a package entry alone proves nothing.
No script in this repository installs workstation tools or changes your engine automatically.

## 2. Check the terminal you will actually use

The commands below use the Terraform baseline. For low-code, follow its
[module 00](../modules/00-prerequisites/LOW-CODE.md), which passes `-Track low-code` and does not check Terraform.

Run inside the container if you chose it; otherwise run on the host. A host check does not validate a container.
From the repository root, PowerShell:

```powershell
& .\scripts\check-tools.ps1
```

Or bash (PowerShell remains a prerequisite, including on macOS/Linux):

```bash
bash ./scripts/check-tools.sh
```

Resolve every `FAIL`. These checks execute only local tool version commands.
They do not check Azure permissions, service availability, policies, quota, or deployed behavior.

## 3. Prepare private, isolated participant names

Review the script. Choose a participant label, approved region, non-sensitive owner label and short cleanup date.
The next example uses synthetic labels, not a prescribed region or account.

```powershell
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry $expiry
```

```bash
read -r -p 'Approved cleanup date (yyyy-MM-dd): ' expiry
bash ./scripts/prepare-workshop.sh -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry "$expiry"
```

The script creates `.workshop/participant.tfvars.json`, ignored by Git, with a cryptographically random
suffix. Even if everyone uses `p01`, each independent preparation gets its own names.
Use a separate checkout, private parameter file and Terraform state per participant; do not copy another person's files.
It never contacts Azure. Repeating the same command reuses the exact saved file;
conflicting settings fail instead of silently changing names. Keep this file and Terraform state through cleanup.
The expiry is a tag, **not automatic resource deletion**.

If an administrator already supplied an approved group, add `-ExistingResourceGroupName` with its exact name
to the **first** preparation command. Terraform reads that group through a data source. It does not import,
rename, tag or delete the group. Child resources will still use the participant suffix.
A new group requires separately approved subscription-level group-creation rights; resource-group Contributor
alone cannot create a sibling group. Prefer the existing-group route rather than widening participant roles.

> [!WARNING]
> A new name or resource group does not reset subscription, regional or service quotas.
> Check shared workshop capacity, policy, global name availability and provisioned API Management costs separately.
> If a service denies a name, investigate before the first apply. Never rename an already deployed group casually.

<details>
<summary>More detail: resource names and safe reruns</summary>

Fresh preparations save 16 lowercase hexadecimal characters (64 random bits) once, not on every deployment.
An existing 10-character suffix and all its resource names remain unchanged.
In the table, `participant` has 2-8 lowercase letters/digits, starting with a letter;
`short` is its first six characters, or the whole prefix if shorter. Never shorten the random suffix.

| Resource | Fresh name | Azure constraint |
|---|---|---|
| New resource group | `rg-mcp-<participant>-<suffix>` | 1-90 characters; unique within the subscription |
| Storage account (planned) | `st<short><suffix>` | 3-24 lowercase letters/digits; globally unique |
| Function App (planned) | `func-mcp-<short>-<suffix>` | Globally unique app name; kept within 32 characters to avoid host-ID truncation |
| API Management (planned) | `apim-mcp-<participant>-<suffix>` | 1-50 letters/digits/hyphens; globally unique |
| Optional App Service plan | `plan-mcp-<participant>-<suffix>-portal` | 1-60 characters; unique within the group |
| Optional portal app | `web-mcp-<participant>-<suffix>-portal` | 2-60 letters/digits/hyphens; globally unique app name |

The Terraform output contains **planned names**, not proof of deployment or a name reservation.
Randomness makes accidental collisions unlikely, not impossible; check global availability before deployment.
An approved existing group keeps its exact name; participant resources still get separate names.
If parameters are missing but known local state, backend metadata or saved plans remain, preparation stops.
Restore the original private file. Custom/remote state cannot always be detected; never regenerate names to repair a deployment.

Do not randomize protocol values, tool names, scopes, app roles or service-required private Domain Name System (DNS) zone names.
Later identity and network modules still need their own isolation and address-space review; they are not implemented yet.

</details>

## 4. Understand the Terraform boundary

`infra/workload` is the Terraform root for **your** resources: the resource-group foundation, then each module turns
on its part with an opt-in variable (Function App in 02, Entra authentication in 03, API Management in 04, delegated and
app-only access in 05). `infra/entra` holds the Microsoft Entra objects, run by an identity administrator (or by you
in a test tenant where you have that role). Nothing is deployed until you apply a reviewed plan. The paid portal is
disabled by default; [hosting](HOSTING.md) documents explicit persistent opt-in and deployment.
The [section 5 deployment map](#5-deployment-map-what-you-deploy-module-by-module) lists what each module adds.
The [module 00 guide](../modules/00-prerequisites/README.md), read-only preflight and administrator request are available.
Run its real environment checks before the foundation plan. The authoring evidence validates the local-terminal
route only; every participant must repeat the checks for their own target.

### Sign into your test tenant

After preparing the parameters in step 3, use **the same PowerShell 7 terminal**:

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\select-azure-context.ps1 -Language en
& .\modules\00-prerequisites\validate.ps1 `
    -TenantId $env:ARM_TENANT_ID `
    -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

The selector asks for your **approved** tenant and subscription IDs and the confirmation `NONPROD`.
It runs `az login --tenant`, selects the subscription with `az account set`, and verifies the context.
`ARM_TENANT_ID` and `ARM_SUBSCRIPTION_ID` stay in this terminal for Terraform.
Get these IDs privately from your administrator; do not post them to GitHub or the portal.

**Expected:** a verified context followed by `PASS module 00 foundation environment checks.`
Signing in does not grant new permissions, and the validator creates no resources.
On failure, stop and use the [Azure context guide](DEPLOYMENT.md).

**Test accounts and MFA:** your test tenant may require multifactor authentication (MFA).
The first time Alice, Bob or Eve signs in, Microsoft Entra asks the account to register a method,
for example an authenticator app. Register it in the browser that opens. Never weaken Conditional Access to skip it.

### How to read validator output

Every module has a `validate.ps1`; `validate.sh` runs the same script, so the output is identical.

- The first line says what the module proves.
- `== Step N: ... ==` headers group the checks. The `Why:` line under each header says what that step proves.
- Each check prints one line: `PASS` or `FAIL`, then what was checked and the HTTP status it expects,
  for example `(expected HTTP 401)`. `INFO` lines explain a skipped or manual check.
- The last line gives the result. One `FAIL` means stop and read the module's Troubleshooting section.

Module 03 shows a [real annotated capture](../modules/03-entra-authentication/README.md#steps) of this output.

<details>
<summary>More detail: review a Terraform plan and preserve its state</summary>

Select your approved context with the [Azure context guide](DEPLOYMENT.md), **in the same terminal** as Terraform.
Then, only in an approved deployment session, review the actual foundation plan:

```powershell
terraform -chdir=infra/workload init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\workload.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
```

```bash
terraform -chdir=infra/workload init -lockfile=readonly &&
terraform -chdir=infra/workload plan -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/workload.tfplan
```

Plan can read Azure. Neither command is run by the board. Do not apply until the exact plan, ownership, permissions,
quota and costs are approved. No `-auto-approve`. Provider registration is disabled; an administrator registers
the exact required providers separately. Azure role assignments and Entra administration are separate permissions.
Never substitute a broad Owner assignment, client secret or production subscription.

Use one checkout/state location for the whole deployment. Switching local/container within the same mounted
checkout preserves files, but a different clone or codespace has different local state. Do not redeploy there:
restore the private parameters and state securely, or configure an approved isolated remote backend first.
Do not commit, upload to the board or share state, saved plans, CLI credentials or participant files.

</details>

The [module 01 local exercise](../modules/01-discover-mcp/README.md) is now runnable with .NET 10 and PowerShell 7,
without Azure sign-in, Terraform or the presenter portal. Its validator and Inspector CLI checks pass locally;
client approval remains manual. Complete module 00 on the workspace route you actually selected before cloud work.
After paid stages, follow module 99. Review destroy against the same state; preserve existing groups and identities.
Do not delete an entire group to bypass an incomplete Terraform cleanup.

## 5. Deployment map: what you deploy, module by module

You build **one** environment, step by step. Each module adds one layer to the previous one. Three rules keep it safe:

1. **One checkout, one private folder, one Terraform state** (the `.workshop` folder), from module 00 to module 99. Never clone again to
   "start over".
2. **Each module adds one small private file** in `.workshop` (ignored by Git). It holds switches and IDs, never a secret.
3. **Every plan passes every private file that exists** (for `infra/workload`), in the order of the table. If you drop a file,
   the plan removes what that file turned on.

| Module | Terraform root | Private file you add | What appears in your tenant | You should see |
|---|---|---|---|---|
| 00 | none (read-only checks) | `participant.tfvars.json` ([section 3](#3-prepare-private-isolated-participant-names)) | Nothing | [validator, all PASS](../assets/screenshots/terminal-00-validate.png) |
| 01 | none (local only) | none | Nothing: the server runs on your computer | [Inspector lists the tools](../assets/screenshots/client-01-inspector.png) |
| 02 | `infra/workload` | `module02.tfvars.json` (`enable_mcp_server`) | Storage account, Function App (Flex Consumption) with the MCP tools behind a key | [Flex plan and MCP tools](../assets/screenshots/azure-02-function-overview.png), [the system key](../assets/screenshots/azure-02-function-keys.png) |
| 03 | `infra/entra`, then `infra/workload` (2 stages) | `entra.tfvars.json`, `module03.tfvars.json` | App registration with app roles, built-in authentication on the Function App; stage 2 replaces the key | [app roles](../assets/screenshots/azure-03-app-roles.png) |
| 04 | `infra/workload` (2 stages) | `module04.tfvars.json` (`enable_governed_gateway`) | API Management Standard v2, private endpoint; stage 2 closes the Function App to the internet | [Function private](../assets/screenshots/azure-04-function-networking.png), [validator](../assets/screenshots/terminal-04-operator.png) |
| 04 part B (optional) | `infra/workload` | `module04b.tfvars.json` (`enable_rest_mcp_demo`) | A REST API exposed as a second MCP server | [MCP tools](../assets/screenshots/azure-04b-mcp-tools.png) |
| 05 | `infra/workload`, then `infra/entra` | `module05.tfvars.json`, `entra-module05.tfvars.json` | Managed identities with federated credentials, the report storage | [API permissions](../assets/screenshots/azure-05-api-permissions.png) |
| 06 | none | none | Nothing: you read logs and traces | [KQL in Logs](../assets/screenshots/azure-06-kql-logs.png) |
| 07 | `infra/entra`, then `infra/workload` | `entra-module07.tfvars.json`, `module07.tfvars.json` | One more allowed client application | [Foundry approval](../assets/screenshots/azure-07-foundry-approve.png) |
| 99 | the same roots, destroy | none | Everything above is removed | the module 99 report |

Each module guide gives the exact commands. If you prefer **one command per module**, create the private file as the
guide shows, then run:

```powershell
& .\scripts\select-azure-context.ps1           # once per terminal: your test tenant and subscription
& .\scripts\deploy-module.ps1 -Module 02       # then 03, 04, 05, 07, in order
```

The script checks the signed-in context, passes the private files that exist in the right order, saves a
`terraform plan`, **waits for you to type** `yes`, applies exactly that plan, then runs the module validator.
`-PlanOnly` stops after the plan. For a module that changes Entra objects, run it with `-Root entra` first.
It never creates your private files, never switches a stage for you and never uses `-auto-approve`.

The captures in this table come from the author's test tenant. Names are replaced by `p01-<suffix>`, IDs by zeros.
They were produced with [tools/capture](../tools/capture/README.md), which you can reuse in your own tenant.

## Sources

- [Azure CLI on Windows](https://learn.microsoft.com/cli/azure/install-azure-cli-windows) and [.NET SDK on Windows](https://learn.microsoft.com/dotnet/core/install/windows).
- [PowerShell installation](https://learn.microsoft.com/powershell/scripting/install/installing-powershell), [Terraform](https://developer.hashicorp.com/terraform/install) and [Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local).
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers) and [alternative engines](https://code.visualstudio.com/remote/advancedcontainers/docker-options).
- [Official Dev Container Features](https://github.com/devcontainers/features), [specification](https://containers.dev/implementors/json_reference/).
- [Azure naming rules](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules) and [quotas](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).
- [AzureRM group resource](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group) and [existing group data source](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/data-sources/resource_group).
- [Terraform provider mocks](https://developer.hashicorp.com/terraform/language/tests/mocking) and [state](https://developer.hashicorp.com/terraform/language/state).
- [MCP practice](PRACTICE.md), [governance](LEARNING-GUIDE.md) and [source assessment](sources.md).

Last verified: 2026-10-14. Local/mock verification is not a container build or Azure deployment validation.
