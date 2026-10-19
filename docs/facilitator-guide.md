# Facilitator guide

[Français](fr/facilitator-guide.md)

This guide supports a 4-hour core workshop. Modules 00 and 02 are validated live. Modules 03 to 06 passed their live
operator checks in a test tenant but stay authored until the Alice, Bob and Eve persona checks pass.
Modules 01, 07 and 99 are authored (offline checks pass). Timings describe the planned delivery and must not be presented
as validation evidence.

## Before participants arrive - 30 minutes

- Confirm the published revision, module status and [architecture provenance](../assets/architecture/README.md).
- Keep Alice, Bob and Eve synthetic in slides and logs. Never display live tokens, tenant IDs or subscriptions.
- Confirm the approved non-production subscription, identity administrator, role-assignment owner and cost boundary.
- Register MFA for Alice, Bob and Eve before the session if the test tenant requires it: sign in once with each account
  and register a method. Never weaken Conditional Access to skip it.
- Renew the portal capacity review (less than 24 hours old) before deploying or redeploying the portal.
  See [review capacity privately](HOSTING.md#review-capacity-privately).
- Plan module 04 API Management for one day: it is billed per hour while it exists. Deploy it the same day and clean it up that day.
- Open the real annotated captures (list below). A capture or recording demonstrates an expected result, not validation.
- Keep optional Agent 365 and AI Gateway material facilitator-only; both are **Preview**.

## Real captures for fallback

Each module shows real captures from the author's test tenant at the step where they apply.
Names are pseudonymised, IDs are zeroed and pink frames mark what to check.

| Module | Where in the guide | What the capture shows |
|---|---|---|
| 02 | [Steps](../modules/02-open-server/README.md#steps) | Storage networking: public access disabled, private endpoints approved |
| 03 | [Steps](../modules/03-entra-authentication/README.md#steps) | Terminal: operator validator output; Alice persona check |
| 03 | [Check the same result in the Azure portal](../modules/03-entra-authentication/README.md#check-the-same-result-in-the-azure-portal) | Function authentication, app registration, app roles, assignment required |
| 05 | [Identity administrator step](../modules/05-delegated-and-app-only/README.md#identity-administrator-approve-trust-and-consent-before-applying) | API permissions; federated credential, no client secret |
| 06 | [Step 3](../modules/06-observe-inventory/README.md#step-3---query-mcp-traffic-in-application-insights) | Application Insights Logs in KQL mode, metadata only |
| 06 | [Optional step](../modules/06-observe-inventory/README.md#optional---ask-the-observability-agent-the-same-question) | Observability Agent: question, generated KQL, same rows (optional) |

Terminal captures follow the validator layout: a purpose line, `== Step N ==` headers with a `Why:` line,
then one `PASS`/`FAIL` line per check with the expected HTTP status.

## Run of show

| Time | Module | Facilitation target | Exact expected outcome | Fallback |
|---|---|---|---|---|
| 00:00-00:15 | Welcome | Explain authentication, authorization and approval | Participants can name all three controls | Use [learning guide](LEARNING-GUIDE.md) |
| 00:15-00:40 | 00 | Run prerequisites and ownership checks | Published validator PASS lines; no resource deployment implied | Pair with a prepared workstation; do not skip permission checks |
| 00:40-01:10 | 01 | Discover and call the local read tool | `tools/list`, exact synthetic result, visible approval control | Use captured Inspector output; keep module status unchanged |
| 01:10-01:30 | 02 | Show why a shared key is insufficient | HTTP 401 without key; HTTP 200 with key and MCP success | Module 02 real captures or a recording; never expose the key |
| 01:30-02:00 | 03 | Teach audience, scope and app role | Wrong audience HTTP 401; Alice/Bob connect; Eve cannot obtain assigned token | Module 03 real terminal and portal captures; synthetic claims from concept guide |
| 02:00-02:10 | Break | Stop and reset clients | No credential remains on screen | Close clients and terminals |
| 02:10-02:45 | 04 | Prove APIM is the only entry point | Bob write 403; Alice write 200; burst 429; direct backend refused; zero body logs | Replay approved recording and inspect expected statuses |
| 02:45-03:15 | 05 | Compare OBO and managed identity | User path: Alice allowed/Bob denied; app path: same result for both | Use the four-cell result table and module 05 real portal captures |
| 03:15-03:40 | 06 | Query metadata and inventory | Caller, fixed tool, status, latency, correlation ID; no payload; gateway endpoint inventoried | Module 06 real KQL capture or a prepared redacted query result |
| 03:40-03:50 | 07 optional | Explain another client without changing the boundary | Only supported secretless connection; no core dependency | Skip. Mention Foundry identity passthrough **Preview** only |
| 03:50-04:00 | 99 | Review cleanup and evidence | Workshop-owned resources accounted for; destroy still requires approval | Use cleanup checklist; never improvise deletion |

## Common errors and safe responses

| Symptom | Explain | Safe response |
|---|---|---|
| HTTP 401 | Authentication or token validation failed | Check issuer, tenant, exact audience and expiry; obtain the correct token |
| HTTP 403 at APIM | Caller is authenticated but lacks the required role or is blocked | Check Alice/Bob assignment and policy; do not widen Bob's role |
| HTTP 200 with `isError: true` | MCP transport succeeded; the tool or downstream resource denied the action | Read the structured tool result and correlation ID |
| Direct Function call works | Gateway bypass remains possible | Stop the exercise; restore private/APIM-only access before continuing |
| OBO fails for Bob | User rights are correctly enforced | Keep the denial; do not use managed identity as fallback |
| Client asks for a secret | The documented client flow is not workshop-compatible | Defer the optional client; never add a client secret |
| Logs show body content | Diagnostic settings violate the workshop boundary | Stop traffic, remove body capture and verify zero body bytes |
| Preview behavior differs | Preview contract or availability changed | Use the recording, label the gap and recheck Microsoft Learn |

## Optional facilitator-only demonstrations

Protected Resource Metadata and API Management MCP management APIs are **Preview**. Agent 365 integration and the
**AI Gateway tier (Preview)** are optional and require separate tenant-level approval; never ask participants to
grant it. Foundry identity passthrough is **Preview** where documented. None of these changes the rule that clients
use the governed APIM endpoint and downstream APIs receive newly acquired audience-specific tokens.

## Close

Record only non-sensitive PASS lines, deviations and public source dates. Do not change a module to `validated`
until its own validator passes on a fresh subscription immediately after the preceding module.

## Sources

- [Workshop sources](sources.md).
- [Generated architecture steps](../assets/architecture/STEPS.md).
- [Microsoft Learn: secure MCP servers](https://learn.microsoft.com/azure/api-management/secure-mcp-servers).

Last verified: 2026-10-14.
