# Session 2 - Integrate and expose MCP servers in an enterprise architecture

Presenter page, about 35 minutes. It follows the morning on MCP basics and comes before the security session.
Everything shown uses synthetic data (Contoso, Alice, Bob, Eve) in a non-production tenant.

**The message:** for every MCP server, an enterprise takes four decisions: **where it runs**, **how clients reach it**,
**how teams find it** and **who consumes it**. Azure API Management becomes the single front door, whatever runs behind it.

## 1. From this morning to the front door

Open the session with this animated walk-through. It starts from the local server of the morning and adds one
element per click, with the real command behind each one. Select **Reveal next** or use the arrow keys.

```reveal
{
  "title": "From this morning to the front door",
  "width": 1100,
  "height": 500,
  "lanes": [
    {"x":10,"width":240,"label":"Consume · clients"},
    {"x":315,"width":245,"label":"Expose · front door"},
    {"x":615,"width":245,"label":"Host · where it runs"},
    {"x":885,"width":205,"label":"Discover · inventory"}
  ],
  "nodes": [
    {"id":"vscode","step":0,"tone":"morning","x":20,"y":44,"width":210,"title":"VS Code + Copilot","detail":["Alice (Contoso)","Agent mode"]},
    {"id":"local","step":0,"until":1,"tone":"morning","x":630,"y":44,"width":215,"title":"Local MCP server","detail":["stdio · Workshop.LocalMcp","get_service_health"]},
    {"id":"func","step":1,"x":630,"y":150,"width":215,"icon":"functions","title":"Azure Functions","detail":["MCP extension","/runtime/webhooks/mcp"]},
    {"id":"entra","step":2,"tone":"governed","x":330,"y":44,"width":215,"icon":"entra","title":"Microsoft Entra ID","detail":["aud: api://<client-id>","roles: Tools.Read"]},
    {"id":"apimA","step":2,"tone":"governed","x":330,"y":150,"width":215,"icon":"apim","title":"workshop-mcp","detail":["API Management · part A","/workshop-mcp/mcp"]},
    {"id":"apimB","step":3,"tone":"preview","x":330,"y":260,"width":215,"icon":"apim","title":"contoso-tickets-mcp","detail":["part B · Preview","list_tickets · get_ticket"]},
    {"id":"rest","step":3,"x":630,"y":260,"width":215,"title":"contoso-tickets-api","detail":["GET /tickets/{ticketId}","mock-response, no backend"]},
    {"id":"anon","step":5,"tone":"risk","x":20,"y":300,"width":210,"title":"Call without a token","detail":["validate-rest-mcp.ps1","HTTP 401 + challenge"]},
    {"id":"clients","step":6,"tone":"governed","x":20,"y":410,"width":210,"icon":"foundry-agent-service","title":"Other clients","detail":["Foundry Agent Service","Copilot Studio"]},
    {"id":"apic","step":7,"tone":"preview","x":895,"y":300,"width":195,"icon":"api-center","title":"Azure API Center","detail":["Preview","gateway URL only"]},
    {"id":"catalog","step":7,"tone":"preview","x":895,"y":410,"width":195,"icon":"foundry-agent-service","title":"Tool catalog","detail":["Foundry · Preview","reads API Center"]}
  ],
  "edges": [
    {"from":"vscode","to":"local","step":0,"until":1,"tone":"morning","label":"stdio"},
    {"from":"vscode","to":"func","step":1,"until":2,"tone":"risk","label":"function key"},
    {"from":"vscode","to":"apimA","step":2,"tone":"governed","label":"Entra token"},
    {"from":"entra","to":"apimA","step":2,"tone":"governed","label":"validate token"},
    {"from":"apimA","to":"func","step":2,"tone":"governed","label":"private"},
    {"from":"apimB","to":"rest","step":3,"tone":"preview","label":"op = tool"},
    {"from":"vscode","to":"apimB","step":4,"tone":"governed","fromSide":"bottom","toSide":"left","toOffset":-10,"label":"list_tickets"},
    {"from":"anon","to":"apimB","step":5,"tone":"risk","offset":10,"label":"401"},
    {"from":"clients","to":"apimB","step":6,"tone":"governed","toSide":"bottom","toOffset":-50,"label":"same URL"},
    {"from":"apimB","to":"apic","step":7,"tone":"preview","fromSide":"bottom","toSide":"left","fromOffset":50,"bend":70,"label":"register gateway URL","labelDy":26},
    {"from":"apic","to":"catalog","step":7,"tone":"preview","label":"reads"}
  ],
  "steps": [
    {
      "title": "This morning: one local server",
      "simple": "This morning, the tool lived on your laptop: only you could use it.",
      "say": "Recap of [module 01](../modules/01-discover-mcp/README.md). The client starts the server as a child process and talks to it over **stdio**: no network, no identity, one user. `tools/list` returns `get_service_health`.",
      "show": "The Inspector command line listing the tools of the local server. Ask the room: who else can call it? Nobody, and that is the limit.",
      "blocks": [
        {
          "language": "powershell",
          "code": "$server = (Resolve-Path .\\modules\\01-discover-mcp\\server\\bin\\Release\\net10.0\\Workshop.LocalMcp.dll).Path\nnpx @modelcontextprotocol/inspector@2.9.0 --cli dotnet $server --method tools/list"
        }
      ]
    },
    {
      "title": "Host: the same tools on Azure Functions",
      "simple": "We put the same tool in the cloud. It works, but anyone who has the key can call it.",
      "say": "Decision 1, **where it runs**. [Module 02](../modules/02-open-server/README.md) deploys the MCP extension on Azure Functions. The endpoint is public and only a function key protects it: the **open** level, shown to make the risk visible.",
      "show": "The URL `https://<function-app-host>/runtime/webhooks/mcp`. The key goes to the clipboard, never on screen. Rotate it right after the demo.",
      "blocks": [
        {
          "language": "powershell",
          "code": "terraform '-chdir=infra\\workload' apply '..\\..\\.workshop\\module02.tfplan'\n$group = terraform -chdir=infra/workload output -raw resource_group_name\n$app = terraform -chdir=infra/workload output -raw mcp_function_app_name\naz functionapp deployment source config-zip --resource-group $group --name $app --src .\\.workshop\\module02.zip --output none\naz functionapp keys list --resource-group $group --name $app --query systemKeys.mcp_extension --output tsv | Set-Clipboard"
        }
      ]
    },
    {
      "title": "Expose: API Management becomes the front door",
      "simple": "We add a front door. It checks your badge before it lets you in.",
      "say": "Decision 2, **how clients reach it**. [Module 04](../modules/04-governed-gateway/README.md) part A puts API Management in front of the Function. The gateway validates a Microsoft Entra token for the server's own audience, checks a role per tool and limits calls per caller. The function key disappears and the Function is no longer published.",
      "show": "The client configuration: one gateway URL, no header, no key, no secret. `$vars` comes from module 04, step 3.",
      "blocks": [
        {
          "language": "powershell",
          "code": "terraform '-chdir=infra\\workload' plan @vars '-out=..\\..\\.workshop\\module04.tfplan'\nterraform '-chdir=infra\\workload' apply '..\\..\\.workshop\\module04.tfplan'"
        },
        {
          "language": "json",
          "code": "{\n  \"servers\": {\n    \"workshop-governed\": { \"type\": \"http\", \"url\": \"https://apim-mcp-<prefix>-<suffix>.azure-api.net/workshop-mcp/mcp\" }\n  }\n}"
        }
      ]
    },
    {
      "title": "Expose part B: a REST API becomes an MCP server",
      "simple": "An existing API can become tools too, with no new code, behind the same door.",
      "say": "Nobody writes MCP code. Each ticked API operation becomes one tool on the same gateway, with the same token check. API Management MCP servers are **Preview** in infrastructure as code (`2025-09-01-preview`).",
      "show": "Azure portal, API Management, **MCP Servers**: `contoso-tickets-mcp`, then **Tools**: `list_tickets` and `get_ticket`.",
      "blocks": [
        {
          "language": "powershell",
          "code": "$varsB = $vars + '-var-file=..\\..\\.workshop\\module04b.tfvars.json'\nterraform '-chdir=infra\\workload' plan @varsB '-out=..\\..\\.workshop\\module04b.tfplan'\nterraform '-chdir=infra\\workload' apply '..\\..\\.workshop\\module04b.tfplan'"
        },
        {
          "language": "text",
          "code": "azapi_resource.rest_mcp_api[0]: Creation complete after 5s [id=.../apis/contoso-tickets-mcp]\nazapi_resource.rest_mcp_tool[\"get_ticket\"]: Creation complete after 2s [id=.../apis/contoso-tickets-mcp/tools/get_ticket]\nazapi_resource.rest_mcp_tool[\"list_tickets\"]: Creation complete after 3s [id=.../apis/contoso-tickets-mcp/tools/list_tickets]",
          "output": true
        }
      ]
    },
    {
      "title": "Consume: Alice calls a tool",
      "simple": "Alice shows her badge, asks for a ticket and gets the answer.",
      "say": "Decision 4, **who consumes it**. In VS Code the server is a URL only. Alice signs in, the gateway checks her token and her role, and the tool answers with synthetic tickets.",
      "show": "Copilot Chat in **Agent** mode. Approve each tool call yourself.",
      "blocks": [
        {
          "language": "prompt",
          "code": "Use the contoso-tickets MCP server. Call list_tickets, then call get_ticket with ticketId \"CT-1001\" and summarise the ticket."
        }
      ]
    },
    {
      "title": "No token, no tool",
      "simple": "No badge, no entry: the door answers 401 and says where to get a badge.",
      "say": "The same call without a token gets **HTTP 401** with a challenge that names the gateway metadata. A token for another audience (Microsoft Graph) is refused too. This is the bridge to the security session.",
      "show": "The validator's PASS lines: each one names the expected HTTP status.",
      "blocks": [
        {
          "language": "powershell",
          "code": "& .\\modules\\04-governed-gateway\\validate-rest-mcp.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID"
        },
        {
          "language": "text",
          "code": "PASS part B MCP request without a token is refused with a challenge naming its metadata URL (expected HTTP 401).\nPASS the backing REST API /contoso-tickets/tickets without a token is refused (expected HTTP 401).\nPASS a valid token for another audience (Microsoft Graph) is refused by the part B MCP server and its REST API (expected HTTP 401).",
          "output": true
        }
      ]
    },
    {
      "title": "Same front door for every client",
      "simple": "Every client uses the same door. Only the badge changes.",
      "say": "Foundry Agent Service and Copilot Studio use the same gateway URL. Only the identity changes: the user's (On-Behalf-Of) or the agent's own (app-only). See modules [05](../modules/05-delegated-and-app-only/README.md) and [07](../modules/07-clients/README.md).",
      "show": "One gateway, several clients. The backend URL never appears in any client."
    },
    {
      "title": "Discover: register the gateway, not the backend",
      "simple": "We list the door's address in a catalogue, so other teams reuse it instead of building a copy.",
      "say": "Decision 3, **how teams find it**. Azure API Center (**Preview** for MCP) keeps one entry per server, with owner and environment. The Foundry private tool catalog (**Preview**) reads that inventory. Portal steps in [module 06](../modules/06-observe-inventory/README.md).",
      "show": "The API Center entry: the endpoint is the gateway URL. Bridge: \"Next, who carries the rights on each call, one token per hop.\""
    }
  ]
}
```

## 2. The whole picture

**In one sentence:** wherever an MCP server runs, people and agents reach it through one front door that checks who
they are, and other teams find it in one inventory.

![Session 2 architecture: clients on the left call one API Management front door with a Microsoft Entra token; behind it, the Azure Functions MCP server (part A) and a REST API whose operations become tools (part B, Preview); the gateway URL is registered in Azure API Center, which the Foundry tool catalog reads (Preview)](../assets/architecture/session2.en.svg)

#### Read it from left to right

1. **Consume: who calls.** A person in VS Code, a Foundry agent or a Copilot Studio agent asks for a tool.
2. **Expose: the front door.** API Management checks the badge (a Microsoft Entra token made for this server) and the
   role, then lets the call in. No badge: HTTP 401.
3. **Host: where it runs.** Behind the door, the team keeps its own server (Azure Functions) or turns an existing REST
   API into tools. Nobody calls them directly.
4. **Discover: how teams find it.** The door's address goes into an inventory, so other teams reuse it instead of
   building a copy.

<details>
<summary>Advanced: read the diagram</summary>

- **One token per hop, one audience per token.** Clients get a Microsoft Entra token for the MCP server's own audience
  (`api://<client-id>`). The gateway validates issuer, tenant, audience and expiry with `validate-azure-ad-token`, then
  checks the app role per tool (`Tools.Read`, `Tools.Write`) and applies a rate limit per caller object ID
  ([module 04](../modules/04-governed-gateway/README.md)).
