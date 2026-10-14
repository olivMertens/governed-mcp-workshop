# Understand the governance boundary

Read a stage, predict its result, then use its published guide and validator when available.
These explanations describe the **planned** workshop, not an already deployed service.
Architecture diagrams show request, identity and administrative flows separately; they do not launch anything.

> [!IMPORTANT]
> Authentication asks who is calling. Authorization asks what that identity may do.
> Client approval asks whether a human permits this particular action. You need all three; none replaces another.

## 00 - Prerequisites and environment

**Goal:** choose the right tools, tenant, subscription, permissions and cost boundary.
The identity administrator controls Entra applications and consent. The workload operator controls resources.
Resource-based access control (RBAC) assignments need separate authority.

**Diagram:** the identity preparation lane targets Entra; the resource preparation lane targets the test
subscription. Neither is an MCP runtime request. A codespace is a development machine, not a test tenant.

> [!TIP]
> Start with the in-board deployment-context guide. Ask who owns identity approval before asking for deployment rights.

**Expected evidence:** the real preflight and identity request are ready. Selecting a subscription alone is insufficient.
**Next:** module 01 after the published module 00 validator passes; there is still no cloud deployment in 01.

**Deep dive:** [tenant/subscription selection](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli),
[Azure role assignments](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).

## 01 - Discover MCP without Azure

**Goal:** distinguish discovery from execution. Model Context Protocol (MCP) describes how a client discovers
tools and invokes their advertised schemas. Standard input/output (stdio) runs locally; Streamable HTTP is for
the remote stages. A browser GET is not a tool-discovery test.

**Diagram:** local client to local server to a synthetic tool. No Entra, gateway or billed cloud resource is required.
Tool annotations help the client, but cannot enforce authorization.

> [!IMPORTANT]
> Keep the client's human approval for writes. Check the actual tool-call record, not an assistant's prose.

**Expected evidence:** a real tool list, a real synthetic result and a visible approval control.
**Next:** module 02 only after validation and approval of the non-production paid deployment.

