# infra/entra - Microsoft Entra identity for the MCP server (module 03)

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

No API permission is requested, so no admin consent is needed in module 03.

## Hand-off and module 05

- `workload_module03_tfvars`: the exact non-secret values for `.workshop/module03.tfvars.json` (workload opt-in).
- `persona_object_ids`: optional private file for the validator's persona cross-check.
- `module05_federated_credential`: parent application object ID, issuer and audience reserved for module 05's managed-identity
  federated credential (On-Behalf-Of). Nothing is created for it now.

## Checks

```powershell
terraform -chdir=infra/entra init -lockfile=readonly
terraform -chdir=infra/entra fmt -check -recursive
terraform -chdir=infra/entra validate
terraform -chdir=infra/entra test
```

The eight tests use a mock AzureAD provider and plan-only runs: they contact no tenant and create nothing. They cover the
created path, persona assignments (Eve never assigned, application role never assigned), the read-only existing path,
refusal of an existing application without assignment required or without the workshop roles, and invalid inputs.

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
- [Terraform mocks](https://developer.hashicorp.com/terraform/language/tests/mocking).

Last verified: 2026-10-14. Mock tests do not establish tenant compatibility; nothing has been applied.
