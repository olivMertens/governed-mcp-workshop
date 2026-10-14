# Build plan — Governed MCP on Azure

Build the modules in this order, one session and one branch per module.
Do not start a module until the previous one validates.
Scoped user-approved exception (2026-10-14): author and run the Azure-independent module 01 locally while
module 00's cloud/container validation is pending. This does not approve cloud work or validate module 00.

## End-state architecture

```text
MCP clients: VS Code + GitHub Copilot, MCP Inspector (optional: Copilot Studio, Foundry agent)
 → Azure API Management (only entry point): Protected Resource Metadata (PRM), validate-azure-ad-token,
   per-tool role check, rate limit, IP filter, payload-free logs
   → Azure Functions MCP server (.NET isolated worker), built-in Entra authentication. Tools:
       get_service_health   read, synthetic data
       create_ticket        write, synthetic side effect (Storage queue)
       whoami               On-Behalf-Of → Microsoft Graph /me
       read_report_as_user  On-Behalf-Of → Azure Storage (the caller's RBAC applies)
       read_report_as_app   managed identity → Azure Storage (same result for everyone)
 → Application Insights / Log Analytics
Azure API Center registers the gateway endpoint (inventory, not a runtime hop).
```

Personas:
- **Alice**: assigned, app roles Tools.Read + Tools.Write, Storage Blob Data Reader.
- **Bob**: assigned, Tools.Read only, no storage role.
- **Eve**: not assigned.

## 00 — Prerequisites and environment
- **Take:** Azure CLI, Terraform, PowerShell 7, .NET 10 and Functions Core Tools >= 4.5.0 from the pinned sample;
  Node.js >= 22.19.0 for the selected MCP Inspector. See [source selections](sources.md) before pinning exact tool versions.
- **Build:** .devcontainer; preflight.ps1 (tools, versions, `az login`, subscription, resource providers, role checks,
  quota, region); docs/requests/identity-request.md listing exactly what an identity administrator must create or consent.
- **Show:** preflight passes; the identity request is clear enough to send as is.
- **Implementation now available:** EN/FR module 00 guide, read-only explicit-context preflight, administrator
  identity request, pinned workstation configuration and private stable participant parameters.
  The shared root supports the group foundation and a default-off public B1 App Service.
  Offline schema/mock/script/server evidence is separate from container and fresh-subscription validation,
  which remain pending. No MCP runtime or Entra root has been implemented.

## 01 — Discover MCP (no Azure)
- **Take:** MCP specification: https://modelcontextprotocol.io/specification (revision 2026-07-28 verified on 2026-10-14: architecture, tools, transports, authorization);
  https://code.visualstudio.com/docs/agent-customization/mcp-servers; MCP Inspector (@modelcontextprotocol/inspector).
- **Build:** a local MCP server from the official C# SDK quickstart (https://github.com/modelcontextprotocol/csharp-sdk);
  connect it to VS Code and to MCP Inspector.
- **Show:** tools/list, a tool call, the approval prompt in the client.
- **Validate:** Inspector lists the tools and returns a result. Check the negotiated protocol version: the current
  specification uses per-request metadata, while older clients use an initialization handshake. Do not mix message shapes.
- **Implemented locally:** [EN/FR guide](../modules/01-discover-mcp/README.md), .NET 10 stdio server,
  SDK 2.2.0 and Hosting 10.0.13 with a package lock. One read-only `get_service_health` tool returns fixed synthetic data.
  The real SDK validator and Inspector 2.9.0 discovery/call pass. VS Code approval remains an explicit manual check;
  no write tool is exposed before its role and approval controls exist. No Azure or Preview dependency.

## 02 — An "open" MCP server (level 0)
- **Take:** https://github.com/Azure-Samples/remote-mcp-functions-dotnet
  at `468c518c884ec318e3001b9573254c9e775409c9`;
  https://learn.microsoft.com/azure/azure-functions/scenario-custom-remote-mcp-server;
  Functions MCP extension docs; Flex Consumption docs.
- **Build:** Terraform for Function App (Flex Consumption), Storage, Application Insights, managed identity;
  the five tools with synthetic data. Use a queue for synthetic tickets. In this module, downstream identity tools
  return clearly labeled synthetic demonstrations; their real authorization behavior is introduced in module 05.
- **Show:** with the key, anyone can call create_ticket.
- **Validate:** HTTP 401 without the MCP extension system key, HTTP 200 with the key and a valid MCP request;
  anonymous access disabled. Set webhook authorization to `System`: upstream `host.json` uses `Anonymous` because
  the upstream sample starts with Entra authentication. Never copy that setting into the key-only module.

## 03 — Identity with Microsoft Entra (level 1)
- **Take:** https://learn.microsoft.com/azure/app-service/configure-authentication-mcp;
  https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode;
  https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial;
  app roles: https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps.
