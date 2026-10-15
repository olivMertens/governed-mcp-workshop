# Identity administrator request - Governed MCP on Azure

Send this request through your approved private process. Do not fill account identifiers into this public file.
Module 00 creates no identity. Module 03 creates exactly the objects below with `infra/entra`, after you review its plan.
Receiving this document authorizes nothing.

## Requested scope and ownership

One non-production, single-tenant workshop deployment per participant, with a stable participant suffix.
The participant suffix appears in display labels; Microsoft Entra generates the object and client IDs.
Record the tenant, owner, expiry, identifiers and approval privately.
The identity administrator owns registrations, enterprise applications, assignments and any consent; the participant owns
only approved workload resources. Run `infra/entra` once, interactively (`az login --tenant <tenant-id> --allow-no-subscriptions`),
with its own private var file (`.workshop/entra.tfvars.json`) and state. Use time-bound roles where available;
do not make participants tenant administrators.

**Roles needed:** Cloud Application Administrator (or Application Administrator) for the objects and assignments below.
User Administrator only if you create the test accounts. No Global Administrator and no admin consent for module 03. Module 05 consent is reviewed separately below.

## Module 03: what `infra/entra` creates

| Object | Exact settings |
|---|---|
| App registration "Workshop MCP API (mcp-&lt;prefix&gt;-&lt;suffix&gt;)" | Single tenant (`AzureADMyOrg`), v2 access tokens, owner = the signed-in administrator, tags `workshop:`, `owner:`, `expiry:`. No redirect URI, **no client secret, certificate or password**, no API permission requested. |
| Application ID URI | `api://<client-id>` |
| Delegated scope | `user_impersonation` (type User). It lets a client act for a signed-in user; it is not a user role. |
| App roles | `Tools.Read` and `Tools.Write` (allowed member type User); `Tools.Execute.All` (allowed member type Application, defined but **not assigned** by this module; only for a separately approved app-only client). |
| Enterprise application | **Assignment required** = yes. Unassigned users such as Eve cannot obtain a token (`AADSTS50105`). |
| Pre-authorized clients for `user_impersonation` only | Visual Studio Code `aebc6443-996d-45c2-90f0-388ff96faa56` (Microsoft Learn Functions MCP tutorial and pinned sample) and Microsoft Azure CLI `04b07795-8ddb-461a-bbee-02f9e1bf7b46` (used by the validator). No other client; never all applications. |
| App role assignments | Alice → `Tools.Read` and `Tools.Write`; Bob → `Tools.Read`; Eve → none. Only for existing accounts whose object IDs you pass. |

**Consent:** none for module 03. No Microsoft Graph or Storage permission is requested, and the two pre-authorized clients
receive `user_impersonation` without a consent prompt. Assignment (not consent) decides who gets in.

**Existing application instead:** set `create_application = false` and `existing_application_client_id`. Terraform only reads
that application and its enterprise application, checks the Application ID URI, `user_impersonation`, the three roles and
assignment required, and fails if one is missing. It never changes or deletes them; only the requested persona assignments
are created. Pre-authorizations on an existing application stay your responsibility.

**Hand-off:** return only `terraform output -json workload_module03_tfvars` (tenant ID, client ID, Application ID URI, allowed
clients) and, optionally, `persona_object_ids`, through the private channel. Never tokens or credentials.

## Test accounts (created outside Terraform)

Terraform does not create users: the AzureAD provider requires a password at creation and would store it in state.
Create dedicated, non-production test accounts with your usual process (for example a Temporary Access Pass, no shared
password), then pass their object IDs in `test_user_object_ids`. They are read-only inputs: never changed or deleted.
Alice, Bob and Eve are teaching labels; agree on isolated accounts or reviewed assignments per participant and never modify
another participant's assignments.

| Persona | MCP app roles (module 03) | Azure data access (module 05) |
|---|---|---|
| Alice | Tools.Read, Tools.Write | Storage Blob Data Reader on the one report container |
| Bob | Tools.Read | No report-container data role |
| Eve | No assignment | No report-container data role |

Azure role-based access control (RBAC) is separate from Entra app roles. A separate scoped administrator performs any Azure
role assignment. Do not assign subscription Owner or broad Storage rights to make the demonstration work.
Write tools additionally require explicit human approval in the client.

## Workload side (participant, for information)