- **No token passthrough to downstream APIs.** Calls from the Function to other APIs use On-Behalf-Of or a managed
  identity, chosen per tool ([module 05](../modules/05-delegated-and-app-only/README.md)).
- **The backend is never published.** Part A reaches the Function through a private endpoint; its public network access
  is disabled. Part B has no backend: REST policies (`mock-response`) answer with synthetic tickets.
- **Discovery for clients.** A call without a token gets HTTP 401 with a challenge that names the gateway's Protected
  Resource Metadata (RFC 9728), so clients such as VS Code know where to sign in.
- **No subscription keys.** Every API sets `subscriptionRequired = false`: access depends on Microsoft Entra tokens
  and app roles only.
- **Inventory, not traffic.** API Center (**Preview** for MCP) stores the gateway URL, owner and environment
  ([module 06](../modules/06-observe-inventory/README.md)); the Foundry private tool catalog (**Preview**) reads it.
- **Infrastructure as code.** API Management MCP servers use API version `2025-09-01-preview` (**Preview**) through
  the azapi provider, in `infra/workload/gateway.tf` and `infra/workload/rest-mcp.tf`.
- Edit the diagram in [session2.drawio](../assets/architecture/session2.drawio), then regenerate the SVG and PNG with
  `scripts/render-architecture.py`.

