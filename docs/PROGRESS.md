# Build progress

The agent updates this file at the end of every module session.
Status values: `todo` · `in-progress` · `validated` · `blocked`.
A module is `validated` only when its validate script passes on a fresh subscription right after the previous modules.

| Module | Title | Status | Validated on | Evidence (PASS lines or PR) | Notes |
|---|---|---|---|---|---|
| 00 | Prerequisites and environment | in-progress |  | Offline only: 33 script/HTTP tests and 11 mock plans; not fresh-subscription evidence. | EN/FR guide, explicit read-only preflight, identity request and optional public B1 hosting implemented. Container and approved Azure target/plan still pending. |
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
- Initial P1 preparation: source assessment, architecture recommendations and build board.
  Module 00 is now implemented locally as described below, but no module is Azure-validated.
  No Azure or Microsoft Entra resource has been changed.
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
  The complete MCP deployment and the exact optional Azure hosting target remain unresolved.
- Module 00 local implementation (2026-10-14): EN/FR guide, validator/cleanup wrappers and identity-administrator
  request. Read-only preflight requires explicit tenant/subscription, rejects mixed authentication overrides,
  verifies provider registration, region, effective grant pagination and stage-specific capacity evidence.
  Its future MCP baseline is not a complete runtime/Policy permission proof.
- Optional public SPA: Linux B1 App Service, default off and persistently opted in without changing suffix/state.
  TLS enforced, FTP/SCM basic publishing disabled, Node 22 explicit startup and read-only package.
  Exact 52-file ZIP, local HTTP server and guarded Entra deployment script; no visitor credentials or MCP API.
  ACA/private visitor sign-in remain unimplemented. B1 costs and actual deployment require separate approval.
- Offline evidence: `PASS local script/HTTP checks (expected HTTP N/A; no Azure access)`;
  `PASS Terraform schema and mock-only plans (expected HTTP N/A; no live plan/apply)`;
  `PASS offline checks only. Module 00 is NOT Azure-validated by this result.`
  Five Terraform 1.16.6/AzureRM 5.9.0 mock plans pass. Synthetic cases cover read-only failures,
  permission pagination, stale/wrong quota evidence, ownership/TLS/runtime checks, WhatIf and exact ZIP contents.
  Combined board/workspace/hosting suite: 29 tests pass. Edge checks pass for EN/FR Pages-prefix routes,
  the real local App Service server, module 00/administrator links, all diagrams and 320/390/1366 layouts.
  Browser traffic remains local GET-only, without credential headers or persistent connection state.
  A fresh Windows checkout with `core.autocrlf=true` also passes offline validation, locked local-provider
  initialization, diagram provenance and the exact portal integrity check, leaving a clean Git tree.
- Authoring tool boundary: ordinary installation had Terraform 1.16.5 and an incomplete npm Core Tools shim.
  Official-checksum-verified Terraform 1.16.6 and Core Tools 4.14.0 ARM64 were installed in session scope for checks,
  not substituted globally. Container execution and fresh-subscription preflight/real plan/apply remain unverified.
  Module 01 must not start before real module 00 validation.
- French editorial revision: participant-facing labels and all French guides reviewed for natural phrasing.
  Beginner instructions appear first; technical setup and advanced context use closed, keyboard-accessible
  disclosure sections in both the board and static exports. Safety requirements, module status and cloud
  approval gates are unchanged. This is a language/readability change, not Azure or container validation.
- Participant naming hardening (2026-10-14): new private parameters save 64 cryptographic random bits once.
  Storage and Function names retain every random bit within their 24/32-character limits; all legacy names are preserved.
  `PASS 100 independent participants, one shared group, identical inputs and unchanged reruns`;
  `PASS legacy stability, invalid suffix rejection and six missing-parameter guards`.
  Eleven mock-only Terraform plans cover service-name constraints, shared-group isolation, real portal name wiring
  and invalid inputs. All 33 local tests pass. EN/FR guides explain separate checkouts/state, preserved existing groups,
  fixed protocol configuration and shared quotas. No global name reservation, real Azure plan or deployment was performed.