- **Build:** infra/entra: app registration (Application ID URI, scope user_impersonation, app roles Tools.Read,
  Tools.Write, Tools.Execute.All), assignment required, pre-authorized client applications (VS Code client ID from
  the sample, Azure CLI); enable built-in authentication and Protected Resource Metadata (PRM) (setting
  WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES, Preview).
- **Show:** VS Code signs in; explain audience (`aud`), scopes (`scp`), and roles using synthetic claim examples;
  Eve is refused. Never paste a live token into a website, chat, committed file, or log.
- **Validate:** 401 without token; 401 with a token for another audience; 200 for Alice and Bob;
  Eve cannot get a token (assignment required).

## 04 — API Management as the only entry point (level 2)
- **Take:** https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server;
  https://learn.microsoft.com/azure/api-management/secure-mcp-servers;
  https://learn.microsoft.com/azure/api-management/mcp-server-overview (governance, limitations);
  https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api (REST, Bicep, Azure CLI, Terraform);
  https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy;
  https://github.com/Azure-Samples/AI-Gateway (labs mcp-client-authorization, mcp-prm-oauth).
- **Build:** APIM v2 (azapi, api-version 2025-09-01-preview), MCP server exposed; policies: validate-azure-ad-token
  (audience = the MCP server), role check per tool from the JSON-RPC body (create_ticket requires Tools.Write),
  rate-limit-by-key on the caller object ID, ip-filter; Application Insights with zero body bytes;
  Function reachable only through APIM (choose and document the network option in the plan step).
- **Recommendation:** Standard v2 outbound virtual network integration, a Function private endpoint, private DNS,
  and public Function access disabled. The MCP management API is **Preview**. Keep public protected resource metadata
  and OAuth challenges on the gateway. Do not expose the private Function URL to clients.
