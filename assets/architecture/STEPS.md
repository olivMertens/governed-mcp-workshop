# Architecture, step by step

These diagrams show learning targets, not deployed resources. See build progress for validation evidence.

The Model Context Protocol (MCP) connects a client to tools. Each step adds a control or explains an ownership boundary.

[What is actually available](../../docs/IMPLEMENTATION-STATUS.md). [Edit diagrams and verify icon provenance](README.md).

Generated from `workshop.drawio`; do not edit separately. Frames are ownership boundaries; repeated views refer to the same environment. GitHub renders Mermaid; the application displays the equivalent SVG with verified icons and routing.

## 00 - Prepare identity and resource authority

Entra authority and Azure resource permissions are distinct. No MCP call or resource creation is shown.

[SVG](00.en.svg) · [PNG](00.en.png)

```mermaid
flowchart LR
  %% Identity preparation - administrative flow
  %% Resource preparation - no deployment yet
  n_node_0_0["Identity admin / Approved scope"]
  n_node_0_2["Public clients / Exact callbacks"]
  n_node_1_0["Workload operator / Test budget"]
  n_node_1_2["Preflight / Permissions / cost"]
  subgraph boundary_0["Microsoft Entra tenant"]
    n_node_0_1["Microsoft Entra ID / Apps and consent"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Your Azure test workload"]
    n_node_1_1["Azure subscription / Resource group"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Review"| n_node_0_1
  n_node_0_1 -->|"Approve"| n_node_0_2
  n_node_1_0 -->|"Select / verify"| n_node_1_1
  n_node_1_1 -->|"Check"| n_node_1_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_2 fill:#ffffff,stroke:#1659dc,color:#172c48
```

## 01 - Discover and call locally

Discovery is not execution. Keep human approval for each write. Negotiate the supported protocol era.

[SVG](01.en.svg) · [PNG](01.en.png)

```mermaid
flowchart LR
  %% Local process boundary - no Azure deployment
  subgraph boundary_0["Local workstation"]
    n_node_0_0["MCP client / VS Code / Inspector"]
    n_node_0_1["Local MCP server / stdio transport"]
    n_node_0_2["Synthetic tool / Explicit approval"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"List / call"| n_node_0_1
  n_node_0_1 -->|"Invoke"| n_node_0_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#ffffff,stroke:#1659dc,color:#172c48
```

## 02 - A shared key is not a user's identity

No anonymous endpoint. Identity tools are simulated until 05. Stop this shared-key stage promptly.

[SVG](02.en.svg) · [PNG](02.en.png)

