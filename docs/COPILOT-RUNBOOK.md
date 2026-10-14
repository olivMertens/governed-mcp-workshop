# Runbook — build this workshop with the GitHub Copilot app

This runbook drives the build from this scaffold to a validated workshop: one module per session, one branch and one pull request per module.
Module 00 preparation and module 01's local MCP exercise are implemented. Neither module is fully validated yet.

Participants do not need this authoring workflow. Start with [workspace choice](GETTING-STARTED.md):
VS Code dev container or local terminal, common tool checks, private participant suffix and the Terraform group foundation.
The board opens `#/start` by default. No module is validated by choosing an environment.

## 1. Before you start

- **GitHub Copilot app** installed and signed in. With Copilot Business or Enterprise, your organization must allow it.
- **Local tools:** Git, GitHub CLI, Azure CLI, Terraform, PowerShell 7, Node.js LTS, and the .NET SDK and Azure Functions Core Tools versions used by
  [Azure-Samples/remote-mcp-functions-dotnet](https://github.com/Azure-Samples/remote-mcp-functions-dotnet).
- **A non-production Azure subscription** where you can create resources and role assignments:
  `az login` then `az account set --subscription <your-test-subscription>`.
- **Test identities:** a test Microsoft Entra tenant, or an identity administrator who can run `infra/entra`
  and create three test users: Alice, Bob and Eve.
- **Recommended — Microsoft Learn MCP server**, so the agent reads the official documentation before writing code:
  - GitHub Copilot app or Copilot CLI: add it from the Customize panel or with `/mcp add`
    (name `microsoft-learn`, type HTTP, URL `https://learn.microsoft.com/api/mcp`, no authentication).
  - Workspace: already configured in portable `.mcp.json`, with `.vscode/mcp.json` for compatibility.
    Both describe the same public endpoint, without credentials. Avoid adding a duplicate server in the same client.

### Bootstrap an empty destination

From the folder containing `setup-workshop-mcp.ps1`, run PowerShell 7:

```powershell
pwsh -ExecutionPolicy Bypass -File .\setup-workshop-mcp.ps1
```

The standalone bootstrap includes the scaffold, current P1 source assessment, and build board. It requires Git
and GitHub CLI (`gh`) unless `-SkipGitHub` is used. If missing, install them with
`winget install --id Git.Git -e` and `winget install --id GitHub.cli -e`, then reopen the terminal.
Git identity must be configured. For publication, the script uses repository-local GitHub noreply identity,
not the globally configured email. It does not change global Git settings.

The default destination is `C:\github\workshop-mcp`. The script refuses a nonempty destination or an existing
remote repository. Do not empty a working folder to bypass this protection.
Options: `-Visibility private`, `-SkipGitHub` (local only), `-OpenVSCode`, `-Path`, and `-RepoName`.
The script does not create or change Azure or Microsoft Entra resources.

### Start from an existing scaffold

If the workshop files are already present, open that folder in a local Copilot session. Do not run the bootstrap
against it. Initialize Git on the existing files, review the publication content, and then create/push the remote
repository only after explicit approval. Use a repository-local noreply Git identity and inspect the staged diff
before the first commit. Keep publication audit terms and local scan reports outside the repository.

The bootstrap contains embedded copies of the scaffold. When updating these files, update its embedded copies
in the same change, and verify a `-SkipGitHub` run in a new, empty test destination. Never test publication by
creating an extra public repository.

## 2. How the build works

| File | Role |
|---|---|
| `.github/copilot-instructions.md` | Permanent rules: content, nine security invariants, stack, module contract |
| `docs/BUILD-PLAN.md` | What to take, in which order, what each module must show and validate |
| `docs/PROGRESS.md` | Status of each module, validation evidence, open decisions |
| `docs/sources.md` | Verified upstream snapshots, useful elements, updates, exclusions and license boundaries |
| `docs/PRACTICE.md` | Client launch recipes, call expectations, per-module hints and safety implications |
| `.github/extensions/workshop-build-board/` | Read-only workshop SPA (**Preview** canvas SDK), backed by repository guides and build progress |
| `.github/skills/workshop-module-builder/SKILL.md` | The procedure the agent follows for every module |
| `.github/agents/workshop-builder.agent.md` | Optional custom agent that applies the skill |
| `AGENTS.md` | Entry point for any coding agent |

Rules of the game:
- One module = one session = one branch = one pull request. Merge it before you start the next module.
- Use **Plan** mode to think, **Interactive** mode for anything that touches Azure or Microsoft Entra,
  **Autopilot** only for documentation.
- Use **local** sessions for modules that deploy to Azure: they need your `az login`.
- The agent must show you the Terraform plan and the Entra changes, and wait for your approval, before applying anything.

## 3. Session sequence

| Step | Mode | Session | Prompt | Done when |
|---|---|---|---|---|
| 1 | Plan | Local | P1 | You approved the tree, the technical choices and the risks |
| 2 | Interactive | Local | P2 | preflight.ps1 and the module 01 validate script pass |
| 3 | Interactive | Local | P3 | Module 02 validate passes |
| 4 | Interactive | Local | P4 | Module 03 validate passes |
| 5 | Interactive | Local | P5 | Module 04 validate passes |
| 6 | Interactive | Local | P6 | Module 05 validate passes |
| 7 | Interactive | Local | P7 | Module 06 validate passes |
| 8 | Interactive | Local | P8 | Module 99 leaves the subscription empty |
| D | Autopilot | Cloud or local, in parallel from step 3 | PD | Concept docs and facilitator guide merged |
| 9 | Plan | Local | P9 | Final review pull request open, no blocking gap left |

### P1 — Plan the whole build (no code)

```text
Read .github/copilot-instructions.md, docs/BUILD-PLAN.md and docs/PROGRESS.md, then the official pages listed in the plan.
Propose the full repository tree, the files of each module, the technical choices (network path from API Management
to the Function, Terraform providers and azapi resources, region) and the risks (Entra permissions, preview features,
cost). Do not write code. Record your recommendations under "Open decisions" in docs/PROGRESS.md.
```

### P2 — Modules 00 and 01

```text
Use the workshop-module-builder skill. Build module 00 (.devcontainer, preflight.ps1, docs/requests/identity-request.md),
and stop when its validation passes. Update docs/PROGRESS.md and open the pull request.
After merge, start a separate session/branch for module 01 and stop when its validate script passes.
```

### P3 — Module 02, the "open" server

```text
Use the workshop-module-builder skill for module 02. Participant prefix p00, my current Azure subscription.
Show me the Terraform plan before applying. Fix until validate.ps1 passes.
```

### P4 — Module 03, Microsoft Entra

```text
Use the workshop-module-builder skill for module 03. Generate infra/entra first and list exactly which Entra objects,
permissions and consents it creates; apply only after my approval. Then enable built-in authentication and the
Protected Resource Metadata on the Function, and prove the expected results for Alice, Bob and Eve.
```

### P5 — Module 04, API Management as the only entry point

```text
Use the workshop-module-builder skill for module 04. API Management must become the only entry point.
Prove with validate.ps1: Bob gets 403 on create_ticket, Alice gets 200, 429 after the limit,
a direct call to the Function is refused, and the logs show tool name and caller without any payload.
```

### P6 — Module 05, On-Behalf-Of vs app-only

```text
Use the workshop-module-builder skill for module 05. Compare On-Behalf-Of and app-only access with Alice and Bob.
validate.ps1 must check the four expected results automatically. No client secret anywhere.
```

### P7 — Module 06, observe and inventory

```text
Use the workshop-module-builder skill for module 06: saved KQL queries or a workbook (tool, caller, status, latency,
top denials) and the registration of the server in Azure API Center.
```

### P8 — Module 99, clean up

```text
Use the workshop-module-builder skill for module 99. Destroy workload and entra, remove role assignments and test users,
and prove that nothing tagged with the workshop remains.
```

### PD — Documentation (parallel session, Autopilot)

```text
Write docs/concepts/ (token chain diagram, scopes vs app roles, On-Behalf-Of vs managed identity, MCP threat model),
docs/facilitator-guide.md and docs/sources.md from docs/BUILD-PLAN.md and the modules already validated.
Do not change any module code or infrastructure. Open a pull request.
```

### P9 — Final review

```text
Review the whole repository against .github/copilot-instructions.md: the nine security invariants, no customer or
internal content, every link valid, Preview labels present, every module cleans up, and module 99 leaves a fresh
subscription empty. List every gap in a pull request and fix only what is safe to fix.
```

## 4. Workshop build board

The project-scoped canvas is already implemented in `.github/extensions/workshop-build-board/`.
Ask: "Show the workshop build board." Reload project extensions if discovery has not picked it up.
The Copilot canvas SDK is **Preview**; it is separate from Azure or Foundry agent infrastructure.

The board is a responsive single-page application (SPA) with a module route, a target architecture overview,
participant guides, the build runbook, verified sources and open decisions. There are no status-entry forms,
personal completion checkboxes or participant accounts. Professionals follow the instructions and run the
module's validation themselves.

The **EN / FR** switch changes both the interface and authored learning content. `?lang=fr#/module/04` is a
French deep link. Language selection is URL state, not participant tracking. A future missing `README.fr.md`
is reported explicitly, with the original English participant guide available separately.
Repository evidence and open decisions remain explicitly labeled original English text.
The **Understand governance**, **Your Azure context**, and **Diagrams and icons** pages contain deep dives,
tenant/subscription selection, cost/permission boundaries and diagram provenance. Each module shows a planned
EN/FR diagram and a next step; 06 offers cleanup 99 with 07 as an optional branch.
See [the French runbook](fr/COPILOT-RUNBOOK.md) for French session prompts.

Context selectors are preparation helpers, not the module 00 preflight. They verify the participant-selected
tenant/subscription using Azure CLI, then set Terraform context in the current shell only. They never create
cloud resources, assign roles or save IDs into the board. Read [DEPLOYMENT.md](DEPLOYMENT.md) before running them.

Hash routes such as `#/module/00` support direct links and browser back/forward navigation.
The board reads a published module's README when it exists. Otherwise it shows a clearly labeled design outline
from `docs/BUILD-PLAN.md`; an outline is not a runnable participant procedure. Modules 00 and 01 are implemented;
modules 02–07 and 99 remain design outlines until their module branches are built and merged.
Use **Refresh content** after changing repository documents. Repository status and evidence are available in
an optional disclosure, separate from the participant instructions.

The interface never writes progress or executes commands. Agent actions still update only `docs/PROGRESS.md`;
no separate progress database exists. Conflicting agent updates are refused rather than overwriting a newer version.
Evidence and notes must be single-line Markdown table cells without pipe characters.

### Practice with your deployed server

Open **Try your MCP** (`#/practice`) for Codespaces setup, local VS Code launch, and client connection help.
Or ask Copilot: "Open the workshop build board on its practice view."
Enter only an HTTPS endpoint with no credentials, query or fragment. This field is held in page memory only:
the board never sends it to its server, saves it or makes an MCP request with it.
Copy buttons prepare commands, a URL-only VS Code user configuration and starter prompts; they do not run them.
If clipboard access is blocked by the host, select the text and copy it manually.

Inspector launch commands pin the registry-available 2.9.0, keep credentials in memory, disable token
persistence, negotiate the protocol era and bind to loopback. The GitHub 2.11.0 source candidate was not yet
available from the configured npm registry during launch testing. Commands fail if the pinned package is
unavailable; they do not change the registry or silently fall back.
Keep its authentication enabled, use its printed private local URL, and do not export credential-bearing headers
or transcripts. Entra requires a separately approved public client, exact redirect URI and delegated scopes;
VS Code preauthorization is not Inspector preauthorization. Never add a client secret.

The Codespaces link opens a creation flow for the published repository. It does not include unpushed local
changes or create a machine automatically. Review costs before creating it. Until module 00 publishes its
dev container, no preconfigured or validated workshop environment is promised. For authenticated Inspector
tests, prefer local desktop or private local forwarding through VS Code desktop, not public browser ports.

Every module has a **Need a hint?** disclosure explaining what its boundary proves and what to check next.
Module validation commands appear only when both the README and the script exist. Running them remains an
explicit participant action with the approvals required by the module. No live test result is inferred from
a connected badge, generated command or example. See [PRACTICE.md](PRACTICE.md) for the full scenarios.

Agent capabilities:

| Capability | Input and result |
|---|---|
| `get_progress` | Returns modules, open decisions, and the current revision. |
| `set_module_status` | Requires module, status, evidence and revision from the last read. Optional notes; validated also requires a real validation date. |
| `list_open_decisions` | Returns the Open decisions section. |

Mark a module `validated` only after its actual validation script passes in the required fresh-subscription
sequence. The board stores evidence; it neither runs tests nor certifies that evidence.
Do not enter confidential text, tokens, prompts, tool arguments/results, or live account identifiers.

To check the board locally without the Copilot runtime:

```powershell
node --test .github\extensions\workshop-build-board\progress.test.mjs
```

### Re-create the board in a different project

In a session, type `/create-canvas`, choose the **project** scope (the canvas is saved in `.github/extensions/`
and versioned with the repository), then paste:

```text
Create a canvas named "Workshop build board". Build a responsive, read-only SPA with hash-route module
navigation, participant instructions from each module README, an overview, verified sources and open decisions.
Remove progress-entry forms. For an unpublished module, show a clearly labeled outline from docs/BUILD-PLAN.md
instead of inventing runnable steps. Show repository status and evidence in a secondary disclosure.
Add a Try your MCP page with Codespaces setup and local launch links, endpoint-only in-memory command preparation,
safe Inspector launch commands and copyable prompts. Calls run in the official client, never through the board.
Read per-module hints from docs/PRACTICE.md. Offer validators only when the README and script actually exist.
Give the agent three capabilities: get_progress, set_module_status(module, status, evidence) and list_open_decisions.
docs/PROGRESS.md stays the only progress source of truth. Only agent actions update it; browsing is read-only.
```

Then ask in any session: "Show the workshop build board and start the next module."

## 5. Before the workshop day

- Dry run: modules 00 to 06 end to end on a fresh subscription with a new prefix, then module 99.
- Record a short video of each level as a fallback.
- Check the cost of the dry run, then clean up.

## Sources

[Build plan](BUILD-PLAN.md), [source register](sources.md), and
[VS Code MCP configuration](https://code.visualstudio.com/docs/agent-customization/mcp-servers).
Last verified: 2026-10-14.
