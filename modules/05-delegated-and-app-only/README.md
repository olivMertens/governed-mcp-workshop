# 05 - Who carries the rights? On-Behalf-Of vs app-only (level 3)

[Français](README.fr.md)

## Goal

Ask the **same question** as two different users and see **who carries the rights** downstream. At the end:

- `whoami` calls Microsoft Graph **on behalf of** the signed-in user and returns only a synthetic persona label (`alice` or `bob`);
- `read_report_as_user` reads a synthetic report in Azure Storage **as the user** (On-Behalf-Of, OBO): **Alice** gets the report,
  **Bob** gets an **MCP tool error inside an HTTP 200 response** because Storage answers him with HTTP 403;
- `read_report_as_app` reads the same report **as the application** (a managed identity): **Alice and Bob get the same result**;
- **no client secret exists anywhere**: the MCP API proves its identity with a managed identity through a federated credential.

> [!WARNING]
> Never paste a live token into a website, a chat, a file, a screenshot or a log. The validator keeps tokens in memory only,
> and `whoami` never returns a real name or email.

## Why it matters

Until now every tool used either nothing downstream (synthetic demonstrations) or the server's own identity. Real tools call
other APIs, and the key design question is **whose rights are used for that call**:

| | User context: **On-Behalf-Of** | Application context: **managed identity** |
|---|---|---|
| Tools | `whoami`, `read_report_as_user` | `read_report_as_app` |
| Downstream token | A **new** token for Graph (`User.Read`) or Storage (`user_impersonation`), issued for the signed-in user | A token for the Function's app-only user-assigned managed identity |
| Who decides access | The **user's** own role on the data (Alice: Storage Blob Data Reader; Bob: none) | The **identity's** role (Storage Blob Data Reader on one container) |
| Result | Differs per user | **Same for every caller** the gateway lets through |
| Risk if misused | Low: the server cannot exceed the user's rights | Confused deputy: anyone allowed to call the tool reads what the app can read |

**One token per hop, one audience per token.** The MCP client's token has the MCP API audience. The server never forwards it to
Graph or Storage (no token passthrough). For user-context tools it sends that token **only to Microsoft Entra ID** as the OBO
*assertion* and receives a separate token per downstream resource. For the app-only tool, the caller's token is not used at all.

**Secretless OBO.** OBO needs the MCP API to authenticate as a confidential client. Instead of a client secret or certificate,
the API registration trusts **one user-assigned managed identity** of the workload through a **federated identity credential**
(issuer `https://login.microsoftonline.com/<tenant>/v2.0`, subject = the identity's principal ID, audience
`api://AzureADTokenExchange`). The server asks that identity for a token with audience `api://AzureADTokenExchange` and uses it as
the client assertion ([concept](../../docs/concepts/obo-and-managed-identity.md)).

**OBO is for users only.** An application token (no `scp` claim, `idtyp=app`) is refused by the user-context tools before any
downstream call: OBO would otherwise produce a token that does not represent the original caller.

**Outer HTTP status vs tool result.** MCP carries tool errors inside a successful JSON-RPC response: Bob's call returns
**HTTP 200** with `result.isError: true`. The gateway's HTTP 403 (module 04) means "you may not call this tool at all"; a tool
error with HTTP 200 means "the tool ran, and the downstream API refused the identity it used".

## What you deploy

Opt-in variables, default off: modules 00 to 04 are unchanged when `enable_delegated_access` is false, and the server keeps the
module 02 demonstrations for `whoami` and `read_report_*`.

**Workload** (`infra/workload/delegated-access.tf`, participant):

| Resource | Settings |
|---|---|
| User-assigned identity `id-mcp-<prefix>-<suffix>-obo` | Trusted by the MCP API's federated credential. **No Azure role.** Used only to get the OBO client assertion. |
| User-assigned identity `id-mcp-<prefix>-<suffix>-report` | App-only identity of `read_report_as_app` |
| Blob container `reports` (module 02 storage account, shared keys disabled) | Private; holds the synthetic `monthly-usage.json` ([synthetic-data](synthetic-data/monthly-usage.json)) |
| Role assignment | **Storage Blob Data Reader** for the `-report` identity, scope = the `reports` container only |
| Role assignment | **Storage Blob Data Reader** for Alice (`delegated_persona_object_ids.alice`), same container scope. **Bob gets none.** |
| Role assignment | Storage Blob Data Contributor on the container for the person who publishes the report (default: the signed-in Terraform user) |
| Function App (module 02) | Both identities attached; non-secret `WORKSHOP_*` settings: tenant, MCP API client ID, both identity client IDs, container URL, persona map |