The participant enables built-in authentication on the Function App with these values: require authentication, HTTP 401 for
unauthenticated requests, issuer `https://login.microsoftonline.com/<tenant-id>/v2.0`, allowed audiences `api://<client-id>`
and `<client-id>` only, allowed client applications = the pre-authorized clients, and Protected Resource Metadata
(`WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES`, **Preview**). Please confirm that this Preview feature is acceptable in your tenant.
The MCP service accepts only its own audience; Microsoft Graph and Storage receive separate downstream tokens, never a
forwarded MCP client token.

## Module 05: downstream delegation and secretless credential (`infra/entra/delegation.tf`)

Reviewed separately, after module 03 and **after** the participant's workload created the On-Behalf-Of (OBO) assertion identity
(`terraform output -json entra_module05_tfvars` in `infra/workload` returns its principal ID). Three opt-in variables, all default
off; created application only:

| Variable | Object | Exact settings |
|---|---|---|
| `enable_delegated_access = true` | Requested API permissions (`azuread_application_api_access`) | **Delegated** Microsoft Graph `User.Read` (client `00000003-0000-0000-c000-000000000000`) and Azure Storage `user_impersonation` (client `e406a681-f3d4-42a8-90b6-c2b029497af1`). Scope IDs are read from your tenant's service principals. **No application permission.** |
| `obo_identity_principal_id = <principal-id>` | Federated identity credential on the MCP API registration | Name `workshop-obo-<prefix>`, issuer `https://login.microsoftonline.com/<tenant-id>/v2.0`, subject = the workload's `id-mcp-<prefix>-<suffix>-obo` **principal (object) ID** (case-sensitive), audience `api://AzureADTokenExchange`. It replaces any client secret: only that managed identity can prove the API's identity. |
| `grant_downstream_admin_consent = true` | Two tenant-wide delegated permission grants (`AllPrincipals`) | Exactly `User.Read` on Microsoft Graph and `user_impersonation` on Azure Storage, for the workshop enterprise application. Your decision: leave it false to grant consent through your own process. |

**Roles needed:** Cloud Application Administrator or Application Administrator (or application owner) for the requested
permissions and the federated credential. Per Microsoft Learn, Cloud Application Administrator or Application Administrator can
grant tenant-wide consent for **delegated** permissions; Privileged Role Administrator is only needed for Microsoft Graph
application permissions, which this workshop never requests.

**What consent allows.** With these grants, the MCP server can exchange a signed-in user's MCP token for a Graph token that reads
only that user's own profile object ID (`/me?$select=id`), and a Storage token that has exactly the user's own Azure RBAC rights.
It can never read anything the user cannot read. App-only access to the report uses a different managed identity and Azure RBAC
on one container; it needs no Entra permission.

**Existing application instead** (`create_application = false`): Terraform changes nothing. Apply the same three settings by
hand on your application, with the same values, and record them privately.

**Hand-off:** return `terraform output -json workload_module05_tfvars` (Alice's and Bob's object IDs only) through the private
channel, for the participant's `.workshop/module05.tfvars.json`. The participant's workload then grants Alice, and only Alice,
Storage Blob Data Reader on the report container.

**Clean-up:** `modules/05-delegated-and-app-only/cleanup.ps1 -TenantId <tenant-id> -Scope Entra` removes only the federated
credential, the two requested permissions and the two grants. Run it before the module 03 Entra clean-up.
## Review and return

Confirm which operations are approved, who executes them, which existing objects must be preserved, the Preview acceptance
and the cleanup owner and date. Validate Alice, Bob, Eve and wrong-audience behavior with the module 03 validator before
declaring success.

## Cleanup

After the participant's workload clean-up, run `modules/03-entra-authentication/cleanup.ps1 -TenantId <tenant-id> -Scope Entra`.
It plans a destroy and refuses anything except deleting the workshop-created registration, Application ID URI, enterprise
application, pre-authorizations and persona assignments. Provided applications and existing users are never deleted; remove
test accounts separately if they were created only for the workshop. Deleted registrations remain restorable for 30 days.

## Sources

- [App roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).
- [Require assignment](https://learn.microsoft.com/entra/identity/enterprise-apps/assign-user-or-group-access-portal).
- [MCP built-in authentication](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).
- [Functions MCP tutorial: built-in authentication and VS Code client ID](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial).
- [On-Behalf-Of](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow).
- [Managed-identity federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).
- [Grant tenant-wide admin consent](https://learn.microsoft.com/entra/identity/enterprise-apps/grant-admin-consent).
- [Azure role assignment scope](https://learn.microsoft.com/azure/role-based-access-control/scope-overview).
- [Pinned sample and source register](../sources.md).

Last verified: 2026-10-15. Matches `infra/entra` as authored for modules 03 and 05; not evidence of identity deployment or consent.
