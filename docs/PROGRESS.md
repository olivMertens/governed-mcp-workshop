# Build progress

The agent updates this file at the end of every module session.
Status values: `todo` · `in-progress` · `validated` · `blocked`.
A module is `validated` only when its validate script passes on a fresh subscription right after the previous modules.

| Module | Title | Status | Validated on | Evidence (PASS lines or PR) | Notes |
|---|---|---|---|---|---|
| 00 | Prerequisites and environment | todo |  |  | P1 source assessment complete; environment implementation and validation pending. |
| 01 | Discover MCP (no Azure) | todo | | | |
| 02 | An "open" MCP server (level 0) | todo | | | |
| 03 | Identity with Microsoft Entra (level 1) | todo | | | |
| 04 | API Management as the only entry point (level 2) | todo | | | |
| 05 | On-Behalf-Of vs app-only (level 3) | todo | | | |
| 06 | Observe and inventory (level 4) | todo | | | |
| 07 | Optional: other clients | todo | | | Facilitator demo only |
| 99 | Clean up | todo | | | |

## Open decisions
- Network (module 04): recommend Standard v2 outbound virtual network integration, Function private endpoint,
  private DNS and public Function access disabled. Confirm deployment connectivity before applying.
- Identity ownership: confirm who runs infra/entra and grants delegated consent; accept existing object IDs
  without changing or deleting those objects when identity creation is skipped.
- Region: evaluate West Europe first. Confirm current Flex runtime support, Standard v2 availability, quota,
  subscription policies and costs before selecting it.
- Test identities: decide between a dedicated non-production tenant and dedicated Alice, Bob and Eve test
  accounts in an existing non-production tenant. Do not store live account details in the repository.
- Versions: source assessment pins upstream examples and records published provider/Inspector versions.
  Validate package/provider combinations and negotiated MCP protocol in module 00/01 before declaring compatibility.
- Gateway authorization: verify per-tool request inspection preserves JSON-RPC and streaming; distinguish gateway
  HTTP status from downstream status returned inside an MCP tool error.
- Optional clients: Copilot Studio's documented manual Entra OAuth path requests a client secret. Defer that
  connection unless an officially supported secretless flow is proven; never relax the workshop rules.
- Cost approval: estimate Standard v2 capacity, private endpoints, telemetry, storage and API Center before deployment.

## Deviations from the build plan
- P1 preparation only: source assessment, updated architecture recommendations, and the project build board.
  No module has been built or validated. No Azure or Microsoft Entra resource has been changed.
- Prefer current Inspector 2.11.0 as a compatibility-test candidate over the older APIM documentation's 0.9.0 tip.
- Upstream Functions sample now targets .NET 10; the Learn quickstarts still show .NET 8. Use the pinned project
  as the runtime starting point and verify Azure runtime support before deployment.
- Keep live tokens out of external token viewers. Use synthetic claim examples for the teaching exercise.
