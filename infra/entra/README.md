# infra/entra - Microsoft Entra identity for the MCP server (modules 03 and 05)

**Run once by an identity administrator**, not by every participant, with an interactive Azure CLI sign-in to an explicit
non-production tenant (`az login --tenant <tenant-id> --allow-no-subscriptions`). It uses a separate private state and a
private var file (`.workshop/entra.tfvars.json`), never committed. Terraform 1.16.6+ below 2; AzureAD is locked to 3.10.0.

## What it manages

Default (`create_application = true`), all workshop-owned:

| Resource | Purpose |
|---|---|
| `azuread_application.mcp` | MCP API registration: single tenant, v2 tokens, scope `user_impersonation`, app roles `Tools.Read`, `Tools.Write` (users) and `Tools.Execute.All` (applications). Stable IDs derived with `uuidv5` from the participant stem. No secret, password, certificate or redirect URI. |
| `azuread_application_identifier_uri.mcp` | Application ID URI `api://<client-id>` |
| `azuread_service_principal.mcp` | Enterprise application with **assignment required** |
| `azuread_application_pre_authorized.clients` | Visual Studio Code (`aebc6443-996d-45c2-90f0-388ff96faa56`) and Azure CLI (`04b07795-8ddb-461a-bbee-02f9e1bf7b46`) for `user_impersonation` only |
| `azuread_app_role_assignment.personas` | Only for test accounts passed in `test_user_object_ids`: Alice → Read + Write, Bob → Read, Eve → none |

**Existing IDs path** (`create_application = false`, `existing_application_client_id`): the application and its enterprise
application are read with data sources and checked (Application ID URI, `user_impersonation`, three roles, assignment
required). They are never imported, changed or deleted. Only the persona assignments you request are created.

**Users are never created here.** AzureAD 3.10.0 requires a password to create a user and stores it in state, so the
administrator creates dedicated test accounts out of band and passes their object IDs. Those users are never managed.

No API permission is requested in module 03, so no admin consent is needed there.

### Module 05 additions (opt-in, created path only)

| Variable | Resource | Purpose |
|---|---|---|
| `enable_delegated_access` | `azuread_application_api_access.downstream` | Delegated Microsoft Graph `User.Read` and Azure Storage `user_impersonation`. Scope IDs are read from the tenant's own service principals (`data.azuread_service_principal.downstream`), never hard-coded. No application permission. |
| `obo_identity_principal_id` | `azuread_application_federated_identity_credential.obo` | The MCP API trusts **one** user-assigned managed identity of the workload: issuer `https://login.microsoftonline.com/<tenant>/v2.0`, subject = that identity's principal (object) ID, audience `api://AzureADTokenExchange`. This replaces any client secret. |
| `grant_downstream_admin_consent` | `azuread_service_principal_delegated_permission_grant.downstream` | Tenant-wide admin consent for exactly those two scopes, decided by the identity administrator (Cloud Application Administrator or Application Administrator). |

Order: the workload creates the identity first (`infra/workload` output `delegated_obo_identity_principal_id`), then the
administrator reruns this root with the three variables. `azuread_application.mcp` ignores `required_resource_access` so the
separate `azuread_application_api_access` resources own it. With `create_application = false` nothing is changed: the
administrator applies the same three settings by hand (see [identity request](../../docs/requests/identity-request.md)).

## Hand-off and module 05

- `workload_module03_tfvars`: the exact non-secret values for `.workshop/module03.tfvars.json` (workload opt-in).
- `persona_object_ids`: optional private file for the validator's persona cross-check.
- `module05_federated_credential`: parent application object ID, issuer, audience and subject of module 05's managed-identity
  federated credential (On-Behalf-Of).
- `module05_delegation` and `workload_module05_tfvars`: what module 05 manages here, and the non-secret values for
  `.workshop/module05.tfvars.json` (Alice's and Bob's object IDs only).

## Checks

```powershell
terraform -chdir=infra/entra init -lockfile=readonly
terraform -chdir=infra/entra fmt -check -recursive
terraform -chdir=infra/entra validate
terraform -chdir=infra/entra test
```

The fifteen tests use a mock AzureAD provider and plan-only runs: they contact no tenant and create nothing. They cover the
created path, persona assignments (Eve never assigned, application role never assigned), the read-only existing path,
refusal of an existing application without assignment required or without the workshop roles, invalid inputs, and module 05
(default off, exact scopes, federated credential values, opt-in consent, existing application untouched, invalid subject).

Clean-up: `modules/03-entra-authentication/cleanup.ps1 -Scope Entra` plans a destroy and refuses any change other than
deleting the objects above.

## Sources

- [AzureAD 3.10.0 provider](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0/docs): `azuread_application`,
  [`azuread_application_identifier_uri`](https://github.com/hashicorp/terraform-provider-azuread/blob/v3.10.0/docs/resources/application_identifier_uri.md),
  [`azuread_application_pre_authorized`](https://github.com/hashicorp/terraform-provider-azuread/blob/v3.10.0/docs/resources/application_pre_authorized.md),
  `azuread_service_principal`, `azuread_app_role_assignment`, [`azuread_user` password requirement](https://github.com/hashicorp/terraform-provider-azuread/blob/v3.10.0/docs/resources/user.md).
- [App roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).
- [MCP authorization with App Service and Functions](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).
- [Functions MCP tutorial (VS Code client ID)](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial).
- [Pinned sample `infra/app/entra.bicep`](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/blob/468c518c884ec318e3001b9573254c9e775409c9/infra/app/entra.bicep) (MIT).
- Module 05: [On-Behalf-Of flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow),
  [app trusts a managed identity](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity),
  [grant tenant-wide admin consent](https://learn.microsoft.com/entra/identity/enterprise-apps/grant-admin-consent).
- [Terraform mocks](https://developer.hashicorp.com/terraform/language/tests/mocking).

Last verified: 2026-10-15. Mock tests do not establish tenant compatibility; nothing has been applied.
