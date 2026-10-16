# Choose your workspace first

**Participant:** use the portal link your presenter sends, choose EN/FR, then start at module 00.
You do not need another App Service or the presenter's administrator account.
Without a portal, follow these Markdown guides.
**Presenter:** use the separate [publishing how-to](PRESENTER.md).

**Try MCP without Azure first:** after cloning and installing .NET 10/PowerShell 7,
use [module 01](../modules/01-discover-mcp/README.md). The presenter portal is optional documentation hosting.

Use **Visual Studio Code (VS Code)** with a dev container, or use your own terminal.
These are two routes to the same scripts, private participant parameters and Terraform root.
Visual Studio IDE is a different product; the container instructions here use the VS Code Dev Containers extension.
No Copilot subscription or canvas is required to read the Markdown guides or run the scripts.

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
git clone --branch main https://github.com/olivMertens/workshop-mcp.git
if ($LASTEXITCODE -ne 0) { throw 'Clone failed. Do not continue in another directory.' }
Set-Location .\workshop-mcp
```

**Expected:** `README.md`, `scripts` and `infra` are in the current folder.
Run the following commands from this folder. If VS Code is installed, open it with `code .`.
Each participant needs their own checkout. Once this repository is public, cloning needs no GitHub account or GitHub CLI.
While it is private, your presenter must grant repository access or share the documentation portal instead.

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
| Local terminal | Git, PowerShell 7.4+, Azure CLI, Terraform, .NET SDK, Node.js, Functions Core Tools | Keep the checkout local. Install the tools below using your organization's approved process. |
| Codespaces (optional) | GitHub access, quota and cost approval | [Choose branch and machine](https://codespaces.new/olivMertens/workshop-mcp). It uses the same `.devcontainer`, but only after these files are published. |

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
| Terraform, to plan deployments | `winget install --id Hashicorp.Terraform --exact` |
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
| Terraform | 1.16.6+, below 2 | [Install Terraform](https://developer.hashicorp.com/terraform/install) |
| .NET SDK | 10 installed | [.NET download](https://dotnet.microsoft.com/download/dotnet/10.0) |
| Node.js | 22.19.0+ | [Node.js download](https://nodejs.org/en/download) |
| Functions Core Tools | 4.5.0+, below 5 | [Core Tools installation](https://learn.microsoft.com/azure/azure-functions/functions-run-local) |

Use Core Tools v4, not the separate **Preview** Functions CLI v5. Some npm Core Tools wrappers download their
binary on the first invocation. The checker refuses incomplete known npm shims instead of starting a download.
Finish the approved installation separately; a package entry alone proves nothing.
No script in this repository installs workstation tools or changes your engine automatically.

## 2. Check the terminal you will actually use

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

`infra/workload` contains the resource-group foundation, future MCP names and an **optional public App Service**.
The paid portal is disabled by default; [hosting](HOSTING.md) documents explicit persistent opt-in and deployment.
It does not deploy Functions, networking, API Management, identities, or an MCP server.
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
