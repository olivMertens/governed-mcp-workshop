# Module 05 - On-Behalf-Of (OBO) for the workshop MCP API (level 3). Opt-in; nothing here exists unless enabled.
# Run by the identity administrator AFTER the workload created the OBO assertion identity (enable_delegated_access in
# infra/workload outputs its principal ID). Created path only: an administrator-provided application (create_application
# = false) is never changed; the administrator applies the same settings by hand (see docs/requests/identity-request.md).
# Pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit 468c518c884ec318e3001b9573254c9e775409c9
# (infra/app/entra.bicep: requiredResourceAccess User.Read, federatedIdentityCredentials), MIT License,
# Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md.
# Workshop changes: Terraform, Azure Storage user_impersonation added, scope IDs read from the tenant's service principals
# instead of hard-coded GUIDs, consent is a separate explicit opt-in, no client secret or redirect URI.

locals {
  delegation_enabled = var.enable_delegated_access
  delegation_managed = local.delegation_enabled && local.managed

  # Well-known first-party application (client) IDs.
  graph_client_id   = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
  storage_client_id = "e406a681-f3d4-42a8-90b6-c2b029497af1" # Azure Storage

  downstream = {
    graph   = { client_id = local.graph_client_id, scope = "User.Read" }
    storage = { client_id = local.storage_client_id, scope = "user_impersonation" }
  }
}

# The tenant's own service principals publish the delegated scope IDs: no GUID is guessed or hard-coded.
data "azuread_service_principal" "downstream" {
  for_each  = local.delegation_enabled ? local.downstream : {}
  client_id = each.value.client_id
}

# Delegated permissions requested by the MCP API: Microsoft Graph User.Read and Azure Storage user_impersonation.
resource "azuread_application_api_access" "downstream" {
  for_each       = local.delegation_managed ? local.downstream : {}
  application_id = azuread_application.mcp[0].id
  api_client_id  = each.value.client_id
  scope_ids      = [data.azuread_service_principal.downstream[each.key].oauth2_permission_scope_ids[each.value.scope]]
}

# Secretless client credential: the MCP API trusts tokens of ONE user-assigned managed identity (the workload's OBO
# assertion identity). Learn: issuer = tenant v2.0 authority, subject = the identity's principal (object) ID,
# audience = api://AzureADTokenExchange. Wrong values are accepted at creation and only fail at token exchange.
resource "azuread_application_federated_identity_credential" "obo" {
  count          = local.delegation_managed && var.obo_identity_principal_id != null ? 1 : 0
  application_id = azuread_application.mcp[0].id
  display_name   = "workshop-obo-${var.participant_prefix}"
  description    = "Workshop module 05: the Function's OBO assertion managed identity proves this API's identity. No client secret."
  audiences      = [local.federated_token_audience]
  issuer         = local.federated_issuer
  subject        = var.obo_identity_principal_id
}

# Tenant-wide (AllPrincipals) admin consent for exactly the two delegated scopes. Separate opt-in: the administrator decides.
# Learn (grant-admin-consent): Cloud Application Administrator or Application Administrator can grant delegated
# permissions; Privileged Role Administrator is only needed for application permissions (app roles) of Microsoft Graph.
resource "azuread_service_principal_delegated_permission_grant" "downstream" {
  for_each                             = local.delegation_managed && var.grant_downstream_admin_consent ? local.downstream : {}
  service_principal_object_id          = azuread_service_principal.mcp[0].object_id
  resource_service_principal_object_id = data.azuread_service_principal.downstream[each.key].object_id
  claim_values                         = [each.value.scope]
}

output "module05_delegation" {
  description = "Module 05 On-Behalf-Of configuration. managed = false means the administrator applies it by hand to the existing application."
  value = {
    enabled                 = local.delegation_enabled
    managed                 = local.delegation_managed
    requested_scopes        = local.delegation_enabled ? { for key, value in local.downstream : key => value.scope } : {}
    federated_credential    = length(azuread_application_federated_identity_credential.obo) == 1
    admin_consent_requested = length(azuread_service_principal_delegated_permission_grant.downstream) == 2
  }
}

output "workload_module05_tfvars" {
  description = "Non-secret values to save as .workshop/module05.tfvars.json for infra/workload (module 05 opt-in). Object IDs only."
  value = {
    enable_delegated_access = true
    delegated_persona_object_ids = {
      alice = var.test_user_object_ids.alice
      bob   = var.test_user_object_ids.bob
    }
  }
}