**Why two new identities?** The OBO identity can act as the MCP API registration, so it holds no data role: a user-context call
can only ever use the user's delegated rights. The app-only rights live on a different identity. The module 02 host identity
(Blob Data Owner on the whole account for the Functions host) is never used by a tool.

**Microsoft Entra** (`infra/entra/delegation.tf`, identity administrator, created application only):

| Variable | Resource | Effect |
|---|---|---|
| `enable_delegated_access` | `azuread_application_api_access` | The MCP API requests delegated Microsoft Graph `User.Read` and Azure Storage `user_impersonation`. Scope IDs are read from the tenant's service principals. No application permission. |
| `obo_identity_principal_id` | `azuread_application_federated_identity_credential` | Trusts the `-obo` identity (subject = its principal ID). |
| `grant_downstream_admin_consent` | `azuread_service_principal_delegated_permission_grant` | Tenant-wide admin consent for exactly those two scopes (the identity administrator decides). |

![Level 3 architecture](../../assets/architecture/05.en.svg)

**Preview:** nothing new in this module. Protected Resource Metadata on the Function (module 03) and the API Management MCP server
API `2025-09-01-preview` (module 04) stay **Preview** if you use them.

**Cost:** two managed identities and one container cost nothing by themselves; the extra Storage transactions and Graph calls
are negligible. Module 04's gateway is still billed while it exists.

**Code:** the tools live in [src/FunctionsMcpServer](../../src/FunctionsMcpServer) (`Logic/DelegatedTools.cs`,
`Identity/DownstreamCredentials.cs`, `Logic/CallerContext.cs`). They follow the pinned sample's `HelloToolWithAuth.cs`
(`Azure-Samples/remote-mcp-functions-dotnet` at `468c518c884ec318e3001b9573254c9e775409c9`, MIT) with these changes: no local
developer-credential fallback, the user assertion comes from the platform-validated request (built-in authentication), only the
Graph object ID is requested (`/me?$select=id`), and a second managed identity carries the app-only rights.

## Prerequisites and required roles

- Modules 02 and 03 deployed (module 04 recommended) with the same private files and Terraform state. Publish the server code
  from this repository version (it contains module 05) **before** module 04 stage 2 locks deployment endpoints.
- Existing test accounts Alice and Bob from module 03 (object IDs only); Eve stays unassigned.
- Terraform 1.16.6+, Azure CLI, PowerShell 7.4+. Region example: `swedencentral`.

**Participant:** Contributor on the workshop resource group, plus permission to create three role assignments scoped to the
`reports` container (for example Role Based Access Control Administrator, constrained to Storage Blob Data Reader and Contributor,
time-bound).

**Identity administrator:** Application Administrator or Cloud Application Administrator (or owner of the workshop application)
to add the federated credential and requested permissions. Granting tenant-wide admin consent for delegated permissions needs
Cloud Application Administrator or Application Administrator. See the [identity request](../../docs/requests/identity-request.md).

## Steps

### PowerShell

Run from the repository root. Steps 2 to 5 change Azure or Microsoft Entra: do them only after approval of the plan.

**1. Offline checks (no Azure).**

```powershell
& .\modules\05-delegated-and-app-only\validate.ps1 -Offline
```

**2. Private workload opt-in file (ignored by Git).** Take Alice's and Bob's object IDs from the identity administrator
(`infra/entra` output `workload_module05_tfvars`).

```powershell
@{ enable_delegated_access = $true; delegated_persona_object_ids = @{ alice = '<alice-object-id>'; bob = '<bob-object-id>' } } |
    ConvertTo-Json | Set-Content -LiteralPath .\.workshop\module05.tfvars.json
```

**3. Workload apply.** Select your approved context first (`& .\scripts\select-azure-context.ps1`). Pass every var file you used
before, plus module 05 (drop `module04.tfvars.json` if you skipped module 04).

```powershell
$vars = '-var-file=..\..\.workshop\participant.tfvars.json', '-var-file=..\..\.workshop\module02.tfvars.json',
        '-var-file=..\..\.workshop\module03.tfvars.json', '-var-file=..\..\.workshop\module04.tfvars.json',
        '-var-file=..\..\.workshop\module05.tfvars.json'
terraform '-chdir=infra\workload' plan @vars '-out=..\..\.workshop\module05.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
# Review: 2 identities, 1 container, 3 role assignments on that container, and an in-place Function App update. After approval:
terraform '-chdir=infra\workload' apply '..\..\.workshop\module05.tfplan'
terraform '-chdir=infra\workload' output -json entra_module05_tfvars   # send this to the identity administrator
```

