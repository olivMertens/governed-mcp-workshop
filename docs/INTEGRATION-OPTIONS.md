# Session 2 - Integrate and expose MCP servers in an enterprise architecture

Presenter page, about 35 minutes. It follows the morning on MCP basics and comes before the security session.
Everything shown uses synthetic data (Contoso, Alice, Bob, Eve) in a non-production tenant.

**The message:** for every MCP server, an enterprise takes four decisions: **where it runs**, **how clients reach it**,
**how teams find it** and **who consumes it**. Azure API Management becomes the single front door, whatever runs behind it.

## 1. The four decisions

| Decision | The question | Azure answer | Where in this workshop |
|---|---|---|---|
| Host | Where does the server run? | Azure Functions, App Service, Container Apps, AKS | [Module 02](../modules/02-open-server/README.md) (Functions) |
| Expose | How do clients reach it, and who checks them? | Azure API Management: an existing MCP server, or a REST API turned into tools | [Module 04](../modules/04-governed-gateway/README.md), parts A and B |
| Discover | How do other teams find it instead of building a copy? | Azure API Center inventory, Foundry private tool catalog (**Preview**) | [Module 06](../modules/06-observe-inventory/README.md) |
| Consume | Which clients call it, with which identity? | GitHub Copilot in VS Code, Foundry Agent Service, Copilot Studio | Modules [03](../modules/03-entra-authentication/README.md) to [07](../modules/07-clients/README.md) |

**Say it in one sentence:** the hosting choice belongs to the team that owns the code; the front door, the identity
and the inventory belong to the platform.

## 2. Where to host an MCP server

| Option | Choose it when | Notes |
|---|---|---|
| Azure Functions (MCP extension) | Stateless tools, pay per call | The workshop's choice. Function keys or Microsoft Entra ID |
| App Service, your own server | You add MCP to an existing web app | App Service authentication with Microsoft Entra ID |
| App Service, built-in MCP (**Preview**) | A REST API with an OpenAPI 3.x spec must become MCP fast, with no MCP code | Every OpenAPI operation becomes a tool |
| Azure Container Apps | Any language in a container, scale to zero | Built-in authentication with Microsoft Entra ID |
| Container Apps dynamic sessions | Sandboxed code execution with platform tools | No custom tools; Hyper-V isolation per session |
| Azure Kubernetes Service | The team already runs Kubernetes | Highest operating effort |

**Question for the room:** your team already runs its APIs on App Service. Do you move them to Functions to add MCP?

<details>
<summary>Show answer</summary>

No. Keep the platform the team already runs. What must stay the same everywhere is the governance: a Microsoft Entra
token for the server's own audience, one gateway in front, metadata-only logs and an inventory entry.

</details>

## 3. Expose: two patterns with Azure API Management

| | Part A: existing MCP server behind the gateway | Part B: REST API exposed as an MCP server |
|---|---|---|
| Who writes MCP code | The server team (here, Azure Functions) | Nobody: API operations become tools |
| What the client gets | Tools, and resources or prompts if the server offers them | Tools only (no resources, no prompts) |
| Where identity is checked | Gateway, then the server again | Gateway |
| Server-side logic | Free: several calls, On-Behalf-Of, managed identity | One operation per tool |
| Choose it when | Tools are designed for agents, or need their own logic | A stable REST API already exists and simple calls are enough |

In both patterns the gateway adds the same controls: a Microsoft Entra token for one audience, a role per tool, a rate
limit per caller, metadata-only logs and one public URL. The backend is never published.

Good to know:

- Supported tiers: Developer, Basic, Standard, Premium, Basic v2, Standard v2 and Premium v2. MCP servers are not
  supported in API Management workspaces.
- Infrastructure as code uses the API Management API version `2025-09-01-preview` (**Preview**).
- Never read the response body in an MCP server policy: it breaks streaming.

