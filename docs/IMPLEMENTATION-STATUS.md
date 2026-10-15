# What is actually available?

The public repository contains working preparation code and a runnable local MCP exercise, not a deployed Azure workshop.
Read [build progress](PROGRESS.md) for evidence. **No module is Azure-validated yet.**

| Area | Available in this branch | Still required |
|---|---|---|
| Participant environment | Tool checks, explicit tenant/subscription selection, private stable names and separate state | Execute the dev container and validate an approved Azure target |
| Public documentation portal | Bilingual single-page application, App Service Terraform and guarded deployment script | Review a real plan, approve costs, deploy and verify the site |
| Local MCP discovery (01) | .NET 10 stdio server, SDK validator, Inspector CLI checks, EN/FR guide and VS Code configuration | Observe the manual per-call client approval; preceding environment gate remains open |
| Open MCP server (02) | .NET 10 Functions MCP server with five synthetic tools, unit tests, default-off Flex/Storage/telemetry/identity Terraform with mock tests, EN/FR guide, validator and scoped clean-up | Approved plan, deployment and live HTTP 401/200 validation; nothing is deployed |
| Entra identity (03) | `infra/entra` root (registration, scope, three app roles, assignment required, pre-authorized VS Code and Azure CLI, persona assignments for existing accounts) and default-off built-in authentication opt-in with Protected Resource Metadata (**Preview**), mock tests, EN/FR guide, validator and scoped clean-up | Identity administrator approval and apply, workload apply in two stages, live 401/200 and Eve checks; nothing is deployed or created |
| Governed gateway (04) | Default-off API Management Standard v2 opt-in: MCP server API (**Preview**), Entra token + per-tool role policy, per-oid rate limit, optional IP filter, gateway Protected Resource Metadata, outbound virtual network integration, Function private endpoint and private DNS, staged public-access lock, zero-body-byte diagnostics; mock tests, EN/FR guide, validator and scoped clean-up | Cost approval, two-stage apply, live 401/403/200/429/direct-403/telemetry checks; nothing is deployed |
| Azure MCP server (05 onward) | Learning targets and diagrams | Downstream On-Behalf-Of and app-only implementation from module 05 |
| Managed identities | Permission model and administrator request | Create identities, scoped role assignments and approved federation in their modules |
| Microsoft Entra | Identity root authored in module 03 (no users, secrets or API permissions) | Apply it with an identity administrator, then validate authorization; module 05 adds On-Behalf-Of consent and federation |
| API Management gateway | Standard v2 gateway, private network and authorization policies authored in module 04 (not deployed) | Deploy after cost approval and validate live; module 06 adds queries and inventory |
| Microsoft Foundry | Optional client scenario only | A separately reviewed project, model, agent and secretless connection if this option is selected |
| Observability and inventory | Payload-free logging requirements | Implement and validate telemetry and API Center registration |

## Follow the architecture in order

Open the [step-by-step diagrams](../assets/architecture/STEPS.md). Each module also shows its diagram
in the application, with a closed-by-default Mermaid source section.
The diagrams are **planned targets**. They never imply that the shown resources exist.

For module 00, follow the [published guide](../modules/00-prerequisites/README.md).
Module 01's [local exercise](../modules/01-discover-mcp/README.md) runs without Azure or the presenter portal.
Its local authoring was explicitly approved before module 00 validated on the local-terminal route.
The optional container/Codespaces route remains unverified.
Module 02's [guide](../modules/02-open-server/README.md) is authored and passes offline checks only; it is not deployed.
Module 03's [guide](../modules/03-entra-authentication/README.md) is authored and passes offline checks only; no Entra object is created.
Module 04's [guide](../modules/04-governed-gateway/README.md) is authored and passes offline checks only; no gateway is deployed.
Modules 05 onward remain outlines. Cloud validation and exact deployment approvals are not waived.

## Identity and gateway boundaries

The documentation portal serves public files. It does not call Azure or need a managed identity today.
It must not collect participant credentials. Azure deployment uses the approved operator's interactive sign-in,
not a publishing key.

The future MCP workload needs its own identities and least-privilege assignments.
Delegated downstream calls use On-Behalf-Of; application calls use a managed identity.
Never forward the MCP client token to Storage or Microsoft Graph.

The core gateway is **API Management Standard v2**, not the Preview AI Gateway tier.
The MCP management API used by module 04 is **Preview**.
Model traffic through an AI gateway is a separate design from MCP tool traffic.
No Foundry project, model deployment, agent or model-routing policy has been implemented or deployed here.
Selecting that optional scenario requires its own source review, quota/cost review, approval and validation.

## Keep documentation synchronized

When an architecture step changes, edit `assets/architecture/workshop.drawio`, regenerate the SVG/PNG
and Mermaid documentation, then run the consistency check. Do not maintain a second handwritten diagram.
The [diagram authoring guide](../assets/architecture/README.md) records commands and icon provenance.
Update this page and `PROGRESS.md` when implementation or real validation changes, not just when a diagram is drawn.

No Azure or Microsoft Entra creation, permission change or deletion is authorized by these documents.

## Sources

- [Build plan](BUILD-PLAN.md), [progress](PROGRESS.md) and [verified technical sources](sources.md).
- [Identity administrator request](requests/identity-request.md).
- [Portal hosting and approval boundary](HOSTING.md).

Last verified: 2026-10-15. Repository implementation status, not live Azure discovery.