Until step 4 is done, `whoami` and `read_report_as_user` fail closed (tool error): the API does not trust the identity yet.

**4. Identity administrator: federated credential, permissions, consent.** In the administrator's own terminal and state:

```powershell
@{ enable_delegated_access = $true; obo_identity_principal_id = '<principal-id-from-step-3>'; grant_downstream_admin_consent = $true } |
    ConvertTo-Json | Set-Content -LiteralPath .\.workshop\entra-module05.tfvars.json
terraform '-chdir=infra\entra' plan '-var-file=..\..\.workshop\entra.tfvars.json' '-var-file=..\..\.workshop\entra-module05.tfvars.json' '-out=..\..\.workshop\entra05.tfplan'
# Review: 2 API access entries, 1 federated credential, 2 consent grants. After approval:
terraform '-chdir=infra\entra' apply '..\..\.workshop\entra05.tfplan'
```

**5. Publish the synthetic report** (Microsoft Entra authentication, no key; retries while the role propagates):

```powershell
& .\modules\05-delegated-and-app-only\publish-report.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

**6. Try it in VS Code.** With the module 04 `workshop-governed` server, ask Copilot as Alice: "Who am I?" and "Read the
monthly-usage report as me, then as the app". Repeat as Bob in another VS Code profile.

**7. Operator checks, then persona checks.**

```powershell
& .\modules\05-delegated-and-app-only\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
foreach ($persona in 'Alice', 'Bob') {
    $env:AZURE_CONFIG_DIR = Join-Path $PWD ".workshop\az-$($persona.ToLower())"
    az login --tenant $env:ARM_TENANT_ID --allow-no-subscriptions   # sign in as $persona in the browser
    & .\modules\05-delegated-and-app-only\validate.ps1 -TenantId $env:ARM_TENANT_ID -Persona $persona
    az logout
}
Remove-Item Env:\AZURE_CONFIG_DIR
```

### Bash

```bash
bash ./modules/05-delegated-and-app-only/validate.sh -Offline
printf '%s\n' '{"enable_delegated_access": true, "delegated_persona_object_ids": {"alice": "<alice-object-id>", "bob": "<bob-object-id>"}}' > .workshop/module05.tfvars.json
source ./scripts/select-azure-context.sh
vars="-var-file=../../.workshop/participant.tfvars.json -var-file=../../.workshop/module02.tfvars.json -var-file=../../.workshop/module03.tfvars.json -var-file=../../.workshop/module04.tfvars.json -var-file=../../.workshop/module05.tfvars.json"
terraform -chdir=infra/workload plan $vars -out=../../.workshop/module05.tfplan      # review, approve
terraform -chdir=infra/workload apply ../../.workshop/module05.tfplan
terraform -chdir=infra/workload output -json entra_module05_tfvars                    # to the identity administrator
# identity administrator, own terminal and state:
printf '%s\n' '{"enable_delegated_access": true, "obo_identity_principal_id": "<principal-id>", "grant_downstream_admin_consent": true}' > .workshop/entra-module05.tfvars.json
terraform -chdir=infra/entra plan -var-file=../../.workshop/entra.tfvars.json -var-file=../../.workshop/entra-module05.tfvars.json -out=../../.workshop/entra05.tfplan
terraform -chdir=infra/entra apply ../../.workshop/entra05.tfplan
# participant again:
bash ./modules/05-delegated-and-app-only/publish-report.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
bash ./modules/05-delegated-and-app-only/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
for persona in Alice Bob; do
  export AZURE_CONFIG_DIR="$PWD/.workshop/az-${persona,,}"
  az login --tenant "$ARM_TENANT_ID" --allow-no-subscriptions
  bash ./modules/05-delegated-and-app-only/validate.sh -TenantId "$ARM_TENANT_ID" -Persona "$persona"
  az logout
