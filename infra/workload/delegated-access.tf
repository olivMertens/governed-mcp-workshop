# Module 05 - who carries the rights? On-Behalf-Of (OBO) vs app-only (level 3). Opt-in with enable_delegated_access = true.
# Pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit 468c518c884ec318e3001b9573254c9e775409c9
# (infra/app/api.bicep: user-assigned identity and OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID), MIT License,
# Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md.
# Workshop changes: Terraform, TWO new user-assigned identities instead of reusing the host identity, a report container,
# container-scoped Storage Blob Data Reader roles, explicit WORKSHOP_* settings. No client secret, key or SAS anywhere.
#
# Why two new identities (and never the module 02 host identity):
#   - id-<stem>-obo: trusted by the MCP API's federated identity credential. Its only use is the OBO client assertion.
#     It holds NO Azure role: a user-context call can only use the user's delegated rights.
#   - id-<stem>-report: the app-only identity of read_report_as_app. Storage Blob Data Reader on the one report container.
#   - the module 02 host identity keeps Blob Data Owner on the whole account for the Functions host; no tool uses it for reports.
# Mixing them would let the app-only rights or the host's account-wide rights leak into a user-context tool.

locals {
  delegated_enabled        = local.mcp_auth_enabled && var.enable_delegated_access
  delegated_container      = "reports"
  delegated_report_blob    = "monthly-usage.json"
  delegated_personas       = { for name, id in var.delegated_persona_object_ids : name => id if id != null }
  delegated_publisher      = var.delegated_report_publisher_object_id != null ? var.delegated_report_publisher_object_id : try(data.azurerm_client_config.delegated[0].object_id, null)
  delegated_identity_ids   = local.delegated_enabled ? [azurerm_user_assigned_identity.delegated_obo[0].id, azurerm_user_assigned_identity.delegated_report[0].id] : []
  delegated_container_url  = local.delegated_enabled ? "${azurerm_storage_account.mcp[0].primary_blob_endpoint}${local.delegated_container}" : null
  delegated_reader_persona = contains(keys(local.delegated_personas), "alice") ? { alice = local.delegated_personas.alice } : {}

  # Non-secret settings read by DelegatedAccessSettings. Absent when module 05 is off, so the server keeps module 02 behaviour.
  delegated_app_settings = local.delegated_enabled ? {
    WORKSHOP_DELEGATED_ACCESS          = "enabled"
    WORKSHOP_TENANT_ID                 = var.entra_tenant_id
    WORKSHOP_MCP_API_CLIENT_ID         = var.mcp_api_client_id
    WORKSHOP_OBO_ASSERTION_CLIENT_ID   = azurerm_user_assigned_identity.delegated_obo[0].client_id
    WORKSHOP_REPORT_IDENTITY_CLIENT_ID = azurerm_user_assigned_identity.delegated_report[0].client_id
    WORKSHOP_REPORT_CONTAINER_URL      = local.delegated_container_url
    WORKSHOP_PERSONA_OBJECT_IDS        = jsonencode(local.delegated_personas)
  } : {}
}

data "azurerm_client_config" "delegated" {
  count = local.delegated_enabled && var.delegated_report_publisher_object_id == null ? 1 : 0
}

resource "azurerm_user_assigned_identity" "delegated_obo" {
  count               = local.delegated_enabled ? 1 : 0
  name                = local.names.obo_identity
  resource_group_name = local.workload_group
  location            = local.workload_location
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "delegated_report" {
  count               = local.delegated_enabled ? 1 : 0
  name                = local.names.report_identity
  resource_group_name = local.workload_group
  location            = local.workload_location
  tags                = local.tags
}

resource "azurerm_storage_container" "reports" {
  count                 = local.delegated_enabled ? 1 : 0
  name                  = local.delegated_container
  storage_account_id    = azurerm_storage_account.mcp[0].id
  container_access_type = "private"
  metadata              = { workshop = "module05", content = "synthetic" }
}

# Least privilege: every module 05 role is scoped to the one report container, never the account or the group.
resource "azurerm_role_assignment" "report_app_reader" {
  count                            = local.delegated_enabled ? 1 : 0
  scope                            = azurerm_storage_container.reports[0].id
  role_definition_name             = "Storage Blob Data Reader"
  principal_id                     = azurerm_user_assigned_identity.delegated_report[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Workshop module 05: read_report_as_app reads the synthetic report container only."
}

# Alice's own data role. Bob deliberately gets none, so read_report_as_user returns a downstream 403 for him.
resource "azurerm_role_assignment" "report_persona_reader" {
  for_each             = local.delegated_enabled ? local.delegated_reader_persona : {}
  scope                = azurerm_storage_container.reports[0].id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value
  principal_type       = "User"
  description          = "Workshop module 05: persona ${each.key} may read the synthetic report container with her own identity (On-Behalf-Of)."
}

# The participant who publishes the synthetic report blob (Storage shared keys are disabled, so upload uses Entra ID).
resource "azurerm_role_assignment" "report_publisher" {
  count                = local.delegated_enabled && local.delegated_publisher != null ? 1 : 0
  scope                = azurerm_storage_container.reports[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.delegated_publisher
  description          = "Workshop module 05: publish the synthetic report blob to this one container. Removed by module 05 clean-up."
}

output "delegated_access_enabled" {
  description = "True when module 05 On-Behalf-Of and app-only tools are deployed."
  value       = local.delegated_enabled
}

output "delegated_obo_identity_principal_id" {
  description = "Principal ID of the OBO assertion identity: the federated identity credential subject for infra/entra (obo_identity_principal_id). Not secret."
  value       = local.delegated_enabled ? azurerm_user_assigned_identity.delegated_obo[0].principal_id : null
}

output "delegated_report_container_url" {
  description = "Synthetic report container. Readable by the app-only identity and Alice only. Null when module 05 is off."
  value       = local.delegated_container_url
}

output "delegated_report_blob_name" {
  description = "Blob name of the synthetic monthly-usage report."
  value       = local.delegated_enabled ? local.delegated_report_blob : null
}

output "delegated_storage_account_name" {
  description = "Storage account that holds the report container (Entra ID data access only)."
  value       = local.delegated_enabled ? azurerm_storage_account.mcp[0].name : null
}

output "entra_module05_tfvars" {
  description = "Non-secret values for the identity administrator's infra/entra rerun (module 05). Consent stays the administrator's decision."
  value = local.delegated_enabled ? {
    enable_delegated_access   = true
    obo_identity_principal_id = azurerm_user_assigned_identity.delegated_obo[0].principal_id
  } : null
}