## 4. Demo 3: a REST API becomes an MCP server (about 8 minutes)

Before the session: deploy [module 04 part B](../modules/04-governed-gateway/README.md) in the test tenant, run its
validator, and keep the real captures ready as a fallback. Delete API Management the same day.

1. In the Azure portal, open API Management, **APIs**, then the **Contoso Tickets** REST API. Show its two operations:
   they return synthetic tickets, with no backend.
2. Open **MCP Servers**: the **Contoso Tickets** MCP server lists two tools, `list_tickets` and `get_ticket`. Each one
   points to an API operation.
3. Open the MCP server **Policies**: the same Microsoft Entra token check as the governed server, a rate limit per
   caller and a role check. No subscription key.
4. In VS Code, the server is a URL only. Sign in as Alice, then paste this prompt in Copilot Chat (**Agent** mode):

   ```prompt
   Use the contoso-tickets MCP server. Call list_tickets, then call get_ticket with ticketId "CT-1001" and summarise the ticket.
   ```

5. Show the failure case: the validator's call without a token gets HTTP 401 with the metadata link. This is the bridge
   to the security session.

Fallback if the live demo cannot run: these real captures come from the same deployment (2026-10-19, author's test
tenant; names pseudonymised, IDs replaced by zeros).

![Real capture: API Management MCP Servers list with the REST-backed contoso-tickets-mcp and the existing workshop-mcp server](../assets/screenshots/azure-04-mcp-servers.png)

![Real capture: MCP server Tools blade with the two REST operations selected as tools](../assets/screenshots/azure-04b-mcp-tools.png)

![Real terminal output: Alice lists the two tools and calls them through the gateway](../assets/screenshots/terminal-04b-alice.png)

## 5. Registry and discovery

- **Azure API Center** is the inventory: one entry per MCP server, with its owner, environment and endpoint. Register
  the gateway URL, never the backend URL ([module 06](../modules/06-observe-inventory/README.md)).
- **Foundry private tool catalog (Preview)** reads that inventory: developers find the organisation's MCP servers in
  Foundry Tools. They need at least the Azure API Center Data Reader role. A role assignment can take up to 24 hours.
- Tenant-wide governance with Agent 365 and Microsoft 365 BYO MCP servers (**Preview**) belongs to the Agent 365 session.

## 6. What a Global Administrator should check when a business unit adopts Foundry

1. **Consent.** Who may grant consent to applications and agents, and is the admin consent workflow on?
2. **Who may add MCP servers.** Foundry project roles decide who can add tools and connections. Prefer the private
   catalog over free-form URLs.
3. **Identities.** Agents get their own identities (Microsoft Entra Agent ID, **Preview**): inventory them like
   applications, with an owner and an expiry.
4. **Conditional Access.** Users and agents reach the same MCP servers: apply the same sign-in policies.
5. **Data leaving the tenant.** A third-party MCP server receives prompts and tool arguments. Approve each one like a
   SaaS application.
6. **Logs and cost.** Metadata only (tool, caller, status, latency). API Management v2 and Foundry are billed while they
   run: tag owners and expiry dates.

**Bridge to the next session:** "We know where MCP servers live and how they are exposed. Next: who carries the rights
on each call, one token per hop."

## Sources

- [About MCP servers in Azure API Management](https://learn.microsoft.com/azure/api-management/mcp-server-overview)
- [Expose a REST API in API Management as an MCP server](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server)
- [Expose and govern an existing MCP server](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server)
- [Manage MCP servers programmatically in API Management](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) (API version `2025-09-01-preview`)
- [Choose an Azure service for your MCP server](https://learn.microsoft.com/azure/container-apps/mcp-choosing-azure-service)
- [Register and discover MCP servers in Azure API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server)
- [Create a private tool catalog in Foundry (preview)](https://learn.microsoft.com/azure/foundry/agents/how-to/private-tool-catalog)

Last verified: 2026-10-19.
