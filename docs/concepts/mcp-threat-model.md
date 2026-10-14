# MCP threat model

[Français](../fr/concepts/mcp-threat-model.md)

This threat model covers the planned governed endpoint. Use the
[module 04](../../assets/architecture/04.en.svg) and [module 06](../../assets/architecture/06.en.svg) architecture
views. The private Function is not a second public entry point.

| Threat | Example | Required control | Proof |
|---|---|---|---|
| Tool poisoning or rug pull | A trusted tool description or behavior changes after review | Pin reviewed sources; inventory a static allowed-tool list; review changes; keep write approval | Tool list and source revision match |
| Prompt injection | Untrusted content tells the agent to call a dangerous tool or disclose data | Treat content as data; minimize tools; enforce roles and client approval; validate arguments | Disallowed write is denied |
| Token passthrough | The MCP token is forwarded to Graph or Storage | One token and audience per hop; OBO or managed identity downstream | Wrong-audience token gets HTTP 401 |
| Confused deputy | Bob causes the app identity to perform an action he cannot perform | Separate user-context and app-only tools; explicit roles; narrow resource assignment | Bob's write gets HTTP 403 |
| Over-broad tool | A general command or unrestricted write exceeds the workshop task | Fixed schemas, synthetic data, least privilege, exact resource scope | Only documented operation is exposed |
| Gateway bypass | A client calls Functions directly | APIM-only public entry; private endpoint; public Function access disabled | Direct backend call is refused |
| Sensitive telemetry | Tokens, prompts, arguments or results enter logs | Zero request/response body bytes; approved metadata only | Log query shows no payload fields |
| Replay or stolen credential | A shared key or token is reused | Short token lifetime; no secrets in files; module 02 key is short-lived only | No committed credentials |

Protected Resource Metadata (PRM) is **Preview**. API Management MCP management APIs using
`2025-09-01-preview` are **Preview**. Neither replaces authorization at the gateway and resource.

## Optional facilitator context only

Microsoft Agent 365 integration is **Preview**. With API Management v2 it can inventory and block a whole server.
Tool-level blocking, tool activity observability and threat protection require the **AI Gateway tier (Preview)**,
which is outside the core workshop. Tenant-wide consent and policy-write access are never participant steps.

Foundry identity passthrough is **Preview** where documented. It does not permit forwarding the MCP token to Graph
or Storage. Optional clients must still use the governed APIM endpoint and a supported secretless flow.

## Expected outcome

For each threat, you can name a preventive control and a measurable denial or log check. No mitigation weakens
the one-audience rule, write approval, least privilege, payload-free logging or APIM-only entry.

## Sources

- [MCP rug-pull attack](https://learn.microsoft.com/security/zero-trust/catalog-ai-attack-techniques/rug-pull-attack).
- [Prompt injection](https://learn.microsoft.com/security/zero-trust/catalog-ai-attack-techniques/prompt-injection).
- [Secure MCP servers in API Management](https://learn.microsoft.com/azure/api-management/secure-mcp-servers).
- [Monitor MCP traffic](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers).
- [Agent 365 and API Management (Preview)](https://learn.microsoft.com/azure/api-management/agent-365).

Last verified: 2026-10-14.
