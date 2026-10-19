# What is actually available?

The repository contains the full workshop: preparation code, a local MCP exercise and modules 02 to 07 and 99.
Read [build progress](PROGRESS.md) for evidence. **Modules 00 and 02 are validated live.** Modules 03 to 06 passed their live
operator checks in the author's test tenant (2026-10-17 and 2026-10-18), but stay `authored` until the Alice, Bob and Eve
persona checks pass. Test accounts may first need to register multifactor authentication (MFA).

| Area | Available in this branch | Still required |
|---|---|---|
| Participant environment | Tool checks, explicit tenant/subscription selection, private stable names and separate state | Execute the dev container and validate an approved Azure target |
| Public documentation portal | Bilingual single-page application, App Service Terraform and guarded deployment script; published on App Service in the presenter's subscription (health and `?lang=en` / `?lang=fr` checks pass) | Renew the capacity review (less than 24 hours old) before each redeployment |
| Local MCP discovery (01) | .NET 10 stdio server, SDK validator, Inspector CLI checks, EN/FR guide and VS Code configuration | Observe the manual per-call client approval; preceding environment gate remains open |
| Open MCP server (02) | **Validated live (2026-10-16).** .NET 10 Functions MCP server with five synthetic tools, unit tests, default-off Flex/Storage/telemetry/identity Terraform with mock tests, optional private Storage (`mcp_private_storage`), EN/FR guide, validator and scoped clean-up | Each participant repeats the live validation in their own subscription |
| Entra identity (03) | `infra/entra` root (registration, scope, three app roles, assignment required, pre-authorized VS Code and Azure CLI, persona assignments for existing accounts) and default-off built-in authentication opt-in with Protected Resource Metadata (**Preview**), mock tests, EN/FR guide, validator and scoped clean-up. Live operator checks pass; Alice persona check passes (2026-10-19) | Bob (HTTP 200) and Eve (refused) persona checks, after their MFA registration |
| Governed gateway (04) | Default-off API Management Standard v2 opt-in: MCP server API (**Preview**), Entra token + per-tool role policy, per-oid rate limit, optional IP filter, gateway Protected Resource Metadata, outbound virtual network integration, Function private endpoint and private DNS, staged public-access lock, zero-body-byte diagnostics; mock tests, EN/FR guide, validator and scoped clean-up. Live operator checks pass (2026-10-18): gateway 401, direct Function 403, zero body bytes | Persona 403/200, burst 429 and telemetry checks. Standard v2 is billed per hour: deploy and clean up the same day |
| Delegated and app-only access (05) | Default-off opt-in: `whoami` (On-Behalf-Of to Graph, persona label only), `read_report_as_user` (On-Behalf-Of to Storage, caller's RBAC) and `read_report_as_app` (app-only managed identity); two separate identities, container-scoped roles, Entra federated credential with opt-in consent and no secret; unit and mock tests, EN/FR guide, validator, publish step and scoped clean-up. Live operator checks pass (2026-10-18) | Persona checks: Alice HTTP 200, Bob HTTP 200 with `isError`, identical app-only result |
| Observe and inventory (06) | Authored: telemetry queries, API Center inventory, EN/FR guide, offline validator and scoped clean-up. The KQL query ran live on gateway traffic (2026-10-18), metadata only | Persona traffic (`tools/call`), API Center registration and listing (manual, **Preview**) |
| Clients (07) and clean-up (99) | Authored: optional client setup (EN/FR guide, offline validator, clean-up scripts); orchestrated clean-up in reverse order with report-only default | Live client checks; report-mode clean-up on a real attendee machine |
| Managed identities | Module 02 host identity and module 05 OBO-assertion and app-only identities with container-scoped roles; operator checks pass live in the author's test tenant | Persona checks |
| Microsoft Entra | Identity root in module 03 (no users or secrets) and module 05 delegation opt-in (delegated Graph `User.Read` and Storage `user_impersonation`, managed-identity federated credential, opt-in admin consent); applied in the author's test tenant | Validate per-user authorization with Alice, Bob and Eve |
| API Management gateway | Standard v2 gateway, private network and authorization policies in module 04; operator checks pass live | Persona, rate-limit and telemetry checks; module 06 adds queries and inventory |
| Microsoft Foundry | Optional client scenario only | A separately reviewed project, model, agent and secretless connection if this option is selected |
| Observability and inventory | Payload-free logging (zero body bytes checked live in module 04) and a KQL query that returns metadata only | Validate with persona traffic and API Center registration |

## Follow the architecture in order

Open the [step-by-step diagrams](../assets/architecture/STEPS.md). Each module also shows its diagram
in the application, with a closed-by-default Mermaid source section.
The diagrams are **planned targets**. They never imply that the shown resources exist.

For module 00, follow the [published guide](../modules/00-prerequisites/README.md).
Module 01's [local exercise](../modules/01-discover-mcp/README.md) runs without Azure or the presenter portal.
Its local authoring was explicitly approved before module 00 validated on the local-terminal route.
The optional container/Codespaces route remains unverified.
Module 02's [guide](../modules/02-open-server/README.md) is validated live (2026-10-16).
Module 03's [guide](../modules/03-entra-authentication/README.md), module 04's [guide](../modules/04-governed-gateway/README.md),
module 05's [guide](../modules/05-delegated-and-app-only/README.md) and module 06's [guide](../modules/06-observe-inventory/README.md)
pass their live operator checks; their persona checks are still pending. Module 07's [guide](../modules/07-clients/README.md) passes offline checks only.
Every validator prints a purpose line, numbered `== Step N ==` headers with a `Why:` line, then one `PASS`/`FAIL` line per check
with the expected HTTP status. Modules 02, 03, 05 and 06 show real annotated captures (names pseudonymised, IDs zeroed). Module 99's [cleanup guide](../modules/99-cleanup/README.md) is authored; its report mode has not been run against a live state. Cloud validation and exact deployment approvals are not waived.

## Identity and gateway boundaries

The documentation portal serves public files. It does not call Azure or need a managed identity today.
It must not collect participant credentials. Azure deployment uses the approved operator's interactive sign-in,
not a publishing key.

The MCP workload has its own identities and least-privilege assignments.
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

Last verified: 2026-10-19. Repository implementation status, not live Azure discovery.
