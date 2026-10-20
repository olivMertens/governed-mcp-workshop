# Build progress

The agent updates this file at the end of every module session.
Status values: `todo` · `in-progress` · `authored` · `validated` · `blocked`.
A module is `authored` when its code, guide and offline checks pass; it can be shipped and the next module can start.
A module is `validated` only when its validate script passes live on a fresh subscription right after the previous modules.
The presenter cannot deploy into participants' tenants: live validation runs in each participant's own subscription,
or in an approved author-owned non-production tenant.

| Module | Title | Status | Validated on | Evidence (PASS lines or PR) | Notes |
|---|---|---|---|---|---|
| 00 | Prerequisites and environment | validated | 2026-10-14 | Live local-terminal validator: explicit context, region, Microsoft.Resources registration, required ARM grants and group capacity PASS; isolated offline suite 14/14 and Terraform tests 11/11 PASS. | Validated on the selected non-production local-terminal route without creating resources. The optional dev-container/Codespaces route remains unverified and is not implied by this result. |
| 01 | Discover MCP (no Azure) | authored | | Real local SDK validator and Inspector 2.9.0 tools/list + tools/call pass; protocol 2026-07-28 with SDK client. | EN/FR guide, locked .NET 10 stdio server and client config implemented. Manual VS Code approval observation remains pending; no Azure needed here. |
| 02 | An "open" MCP server (level 0) | validated | 2026-10-16 | Live validator in the author's test subscription: running HTTPS-only app, HTTP 401 without key and with a wrong key, initialize 200 (protocol 2025-06-18), tools/list 200 with exactly five tools, create_ticket 200 with only the key (risk shown, one synthetic ticket). Offline validator, 39/39 unit tests, Terraform fmt/validate and 49/49 mocked runs PASS. | A tenant Azure Policy (`modify` effect, management-group scope) forced Storage public network access to `Disabled`; Flex publishing failed with HTTP 403. Added the `mcp_private_storage` opt-in (shared VNet, delegated /27 Flex subnet, blob and queue private endpoints and DNS zones); no exemption requested, no shared key. Applied 11+1 then 9+1 (0 deletions). Key rotated after validation. Resources kept for module 03. Microsoft.ApiCenter registered (free) to pass the full MCP preflight. |
| 03 | Identity with Microsoft Entra (level 1) | validated | 2026-10-19 | Live operator checks 2026-10-17 in the author's test tenant: Entra apply 8 added (no secret, assignment required); stage 1 and 2 in-place updates; validator PASS: no token 401 by built-in authentication, PRM (Preview) names tenant and user_impersonation, Graph-audience token 401, authsettingsV2 required/Return401/tenant issuer/MCP audience, key gate replaced, system key alone 401. Persona check Alice live 2026-10-19 after her MFA registration (authenticator app): PASS signed-in account matches the private object ID, initialize HTTP 200 with a token for the MCP audience (protocol 2025-06-18), tools/list exactly five tools. Bob persona 2026-10-19 PASS: signed-in object ID matches, initialize HTTP 200 (protocol 2025-06-18), tools/list exactly five tools. Eve persona 2026-10-19 PASS: Entra refuses the token with AADSTS50105 (not assigned). Offline validator and Terraform mock runs PASS. | Each test account first registered MFA in the test tenant. Recent Azure CLI versions fall back to an interactive pop-up after a refused token; the validators now call `Get-WorkshopAccessToken` (60-second timeout, keeps only the AADSTS code). Test accounts created by the identity administrator outside Terraform; IDs only in private files. |
| 04 | API Management as the only entry point (level 2) | validated | 2026-10-20 | Live operator checks 2026-10-18: Standard v2 created in about 2.5 min; validator PASS: gateway 401 with PRM challenge, gateway PRM names gateway/tenant/scope, direct Function host HTTP 403, Graph-audience token 401, Function publicNetworkAccess Disabled, deployed diagnostics 0 body bytes and no header at both scopes. Offline validator and 49/49 workload mock runs PASS. | Not `validated`: persona, burst 429 and telemetry checks not run (MFA registration required for test accounts). Fixed: the 2025-09-01-preview service rejects `mcpProperties.endpoints` as an array (published REST reference and samples show an array); gateway.tf now sends a map keyed by name with azapi schema validation disabled on that resource. A tenant automation switches the optional portal plan to F1 nightly; plans then restore B1. MCP server API is **Preview**. Optional part B (REST API exposed as an MCP server, API-first, `enable_rest_mcp_demo`) deployed live 2026-10-19 with stage 1 (apply 27 added, 3 changed, 0 destroyed; APIM Standard v2 in about 6 min): `validate-rest-mcp.ps1` operator PASS (MCP 401 with PRM challenge, PRM 200, REST API 401 without token, Graph-audience 401, type mcp with list_tickets/get_ticket mapped, 0 body bytes); Alice persona PASS (tools/list exactly 2 tools, list_tickets 3 synthetic tickets, get_ticket CT-1001). Live findings: REST API policies (token check, then mock-response) do run for MCP tool calls; tool names are the tool resource names; the argument is named after the template parameter (ticketId); APIM omits `isError` on success (validator now treats absent as false). Alice persona for part A not run (stage 2 not applied). Cleanup `-Apply` PASS (phase 0: 10 destroyed; phase 2: 17 destroyed); APIM removed the same day. Bob not run. Full live run 2026-10-20 (redeployed: 17 added, stage 2 lock): live finding, the MCP server had no backend entity, so APIM answered tools/list itself with an empty list (forward-request 0 ms, portal Source: API); fix: `azapi_resource.mcp_backend` + `backendId` (portal Source: MCP server, SSE passthrough). Second finding: in passthrough mode APIM rewrites the challenge `resource_metadata` under the API path; the MCP policy now answers that anonymous GET with the same static PRM (uses `context.Request.OriginalUrl`). Validator PASS: operator (401 + PRM at both URLs, direct 403, Graph token 401, publicNetworkAccess Disabled, 0 body bytes); Alice (5 tools, get_service_health 200, create_ticket 200, unknown 403, malformed 400); Bob (read 200, create_ticket 403, burst of 40 → 429); Eve (AADSTS50105); telemetry (103 gateway requests, 60 tool traces with tool label and caller oid, no body). Part B re-applied (10 added): operator and Bob PASS. |
| 05 | On-Behalf-Of vs app-only (level 3) | validated | 2026-10-20 | Live operator checks 2026-10-18: workload apply 6 added; Entra apply 5 added (delegated Graph User.Read and Storage user_impersonation, one federated credential, admin consent); validator PASS: Function settings name both identities and hold no secret, MCP API has no client secret and exactly one federated credential, report container has 2 Storage Blob Data Reader assignments (app-only identity, Alice) and none for the OBO identity or Bob. | Not `validated`: persona checks (Alice 200, Bob 200 with isError, as_app identical) not run (MFA registration required). With module 02 private Storage, publish-report.ps1 from outside the VNet fails as expected; the synthetic report was uploaded from a short-lived ACI in a delegated subnet with a container-scoped managed identity, then the ACI, identity, role and subnet were deleted. Full live run 2026-10-20: workload re-applied (6 added); new OBO identity, so the Entra federated credential subject was updated (1 changed, no secret); report uploaded again from a temporary ACI (the subnet's auto-created NSG is also deleted). Validator PASS: operator (two identities, one federated credential, 2 readers on the container); Alice (whoami 'alice' through OBO, read_report_as_user 200); Bob (whoami 'bob', read_report_as_user HTTP 200 with isError true, downstream 403); read_report_as_app identical for both. Eve is not a module 05 persona (refused by Entra in modules 03 and 04). |
| 06 | Observe and inventory (level 4) | validated | 2026-10-20 | KQL run live 2026-10-18 on gateway traffic with `az monitor app-insights query --analytics-query @file`: rows for initialize/401/workshop-validator with metadata only. Offline validator PASS. | Not `validated`: no persona traffic (tools/call) yet; API Center registration and BYO listing are manual and not run. Fixed: Learn documents `api.type == Mcp`, but a passthrough MCP server logs `mcp-backend`; the query accepts both. Single quotes keep the query intact through the Azure CLI on Windows. Agent 365 (06b) remains a presenter talk track. Portal capture of the same query in Logs (KQL mode) added 2026-10-19. API Center create, register, capture and delete live 2026-10-19. 2026-10-20: KQL on persona traffic returned 134 rows (create_ticket 200 for Alice and 403 for Bob in 3.6 ms, burst ping 429, whoami, read_report_*, list_tickets); live finding: the passthrough server logs `api.type` `pass-through-mcp` (part B: `mcp-backend`); query and offline check updated. |
| 07 | Optional: other clients | validated | 2026-10-20 | Offline validator 14/14 PASS in a fresh clone (PR #13, merged `6eb049c`). Bash syntax check passed. | Part A run live 2026-10-20: Foundry project (azd starter, 3 min 21 s), dedicated client app, OAuth identity passthrough (Preview). Findings: the secretless public client failed at the credential manager's code redemption (Entra sign-in succeeded), so a one-day secret is handed to the connection via ARM without printing (rule 5 updated); Foundry calls `server/discover` (MCP 2026-07-28) first, now allowed with Tools.Read; Foundry Agent Consumer returned 403 for direct project calls, Foundry User worked; a consent link opened by another user binds that user's token. Live PASS: Alice tools/list 5 tools, approval, get_service_health healthy; Bob's approved create_ticket refused by the gateway (HTTP 403). Copilot Studio stays an outline. Clean-up script with guarded Terraform phases; module 99 runs it first. |
| 99 | Clean up | validated | 2026-10-20 | Offline validator passes in a fresh clone at `4c8cece`: `validate.ps1 -Offline` RESULT PASS (0 failures); `validate.sh --offline` 11 PASS, exit 0 (PR #15). | Report-mode `cleanup.ps1` is not verified in a clean clone: it needs attendee state (`.workshop/participant.tfvars.json` and the module 02/03 opt-in files). Run it on a real attendee machine before validating. Open decision: skip or fail clearly when that state is absent. Live `-Apply` 2026-10-20 on modules 02 to 07 (part B included): every stage PASS in order (07, 05 workload and Entra, 04 phases 0-2, 03 workload and Entra, 02); test users kept; only the presenter portal remains. Findings fixed: applied stages now archive their var files to `.workshop/applied/` (a rerun replanned removed modules); module 05 passes the part B file; the portal's WORKSHOP_MCP_* hint refresh is accepted; an expired PIM role gave `Authorization_RequestDenied` (documented). Manual leftovers documented: policy-created NSGs, Smart Detection action group, Foundry agent identity blueprint (now deleted by module 07). |

## Shorter reader counter and module 07 capture check (2026-10-20)

The "Follow the guide" card now shows only the step count: "19 steps" / "19 étapes".
Removed the redundant phrase from this card in both languages, without changing navigation or other reader headings.
Added a regression for the exact displayed label and its jump back to the first lesson.

Verified the existing module 07 Foundry images visually and against the four bilingual track guides:
MCP/OAuth connection settings, explicit approval and the synthetic tool result are linked in every guide.
The Terraform guide also includes the real PowerShell approval/read/refused-write capture.
Added regression assertions preserving the three Foundry portal images in all four guides.
Copilot Studio has no real capture or live validation in this workshop; part B remains explicitly reading-only.
No new screenshot, Foundry/Copilot Studio connection, Azure change or Microsoft Entra change was made.
Targeted site/track checks: 25/25 PASS.

## Publication preparation from current main (2026-10-20)

The user approved commit, push, merge and redeployment of the participant site.
Prepared `publish/fr-guides-cli-20261020` from refreshed `origin/main`, in an isolated worktree;
the original working directory and its uncommitted changes remain untouched.
Retained the newer animated diagrams and hosting changes already merged into main.
Resolved obsolete mixed-guide instructions in favor of the independent low-code and Terraform guides.
Removed the old in-page track picker so the URL-based choice is the only deployment-track selector.
Kept legacy mixed-guide parsing coverage, and updated the live-guide regression to require separate files.
Corrected one French label in the retained module 03 animation; no topology or generated architecture asset changed.

Full validation on the integrated publication tree: all 14 Node test files, 111/111 tests PASS,
zero failures and zero skipped. Both local MCP tests pass in this clean worktree: the editor-held DLL
and private VS Code configuration failures recorded above/below are specific to the original working directory.
The public static export builds successfully with exactly 105 allowlisted files.
No private participant files, Terraform state or runtime configuration are included.
Publication uses the existing GitHub Pages workflow on merged main, not an Azure deployment.
No Azure or Microsoft Entra resource change is authorized or performed by this publication.

## Integration handoff: French result boxes and capture lists (2026-10-20)

Kept the French `> **Résultat attendu** —` boxes and module 01's "Pourquoi :" and "Anticipez :" labels.
Converted the remaining unboxed "Attendu :" after the module 03 administrator's read-only Entra inspection
to the same box format, without changing its expected values or the following explanation.
The module 03 regression now requires a result box after every PowerShell block, except the explicit
plan-review STOP, which remains required before applying the Entra plan.

The renderer and portal screenshot lists are identical: 48 unique names, including the four additional
portal/validator captures and all eight `terminal-*-az-*` captures. Added explicit regression coverage
for retaining those twelve entries and the module 01 labels. Existing counts are already correct:
105 static-site files, 107 packaged-portal files, 105 integrity-checked public files.
The full run verifies list equality, asset existence, export contents and HTTP access.
Read `tools/capture/README.md`; no new capture or cloud access was needed.

Ran all 14 repository Node test files after these changes: 108 tests, 106 PASS, 2 FAIL, zero skipped.
Both failures are the previously recorded local environment problems in `scripts/local-mcp.test.mjs`:
the editor's running MCP server locks the local server DLL during rebuild, and the private VS Code
configuration lacks the `microsoft-learn` alias expected by the configuration test.
No test was skipped or weakened, and no editor process or private configuration was changed.
Scoped whitespace checks PASS.

GitHub now reports PR #1 (`next-work` into `main`) merged, at 2026-10-20 19:26 UTC.
Refreshed `origin/main` without changing the working branch or existing edits.
The current `captures-and-deploy-map` branch does not include the refreshed main tip; no commit, push,
merge or publication was performed. Any publication branch must be newly created from `origin/main`.
Never push `archived-main`.

## Follow-up French prose review after module 99 feedback (2026-10-20)

The earlier "Complete French guide review" entry overstated the editorial result: awkward French remained,
including in module 99. Passing structural tests and checking introductions did not establish the quality
of every explanation. This follow-up explicitly corrects that claim.

Personally read the full prose of all 17 French module guides, covering both tracks and shared module 01:
objectives, explanations, prerequisites, instructions, tables, warnings, captions, expected results,
troubleshooting, cleanup, review questions, hidden answers and source notes. Revised 16 guides;
the module 03 Terraform guide needed no further wording change in this pass.

Rewrote module 99 around the participant's actual cleanup order. Distinguishes the MCP resource group,
the separate optional Foundry group, Microsoft Entra identities, catalogue entries and permanently deleting
recoverable resources. Explains that a Foundry account is an Azure resource, not a user account.
The question now asks whether deleting the server's group also cleans up the agent deployed in module 07.
Ownership checks, approval and protection of shared resources remain explicit.
Aligned the module 99 learning-guide and practice summaries.

Elsewhere, replaced compressed jargon with named accounts, resources and actions; clarified deployment-account
versus Alice/Bob checks and Eve's lack of assignment. Preserved the module 03 versus module 04 authorization
boundary. Corrected the reader's singular review label ("1 question, réponse masquée") in French and English.

Validation: 24/24 focused site/track tests PASS, including the complete module 99 assessments and singular/plural
labels. Module 99 offline validator PASS, zero failures. All 293 fenced command, configuration, diagram and output
blocks across the 17 guides match the pre-review baseline after line-ending normalization.
Local browser checks of both module 99 tracks confirmed one low-code question and three Terraform questions,
all answers reveal correctly, and no horizontal overflow at 390 and 1280 pixels. The warning title is separate
from its text in the rendered page. These checks verify structure and rendering, not linguistic quality.

No cloud calls, resource changes, cleanup execution, external-source revalidation, public deployment or
module-status change occurred during this follow-up.

## Copyable Azure CLI inspections and real result captures (2026-10-20)

Added an explained hands-on inspection to all 17 French guides, covering both tracks and the shared local module.
Each sequence gives its purpose, copyable PowerShell blocks, the fields to compare, a result image and failure guidance.
Terraform-track setup reads the existing resource names; portal-track setup reconstructs its own `lc` names without state.
Module 01 uses its local validator and real Inspector image, not an artificial Azure command.
Module 99 shows a pre-cleanup inventory and explains the separate post-cleanup checks for dedicated versus shared groups.

The user explicitly approved read-only access to the current CLI context and confirmed an authorized non-production
environment. Queried existing workshop resources only; captured eight new masked, annotated CLI results for
context, Function runtime/HTTPS, enforced Entra, private Function access, the two identities, HTTP-code counts,
the existing APIM gateway and the inventory before cleanup. No deployment, role change, secret/key retrieval,
MCP write or cleanup was performed. Existing Foundry screenshots remain labelled as earlier examples;
the low-code tracks were not redeployed or live-validated.

Live CLI evidence exposed null top-level Function aliases in this environment. The new commands use
`az resource show` with `Microsoft.Web/sites`, API version 2024-11-01 and explicit `properties` projections.
Capture specs now preserve JSON/table lines and require the expected output values, not just exit code zero.
All eight capture runs passed those checks; all eight images were visually reviewed after masking.
The documented Terraform inspection setup and read-only group-existence check also passed.

Synchronized the renderer, static portal and author-server screenshot allowlists.
The author server was also missing already-published capture names; every published screenshot is now tested over HTTP,
while unknown names and query-string attempts remain rejected.

Validation: 67/67 focused board/site/track/portal/masking tests PASS; new regressions parse all 33 added PowerShell
blocks, require explicit CLI failure checks and verify exact displayed commands against capture specifications.
Local browser checks at 390x844 passed across all 17 French guide routes: 33 copy controls preserved exact code
using an intercepted browser clipboard, all 21 inspection image occurrences loaded, and no page overflow.
Scoped syntax/whitespace checks PASS. Sources updated; no public deployment or module-status change.

## Complete French guide review (2026-10-20)

Read and revised all 17 French guides across the nine modules: both deployment tracks, with module 01 shared.
Objectives now address participants directly. Replaced literal translations, compressed portal instructions
and unexplained governance jargon with concrete actions, their purpose, their order and the results to check.
Administrator handoffs and validation limits remain explicit; pending live validation is not presented as a learning objective.
Preserved recorded-output provenance, Preview warnings, support limits and Copilot Studio's reading-only status.

Aligned the French plan, learning guide and practice hints with the participant journey and both tracks.
Clarified that Terraform state belongs to the Terraform track, not the portal track.
Corrected French gateway prerequisites: Alice and Bob receive the planned roles; Eve receives no assignment.
The module 03 distinction remains explicit: Bob can still write there, while Eve cannot obtain the MCP token;
module 04 introduces per-tool role checks.

Validation: 21/21 combined site/track tests PASS, including a new regression covering all 17 French objectives,
validation/source sections and the corrected Eve prerequisite. All 260 fenced command, configuration and output
blocks are byte-identical after line-ending normalization to the baseline captured before this editorial pass.
Local browser checks passed for all 17 French module/track introductions at 390x844: one reading article per route,
participant-facing objective text and no horizontal page overflow. Scoped whitespace check PASS.
No cloud query, resource change, public deployment, external-source revalidation or module-status change.

## Participant wording review (2026-10-20)

Reviewed the prose in all nine French module guides (00 to 07 and 99), including low-code steps,
expected results, troubleshooting and clean-up. Reworded literal translations and facilitator-directed
instructions without changing fenced commands, prompts, queries or recorded output.
Module 07 now consistently describes an optional participant exercise with Foundry; Copilot Studio
remains a reading-only outline, not a live-validated exercise. Updated the EN/FR summaries, prerequisite
text and navigation badges so they no longer describe the whole module as a facilitator demo.
Recordings do not substitute for the resources needed to perform the exercise.

Validation: 51/51 focused board/site/portal tests PASS, including a participant-wording regression;
263 fenced blocks unchanged across 19 edited Markdown files compared with HEAD; `git diff --check` PASS.
Local browser checks pass for all nine French module routes at 390 pixels, the corrected module 07
Preview note on desktop, and its English participant badge at 1366 pixels.
No Azure or Microsoft Entra query, resource change, public deployment, external-source revalidation
or module-status change was performed.

## French writing rule and module 02 wording (2026-10-20)

Added an always-on repository writing rule: French participant content must read as original French,
not as sentence-by-sentence English translation. Address the participant directly, explain concrete actions
and expected observations, and keep authoring history out of learning objectives. Relevant validation limits
remain explicit in the validation section.

Rewrote the module 02 French portal guide's prose and the Terraform guide's introduction and warning.
The exercise now states what participants deploy, test and learn from the shared key.
Replaced literal phrases about a temporary "level" and a "governed gateway" with explicit instructions:
keep key protection, continue to Entra or clean up, then enforce per-tool roles in module 04.
The portal guide's pending end-to-end validation is still disclosed, outside the objective.

Validation: 19/19 focused site/track tests PASS, including a new wording-rule regression;
all 22 fenced command/example blocks in the two module 02 French guides unchanged from this task's starting point;
scoped whitespace check PASS. No cloud query, resource change, public deployment or module-status change.

## Module 03 French participant reassessment (2026-10-20)

Rewrote the French Terraform guide as a participant journey rather than an author deployment report.
The goal, three-account scenario and completion criteria precede the commands. Bob has an assignment and can
still write at this level; Eve can sign into the tenant but cannot obtain the MCP token (AADSTS50105).
Client preauthorization, user assignment, token audience and per-tool authorization are explained separately.

The user selected Terraform mutations with read-only Azure CLI inspection, not a migration of managed resources.
Administrator preparation is a closed handoff; participant actions follow Entra plus key, deployed configuration
readback and HTTP 401, then key-gate replacement, server checks and three isolated account checks.
Plans and applies are separate. CLI inspection selects only relevant app settings and never displays tokens.
Persona testing preserves the original CLI configuration even on failure.
Removed author apply transcripts and fixed resource-count expectations from the French participant guide.
Aligned the French low-code scenario and the French plan, learning and practice summaries.
Six Terraform-track review questions and four low-code questions distinguish expected refusal from unrelated failures.

Validation: module 03 offline validator PASS, including Terraform format/schema/mock checks for both roots;
18/18 focused site/track tests PASS. New regressions parse all 17 French PowerShell examples without executing
them and exercise nine mocked pre-key-removal outcomes (one valid, eight refused).
Local participant-preview browser checks: all 38 French Terraform reading steps at 390x844 display one article
without page overflow; six review answers start closed and all open correctly. Static participant export PASS.
Microsoft Learn sources reread; no live Azure/Entra query or mutation, public deployment, architecture change
or module validation-status change. New teaching commands have not been rerun against a live subscription.

## Independent participant tracks (2026-10-20)

Separated the participant progression, not just the low-code paragraphs:

- Modules 00, 02 to 07 and 99 now have independent `LOW-CODE.md` / `LOW-CODE.fr.md` guides.
  Their READMEs follow Terraform + PowerShell without interleaved low-code steps. Module 01 remains shared.
- Low-code is portal-first: exact portal actions, existing real captures with provenance, explicit variables,
  necessary publishing/configuration commands, expected results, persona validation and cleanup.
  Missing real captures are disclosed; no screenshot or live result was invented.
- Module 00, the tool checker and preflight accept `-Track low-code`. That path does not execute Terraform.
  Preflight resolves low-code group names and preserves an administrator-provided group name.
- The selected track stays in the URL through module navigation, refresh and language changes.
  The reader, questions, source path, validation help, PDF and inspection reference use that guide.
  Both HTTP runtimes allow only the known language/track selectors; unknown or duplicate selectors remain refused.
- Low-code inspection reads the private participant JSON rather than local infrastructure state.
  Cleanup distinguishes workload groups, optional Foundry resources, identity objects and shared resources.

Offline validation: `modules/00-prerequisites/validate.ps1 -Offline -Track low-code` PASS, 28/28 tests,
with a throwing Terraform guard in the parent PowerShell process. Board regressions: 37/37 PASS.
Together: 65/65 PASS. Tests cover all 34 bilingual guides, first-step ordering, callouts/questions,
immediate command-result boxes, intact runnable blocks, PowerShell parsing, local links, screenshot allowlists,
track isolation and both HTTP runtimes. Existing module validators 02 to 07, 99 and optional 04 part B
also passed offline during guide authoring. Tests run serially after concurrent PowerShell fixture timeouts;
no timeout or security check was weakened. `git diff --check` PASS.

Local browser checks: 36 module views across both tracks and languages at 390/1366 pixels,
correct track-specific sources and no page overflow. Refresh, language changes, previous/next navigation
and the low-code inspection page preserve the selected track. Module 07 PDF preparation uses the selected
guide, loads its real screenshots and contains no Terraform command in the low-code version.
Public bundle: 95 allowlisted files, HTTP health 200 and selected-track entry URL 200.
After the final content fixes, rebuilt the bundle and checked all 18 French module/track views again:
each opens on Objectif (with continuation pages where needed), without horizontal page overflow.

The new composition has not been followed end-to-end on a fresh subscription. Previous live dates remain
historical evidence, not validation of the separated guides. No Azure or Microsoft Entra resource query,
resource change, publication or module-status change was performed in this session.
Two public documentation references for the inspection guide were reread; see `docs/sources.md`.

## Interface appearance evidence

Release checks (2026-10-16): module 01's real local SDK validator passes build, negotiation, discovery,
both synthetic reads, invalid-input refusals and post-error responsiveness. Manual VS Code approval remains
unverified, so the module stays authored. Focused reader/site/portal/deployment suite: 42/42 PASS;
module 06 offline 20/20 and module 07 offline 14/14 PASS; architecture consistency PASS.
The public ZIP contains the exact 52-asset allowlist plus its integrity manifest and server (54 files).
The deployment fixture now compares exact ZIP names, not the obsolete fixed count.
Local MCP configuration is unchanged and matches the committed file. The deployment script matches the
upstream status-check fix. These checks do not validate any Azure MCP runtime or later workshop module.

Reader repair (2026-10-16, local UI only): corrected the module 06/07 folder mappings so their existing bilingual
guides and offline-validator commands are published instead of design outlines. Repeated module lead text
and reader instructions were removed; service/dependency summaries are now a closed optional reference.
Seven concept questions per language have closed-by-default answers. Modules 06/07 add matching questions
and reuse the existing editable Draw.io-derived 05/06/07 diagrams inline, without changing the architecture.
Module 06 separates request metadata, caller traces, client approval and downstream audit, including missing
fields, sampling and HTTP 200 tool errors. Module 07 documents the delegated-scope incompatibility of app-only
Foundry callers and stops the documented Copilot Studio Manual flow at its client-secret requirement.
No cloud deployment, publication, identity change or live module validation is implied.
Validation: focused board/site/portal tests 41/41 PASS; module 06 offline 20/20 and module 07 offline 14/14 PASS;
architecture `--check` PASS for 18 SVG/PNG pairs and both Mermaid guides. Real local browser checks covered
108 reading pages across concepts and modules 06/07 in EN/FR at 320/1366 px: 18 answers hidden/revealed/hidden,
8 inline diagram instances loaded, no page overflow or JavaScript page errors. Existing diagram exports were reused,
not regenerated; no component, identity or deployment boundary changed.

Appearance update (2026-10-16): the shared presenter/participant interface reuses the existing Microsoft
and Azure SVG icons in an accessible appearance dialog, with Template (system colors), White and Dark choices.
Neutral White/Dark surfaces use small Azure-blue accents; the preference is browser-local.
All 39 focused board/site/portal tests pass. Real local Edge checks pass for 18 EN/FR combinations
(320/390/1366 px, three themes), including loaded icons, no dialog overflow, Escape/focus restoration
and theme persistence after reload. This is local UI evidence only; no Azure publication or module validation.

## MCP fundamentals and reading pages

Added original EN/FR MCP concept pages (2026-10-16), linked from Start and every module.
They cover host/client/server, agent building blocks, tools/resources/prompts, one illustrative execution loop,
transports/version differences, API/connector/retrieval distinctions and identity/approval boundaries.
Only verified public sources were used; no private event material was copied.
All module readers, including design outlines without published guides, paginate long content at complete elements.
The 180-word target preserves executable fences, nested disclosures and list items; long tables repeat their headers
without splitting rows. Indivisible elements and short displayed code can exceed the target.
Focused board/site/portal suite: 40/40 PASS.
Real local Edge validation: 22 EN/FR module/concept/governance routes, 390 reading pages, no JavaScript errors,
no page overflow at 320/1366 px, next/previous and heading focus PASS. Largest observed page: 211 visible words.
No module status was promoted and no cloud action or publication was performed.

Reading order and brand update (2026-10-16): each guided page now reads top to bottom (position and progress bar,
content, then Previous/Next naming the next step, then a closed outline). Optional material follows the lesson
under "Go further". The rail uses an inline Azure-gradient shield mark that needs no network asset.
Product icons fall back to a neutral glyph instead of a broken image. Root cause of the reported broken icons:
the shared canvas tab outlived its local board server (connection refused) and showed a stale page;
the server now rereads the interface on each load. Concept pages add OBO explained simply, OBO versus app-only
choice criteria and implementation implications (EN/FR). Focused suite: 40/40 PASS; local Edge checks of module 05
and the OBO pages PASS. No cloud action or publication.

Command results for attendees (2026-10-16): modules 01 to 05, EN/FR, now place a result box directly after each key
command: the output, its provenance label, then "What it means for you". Green "Real result" boxes are actual
captures: module 01 validator and Inspector discovery/call/error (local, synthetic data), module 02 offline validator,
and the module 02 saved-plan summary from the author's test subscription (no names or IDs). Blue "Expected result"
boxes quote the exact validator messages for live checks not yet run (02 live, 03 operator/personas, 04, 05); they are
labelled as not a capture from the reader's tenant. Output blocks have no copy button. Pagination never separates a
result from its command (20 boxes checked in Edge, 0 orphans). Offline validators 02-05 PASS; focused suite 40/40 PASS
(portal counts aligned with the two new product icons).

Readable validators and annotated captures (2026-10-19): every `validate.ps1` now prints a one-line module purpose, then
numbered `== Step N: ... ==` headers with a plain `Why:` line before each group of checks (`validate.sh` runs the same
script, so bash output is identical). PASS/FAIL/INFO texts are unchanged. Real Azure portal captures for modules 02
(storage networking), 03, 05 and 06 (Logs, KQL mode) and real terminal captures for module 03 (operator, Alice) are
published with pink frames on what to check; names are pseudonymised and IDs zeroed before capture. Terminal captures
render the real, masked validator output in a terminal-style frame.

## Session 2 presenter walk-through (2026-10-20)

`docs/INTEGRATION-OPTIONS.md` (EN/FR) opens with a new step, "From this morning to the front door": an animated
architecture that the presenter builds in 8 fragments (local stdio server, Functions open level, API Management part A,
part B REST-as-MCP **Preview**, Alice's call, 401 without a token, other clients, API Center and Foundry catalog **Preview**).
Each fragment shows the talk track, what to show, and the exact command or real output from modules 01, 02 and 04.
The board renders a ` ```reveal ` JSON block as an inline SVG with reveal.js-style fragments (fade, draw, highlight,
strike), buttons, dots and arrow keys; no reveal.js library, CDN, new dependency or execution path (CSP unchanged).
It honours reduced motion, both themes and print. Later sections are renumbered 2 to 7; no inbound link used the numbers.

Offline checks: board, static-site and portal suites 46/46 PASS, including two new tests (malformed specs and unknown
icons are refused; EN/FR layouts match; every command line shown exists verbatim in a module guide).
`terraform fmt -check`, `validate` (entra, workload) and mocked `terraform test` PASS (workload 53/53, entra 15/15);
`validate.ps1 -Offline` and `validate-rest-mcp.ps1 -Offline` PASS. Diagram names, tools, paths, `2025-09-01-preview`
and `subscriptionRequired = false` match `rest-mcp.tf`, `gateway.tf` and the policies.
Read-only `terraform plan` 2026-10-20 against the author's test subscription after the full clean-up (participant and
module 02, 03, 04, 04b var files): `48 to add, 1 to change, 0 to destroy`; part B renders its 10 documented resources;
the one change is the known portal `app_settings` hint refresh. No apply; the plan file was deleted. Nothing deployed.
Browser checks: EN/FR, dark/light, all 8 fragments by keyboard and buttons, no console error. No module status changes.

The presentation skills used to build this page are authoring aids and stay outside the repository.

Audience layer (same day): every fragment now opens with one "In plain words" sentence (front door and badge
image), the presenter detail follows. A new step, "The whole picture", shows a repo-style architecture from a separate
editable source, `assets/architecture/session2.drawio` (EN/FR pages), rendered by `scripts/render-architecture.py`:
four dashed frames in decision order (consume, expose, host, discover), verified workshop icons embedded, blue request
arrows and a green dashed inventory arrow. `--check` PASS for all pages (routing, crossings, 16 px clearance,
perpendicular arrows, text fit, embedded icons, PNG provenance); module exports and Mermaid guides unchanged.
"Read it from left to right" gives four plain bullets and an "Advanced: read the diagram" disclosure (token per hop,
no passthrough, private backend, PRM challenge, no subscription keys, inventory, Preview API version).
The board, local server, static site and portal serve the five new assets (static site 91 files, portal 93/91);
French module links in the walk-through now use `../../`. Suites 48/48 PASS.

## Guided exercise UI (2026-10-20)

Module 01's English and French guides now have four explicit requests: discover the contract, read `workshop-api`,
change to `ticket-queue`, then reject `billing`. Each keeps its purpose, prediction, command, output provenance,
interpretation and observation together. Bash offers the same four calls with a result after every command.
The shared reader never splits an authored request by word count. It shows request-local progress, numbered
navigation, a terminal command beside a deliberately revealed recorded/expected answer, and highlighted evidence.
The module page has a direct "Your turn" entry after the reader has built the server and prepared Inspector.
Reference examples are not personal execution or completion evidence. No browser execution, output collection,
token input, new dependency, resource change, cost or architecture change was introduced.

Offline checks: board, static-site and portal regression suites (46 tests); real module 01 SDK validator PASS in an
isolated copy of the unchanged server sources (locked restore/build, both exact synthetic results, rejected inputs,
no writes and no payload logging). Pinned Inspector 2.9.0 CLI: all four requests checked against that server, including
its `tool_is_error` summary and exit code 5 for the intentional refusal (not code 0); EN/FR guards and explanation corrected.
The direct local test runner could not rebuild the editor-held DLL; its separate
VS Code config assertion also expects a `microsoft-learn` alias absent from the local configuration. No existing
editor process or configuration was changed to bypass those failures.
Browser checks: all four requests EN/FR, 25/50/75/100% request progress, unchanged command text, closed reference
answers, keyboard reveal and Previous/Next; two columns at 1440/1024px and one at 390px with no horizontal overflow.
Request navigation and reference reveal send no network requests. The existing six-request server guide still
shows all six requests, without assuming local Inspector preparation. Manual client approval remains unverified;
module 01 stays `authored`, not newly live-validated.

## Real captures and deployment map (2026-10-20)

`tools/capture` (new, optional author tooling, `playwright-core` 1.64.0 pinned, Edge channel, no browser download)
produces annotated captures from the author's own test tenant. `capture-portal.mjs` masks the account, tenant,
subscription, participant names and every GUID or 32-hex ID in every frame of the portal page, draws the pink numbered
frames, then **refuses to save** if any private value is still visible, before and after the screenshot.
`capture-terminal.mjs` runs a real validator, masks its output, rejoins PowerShell's console wrapping and measures the
frames on the rendered lines. Masking rules are built at run time; nothing private is committed. Unit tests use a
synthetic Fabrikam context. New real captures, live on `host01` (modules 02 to 05 deployed): Function App Overview
(Flex Consumption, five `mcpToolTrigger` tools) and App keys (`mcp_extension` system key, values hidden) in module 02;
Function App Networking (public access Disabled, one private endpoint, VNet integration) in module 04; module 00
validator (live, read-only); module 04 operator validator refreshed (now with a third frame on the persona checks).
Finding: the API Management MCP server blade cannot be opened by URL (the generic blade uses API version 2021 and
returns 404) and does not react to automated clicks; part A's policy capture is therefore not included. `az rest`
fails on Windows with the policy's `rawxml` body (cp1252 and BOM); not worked around with a manual ARM token.

`docs/GETTING-STARTED.md` (EN/FR): section 4 no longer says Terraform deploys no Function, gateway or identity; new
section 5 "Deployment map" lists, per module, the Terraform root, the private file, what appears in the tenant and the
capture to compare with. The board's start page shows that map directly instead of inside the collapsed guide.
`scripts/deploy-module.ps1` runs one module: context check, cumulative private files in guide order (part B kept while
its file exists, as module 04 requires), saved plan, typed `yes`, apply, validator. Live `-PlanOnly` on `host01` for
module 05: 8 private files, `0 to add, 6 to change, 0 to destroy` (known app-setting and tag drift), nothing applied.

## Open decisions

- Network (module 04): implemented as recommended (Standard v2 outbound virtual network integration, Function private
  endpoint, private DNS, public Function access disabled in a separate stage 2 apply). Open: how participants republish
  code after stage 2 (deployment endpoints become private); the guide says publish before stage 2.
- Identity ownership: confirm who runs infra/entra and grants delegated consent; accept existing object IDs
  without changing or deleting those objects when identity creation is skipped. (Module 03 implements both paths;
  module 03 itself needs no consent. Test accounts are created outside Terraform.)
- Region: Sweden Central (`swedencentral`) is the default example (decided 2026-10-14). Confirm current Flex runtime support, Standard v2 availability, quota,
  subscription policies and costs before selecting it.
- Test identities: decide between a dedicated non-production tenant and dedicated Alice, Bob and Eve test
  accounts in an existing non-production tenant. Do not store live account details in the repository.
- Versions: source assessment pins upstream examples and records published provider/Inspector versions.
  Validate package/provider combinations and negotiated MCP protocol in module 00/01 before declaring compatibility.
- Gateway authorization: verify per-tool request inspection preserves JSON-RPC and streaming; distinguish gateway
  HTTP status from downstream status returned inside an MCP tool error (module 05 implements the downstream half).
- Module 05 consent: tenant-wide admin consent for delegated Graph `User.Read` and Storage `user_impersonation` is an
  explicit identity-administrator opt-in (`grant_downstream_admin_consent`); decide per tenant whether Terraform or the
  administrator's own process grants it. Existing applications are configured by hand.
- Optional clients: Copilot Studio's documented manual Entra OAuth path requests a client secret. Defer that
  connection unless an officially supported secretless flow is proven; never relax the workshop rules.
- Cost approval: estimate Standard v2 capacity, private endpoints, telemetry, storage and API Center before deployment.
- Participant isolation: prepare one stable random suffix and private state per participant. Default to a dedicated
  group; accept an approved existing group without managing it. Shared quotas still require cohort capacity checks.

## Deviations from the build plan
- Clean-up guards (2026-10-18, found while removing APIM live): API Management returns policies as normalised XML
  (tabs, XML entities, format `xml`) while Terraform sends `rawxml`, so every plan re-sends both azapi policies unchanged
  and the module 04/05 guards refused to run. They now accept those two policy updates only when the text is identical
  apart from whitespace and entity encoding. Module 04 also accepts the update that points the optional portal's
  `WORKSHOP_MCP_ENDPOINT` hint back at the Function, and nothing else on the portal. Synthetic tests cover acceptance and
  refusal. Live: module 05 workload (6 destroyed) and module 04 (17 destroyed, APIM gone) cleaned up on 2026-10-18;
  modules 02 and 03 and the module 05 Entra delegation remain deployed in the author's test tenant.
- Module 99 (2026-10-17): the orchestrator now skips a stage whose own clean-up lacks its required private file
  (`SKIP <stage> (missing .workshop/<file>; ...)`) instead of stopping at module 05 when only module 02 was deployed.
  Module 02 runs whenever `participant.tfvars.json` exists, since its clean-up needs nothing else. `cleanup.sh` now
  translates `--tenant-id` and `--subscription-id`. Real report run on 2026-10-17 ends with `DONE report only`.
  Every module guide command now shows its result: "Real result" for runs captured on 2026-10-16/17 (modules 00, 02,
  06, 07, 99), "Expected result" built from the scripts' own messages elsewhere (modules 03-05 are not deployed).
- Module 02 live validation (2026-10-16, author-owned non-production tenant, explicit user approval): the tenant's
  management-group Azure Policy forces Storage public network access to `Disabled` at creation. The build plan assumed
  public Storage reachable by the Function App's managed identity. The new opt-in `mcp_private_storage` (file
  `infra/workload/private-storage.tf`) adds the documented Flex Consumption pattern: a /27 subnet delegated to
  `Microsoft.App/environments` and blob and queue private endpoints with private DNS. It shares the module 04 virtual
  network and private endpoint subnet (`gateway_vnet_address_space`), so module 04 adds only its own subnet and endpoint.
  The MCP endpoint stays public with its key gate. The diagram `02` still shows the default public-Storage path.
  The cleanup now also accepts the removal of only the portal `WORKSHOP_MCP_ENDPOINT` hint, which the previous rule
  refused whenever the optional portal existed. With Azure CLI 2.91, `az functionapp show` returns the raw ARM shape for
  Flex apps; the validator reads both shapes. A valid MCP tool result without `isError` no longer trips strict mode.
- Module 05 author-only implementation (2026-10-15), explicitly scoped by the user: server code, `infra/entra/delegation.tf`,
  `infra/workload/delegated-access.tf`, EN/FR guide, validator, clean-up and publish step; local/offline checks only. No
  `terraform plan` against Azure or Entra, no apply, no Azure or Microsoft Entra object created or changed. Module 04 is
  `authored` (not deployed), which is enough to continue under the `authored` rule.
  Offline evidence (`validate.ps1 -Offline`, Windows, Terraform 1.16.6, AzureRM 5.9.0, AzAPI 2.13.0 and AzureAD 3.10.0 mocks,
  .NET SDK 10):
  `PASS server: On-Behalf-Of with a managed-identity assertion, one token per downstream (Graph User.Read, Storage user_impersonation), app-only identity for read_report_as_app, app-only callers refused, no developer-credential fallback, no token parsing (expected HTTP N/A).`
  `PASS infra/entra: federated credential (tenant v2.0 issuer, managed identity principal ID subject, api://AzureADTokenExchange), delegated Graph User.Read + Storage user_impersonation only, admin consent opt-in, no password or certificate (expected HTTP N/A).`
  `PASS infra/workload: separate OBO assertion and app-only identities, every module 05 role on the one report container, no role for the OBO or host identity, Bob none, opt-in only (expected HTTP N/A).`
  `PASS synthetic report and expected results are labelled synthetic and contain no address, ID or token (2 files, expected HTTP N/A).`
  `PASS no client secret, key, SAS or token in module 05, server, infra/entra or infra/workload files (46 files, expected HTTP N/A).`
  `PASS locked build and unit tests: Alice reads, Bob denied downstream, app-only identical for everyone, app-only callers refused, Graph gets only its own token (expected HTTP N/A).`
  `PASS Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).`
  `PASS offline checks only. Module 05 is NOT deployed or validated by this result.`
  Synthetic node tests cover the live validator (operator: no secret setting, no password credential, exactly one federated
  credential for the OBO identity, container roles; personas: whoami label without name/email, Alice as_user 200, Bob as_user
  HTTP 200 with `isError: true`, as_app identical across personas through a saved hash; fail-closed for the right reason when
  module 05 is off, Bob can read, Bob gets an outer 403, Alice is denied, as_app differs, whoami leaks an address or the wrong
  label, a client secret exists, the federated credential is missing or trusts another identity, a secret-like setting exists,
  Bob or the OBO identity holds a container role; tokens never printed), the clean-up guard (workload and Entra phases, only
  module 05 deletions, foreign changes refused, idempotent, temporary var file removed) and the publish step (Entra auth only,
  retry during role propagation, refusal when not deployed).
  Deviations and decisions: (1) Two **new** user-assigned identities: `-obo` (federated credential subject, no Azure role) and
  `-report` (Storage Blob Data Reader on the `reports` container). The sample uses one identity for host storage and the
  assertion; the module 02 host identity (account-wide Blob Data Owner) is never used by a tool. (2) The report container lives
  in the module 02 storage account (name length leaves no room for a second deterministic account); roles are container-scoped,
  and the host identity's account-wide role is documented. (3) No local developer-credential fallback (the sample uses a
  `ChainedTokenCredential` in Development): disabled settings keep the module 02 demonstrations, enabled settings fail closed.
  (4) The user assertion comes from the `Authorization` header forwarded by built-in authentication (token store off since
  module 03); tenant, object ID and scopes come from the platform-injected `X-MS-CLIENT-PRINCIPAL`, never from parsing the JWT;
  app-only callers (no `scp` or `idtyp=app`) are refused for user-context tools. (5) `whoami` calls Graph `/me?$select=id`
  over HTTPS (no Microsoft.Graph SDK) and returns only an allowlisted persona label (sample returns display name and mail).
  (6) Explicit `WORKSHOP_*` settings instead of `WEBSITE_AUTH_CLIENT_ID` / `OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID`, and no
  client-secret setting name in built-in authentication (the sample points it at the identity for browser login, not needed
  here). (7) Storage OBO token requested for `https://storage.azure.com/user_impersonation`, app-only for `.default`, enforced by
  a scoped credential wrapper; Graph token for `User.Read`. (8) Entra permissions use `azuread_application_api_access` with
  scope IDs read from the tenant's service principals; `azuread_application.mcp` now ignores `required_resource_access`
  (no change to module 03 plans). (9) Admin consent is a separate opt-in (`grant_downstream_admin_consent`), Learn: Cloud
  Application Administrator suffices for delegated permissions. (10) Synthetic report published by `publish-report.ps1` with
  `az storage blob upload --auth-mode login` (shared keys stay disabled; no AzureRM data-plane provider change), using a
  container-scoped Storage Blob Data Contributor role for the publisher, removed by clean-up. (11) Bob's denial is a tool
  error: Functions MCP extension 1.5.0 rethrows worker failures and the MCP C# SDK maps non-MCP exceptions to `isError: true`
  with a generic message (verified in source, not live). (12) The architecture diagram already depicted this design; unchanged
  (`render-architecture.py --check` PASS). (13) The module 05 Entra clean-up must run before module 03's (whose allow-list
  accepts only module 03 objects).
  Source gaps: the OBO article describes a certificate-signed `client_assertion`; the managed-identity federation article
  shows the managed identity token as the assertion with `ClientAssertionCredential` (Azure.Identity `OnBehalfOfCredential`
  accepts the same callback, as in the sample). Microsoft.Identity.Web documents `SignedAssertionFromManagedIdentity` for
  ASP.NET Core APIs that validate tokens themselves; not used because built-in authentication validates the token. Learn does
  not document how the Functions MCP extension surfaces tool exceptions; behaviour taken from the extension and SDK source.
  The sample's `GetTenantId` reads `X-MS-CLIENT-PRINCIPAL`; Learn documents that App Service clients cannot set that header.
  Open: first deployment, identity-administrator review and consent, Storage service principal presence in the tenant,
  role-propagation timing, live persona checks, whether the hosted MCP extension passes `Authorization` in transport headers
  through the gateway (the sample relies on it), code republishing after module 04 stage 2.
- Module 04 author-only implementation (2026-10-15), explicitly scoped by the user: workload opt-in (`network.tf`,
  `gateway.tf`, `diagnostics.tf`, AzAPI 2.13.0 locked), policies, EN/FR guide, validator and clean-up; local/offline checks
  only. No `terraform plan` against Azure, no apply, no Azure or Microsoft Entra object created or changed. Module 03 is
  `authored` (not deployed), which is enough to continue under the `authored` rule.
  Offline evidence (`validate.ps1 -Offline`, Windows, Terraform 1.16.6, AzureRM 5.9.0, AzAPI 2.13.0 and AzureAD 3.10.0 mocks):
  `PASS gateway policy: Entra token for the MCP audience only, create_ticket requires Tools.Write, other tools Tools.Read, malformed or unknown calls denied, per-oid rate limit, optional ip-filter, gateway PRM challenge (expected HTTP 401/403/429).`
  `PASS Protected Resource Metadata is answered by the gateway itself and never names the private Function host (expected HTTP 200).`
  `PASS Terraform: Standard v2 public gateway, outbound integration, Function private endpoint and private DNS, public access disabled only in stage 2, MCP API Preview with no subscription key (expected HTTP 403 on the direct host).`
  `PASS diagnostics: 0 body bytes for frontend/backend requests/responses at both scopes, no header logged (no Authorization), no client IP (expected HTTP N/A).`
  `PASS no access token, subscription key, function key, SAS or client secret in module 04 or workload files (expected HTTP N/A).`
  `PASS Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).`
  `PASS offline checks only. Module 04 is NOT deployed or validated by this result.`
  Synthetic node tests cover the live validator (gateway 401 with the gateway PRM challenge, PRM 200, Graph token 401, direct
  Function 403, ARM public access Disabled and 0-byte diagnostics, Alice create_ticket 200, Bob create_ticket 403 and
  get_service_health 200, unknown tool 403, missing method 400, burst 429, payload-free telemetry, Eve AADSTS50105; fail-closed
  when the gateway is open, Bob can write, the Function answers publicly, only stage 1 is applied, body bytes are logged,
  telemetry holds a payload, no 429 or the PRM leaks the private host; tokens never printed) and the clean-up guard (reopen
  the Function first, then delete only gateway resources, refuse foreign changes or a server delete, idempotent).
  Deviations and decisions: (1) Two applies: stage 1 builds the gateway and private path while the Function stays public but
  Entra-protected; stage 2 (`gateway_lock_function`) disables public access, so no step leaves the server unreachable or
  anonymous. (2) The gateway forwards the same MCP-audience token to the Function (one logical resource, defence in depth);
  no audience is broadened, unlike the AI-Gateway PRM lab, which also accepts a gateway-URL audience. (3) PRM is served by the
  gateway as static JSON with the module 03 scope `api://<client-id>/user_impersonation` (lab: gateway-URL scope). (4) The
  policy requires the `user_impersonation` scope, so app-only tokens are refused at the gateway in this module. (5) No
  subscription key, product or named value: Entra tokens and app roles are the only access mechanism; non-secret values are
  rendered by Terraform `templatefile()` so mock tests assert the exact policy. (6) Diagnostics log 0 body bytes and no header at
  both the all-APIs and MCP API scopes (Learn requires only frontend response 0 at global scope). (7) The APIM logger uses the
  connection string plus the gateway user-assigned identity (Monitoring Metrics Publisher on the one component), because
  Application Insights local authentication is disabled since module 02. (8) Gateway URL is derived from the deterministic name
  (`https://apim-<stem>.azure-api.net`), so outputs and policies are known at plan time. (9) Portal prefill advertises the
  gateway URL once module 04 is enabled. (10) The architecture diagram already depicted this design; unchanged
  (`render-architecture.py --check` PASS). (11) Terraform 1.16.6 was found under a different session folder than the path
  given in the request; same version.
  Source gaps: Learn's REST/Terraform examples use `mcpProperties.endpoints` as an array of `{name, uriTemplate}`, the
  AI-Gateway PRM lab uses an object map, and the client-authorization lab omits endpoints; the workshop follows Learn.
  `secure-mcp-servers` says request headers are forwarded automatically, then shows setting `Authorization` in the outbound
  section; the workshop sets it explicitly in inbound. Overview says tools only; the existing-server article says tools and
  resources. Learn still suggests MCP Inspector 0.9.0 for APIM tests.
  Open: correctness of the per-tool role check and JSON-RPC parsing on a live gateway (policy expressions are not executed
  offline), streaming behaviour through the gateway, App Insights `AppRoleName` match in the telemetry query, Standard v2
  availability and cost approval in the chosen region, code republishing after stage 2, first deployment and live validation.
- Module 03 author-only implementation (2026-10-14), explicitly scoped by the user: `infra/entra` root, workload
  opt-in, guides, validators and clean-up; local/offline checks only. No `terraform plan` against Azure or Entra, no apply,
  no Azure or Microsoft Entra object created or changed. Module 02 is still `in-progress` (not deployed), so this is an
  authoring exception to "previous module validated first", not deployment authorization.
  Offline evidence (`validate.ps1 -Offline`, Windows, Terraform 1.16.6, AzureAD 3.10.0 and AzureRM 5.9.0 mocks):
  `PASS host.json keeps the level 0 System webhook level; the published package is never anonymous on its own (expected HTTP N/A).`
  `PASS the key gate is removed only together with enforced built-in authentication and Return401 (expected HTTP 401 without a token).`
  `PASS infra/entra: single tenant, user_impersonation, Tools.Read/Tools.Write/Tools.Execute.All, assignment required, no secret or user (expected HTTP N/A).`
  `PASS no access token, key, SAS or client secret in module 03, infra/entra or workload files (expected HTTP N/A).`
  `PASS synthetic claim examples use synthetic IDs only and contain no token (4 files, expected HTTP N/A).`
  `PASS Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).`
  `PASS offline checks only. Module 03 is NOT deployed or Entra-validated by this result.`
  Synthetic node tests cover the live validator (401 without token, PRM metadata, 401 for a Graph token, ARM auth settings,
  401 with the key alone, 200 for Alice and Bob, Eve refused with AADSTS50105; fail-closed when the endpoint is open, a Graph
  token is accepted, Eve gets a token or only stage 1 is applied; tokens and keys never printed) and the clean-up guard
  (key gate restored before auth is removed, Entra destroy limited to workshop objects, foreign changes refused, idempotent).
  Deviations: (1) Terraform never creates test users: AzureAD 3.10.0 requires a password at user creation and stores it in
  state, which conflicts with "no secrets in files"; the administrator provides existing accounts (object IDs only).
  (2) Two-stage key-gate replacement (`entra_auth_replace_key_gate`) instead of Learn's single step, because AzureRM writes
  app settings and auth settings separately; this avoids any moment with an anonymous webhook. (3) Application ID URI is
  `api://<client-id>` (sample uses a custom string). (4) No secret setting, federated credential, token store, redirect URI
  or Graph permission in module 03 (sample has them for browser login/OBO); module 05 adds the federated credential.
  (5) Allowed audiences are the API's URI and client ID (same API, v1/v2 formats); allowed clients exclude the API itself.
  (6) Built-in authorization is server-level: Bob can still call `create_ticket` until module 04 adds per-tool roles.
  (7) Fixed a latent module 02 validator bug: an unbound `[guid]` parameter is `$null`, not `Empty`, so running it without
  tenant/subscription now stays offline as its README states. No module 02 behavior or resource changed otherwise.
  Open: identity administrator review and approval of `infra/entra`, test accounts, Preview acceptance for PRM, first
  deployment (both stages), live operator and persona checks, VS Code sign-in observation, AzureRM handling of
  `WEBSITE_AUTH_*` app settings alongside `auth_settings_v2` on Flex.
- Module 02 author-only implementation (2026-10-14), explicitly scoped by the user: build code, Terraform,
  guides and validators; run only local/offline checks. No `terraform plan` against Azure, no apply, no Azure or
  Microsoft Entra change. Module 01 is still `in-progress` (manual approval observation), so this is an authoring
  exception to "previous module validated first", not deployment authorization.
  Offline evidence (`validate.ps1 -Offline`, Windows, Terraform 1.16.6, AzureRM 5.9.0 mocks, .NET SDK 10.0.402):
  `PASS host.json MCP webhook authorization level is System (expected HTTP 401 without the mcp_extension key).`
  `PASS no anonymous authorization level in server source (expected HTTP N/A).`
  `PASS no key, SAS, connection-string or client-secret pattern in module 02 files (expected HTTP N/A).`
  `PASS Terraform disables Storage shared keys, uses managed identity and outputs no key (expected HTTP N/A).`
  `PASS locked build and tool unit tests: synthetic results, strict inputs, no write without the exact shape (expected HTTP N/A).`
  `PASS Terraform format, schema and mock-only plans, including module 02 opt-in (expected HTTP N/A; no live plan/apply).`
  `PASS offline checks only. Module 02 is NOT deployed or Azure-validated by this result.`
  Synthetic node tests cover the live validator (401 without key, 401 with a wrong key, 200 initialize/tools/list,
  fail-closed on an anonymous endpoint or an extra tool, key never printed) and the clean-up guard (deletes only
  module 02 resources, refuses foreign changes or updates, idempotent when empty).
  Deviations: upstream `host.json` uses `Anonymous`; this module uses `System`. Upstream grants account-wide
  Storage Queue Data Contributor for the MCP extension; Learn documents queue use only for the deprecated SSE
  transport, so the host gets Storage Blob Data Owner only and `create_ticket` gets Storage Queue Data Message
  Sender on the `tickets` queue only. Recheck at first deployment: if the host requires queues for Streamable HTTP,
  stop and ask before widening a role. AzureRM 5.9.0 writes a key-less `AzureWebJobsStorage` string for identity
  storage; the configuration overrides it with an empty value so the host uses `AzureWebJobsStorage__*` identity
  settings. This causes an expected in-place app-settings diff on every plan and must be verified on first deployment.
  The upstream preview MCP SDK package, Graph, QR, Apps, Blob and OpenTelemetry packages are not used. The Functions
  Worker SDK still restores its generated extension project (WebJobs MCP extension 1.5.0) at build time, outside the
  package lock. The opt-in is a private `.workshop/module02.tfvars.json` var file, not a new participant parameter,
  so module 00 parameter validation is unchanged; later plans must keep passing it. Module 01 node tests failed
  locally only because the user's running `workshop-local` server locked its DLL and an uncommitted local
  `.vscode/mcp.json` edit; they pass in a clean worktree.
  Open: first deployment, live validator run, VS Code connection with the secure input, key rotation, Flex .NET 10
  runtime availability in the chosen region, cost approval.
- Module 01 local implementation (2026-10-14), explicitly requested by the user while module 00's
  cloud/container gate is pending. This is a scoped authoring/local-execution exception, not cloud authorization.
  SDK 2.2.0 and Hosting 10.0.13 are pinned with a transitive package lock; upstream license notices retained.
  One synthetic read-only health tool, no external calls, write tools, HTTP listener or payload logs.
  `PASS tools/list exposes exactly one read tool (expected HTTP N/A; stdio).`
  `PASS exact synthetic result for workshop-api (expected HTTP N/A; stdio).`
  `PASS exact synthetic result for ticket-queue (expected HTTP N/A; stdio).`
  `PASS unknown service returns a tool error (expected HTTP N/A; stdio).`
  `PASS missing service returns a tool error (expected HTTP N/A; stdio).`
  `PASS write tool is not exposed (expected HTTP N/A; stdio).`
  `PASS server remains responsive after rejected inputs (expected HTTP N/A; stdio).`
  `PASS no server stderr logging during tested calls (expected HTTP N/A; stdio).`
  `PASS local MCP checks complete (expected HTTP N/A; stdio, no Azure).`
  Real Inspector 2.9.0 CLI discovery/call succeeded. SDK client negotiated 2026-07-28.
  PowerShell and Git Bash wrappers pass. The 37-test local regression suite passes, including real stdio
  execution and EN/FR static exports with module 01's guide/validator and module 02 still marked planned.
  Manual VS Code approval is documented but not observed; no fresh-container/cloud claim.
  Module 00 and 01 remain in-progress. No Azure or Microsoft Entra change and no Preview feature used here.
- Presenter preparation (2026-10-14): separate EN/FR presenter how-to and participant entry points.
  Live local-terminal foundation preflight passed on an explicitly resolved private test target:
  `PASS subscription region (expected HTTP 200; availability is not a capacity reservation)`;
  `PASS required ARM permission grants (expected HTTP 200; deny assignments, policy and deployment approval remain separate)`;
  `PASS resource group capacity (expected HTTP 200; below the documented 980-group limit)`;
  `PASS module 00 foundation environment checks.`
  Terraform 1.16.6/AzureRM 5.9.0 initialized, schema/format checks passed and a real foundation plan proposes
  one new resource group. The plan has NOT been applied. Private target IDs, account, suffix and plan remain ignored.
  Fixed unsupported CLI subscription argument during region discovery and Windows CMD parsing of quota queries;
  synthetic tests now cover malformed region/group arrays. PowerShell Terraform examples quote file arguments.
  This is not a fresh-subscription/container validation or a deployed portal; module 00 remains in-progress.
- Agent 365 integration clarification (2026-10-14): README and EN/FR module 06 learning panels explicitly mark
  the integration and AI Gateway tier **Preview**. The board reads these panels directly.
  This remains a planned facilitator demo, not implemented infrastructure. Tenant-wide policy-write consent
  is excluded from participant scripts. Documented denial expectations distinguish server HTTP 403 from tool
  HTTP 200 with `result.isError: true`. No cloud resource or validation status changed.
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
  The subsequent user-approved local-only module 01 exception is recorded above; cloud gates are unchanged.
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
- Iterative diagram documentation (2026-10-14): both Mermaid guides derive all 18 graphs from the existing
  Draw.io source, preserving components, directed/dashed edges and ownership boundaries. Existing SVG/PNG remain
  byte-identical. The application displays matching icon-rich SVGs and closed Mermaid source/copy sections.
  Separate EN/FR implementation-status pages state that managed identities, Entra, gateway and Foundry are not deployed.
  `PASS Mermaid 11.12.0: 18 graphs parsed/rendered with matching node/edge counts` (session-only dependency);
  35 local tests pass serially. EN/FR browser checks cover 26 routes in both static and App Service runtimes,
  all module diagrams/source copies, closed advanced sections and 320/390/1366 layouts.
  An initial concurrent run timed out in two synthetic PowerShell fixtures under shared-host load;
  the complete serial run passes without relaxing assertions or changing timeouts.
  No cloud resource, module validation status, role or Preview gate changed.
- Documentation workstream PD (2026-10-14): added bilingual concept guides for the token chain, scopes versus
  app roles, OBO versus managed identity and the MCP threat model, plus bilingual facilitator timing, expected
  outcomes, safe fallbacks and common-error guidance. The guides link the existing Draw.io-derived SVG and generated
  Mermaid assets; no second architecture source or export was created. Public Microsoft Learn sources only.
  Protected Resource Metadata, API Management MCP management APIs, Foundry identity passthrough, Agent 365 and
  AI Gateway tier are marked **Preview** where used. Agent 365/AI Gateway remain facilitator-only.
  This is documentation evidence only: module statuses and validation evidence are unchanged.
- Module 99 README visuals (2026-10-16, user-approved scope): EN/FR guides embed the existing generated
  Mermaid in a closed disclosure and link icon-rich SVG/PNG exports. All five GitHub alert types have
  translated labels, decorative icons and distinct light/dark colors in the shared board/presenter renderer.
  Alert paragraphs, lists, code and ordinary blockquotes retain their structure; inline bold stays inline.
  `PASS 31/31 focused board, static export and presenter portal tests`;
  `PASS module 99 offline validator (0 failures)`; `PASS architecture --check (18 exports and both Mermaid guides)`.
  Local presenter-bundle browser checks pass in EN/FR, light/dark, at 320/390/1366 pixels.
  Tip and diagram screenshots were inspected. No global page overflow; diagrams scroll in their own region.
  No architecture, icon asset, deployment, permission or module status changed. No Azure/Entra action was run.
- Shared code-copy and Azure inspection UI (2026-10-16, user selected terminal execution):
  every non-Mermaid fenced code block uses the existing copy control, with a language label and
  shell-specific review guidance. Code is preserved verbatim rather than translated.
  EN/FR Azure context guides provide read-only, context-checked inspection of the exact workload group
  and participant tag from local Terraform outputs, plus Azure/Entra portal links.
  The shared UI never executes these commands or collects credentials, identifiers or private results.
  `PASS 34/34 focused board/export/portal tests`, including nine mocked inspection scenarios.
  Browser checks cover all 18 module/language routes and 128 exact README/outline code blocks;
  copy events use a mocked clipboard and clipboard denial shows the French manual-copy message.
  The Azure context page passes EN/FR light/dark checks at 320/390/1366 pixels; its code block was visually inspected.
  No live Azure query, resource change, public deployment or module-status change was performed.
- Contextual authentication documentation (2026-10-16, user requested all authentication modules):
  modules 02 through 05 now link each demonstrated result to its Microsoft Learn explanation and the relevant
  API, SDK or policy reference, in EN/FR. References sit in expected results, before validation, and are exported
  unchanged to the attendee/presenter application. They distinguish key-only access, server authentication,
  per-tool authorization and downstream OBO versus managed identity.
  `PASS 31/31 distinct official documentation URLs (HTTP 200)`;
  `PASS 35/35 focused board/export/portal tests`, including bilingual reference parity, source registration,
  placement and Preview labels. Fake offline clients are not presented as live identity evidence.
  Token-decoder, secret-based OBO and payload-logging examples in general documentation are explicitly excluded.
  No Azure/Entra query or change, deployment, permission change or module-status change was performed.
- Progressive teaching UI (2026-10-16, user requested concise presenter pages and deliberate commands):
  published module guides and the Azure context, presenter, hosting and workspace documents now show one authored
  section or numbered action at a time. Previous/next controls, a step selector and keyboard focus support reading;
  navigation never executes commands or records completion. Complete guides, architecture and long reference
  blocks remain closed by default. Code fences and nested disclosures are never split automatically.
  EN/FR Azure inspection is taught as context, group, participant tag, query and portal comparison;
  the local MCP lesson separates preparation, discovery and invocation. Presenter foundation and health checks
  explain prediction and observation. Module 05 separates planning, explicit approval, apply and the private
  administrator handoff. Long conceptual sections have explicit teaching headings rather than automatic truncation.
  `PASS 38/38 focused board/export/portal tests`, including reader controls, unchanged fenced content and
  ten mocked inspection outcomes; changing Azure context between reading state and querying stops before the resource read.
  Local browser checks cover 22 EN/FR routes and 371 reading steps: one article at a time, no JavaScript errors,
  all 14 long blocks closed, maximum 341 displayed article words excluding closed reference content.
  Twelve EN/FR light/dark layouts at 320/390/1366 pixels have no page overflow; exact copy uses a mocked clipboard.
  Opening a long reference block and the desktop teaching view were checked. Preview bundle contains only
  52 allowlisted files and was used locally only. No Azure/Entra access, deployment or module-status change.
- Presenter App Service portal (2026-10-16): deployed the optional public portal in the presenter's own
  non-production subscription, approved for the portal only. Resource group
  in westeurope, one Linux B1 plan, one Node 22 web app (HTTPS-only). ZIP deploy via Entra-authenticated
  `az webapp deploy`; no publishing keys or basic auth used. `GET /health` returned 200 `{"status":"ok"}`;
  `/?lang=en#/start` and `/?lang=fr#/start` returned 200. `/en/` and `/fr/` return 404 by design (language is
  a query parameter). `deploy-portal.ps1` reported a false failure at its status check (Kudu status 4 on a
  successful OneDeploy); fixed in PR #19 by reading the deployment log instead. GitHub Pages stays off.
  Module statuses are unchanged: no module 01 to 07 or 99 live validation was run.