**Deep dive:** [MCP architecture](https://modelcontextprotocol.io/specification/2026-07-28/architecture),
[transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports),
[tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
[VS Code clients](https://code.visualstudio.com/docs/agent-customization/mcp-servers).

## 02 - A key is not a user's identity

**Goal:** demonstrate the limits of a shared credential. The Azure Functions MCP extension uses its
`mcp_extension` system key and `System` webhook authorization. "Open" means no per-user identity yet, not anonymous.

**Diagram:** a key-bearing client calls Functions; a synthetic write reaches a Storage queue in the test subscription.
Identity-dependent tools are explicitly simulated until module 05.

> [!WARNING]
> Keep this stage short-lived. Never disable webhook protection, save a credential-bearing header or put a key in a URL.
> Anyone with the key can perform the exposed actions; this is not the enterprise target state.

**Expected evidence:** HTTP 401 without the key; HTTP 200 plus a successful MCP result with the correct key.
**Next:** module 03 replaces the shared-key teaching boundary with assigned-user authentication.

**Deep dive:** [official pinned Functions sample](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9),
[MCP bindings](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp).

## 03 - Identity, scope and app role

**Goal:** accept tokens for this MCP resource only. Validate issuer, tenant, audience and expiry using the
platform; then enforce delegated scopes and app roles. Never write a custom JSON Web Token (JWT) validator.
A scope says what the client may do for a user. An app role says which user or application may do an operation.

**Diagram:** sign-in first returns a token to the client. A separate request lane shows that client calling the
Function with that token. Entra does not proxy tool calls. Protected Resource Metadata (PRM) is **Preview**.

> [!IMPORTANT]
> Alice and Bob are assigned; Eve is not. Authentication alone does not grant every tool.
> Use synthetic claim examples, never a live token in a decoder site, chat or file.

**Expected evidence:** HTTP 401 for absent/wrong-audience tokens; Alice and Bob connect; Eve cannot obtain the
required assigned-user token. Role-specific gateway checks come in 04.
**Next:** module 04 makes API Management the enforced entry point.

**Deep dive:** [MCP authorization and PRM](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp),
[app roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).

## 04 - An enforced gateway, not just a convenient URL

**Goal:** API Management (APIM) checks the exact MCP audience, scope, role and rate limit. It does not broaden
accepted audiences to make a call work. APIM and Functions protect one logical MCP resource.
The MCP management API `2025-09-01-preview` is **Preview**, not the preview AI Gateway tier.

**Diagram:** client to Standard v2 APIM to a private Function. Outbound virtual network integration and private
DNS provide reachability; disabling public Function access prevents bypass. Network isolation is not token validation.

> [!WARNING]
> Test direct-backend denial too. A working gateway path is insufficient if the public Function still accepts calls.
> Bob must not receive Tools.Write just to make a demonstration look successful.

**Expected evidence:** Bob's approved synthetic write gets gateway HTTP 403, Alice's gets HTTP 200 and a successful
result, a burst gets 429, direct backend access is denied and logs contain zero body bytes.
**Next:** module 05 compares whose rights reach downstream data.

**Deep dive:** [existing-server exposure](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server),
[token policy](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy),
[outbound networking](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound),
[programmatic management (Preview)](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api).

## 05 - Delegated versus application access

**Goal:** On-Behalf-Of (OBO) exchanges a user's MCP token for a separate downstream token, preserving user context.
An explicit managed identity (MI) obtains an app-only token with the application's own resource-scoped rights.
Supported identity libraries and federated credentials avoid client secrets.

**Diagram:** two independent request lanes retain APIM. The top lane uses a user-context Storage token;
the bottom uses a managed-identity Storage token. `whoami` uses a separately acquired Microsoft Graph token
for Graph's own audience; Graph is not the Storage endpoint shown here.

> [!WARNING]
> Never forward the MCP token to Graph or Storage. An app-only identity is not a way to impersonate a user.
> Do not fall back to a developer identity after a delegation failure.

| Tool | Alice | Bob | Whose resource rights? |
|---|---|---|---|
| `read_report_as_user` | Allowed | Downstream denial | The user |
| `read_report_as_app` | Same authorized synthetic report | Same authorized synthetic report | The managed identity |

**Expected evidence:** all four cases. Record transport status and MCP error state: a downstream HTTP 403 may be
inside an outer HTTP 200.
**Next:** module 06 traces metadata without capturing content.

**Deep dive:** [OBO token boundary](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow),
[secretless managed-identity federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).

## 06 - Observe metadata, inventory endpoints

**Goal:** explain who called which tool and whether it worked without recording its body.
Use authenticated caller object ID, fixed tool name, status, latency and correlation ID only.
Kusto Query Language (KQL) can correlate those approved fields.

**Diagram:** the request path, telemetry lane and inventory-registration lane are separate.
Application Insights receives metadata, not a copy of the payload. Azure API Center lists the gateway endpoint;
it does not forward requests, authenticate callers or grant tool permission.

> [!WARNING]
> Zero body bytes at inherited frontend and backend diagnostic scopes. No tokens, prompts, arguments, results
> or exported Inspector transcripts. Optional Microsoft 365 inventory is **Preview** and facilitator-only.

**Expected evidence:** a metadata-only call trace, useful denial queries and the governed endpoint in inventory.
**Next:** module 99 stops costs. Module 07 is an optional facilitator branch, not a prerequisite.

**Deep dive:** [APIM telemetry](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights),
[API Center registration](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server),
[Microsoft 365 BYO inventory (Preview)](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server).

## 07 - Optional clients, same boundary

**Goal:** compare a user-delegated client with an application-identity client without changing the server's boundary.
The diagram is a **planned optional connection**, not proof of a created Foundry agent or a configured Copilot Studio agent.

**Diagram:** optional client to the same governed gateway to the private Function. Determine which identity reaches
MCP before interpreting tool results. Recheck Preview status, licensing, scopes, callback support and secretless authentication.

> [!IMPORTANT]
> Defer the documented Copilot Studio manual OAuth route if it requires a client secret.
> A product feature called identity passthrough does not permit server-to-downstream token passthrough.

**Expected evidence:** only an explicitly supported, approved, secretless connection. No extra client is required
to complete the core path.
**Next:** module 99, even if this demonstration is skipped.

**Deep dive:** [Foundry authentication, selected flows Preview](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication),
[Copilot Studio MCP](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent).

## 99 - Clean up only what the workshop owns

**Goal:** stop costs and remove workshop-created assignments without deleting shared resources.
The diagram's two lanes are administrative review/cleanup, not runtime requests.

> [!WARNING]
> Review the actual destroy plan and get explicit approval. Destroy workload first, then only workshop-created
> Entra objects. Preserve provided IDs, existing accounts and shared infrastructure.

**Expected evidence:** no remaining workshop-owned tagged workload resources; exact created identity objects and
role assignments accounted for; retention/soft-delete and inventory checked. Stop clients and unused codespaces.
**Next:** return to the overview or repeat the workshop with a new approved prefix after cleanup is verified.

**Deep dive:** [Terraform destroy semantics](https://developer.hashicorp.com/terraform/cli/commands/destroy),
[Azure role assignments](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).

## Sources

Use the in-board source register for the full official links, pinned samples, licenses and unresolved compatibility
gates. See [sources.md](sources.md), [DEPLOYMENT.md](DEPLOYMENT.md) and [PRACTICE.md](PRACTICE.md).
Last verified: 2026-10-14. These are authored teaching summaries, not copies of upstream documentation.
