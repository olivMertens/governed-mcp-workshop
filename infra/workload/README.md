# Workload foundation

This root currently manages only one dedicated workshop resource group, or reads an approved existing group.
It does not deploy an MCP server. Planned service names are outputs for later modules, not created resources.

Start with [workspace preparation](../../docs/GETTING-STARTED.md), or [the French guide](../../docs/fr/GETTING-STARTED.md).
Both workstation routes use this root and the same private `.workshop/participant.tfvars.json`.
Keep one private state per participant. Do not share state or generate new names on every module.

New-group mode requires approved group-creation authority at subscription scope.
Existing-group mode uses only a data source and does not manage the group or its tags.
Future child-resource creation and role assignments need their own scoped permissions.
No automatic resource-provider registration is enabled.

Only after context, plan and cost approval:

```powershell
terraform -chdir=infra/workload init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform -chdir=infra/workload plan -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/workload.tfplan
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
```

The equivalent bash commands use `&&` between init and plan.
Review the saved plan privately. Apply it only with separate explicit approval.
When the foundation is the only deployed content, prepare a destroy plan with the same var-file and state:

```powershell
terraform -chdir=infra/workload plan -destroy -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/destroy.tfplan
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

## Sources

- [Azure naming rules](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules).
- [AzureRM group](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group).
- [Terraform mocks](https://developer.hashicorp.com/terraform/language/tests/mocking).

Last verified: 2026-10-14. Mock tests do not establish Azure deployment compatibility.
