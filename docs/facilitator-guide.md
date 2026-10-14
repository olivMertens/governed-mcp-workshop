# Facilitator guide

[Français](fr/facilitator-guide.md)

This guide supports a 4-hour core workshop. Modules 00 and 01 are currently implemented; later timings describe
the planned delivery and must not be presented as validation evidence. Use [PROGRESS.md](PROGRESS.md) for status.

## Before participants arrive - 30 minutes

- Confirm the published revision, module status and [architecture provenance](../assets/architecture/README.md).
- Keep Alice, Bob and Eve synthetic in slides and logs. Never display live tokens, tenant IDs or subscriptions.
- Confirm the approved non-production subscription, identity administrator, role-assignment owner and cost boundary.
- Prepare screenshots or recordings for every cloud step. A recording demonstrates an expected result, not validation.
- Keep optional Agent 365 and AI Gateway material facilitator-only; both are **Preview**.

## Run of show

| Time | Module | Facilitation target | Exact expected outcome | Fallback |
|---|---|---|---|---|
| 00:00-00:15 | Welcome | Explain authentication, authorization and approval | Participants can name all three controls | Use [learning guide](LEARNING-GUIDE.md) |
| 00:15-00:40 | 00 | Run prerequisites and ownership checks | Published validator PASS lines; no resource deployment implied | Pair with a prepared workstation; do not skip permission checks |
| 00:40-01:10 | 01 | Discover and call the local read tool | `tools/list`, exact synthetic result, visible approval control | Use captured Inspector output; keep module status unchanged |
| 01:10-01:30 | 02 | Show why a shared key is insufficient | HTTP 401 without key; HTTP 200 with key and MCP success | Recording; never expose the key |
| 01:30-02:00 | 03 | Teach audience, scope and app role | Wrong audience HTTP 401; Alice/Bob connect; Eve cannot obtain assigned token | Synthetic claims from concept guide |
| 02:00-02:10 | Break | Stop and reset clients | No credential remains on screen | Close clients and terminals |
| 02:10-02:45 | 04 | Prove APIM is the only entry point | Bob write 403; Alice write 200; burst 429; direct backend refused; zero body logs | Replay approved recording and inspect expected statuses |
| 02:45-03:15 | 05 | Compare OBO and managed identity | User path: Alice allowed/Bob denied; app path: same result for both | Use the four-cell result table |
| 03:15-03:40 | 06 | Query metadata and inventory | Caller, fixed tool, status, latency, correlation ID; no payload; gateway endpoint inventoried | Prepared redacted query result |
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
