# Workload foundation

By default this root manages one dedicated workshop resource group, or reads an approved existing group.
An explicit persistent opt-in adds a public Linux App Service B1 portal; see [hosting](../../docs/HOSTING.md).
An explicit module 02 opt-in (`enable_mcp_server = true`, default false) adds the level 0 MCP server:
Flex Consumption Function App, Storage with shared keys disabled, a `tickets` queue, Log Analytics,
Application Insights and one user-assigned managed identity with three resource-scoped role assignments
(see [module 02](../../modules/02-open-server/README.md) and `mcp-server.tf`). Without the opt-in, nothing changes.
An explicit module 03 opt-in (`enable_entra_auth = true` plus the IDs from `infra/entra`, default false) adds Microsoft Entra
built-in authentication to that Function App (`entra-auth.tf`): require authentication, HTTP 401, tenant issuer, MCP audience
only, allowed clients and Protected Resource Metadata (**Preview**). A second apply with `entra_auth_replace_key_gate = true`
then drops the system key; see [module 03](../../modules/03-entra-authentication/README.md).
An explicit module 04 opt-in (`enable_governed_gateway = true`, default false, requires both module 03 stages) adds API Management
Standard v2 as the only MCP entry point (`gateway.tf`, `network.tf`, `diagnostics.tf`): outbound virtual network integration,
a Function private endpoint with `privatelink.azurewebsites.net`, the MCP server API through AzAPI `2025-09-01-preview` (**Preview**),
policies from `modules/04-governed-gateway/policies` and zero-body-byte diagnostics. A second apply with `gateway_lock_function = true`
disables public access on the Function; see [module 04](../../modules/04-governed-gateway/README.md).
Terraform requires 1.16.6+ below 2; AzureRM is locked to 5.9.0 and AzAPI to 2.13.0 (module 04 only).

Start with [workspace preparation](../../docs/GETTING-STARTED.md), or [the French guide](../../docs/fr/GETTING-STARTED.md).
Both workstation routes use this root and the same private `.workshop/participant.tfvars.json`.
Keep one private state per participant. Do not share state or generate new names on every module.
Fresh preparations use a saved 64-bit cryptographic suffix, even when participant labels are identical.
Storage and Function names shorten only the human prefix to six characters, keeping all random bits
within the Storage 24-character and Functions host-ID 32-character limits.
Legacy 10-character suffixes keep every original name. See the start guide's naming table.
Restore missing private parameters rather than generating replacements for an existing deployment.

New-group mode requires approved group-creation authority at subscription scope.
Existing-group mode uses only a data source and does not manage the group or its tags.
Future child-resource creation and role assignments need their own scoped permissions.
No automatic resource-provider registration is enabled.

Only after context, plan and cost approval:

```powershell
terraform -chdir=infra/workload init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\workload.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
```

The equivalent bash commands use `&&` between init and plan.
Review the saved plan privately. Apply it only with separate explicit approval.
When full teardown of this root is intended, prepare a destroy plan with the same var-file and state:

```powershell
terraform '-chdir=infra\workload' plan -destroy '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\destroy.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform destroy plan failed.' }
```

After explicit deletion approval, applying that reviewed saved plan removes only managed objects.
The provider refuses to delete a nonempty managed group. Never disable this protection to bypass cleanup.
Existing groups are data sources, not destroy targets. Preserve their unrelated contents and identities.
An expiry tag does not schedule deletion. Full module 99 cleanup is still pending.

Offline checks after provider initialization:

```powershell
terraform -chdir=infra/workload fmt -check -recursive
terraform -chdir=infra/workload validate
terraform -chdir=infra/workload test
```

The tests use a mock Azure provider and plan-only runs. They create no Azure resources.
Eleven foundation runs cover new/existing groups, legacy compatibility, 64-bit names at minimum/maximum prefix lengths,
shared-group isolation, invalid names, default-off hosting and the opt-in TLS/runtime settings.
Seven module 02 runs (`tests/mcp_server.tftest.hcl`) cover default-off, identity-only storage, no key or SAS in app settings,
exact role scopes, the optional IPv4 allow-list, existing groups and rejected open/malformed ranges or unbounded scale.
Eight module 03 runs (`tests/entra_auth.tftest.hcl`) cover default-off (module 02 unchanged), enforced authentication with
one audience and allowed clients, no secret setting or token store, the two-stage key gate, and rejected incomplete or
unsafe inputs.
Ten module 04 runs (`tests/governed_gateway.tftest.hcl`, AzureRM and AzAPI mocks) cover default-off (module 03 unchanged), the
Standard v2 private path, the exact rendered policies (one audience, per-tool roles, per-oid rate limit, gateway PRM, no
subscription key), zero body bytes at both diagnostic scopes, the stage 2 Function lock, the optional IP filter, the portal
advertising only the gateway, and rejected unsafe inputs.
Module 00's [offline validator](../../modules/00-prerequisites/README.md#validate) also covers local HTTP,
bundle integrity, private-file exclusion, and synthetic preflight/deployment failures.

## Sources

- [Azure naming rules](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules).
- [AzureRM group](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group).
- [Linux web app](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/linux_web_app).
- [App Service secretless deployment](https://learn.microsoft.com/azure/app-service/deploy-authentication-types).
- [Terraform mocks](https://developer.hashicorp.com/terraform/language/tests/mocking).
- [AzureRM 5.9.0 Flex Consumption](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/function_app_flex_consumption.html.markdown).
- [Flex Consumption plan](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan).
- [MCP server authorization with built-in authentication](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).
- [Manage API Management MCP servers with Terraform (Preview API)](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api).
- [Standard v2 outbound virtual network integration](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound).

Last verified: 2026-10-15. Mock tests do not establish Azure deployment compatibility.