done
unset AZURE_CONFIG_DIR
```

## What you should see

Same question, two personas. Outer HTTP status first, then the MCP tool result
([synthetic examples](synthetic-data/expected-tool-results.json)).

| Persona | Tool | Outer HTTP | Tool result | Why |
|---|---|---|---|---|
| Alice | `whoami` | HTTP 200 | `isError: false`, `persona: "alice"` | OBO token for Graph `User.Read`; only the object ID is read and mapped to a label |
| Bob | `whoami` | HTTP 200 | `isError: false`, `persona: "bob"` | Same flow, Bob's own token |
| Alice | `read_report_as_user` | HTTP 200 | `isError: false`, the two synthetic rows | OBO token for Storage; Alice holds Storage Blob Data Reader on `reports` |
| Bob | `read_report_as_user` | **HTTP 200** | **`isError: true`** | OBO token for Storage; Bob has no role, Storage answers **HTTP 403** downstream |
| Alice | `read_report_as_app` | HTTP 200 | `isError: false`, the two synthetic rows | The `-report` managed identity reads the container |
| Bob | `read_report_as_app` | HTTP 200 | `isError: false`, **identical** rows | Same identity, same rights: the caller does not matter |
| Any app-only caller | `whoami` / `read_report_as_user` | HTTP 200 (or 403 at the gateway) | `isError: true` | OBO works for users only; refused before any downstream call |

Server logs show one line per call with the tool name, the caller object ID, the outcome (`success`, `denied-downstream:403`,
`rejected-caller`), the latency and the invocation ID. Never the arguments, the report, a name or a token.

## Validate

`validate.ps1` (or `validate.sh`) always runs the offline checks first: On-Behalf-Of with a managed-identity assertion and one
token per downstream resource; app-only callers refused; no developer-credential fallback and no token parsing in the server; the
Entra federated credential and exact delegated scopes with opt-in consent and no password; every module 05 role on the one report
container, none for the OBO identity or Bob; synthetic data only; no secret pattern; unit tests; Terraform format, schema and
mock tests for both roots.

Offline output (this result is **not** deployment evidence):

```text
PASS server: On-Behalf-Of with a managed-identity assertion, one token per downstream (Graph User.Read, Storage user_impersonation), app-only identity for read_report_as_app, app-only callers refused, no developer-credential fallback, no token parsing (expected HTTP N/A).
PASS infra/entra: federated credential (tenant v2.0 issuer, managed identity principal ID subject, api://AzureADTokenExchange), delegated Graph User.Read + Storage user_impersonation only, admin consent opt-in, no password or certificate (expected HTTP N/A).
PASS infra/workload: separate OBO assertion and app-only identities, every module 05 role on the one report container, no role for the OBO or host identity, Bob none, opt-in only (expected HTTP N/A).
PASS synthetic report and expected results are labelled synthetic and contain no address, ID or token (2 files, expected HTTP N/A).
PASS no client secret, key, SAS or token in module 05, server, infra/entra or infra/workload files (46 files, expected HTTP N/A).
PASS locked build and unit tests: Alice reads, Bob denied downstream, app-only identical for everyone, app-only callers refused, Graph gets only its own token (expected HTTP N/A).
PASS Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).
PASS offline checks only. Module 05 is NOT deployed or validated by this result.
```

Live modes, after an approved deployment:

- **Operator** (`-TenantId -SubscriptionId`): the Function settings name both identities and hold no secret setting; the MCP API
  registration has **no password credential** and exactly one federated credential trusting the OBO identity; the `reports`
  container has Storage Blob Data Reader for the app-only identity and Alice only, nothing for the OBO identity or Bob.
- **Persona** (`-TenantId -Persona Alice|Bob`): `whoami` returns the persona label and no name or email; Alice's
  `read_report_as_user` returns the report (HTTP 200, `isError: false`); Bob's returns **HTTP 200 with `isError: true`**;
  `read_report_as_app` returns the same synthetic rows for both (the second run compares a hash saved by the first, in `.workshop/`).

The module is `validated` only when all of these pass on a fresh subscription right after modules 00 to 04.

## Troubleshooting

| Symptom | Check |
|---|---|
| `whoami` / `read_report_as_user` give `isError: true` for Alice too | Step 4 not done (no federated credential or consent), or the subject is not the `-obo` identity's **principal** ID. Wrong issuer, subject or audience is accepted at creation and fails only at token exchange. |
| Same, and the server log outcome is `failed:AuthenticationFailedException` | The token exchange failed. Check, in order: the federated credential values, admin consent (`grant_downstream_admin_consent = true` or the portal), and that the `-obo` identity is attached to the Function. The server never logs the Entra error text. |
| Alice gets `isError: true` on `read_report_as_user` only | Her Storage role is still propagating (a few minutes), or `delegated_persona_object_ids.alice` is wrong. |
| `read_report_as_app` gives `isError: true` | Report not published (run step 5), or the `-report` identity's role is still propagating. |
| `publish-report.ps1` keeps failing | You need Storage Blob Data Contributor on `reports`; set `delegated_report_publisher_object_id` if Terraform ran as someone else. |
| `Invalid index` on `oauth2_permission_scope_ids` in `infra/entra` | The Azure Storage service principal is missing in the tenant; an administrator creates it (`az ad sp create --id e406a681-f3d4-42a8-90b6-c2b029497af1`). |
| Tools still return "demonstration" results | The deployed code predates module 05, or `WORKSHOP_DELEGATED_ACCESS` is not `enabled`. Publish the code (before module 04 stage 2). |
| Gateway HTTP 403 for every call | That is module 04 (role or scope). A downstream refusal is never an outer HTTP 403. |

## Clean up

The script plans first, refuses any change outside module 05, and is idempotent; run once to review, then with `-Apply`. Not run
by the author: no deployment exists.

```powershell
# Participant: identities, container (and the report), role assignments, settings
& .\modules\05-delegated-and-app-only\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
& .\modules\05-delegated-and-app-only\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
Remove-Item -LiteralPath .\.workshop\module05.tfvars.json, .\.workshop\module05-as-app-*.sha256 -ErrorAction SilentlyContinue
# Identity administrator: federated credential, requested permissions, consent grants
& .\modules\05-delegated-and-app-only\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -Scope Entra -Apply
Remove-Item -LiteralPath .\.workshop\entra-module05.tfvars.json -ErrorAction SilentlyContinue
```

```bash
bash ./modules/05-delegated-and-app-only/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -Apply
bash ./modules/05-delegated-and-app-only/cleanup.sh -TenantId "$ARM_TENANT_ID" -Scope Entra -Apply
rm -f .workshop/module05.tfvars.json .workshop/module05-as-app-*.sha256 .workshop/entra-module05.tfvars.json
```

Run the Entra clean-up **before** module 03's Entra clean-up, which accepts only module 03 objects. Modules 02 to 04 stay. If
you continue to module 06 now, keep everything.

## Go further

- Read [DelegatedTools.cs](../../src/FunctionsMcpServer/Logic/DelegatedTools.cs): where is the per-tool choice of identity made,
  and why can it never change at run time?
- Why does the OBO identity have no Azure role, and what would go wrong if `read_report_as_app` used it?
- Give Bob Storage Blob Data Reader on `reports` for a few minutes: which result changes, and which never does?
- Microsoft.Identity.Web offers the same secretless pattern for ASP.NET Core APIs (`SignedAssertionFromManagedIdentity`); this
  module uses Azure.Identity because built-in authentication already validates the token.

## Sources

- [Microsoft identity platform and OAuth 2.0 On-Behalf-Of flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow)
- [Configure an application to trust a managed identity](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity)
- [Certificateless authentication with Microsoft.Identity.Web](https://learn.microsoft.com/entra/msidweb/authentication/certificateless)
- [Grant tenant-wide admin consent to an application](https://learn.microsoft.com/entra/identity/enterprise-apps/grant-admin-consent)
- [Authorize access to blobs with Microsoft Entra ID](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory) and
  [assign an Azure role for blob data access](https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access)
- [Microsoft Graph user: get (`/me`, `User.Read`)](https://learn.microsoft.com/graph/api/user-get)
- [Work with user identities in App Service authentication (`X-MS-CLIENT-PRINCIPAL`)](https://learn.microsoft.com/azure/app-service/configure-authentication-user-identities)
- [Pinned sample `HelloToolWithAuth.cs`](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/blob/468c518c884ec318e3001b9573254c9e775409c9/src/FunctionsMcpTool/HelloToolWithAuth.cs)
  and [`infra/app/entra.bicep`](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/blob/468c518c884ec318e3001b9573254c9e775409c9/infra/app/entra.bicep) (MIT)
- [Azure Functions MCP extension 1.5.0 (`HttpTransport` headers)](https://github.com/Azure/azure-functions-mcp-extension/tree/worker-1.5.0) and
  [MCP C# SDK tool errors (`isError`)](https://github.com/modelcontextprotocol/csharp-sdk)
- [AzureAD 3.10.0](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0/docs) (`azuread_application_api_access`,
  `azuread_application_federated_identity_credential`, `azuread_service_principal_delegated_permission_grant`) and
  [AzureRM 5.9.0](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs)

Last verified: 2026-10-15. Authored and checked offline only; not yet deployed or validated in Azure.
