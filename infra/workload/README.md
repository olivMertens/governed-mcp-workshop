# Workload foundation

By default this root manages one dedicated workshop resource group, or reads an approved existing group.
An explicit persistent opt-in adds a public Linux App Service B1 portal; see [hosting](../../docs/HOSTING.md).
It does not deploy an MCP server. Planned MCP service names are outputs for later modules, not created resources.
Terraform requires 1.16.6+ below 2; AzureRM is locked to 5.9.0.

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
Eleven runs cover new/existing groups, legacy compatibility, 64-bit names at minimum/maximum prefix lengths,
shared-group isolation, invalid names, default-off hosting and the opt-in TLS/runtime settings.
Module 00's [offline validator](../../modules/00-prerequisites/README.md#validate) also covers local HTTP,
bundle integrity, private-file exclusion, and synthetic preflight/deployment failures.

## Sources

- [Azure naming rules](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules).
- [AzureRM group](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group).
- [Linux web app](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/linux_web_app).
- [App Service secretless deployment](https://learn.microsoft.com/azure/app-service/deploy-authentication-types).
- [Terraform mocks](https://developer.hashicorp.com/terraform/language/tests/mocking).

Last verified: 2026-10-14. Mock tests do not establish Azure deployment compatibility.