</details>

## 3. The four decisions

| Decision | The question | Azure answer | Where in this workshop |
|---|---|---|---|
| Host | Where does the server run? | Azure Functions, App Service, Container Apps, AKS | [Module 02](../modules/02-open-server/README.md) (Functions) |
| Expose | How do clients reach it, and who checks them? | Azure API Management: an existing MCP server, or a REST API turned into tools | [Module 04](../modules/04-governed-gateway/README.md), parts A and B |
| Discover | How do other teams find it instead of building a copy? | Azure API Center inventory, Foundry private tool catalog (**Preview**) | [Module 06](../modules/06-observe-inventory/README.md) |
| Consume | Which clients call it, with which identity? | GitHub Copilot in VS Code, Foundry Agent Service, Copilot Studio | Modules [03](../modules/03-entra-authentication/README.md) to [07](../modules/07-clients/README.md) |

**Say it in one sentence:** the hosting choice belongs to the team that owns the code; the front door, the identity
and the inventory belong to the platform.

## 4. Where to host an MCP server

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

## 5. Expose: two patterns with Azure API Management

| | Part A: existing MCP server behind the gateway | Part B: REST API exposed as an MCP server |
|---|---|---|
| Who writes MCP code | The server team (here, Azure Functions) | Nobody: API operations become tools |
| What the client gets | Tools and resources; API Management does not support MCP prompts yet | Tools only (no resources, no prompts) |
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

## 6. Demo 3: a REST API becomes an MCP server (about 8 minutes)

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

![Real capture: API Management MCP Servers list; frame 1 marks workshop-mcp with Source MCP server (passthrough to the Function), frame 2 contoso-tickets-mcp with Source API (built from the REST API)](../assets/screenshots/azure-04-mcp-servers.png)

![Real capture: MCP server Tools blade with the two REST operations selected as tools](../assets/screenshots/azure-04b-mcp-tools.png)

![Real terminal output: Alice lists the two tools and calls them through the gateway](../assets/screenshots/terminal-04b-alice.png)

## 7. Registry and discovery

- **Azure API Center** is the inventory: one entry per MCP server, with its owner, environment and endpoint. Register
  the gateway URL, never the backend URL ([module 06](../modules/06-observe-inventory/README.md)).
- **Foundry private tool catalog (Preview)** reads that inventory: developers find the organisation's MCP servers in
  Foundry Tools. They need at least the Azure API Center Data Reader role. A role assignment can take up to 24 hours.
- Tenant-wide governance with Agent 365 and Microsoft 365 BYO MCP servers (**Preview**) belongs to the Agent 365 session.

## 8. What a Global Administrator should check when a business unit adopts Foundry

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

Last verified: 2026-10-20.