```mermaid
flowchart LR
  %% Short-lived key demonstration - your test subscription
  n_node_0_0["MCP client / System key"]
  subgraph boundary_0["Your Azure test workload"]
    n_node_0_1["Azure Functions / System protection"]
    n_node_0_2["Azure Storage / Synthetic queue"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"MCP + key"| n_node_0_1
  n_node_0_1 -->|"Write approved"| n_node_0_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 03 - Sign in first, call the protected resource second

401 without a valid MCP token. Eve is unassigned. No live tokens in logs, chat, files or decoder websites.

[SVG](03.en.svg) · [PNG](03.en.png)

```mermaid
flowchart LR
  %% 1. Identity flow - Entra returns the token to the client
  %% 2. Request flow - PRM discovery is Preview
  n_node_0_0["MCP client / Approved public app"]
  n_node_0_2["Same MCP client / Token for MCP"]
  n_node_1_0["MCP client / MCP audience"]
  subgraph boundary_0["Microsoft Entra tenant"]
    n_node_0_1["Microsoft Entra ID / Assigned users"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Your Azure test workload"]
    n_node_1_1["Azure Functions / Platform validation"]
    n_node_1_2["Synthetic read / Scope / app role"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Sign in"| n_node_0_1
  n_node_0_1 -->|"Issue token"| n_node_0_2
  n_node_1_0 -->|"MCP token"| n_node_1_1
  n_node_1_1 -->|"Authorize"| n_node_1_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_2 fill:#ffffff,stroke:#1659dc,color:#172c48
```

## 04 - Only the governed gateway accepts clients

Public Function access disabled. Private DNS + outbound integration. 403 Bob / 429 burst. MCP management API: Preview.

[SVG](04.en.svg) · [PNG](04.en.png)

```mermaid
flowchart LR
  %% Request flow - APIM and Functions protect one MCP resource
  n_node_0_0["MCP client / Token for MCP"]
  subgraph boundary_0["Your Azure test workload"]
    n_node_0_1["API Management / Standard v2"]
    n_node_0_2["Azure Functions / Private endpoint"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"MCP token"| n_node_0_1
  n_node_0_1 -->|"Private network"| n_node_0_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 05 - Two downstream identities, two different permission checks

Never forward the MCP token to Storage or Graph. Graph needs its own token. Downstream 403 can be inside HTTP 200.

[SVG](05.en.svg) · [PNG](05.en.png)

```mermaid
flowchart LR
  %% User context - On-Behalf-Of (OBO)
  %% Application context - managed identity (MI)
  n_node_0_0["MCP client / Alice / Bob"]
  n_node_1_0["MCP client / Alice / Bob"]
  subgraph boundary_0["Your Azure test workload"]
    n_node_0_1["API Management / MCP role check"]
    n_node_0_2["Azure Functions / OBO exchange"]
    n_node_0_3["Azure Storage / User RBAC"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Your Azure test workload"]
    n_node_1_1["API Management / MCP role check"]
    n_node_1_2["Azure Functions / Explicit MI"]
    n_node_1_3["Azure Storage / MI container role"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"MCP token"| n_node_0_1
  n_node_0_1 -->|"MCP token"| n_node_0_2
  n_node_0_2 -->|"Storage token / User rights"| n_node_0_3
  n_node_1_0 -->|"MCP token"| n_node_1_1
  n_node_1_1 -->|"MCP token"| n_node_1_2
  n_node_1_2 -->|"Storage token / App rights"| n_node_1_3
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_3 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_3 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 06 - Requests, observation and inventory are separate flows

Only tool, caller object ID, status, latency and correlation ID. API Center does not authorize or relay requests.

[SVG](06.en.svg) · [PNG](06.en.png)

```mermaid
flowchart LR
  %% 1. Runtime request - governed endpoint only
  %% 2. Observation - not a request-body copy
  %% 3. Inventory - administrative registration, not runtime routing
  n_node_0_0["MCP client / Approved call"]
  n_node_2_0["Register gateway / Approved endpoint"]
  subgraph boundary_0["Your Azure test workload"]
    n_node_0_1["API Management / Validate / authorize"]
    n_node_0_2["Azure Functions / Private endpoint"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Your Azure test workload"]
    n_node_1_0["Same gateway / Authenticated caller"]
    n_node_1_1["Application Insights / Zero body bytes"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_2["Your Azure test workload"]
    n_node_2_1["Azure API Center / No access grant"]
  end
  style boundary_2 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"MCP"| n_node_0_1
  n_node_0_1 -->|"Private network"| n_node_0_2
  n_node_1_0 -->|"Metadata only"| n_node_1_1
  n_node_2_0 -->|"Inventory"| n_node_2_1
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_2_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_2_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 07 - Optional clients use the same governed boundary

No agent deployed here. Check licensing, Preview and secretless support. Defer any client-secret requirement.

[SVG](07.en.svg) · [PNG](07.en.png)

```mermaid
flowchart LR
  %% Planned facilitator demo - selected Foundry flows Preview
  n_node_0_0["Optional MCP client / User or application"]
  subgraph boundary_0["Your Azure test workload"]
    n_node_0_1["API Management / Same controls"]
    n_node_0_2["Azure Functions / Private endpoint"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Approved identity"| n_node_0_1
  n_node_0_1 -->|"Private network"| n_node_0_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 99 - Remove workshop-owned resources, preserve shared identities

Workload first, then only created Entra objects. Check assignments, private DNS, inventory, retention and codespaces.

[SVG](99.en.svg) · [PNG](99.en.png)

```mermaid
flowchart LR
  %% 1. Resource cleanup - administrative flow after explicit approval
  %% 2. Identity cleanup - do not delete supplied identities
  n_node_0_0["Review ownership / Actual destroy plan"]
  n_node_0_2["Verify inventory / Costs / retention"]
  n_node_1_0["Identity admin / Review created IDs"]
  n_node_1_2["Preserve existing / Users / apps"]
  subgraph boundary_0["Your Azure test workload"]
    n_node_0_1["Azure subscription / Workload teardown"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Microsoft Entra tenant"]
    n_node_1_1["Microsoft Entra ID / Workshop objects only"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Approve"| n_node_0_1
  n_node_0_1 -->|"Verify"| n_node_0_2
  n_node_1_0 -->|"Approve scope"| n_node_1_1
  n_node_1_1 -->|"Verify"| n_node_1_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_2 fill:#ffffff,stroke:#1659dc,color:#172c48
```

## Sources

- [Draw.io](workshop.drawio).
- [GitHub Mermaid](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams).
- [Mermaid flowcharts](https://mermaid.js.org/syntax/flowchart.html).

Last verified: 2026-10-14.
