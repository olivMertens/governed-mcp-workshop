# Governed MCP on Azure

A hands-on workshop for platform, identity and Microsoft 365 administrators.
Take a **Model Context Protocol (MCP)** server from a shared key to authenticated,
role-controlled access through Azure API Management.
Run the exercises in **your own approved non-production Azure subscription**, using synthetic data.

**Open the workshop:** [English](https://olivmertens.github.io/governed-mcp-workshop/?lang=en#/start)
| [Français](https://olivmertens.github.io/governed-mcp-workshop/?lang=fr#/start)

> [!IMPORTANT]
> The public website is hosted on **GitHub Pages**. It displays guides, commands, diagrams and captures.
> It does not sign in to Azure, deploy resources or validate your environment.
> You do not need to deploy a documentation portal or use a presenter's administrator account.

## Start here

1. Choose one deployment track below.
2. Follow the [getting-started guide](docs/GETTING-STARTED.md)
   ([français](docs/fr/GETTING-STARTED.md)) to clone the repository and install your track's tools.
3. Complete module 00, then follow the modules in order. Run each module's validator before continuing.
4. Reserve time for module 99 whenever you create resources, even if you stop before the final module.

To try MCP without deploying anything to Azure, use the shared
[module 01 exercise](modules/01-discover-mcp/README.md)
([français](modules/01-discover-mcp/README.fr.md)) after installing its local prerequisites.

## Choose your track

| Track | What you use | Start |
|---|---|---|
| **Low-code** | Azure and Microsoft Entra portals, with PowerShell 7 and Azure CLI for publishing, settings and checks. **No Terraform required.** | [English](modules/00-prerequisites/LOW-CODE.md) · [Français](modules/00-prerequisites/LOW-CODE.fr.md) |
| **Terraform + PowerShell** | Reviewed Terraform plans, PowerShell scripts and Azure CLI inspection commands. | [English](modules/00-prerequisites/README.md) · [Français](modules/00-prerequisites/README.fr.md) |

The website remembers your choice in its address: `?track=low-code` or `?track=terraform`.
Module 01 is shared; the other modules have separate guides for each track.
Follow only one track's deployment, validation and cleanup instructions.
Changing the selected guide does not migrate resources: do not apply Terraform to resources created by the low-code track.
See [track details](docs/TRACKS.md) ([français](docs/fr/TRACKS.md)).

Local terminal, dev container and Codespaces are workspace options, not additional deployment tracks.
Container and Codespaces setup is optional reference material; the website does not require a workspace selection.
The website uses PowerShell 7 examples. Bash alternatives remain in the repository guides.

## Modules

| Module | What you learn | Low-code | Terraform + PowerShell |
|---|---|---|---|
| **00 — Prerequisites** | Check your tools, approved Azure target and required permissions without creating resources. | [EN](modules/00-prerequisites/LOW-CODE.md) · [FR](modules/00-prerequisites/LOW-CODE.fr.md) | [EN](modules/00-prerequisites/README.md) · [FR](modules/00-prerequisites/README.fr.md) |
| **01 — Discover MCP** | List and call a local tool with MCP Inspector and VS Code, without Azure. | [EN](modules/01-discover-mcp/README.md) · [FR](modules/01-discover-mcp/README.fr.md) | Shared guide |
| **02 — Server protected by a key** | Deploy five synthetic tools and see why a shared key does not identify the user. | [EN](modules/02-open-server/LOW-CODE.md) · [FR](modules/02-open-server/LOW-CODE.fr.md) | [EN](modules/02-open-server/README.md) · [FR](modules/02-open-server/README.fr.md) |
| **03 — Microsoft Entra authentication** | Let Alice and Bob connect; refuse Eve. Distinguish server access from per-tool rights. | [EN](modules/03-entra-authentication/LOW-CODE.md) · [FR](modules/03-entra-authentication/LOW-CODE.fr.md) | [EN](modules/03-entra-authentication/README.md) · [FR](modules/03-entra-authentication/README.fr.md) |
| **04 — Governed gateway** | Make API Management the only entry point and enforce each tool's role. Bob can read but cannot write. | [EN](modules/04-governed-gateway/LOW-CODE.md) · [FR](modules/04-governed-gateway/LOW-CODE.fr.md) | [EN](modules/04-governed-gateway/README.md) · [FR](modules/04-governed-gateway/README.fr.md) |
| **05 — Delegated and app-only access** | Compare On-Behalf-Of user access with managed-identity access to downstream APIs. | [EN](modules/05-delegated-and-app-only/LOW-CODE.md) · [FR](modules/05-delegated-and-app-only/LOW-CODE.fr.md) | [EN](modules/05-delegated-and-app-only/README.md) · [FR](modules/05-delegated-and-app-only/README.fr.md) |
| **06 — Observe and inventory** | Query metadata-only logs and register the governed endpoint in Azure API Center. | [EN](modules/06-observe-inventory/LOW-CODE.md) · [FR](modules/06-observe-inventory/LOW-CODE.fr.md) | [EN](modules/06-observe-inventory/README.md) · [FR](modules/06-observe-inventory/README.fr.md) |
| **07 — Optional clients** | Connect a Microsoft Foundry agent and approve tool calls. Copilot Studio is reading-only. | [EN](modules/07-clients/LOW-CODE.md) · [FR](modules/07-clients/LOW-CODE.fr.md) | [EN](modules/07-clients/README.md) · [FR](modules/07-clients/README.fr.md) |
| **99 — Clean up** | Inventory and remove only workshop-owned resources and identities, including optional Foundry resources. | [EN](modules/99-cleanup/LOW-CODE.md) · [FR](modules/99-cleanup/LOW-CODE.fr.md) | [EN](modules/99-cleanup/README.md) · [FR](modules/99-cleanup/README.fr.md) |

Module 04 also includes an optional example that exposes REST API operations as MCP tools.
The core gateway uses **API Management Standard v2**, not the Preview AI Gateway tier.
Preview features, including the API Management MCP API and Foundry OAuth identity passthrough,
are labelled in the relevant guides.

## Validation and current limits

- The repository contains the guides, server code, deployment scripts, offline checks and cleanup instructions.
  Recorded live tests in the author's approved environment are documented in [build progress](docs/PROGRESS.md).
- Earlier live tests do **not** certify every instruction in the current guides or every low-code path.
  Follow your guide's validation notes and repeat its checks in your own environment.
- Module 01 runs locally. Its SDK and Inspector checks do not verify the manual VS Code approval prompt.
- The dev container and Codespaces configuration still require runtime validation on a suitable host.
- Foundry captures show earlier real tests: Alice's approved read succeeds and Bob's approved write is refused.
  **Copilot Studio is an unvalidated, reading-only overview**, not a hands-on connection with real screenshots.
- An offline `PASS`, a screenshot or moving to the next page is not proof of a successful Azure deployment.

## Diagrams, captures and practice

The module guides place commands, expected results and relevant real captures beside the exercise.
Private values in captures are masked; use your own names and compare the documented fields.
The module 99 inventory capture is **before cleanup**, not evidence that resources have been deleted.

The Terraform guides for modules 01 to 07 include step-by-step SVG animations; module 01 is shared.
Those animations are not yet included in the separate low-code guides for modules 02 to 07.
Static architecture diagrams are also available from the module pages.

- [Practice guide](docs/PRACTICE.md) · [Exercices en français](docs/fr/PRACTICE.md)
- [The five tools and their responses](docs/MCP-SERVER.md) · [Les outils et leurs réponses](docs/fr/MCP-SERVER.md)
- [Architecture diagrams](assets/architecture/STEPS.md) · [Schémas en français](assets/architecture/STEPS.fr.md)
- [Editable diagram sources and image notices](assets/architecture/README.md)

## Safety and costs

- Use non-production resources and synthetic Alice, Bob and Eve scenarios only.
- Obtain the required identity administrator approval before changing Microsoft Entra applications or permissions.
- Review resource creation, permissions and costs before deployment. In the Terraform track, review the plan before applying it.
- Keep one token audience per service hop. Never forward an MCP client token to a downstream API.
- Write tools require the documented role and explicit human approval. Do not weaken a control to make a test pass.
- Keep credentials, tokens, private participant parameters and Terraform state out of Git and shared outputs.
  Reuse your private naming parameters and state until cleanup is complete.
- Azure resources can continue to incur charges while idle. An expiry tag does not delete them.
  Follow module 99 for your track, including the separate Foundry resource group and identity objects.
  Preserve administrator-provided and shared resources.

## For presenters and contributors

Share the public English or French workshop link above. Participants run their own commands and use their own
approved subscriptions; publishing the documentation never deploys their MCP workloads.

For another documentation host, use the [hosting guide](docs/HOSTING.md)
([français](docs/fr/HOSTING.md)). An Azure-hosted copy is optional.
The repository's **Publish workshop guides** GitHub Actions workflow publishes GitHub Pages from `main`
when it is run manually; a push or pull request does not automatically redeploy the site.

- [Build plan](docs/BUILD-PLAN.md)
- [Build progress and validation evidence](docs/PROGRESS.md)
- [Copilot authoring runbook](docs/COPILOT-RUNBOOK.md)
- [Contribution instructions](.github/copilot-instructions.md)
- [Sources and verification dates](docs/sources.md)

## License and disclaimer

Community workshop, not an official Microsoft product. Provided "as is" under the [MIT License](LICENSE).
Third-party assets retain their own notices and usage terms.
The official documentation linked in each module is the reference.
