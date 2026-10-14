# Identity administrator request - Governed MCP on Azure

Send this request through your approved private process. Do not fill account identifiers into this public file.
Module 00 creates no identity. Review the later module's exact plan before approving changes.

## Requested scope and ownership

One non-production, single-tenant workshop deployment per participant, with a stable participant suffix.
Record the tenant, owner, expiry, existing application/object identifiers and approval privately.
The identity administrator owns registrations, enterprise applications, assignments and consent.
The participant owns only approved workload resources. Accept existing IDs without importing, modifying or deleting
administrator-owned objects. Use time-bound authority where available; do not make participants tenant administrators.

## API application and enterprise application

- One logical MCP API audience, a unique Application ID URI and single-tenant issuer.
- Delegated scope `user_impersonation`. It authorizes a client to act for a signed-in user; it is not a user role.
- User app roles `Tools.Read` and `Tools.Write`, allowed member type `User`.
- Application app role `Tools.Execute.All`, allowed member type `Application`, only for a separately approved app-only client.
  Do not grant it to every client or use it as an implicit bypass for write tools.
- Require assignment on the enterprise application. Unassigned Eve must not obtain access.
- Pre-authorize only the exact reviewed public clients needed by the module: the VS Code client identified in the
  pinned official sample and Azure CLI where its interactive delegated flow is required.
  Do not guess client identifiers or pre-authorize all applications.
- Use documented protected-resource metadata and OAuth challenges at the gateway. The selected App Service
  metadata configuration is **Preview**; approve it explicitly in module 03.
- The MCP service accepts only its own audience. Microsoft Graph and Storage receive separate downstream tokens,
  never a forwarded MCP client token.

## Downstream consent and secretless credentials

Module 05 needs delegated Microsoft Graph `User.Read` for `/me` and Azure Storage `user_impersonation`
for the caller's authorized data access. No Graph application permissions or directory-wide read permission are requested.
Review consent according to tenant policy. A consent grant does not grant a caller access to Storage data.
The workload's app identity uses the documented managed-identity federated credential trust for On-Behalf-Of,
not a client secret, copied certificate, publish profile or shared deployment key.
Record the exact issuer, subject and audience from the reviewed plan privately before creating the trust.

## Test assignments and separate Azure data roles

Use dedicated synthetic test personas or approved existing test users; never real business data.

| Persona | MCP user app roles | Azure data access |
|---|---|---|
| Alice | Tools.Read, Tools.Write | Storage Blob Data Reader on the one report container |
| Bob | Tools.Read | No report-container data role |
| Eve | No assignment | No report-container data role |

Azure role-based access control (RBAC) is separate from Entra app roles.
The workload managed identity receives only the required report-container reader role and synthetic-ticket
queue data role on the exact resources. A separate scoped administrator performs any required Azure role assignments.
Do not assign subscription Owner or broad Storage rights to make the demonstration work.
Write tools additionally require explicit human approval in the client.

## Review and return

Confirm which operations are approved, who executes them, which existing objects must be preserved, consent
conditions and the cleanup owner/date. Return only needed identifiers through the private channel, never tokens
or credentials. No directory creation or consent is authorized by merely receiving this document.
Validate Alice/Bob/Eve and wrong-audience behavior in the real identity module before declaring success.

## Cleanup

Remove only workshop-owned assignments, consent/trust and registrations after the reviewed workload cleanup.
Preserve existing users, groups, applications and administrator-owned resources.
Review separate Terraform roots/state before destruction; this request is not a cleanup authorization.

## Sources

- [App roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).
- [Require assignment](https://learn.microsoft.com/entra/identity/enterprise-apps/assign-user-or-group-access-portal).
- [MCP built-in authentication](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).
- [On-Behalf-Of](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow).
- [Managed-identity federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).
- [Azure role assignment scope](https://learn.microsoft.com/azure/role-based-access-control/scope-overview).
- [Pinned sample and source register](../sources.md).

Last verified: 2026-10-14. Request template, not evidence of identity deployment or consent.
