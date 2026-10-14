# Build progress

The agent updates this file at the end of every module session.
Status values: `todo` · `in-progress` · `validated` · `blocked`.
A module is `validated` only when its validate script passes on a fresh subscription right after the previous modules.

| Module | Title | Status | Validated on | Evidence (PASS lines or PR) | Notes |
|---|---|---|---|---|---|
| 00 | Prerequisites and environment | todo |  |  | Partial preparation: workstation choice, tool checks, container config and Terraform group foundation. Container runtime/full preflight/Azure validation pending. |
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
- Participant isolation: prepare one stable random suffix and private state per participant. Default to a dedicated
  group; accept an approved existing group without managing it. Shared quotas still require cohort capacity checks.

## Deviations from the build plan
- P1 preparation only: source assessment, updated architecture recommendations, and the project build board.
  No module has been built or validated. No Azure or Microsoft Entra resource has been changed.
- Prefer current Inspector 2.11.0 as a compatibility-test candidate over the older APIM documentation's 0.9.0 tip.
- Upstream Functions sample now targets .NET 10; the Learn quickstarts still show .NET 8. Use the pinned project
  as the runtime starting point and verify Azure runtime support before deployment.
- Keep live tokens out of external token viewers. Use synthetic claim examples for the teaching exercise.
- Practice UI only: client launch recipes, expected call outcomes and contextual hints are available.
  Module status is unchanged; no deployed endpoint has been tested and no module is validated by these additions.
- Inspector launch verification: the configured npm registry resolves 2.9.0 but not the GitHub 2.11.0 source
  candidate. Practice commands explicitly pin 2.9.0 with memory-only credentials and protocol negotiation.
  This does not replace the module-specific compatibility checks or change the managed registry.
- Board learning content only: EN/FR navigation and guides, nine planned architecture views per language,
  governance/reference pages, contextual next steps and own-tenant/subscription context selectors.
  These additions do not implement or validate any module, grant permissions, or deploy Azure/Entra resources.
- Workstation preparation: default start-page choice for VS Code dev container, local terminal and optional Codespaces.
  Common scripts check tools and prepare ignored participant parameters without Azure access. Terraform's group-only
  foundation passes provider-mocked plan tests; no real plan/apply was run. Container runtime is unverified because
  no reachable engine was available. These checks do not validate module 00 or any runtime module.
- Static landing-site preparation: the same EN/FR board exports to an allowlisted standalone bundle with relative
  project-site paths and no live canvas capability. A manual Pages workflow and bilingual hosting guide are prepared.
  Local checks pass for the 50-file artifact, linked-source refusal, all 18 project-prefix diagrams, EN/FR routes,
  mobile layouts and explicit static-content errors. Requests remain local GETs with no capability/auth header,
  persistent connection storage or progress mutation. These are website checks, not module validation.
  Source review/merge is required before site publication; no Pages activation, workflow dispatch or Azure/Entra
  change was performed.
  The complete MCP deployment and the exact optional App Service/ACA hosting target remain unresolved.
