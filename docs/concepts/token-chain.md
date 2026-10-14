# Token chain: one token for each hop

[Français](../fr/concepts/token-chain.md)

Use the [module 05 architecture](../../assets/architecture/05.en.svg) with the
[generated Mermaid view](../../assets/architecture/STEPS.md#05--who-carries-the-rights).
`assets/architecture/workshop.drawio` remains the single architecture source.

## The rule

An access token is issued for one resource. Its `aud` (audience) claim identifies that resource.
Every resource validates the issuer, tenant, audience and expiry before it checks scopes or roles.

```text
Alice -> MCP client: sign in
MCP client -> APIM/Functions: token A, audience = governed MCP server
Functions -> Microsoft Graph: token B, audience = Microsoft Graph
Functions -> Azure Storage: token C, audience = Azure Storage
```

Token A can cross API Management (APIM) to the private Function only because they protect one logical MCP
resource. It is never sent to Graph or Storage. The Function obtains token B or C through On-Behalf-Of (OBO)
for a user-context tool, or through managed identity for an app-only tool.

## Synthetic walkthrough

1. Alice signs in. The client requests the MCP server's delegated scope.
2. APIM validates token A and checks the fixed tool name and Alice's app role.
3. `whoami` exchanges Alice's assertion for token B. Graph validates its own audience.
4. `read_report_as_user` obtains a separate Storage token C carrying Alice's delegated context.
5. `read_report_as_app` obtains a separate Storage token C from the managed identity. It has no Alice context.

Bob's MCP token can be valid while Storage still denies `read_report_as_user`. Eve cannot obtain the required
assigned-user token. A downstream HTTP 403 can appear inside an MCP tool error carried by outer HTTP 200.

## Expected outcome

You can identify the issuer, audience and rights owner at every hop without inspecting a live token.
No token, prompt, tool argument or tool result is written to logs. APIM remains the only public entry point.

> [!WARNING]
> Token passthrough is not delegation. Never forward the MCP token to a downstream API, broaden accepted
> audiences, or fall back to a developer credential after an OBO failure.

## Sources

- [Access tokens](https://learn.microsoft.com/entra/identity-platform/access-tokens).
- [Validate claims](https://learn.microsoft.com/entra/identity-platform/claims-validation).
- [On-Behalf-Of flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow).
- [Built-in MCP authorization and Protected Resource Metadata (Preview)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).

Last verified: 2026-10-14.