- **Show:** Bob calls create_ticket → 403, Alice → 200; burst → 429; direct call to the Function refused; logs without payload.
- **Validate:** all of the above as PASS/FAIL lines.
- **Optional 04b:** expose a synthetic REST API as an MCP server (https://learn.microsoft.com/azure/api-management/export-rest-mcp-server; AI-Gateway lab mcp-from-api).

## 05 — Who carries the rights? On-Behalf-Of vs app-only (level 3)
- **Take:** https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow;
  src/FunctionsMcpTool/HelloToolWithAuth.cs in the sample; federated identity credential with a user-assigned managed identity
  (https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).
- **Build:** whoami and read_report_as_user (On-Behalf-Of, Graph User.Read and Azure Storage user_impersonation);
  read_report_as_app (managed identity, Storage Blob Data Reader on one container).
- **Show:** same question, Alice vs Bob: as_user → 200 for Alice, 403 for Bob; as_app → same result for both.
- **Validate:** the four results; no client secret anywhere. Record both outer HTTP status and the MCP tool result:
  a downstream HTTP 403 can be returned as a tool error inside an HTTP 200 response.

## 06 — Observe and inventory (level 4)
- **Take:** APIM Application Insights integration and KQL; Azure API Center MCP inventory:
  https://learn.microsoft.com/azure/api-center/register-discover-mcp-server;
  AI-Gateway lab mcp-registry-apic;
  bring your own (BYO) MCP server in the Microsoft 365 admin center (Preview): https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server.
- **Build:** a workbook or saved KQL queries (tool, caller, status, latency, top denials); register the server in API Center.
- **Show:** who called which tool, when, with what result.
- **Optional 06b (Preview):** Agent 365 / Microsoft 365 admin center inventory as a demo only (Preview, licensing and
  Frontier requirements), no participant step. Source: https://learn.microsoft.com/azure/api-management/agent-365
  (Preview, verified 2026-10-14) and the
  [Tech Community post](https://techcommunity.microsoft.com/blog/integrationsonazureblog/microsoft-agent-365-and-azure-api-management-integration-for-mcp-governance/4563335).
  Facts to respect:
  - Needs an Agent 365 tenant and a tenant administrator's one-time consent that grants the **A365 MCP Gateway Policy
    Operator** role at tenant level, with read and write on API-scoped policies. This widens a role beyond one
    resource group, so it is never a participant step (security invariant 8).
  - With API Management v2 (our core gateway): inventory and block/unblock of a server only (blocked server returns 403).
    Tool-level blocking, tool activity observability and Defender/Purview threat protection need the **AI Gateway tier
    (Preview)**, which stays outside the core path.
  - Tool-level control needs a static list of allowed tools on each MCP server.
  - Agent 365 does not route agents through the gateway: the client must use the gateway endpoint, and direct access to
    the MCP server must stay blocked.

## 07 — Optional: other clients
- **Take:** https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication;
  https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent.
- **Show:** the same governed server from a Foundry agent (project managed identity or OAuth identity passthrough, Preview)
  and from Copilot Studio. Facilitator demo only.

## 99 — Clean up
- terraform destroy for workload and entra; delete role assignments and test users;
  check that nothing remains (`az resource list --tag workshop=...`).

## Docs to produce
- docs/concepts/: token chain diagram, scopes vs app roles, On-Behalf-Of vs managed identity, MCP threat model
  (tool poisoning, prompt injection, token passthrough, confused deputy, over-broad tools).
- docs/facilitator-guide.md: timings, expected outputs, fallback recordings, common errors.
- docs/sources.md: every link above with its last verified date.

## P1 recommendations (design only)

Last source review: 2026-10-14. These are implementation recommendations, not a deployed or validated workshop.
The selected upstream files, versions, licenses, updates, and exclusions are in [sources.md](sources.md).

### Target repository tree

The scaffold, board, workstation preparation and resource-group foundation are present now. The following is the
complete intended tree; runtime modules still need implementation. Every module has the same README contract and its own
`validate.ps1`, `validate.sh`, `cleanup.ps1`, and `cleanup.sh`. Shared Terraform lives in two roots, not one
copy per module. Module folders contain only module-specific assets and instructions.

```text
.devcontainer/
  devcontainer.json
  Dockerfile
.github/
  agents/workshop-builder.agent.md
  copilot-instructions.md
  skills/workshop-module-builder/SKILL.md
  extensions/workshop-build-board/
    extension.mjs, progress.mjs, journey.mjs, server.mjs, board.html, progress.test.mjs
.vscode/mcp.json
.mcp.json
docs/
  BUILD-PLAN.md, PROGRESS.md, COPILOT-RUNBOOK.md, PRACTICE.md, sources.md
  requests/identity-request.md
  concepts/token-chain.md
  concepts/scopes-and-app-roles.md
  concepts/obo-and-managed-identity.md
  concepts/mcp-threat-model.md
  facilitator-guide.md
infra/
  entra/
    versions.tf, providers.tf, main.tf, variables.tf, outputs.tf
    .terraform.lock.hcl
  workload/
    versions.tf, providers.tf, main.tf, variables.tf, outputs.tf
    network.tf, gateway.tf, diagnostics.tf, inventory.tf
    .terraform.lock.hcl
src/
  LocalMcpServer/
    LocalMcpServer.csproj, Program.cs, Tools.cs
  FunctionsMcpServer/
    FunctionsMcpServer.csproj, Program.cs, host.json
    Tools/ServiceHealthTool.cs, Tools/CreateTicketTool.cs
    Tools/WhoAmITool.cs, Tools/ReadReportAsUserTool.cs, Tools/ReadReportAsAppTool.cs
    Identity/DownstreamCredentials.cs
tests/
  FunctionsMcpServer.Tests/
scripts/
  preflight.ps1, preflight.sh
  deploy.ps1, deploy.sh
  lib/Validation.psm1, lib/validation.sh
modules/
  00-prerequisites/             README, validation, cleanup
  01-discover-mcp/              README, validation, cleanup, client-config/
  02-open-server/               README, validation, cleanup, synthetic-data/
  03-entra-authentication/      README, validation, cleanup, synthetic-claims/
  04-governed-gateway/          README, validation, cleanup, policies/
  05-delegated-and-app-only/    README, validation, cleanup, synthetic-data/
  06-observe-and-inventory/    README, validation, cleanup, queries/
  07-other-clients/            README, validation, cleanup, demo-checklist.md
  99-cleanup/                  README, validation, cleanup
THIRD-PARTY-NOTICES.md          Add when upstream code is first adapted
README.md, LICENSE, AGENTS.md, setup-workshop-mcp.ps1
```

### Choices and implementation gates

| Area | Recommendation | Gate before implementation or deployment |
|---|---|---|
| Runtime | .NET 10 isolated worker; Functions host v4; ordinary MCP tool trigger extension 1.5.0 as the upstream starting point | Confirm deployed runtime support, restore and test the minimal tool project. Do not import the sample's Apps/QR/preview SDK dependencies unnecessarily. |
| Local introduction | C# SDK 2.2.0, minimal stdio tool, synthetic arguments | Pin its package and hosting dependencies; send logs to stderr. No weather API or model subscription needed. |
| Inspector | GitHub 2.11.0 source candidate; practice launch pins the registry-available 2.9.0, Node.js >= 22.19.0 | Launch testing found no 2.11.0 package in the configured npm registry. Check availability before launch; test both local and gateway connections. Learn still recommends 0.9.0 in older APIM tips; do not adopt it blindly. Keep tokens in memory or an OS keychain, not plaintext container storage. |
| Protocol | Teach current 2026-07-28 terminology and explicitly explain legacy negotiation | Verify what each pinned client/server actually supports. APIM documents a minimum of 2025-06-18, not proof of every 2026 feature. |
| Terraform | Candidate exact pins: azurerm 5.9.0, azuread 3.10.0, azapi 2.13.0 | Versions exist in the registry; compatibility is not deployment-tested. Commit lock files after module validation, with no state/tfvars. |
| Resource model | AzureRM for Flex, storage, identities, private networking, and supported gateway settings; AzAPI for missing properties and MCP APIs/policies at `2025-09-01-preview` (**Preview**) | Use `Microsoft.ApiManagement/service/apis` with `type: mcp`, `transportType: streamable` and the real Function endpoint `/runtime/webhooks/mcp`. Existing-server proxying does not need REST tool subresources. |
| Network | Standard v2 public gateway with outbound virtual network integration to a Function private endpoint; private DNS and public Function access disabled | Dedicated delegated APIM subnet with network security group; separate private endpoint subnet. Prove gateway access and public direct denial; decide how deployment reaches restricted services. Basic v2 lacks this outbound integration. |
| Region | Evaluate West Europe as the first candidate, with no assumed availability | Preflight must check current Flex locations/runtime, Standard v2 availability, regional quota and policy restrictions for the chosen subscription. Ask before using a different region. |
| Identity | One MCP audience, user scope plus Tools.Read/Tools.Write app roles; assignment required | Identity administrator approves exact objects, consent, test users, and preauthorized clients. Read existing IDs when creation is skipped. |
| Token boundary | Gateway and Function protect one logical MCP resource; the client token is validated there, never sent to Graph or Storage | Separate downstream tokens via On-Behalf-Of (OBO) or managed identity. If gateway and backend become distinct audiences, design explicit token exchange; do not broaden the Function's accepted audiences. |
| OBO | User-assigned managed identity plus a federated identity credential, supported Azure Identity libraries | Downstream Graph User.Read and Storage delegated consent; same-tenant application/identity trust. Reject app-only calls to user-context tools. Never fall back to developer identity in deployed validation. |
| App-only | Separate explicit managed-identity credential for the app-context tool | Storage Blob Data Reader on the one synthetic report container, not the entire subscription. |
| Authorization | Platform token validation plus per-tool role checks; no automatic approval for writes | Preserve the request body when inspecting JSON-RPC. Deny malformed or unsupported call shapes safely. Verify gateway HTTP 403 and distinguish downstream errors embedded in MCP HTTP 200. |
| Telemetry | Authenticated caller object ID, fixed tool name, status, latency and correlation ID only | Zero body bytes on frontend/backend requests/responses at all inherited scopes. Never read streaming response bodies, log arguments/results, or trust caller-supplied identity headers. |
| Inventory | Register only the governed gateway endpoint in API Center | Do not import a third-party server catalog. Inventory registration does not itself authorize runtime access. |

### Risks, permissions, costs, and cleanup

- **Identity permissions:** separate Azure resource creation from Microsoft Entra application/consent work.
  A workload participant needs resource deployment permissions on the workshop resource group. The identity
  administrator needs application management and the consent permissions required by the selected delegated
  APIs. Role assignment permissions are separate from Contributor. Do not request Owner by default.
- **Test identities:** Alice and Bob need actual assigned app roles; Eve remains unassigned. Use dedicated
  non-production test accounts. `whoami` must return an allowlisted synthetic persona, not a live display name
  or email copied into a workshop artifact.
- **Preview:** App Service protected resource metadata, the APIM MCP management API, the canvas SDK surface,
  and optional Microsoft 365 BYO inventory remain explicitly labeled. Self-hosted MCP on Functions is
  **Preview** and is not selected. Recheck optional client feature status before its demo.
- **Source conflicts:** the App Service VS Code walkthrough auto-creates a client secret; use the sample's
  managed-identity federation pattern instead. PRM lab text has an RFC number typo and older authorization
  language; the standard is RFC 9728. API Management overview and existing-server docs disagree on resources;
  use only tools in the core workshop. Do not copy OAuth-server emulation or permissive multi-audience examples.
- **Costs:** Standard v2 is provisioned gateway capacity, not a few Functions executions. Include private
  endpoint, storage, telemetry ingestion/retention, API Center and optional agent charges in the estimate
  before approval. Keep always-ready Functions instances off unless required. No prices are assumed here.
- **Cleanup:** module 99 destroys workload first, then only workshop-created Entra objects and test accounts.
  Preserve provided identities and existing infrastructure. Check role assignments, private DNS/endpoint
  resources, API Center records, soft-deletion/retention behavior, and the complete workshop-tagged inventory.
- **Completion:** prove the previous module first; never convert a design recommendation or canvas save into
  validation evidence. A private gateway design is not implemented until a fresh deployment proves it.

## Sources

See [sources.md](sources.md) for the source register, exact upstream pins, reuse decisions, and limitations.
Last verified: 2026-10-14.
