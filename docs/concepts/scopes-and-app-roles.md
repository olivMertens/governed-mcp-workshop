# Scopes and app roles

[Français](../fr/concepts/scopes-and-app-roles.md)

Authentication identifies the caller. A delegated scope states what a client may request for a signed-in user.
An app role states which assigned user or application may perform an operation. Human approval authorizes one
proposed tool call. These controls complement one another.

| Control | Token claim | Workshop example | Question answered |
|---|---|---|---|
| Delegated scope | `scp` | `user_impersonation` | May this client call the MCP server for Alice? |
| App role | `roles` | `Tools.Read`, `Tools.Write` | May Alice perform this operation? |
| Client approval | Client record | Approve `create_ticket` | Does the human approve this write now? |

## Alice, Bob and Eve

- **Alice** is assigned `Tools.Read` and `Tools.Write`. After she approves the write, `create_ticket` may run.
- **Bob** is assigned `Tools.Read`. His valid sign-in and scope do not grant `Tools.Write`; APIM returns HTTP 403.
- **Eve** is not assigned. With assignment required, she cannot obtain the workshop access token.

The API defines stable app roles. Administrators assign them to users or applications. The resource checks the
exact claim values. A consented scope is not a role assignment, and preauthorization does not grant a tool role.
Use platform token validation and policy or framework authorization. Never hand-write JSON Web Token validation.

## Expected outcome

Given a synthetic claim set, you can explain why Alice is allowed, Bob is denied for a write and Eve cannot enter.
Write tools always require both an explicit role and human approval. Logs retain only caller object ID, fixed tool
name, status, latency and correlation ID.

## Sources

- [Scopes and permissions](https://learn.microsoft.com/entra/identity-platform/scopes-oidc).
- [Add app roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).
- [Verify scopes and app roles](https://learn.microsoft.com/entra/identity-platform/scenario-protected-web-api-verification-scope-app-roles).

Last verified: 2026-10-14.
