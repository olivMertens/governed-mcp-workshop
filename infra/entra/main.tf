# Module 03 - Microsoft Entra identity for the workshop MCP server (level 1).
# Run once by an identity administrator. Creates only workshop-owned objects, or reads an administrator-provided
# application without managing it. Never creates users, passwords, client secrets or certificates.
# Shape adapted from Azure-Samples/remote-mcp-functions-dotnet at commit 468c518c884ec318e3001b9573254c9e775409c9
# (infra/app/entra.bicep), MIT License, Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md.
# Workshop changes: Terraform instead of Bicep, app roles and assignment required, Application ID URI api://<client-id>,
# no redirect URI, no Microsoft Graph permission (module 05), no federated credential yet (module 05).

data "azuread_client_config" "current" {}

locals {
  stem    = "mcp-${var.participant_prefix}-${var.resource_suffix}"
  managed = var.create_application

  # Deterministic, stable IDs: same inputs always produce the same scope and role IDs.
  id_namespace = "https://workshop.invalid/governed-mcp/${local.stem}"
  scope_id     = uuidv5("url", "${local.id_namespace}/scope/user_impersonation")
  roles = {
    "Tools.Read" = {
      id           = uuidv5("url", "${local.id_namespace}/role/Tools.Read")
      member_types = ["User"]
      display_name = "Read workshop tools"
      description  = "Call read-only workshop MCP tools."
    }
    "Tools.Write" = {
      id           = uuidv5("url", "${local.id_namespace}/role/Tools.Write")
      member_types = ["User"]
      display_name = "Write with workshop tools"
      description  = "Call workshop MCP tools that change synthetic data, such as create_ticket."
    }
    "Tools.Execute.All" = {
      id           = uuidv5("url", "${local.id_namespace}/role/Tools.Execute.All")
      member_types = ["Application"]
      display_name = "Execute workshop tools as an application"
      description  = "App-only access for a separately approved client. Not assigned by this module."
    }
  }

  tags = ["workshop:${local.stem}", "owner:${var.owner}", "expiry:${var.expiry}"]

  application_client_id = local.managed ? azuread_application.mcp[0].client_id : data.azuread_application.existing[0].client_id
  application_object_id = local.managed ? azuread_application.mcp[0].object_id : data.azuread_application.existing[0].object_id
  identifier_uri = local.managed ? azuread_application_identifier_uri.mcp[0].identifier_uri : try(
    [for uri in data.azuread_application.existing[0].identifier_uris : uri if startswith(uri, "api://")][0], null
  )
  app_role_ids              = local.managed ? { for name, role in local.roles : name => role.id } : data.azuread_application.existing[0].app_role_ids
  scope_ids                 = local.managed ? { user_impersonation = local.scope_id } : data.azuread_application.existing[0].oauth2_permission_scope_ids
  service_principal_id      = local.managed ? azuread_service_principal.mcp[0].object_id : data.azuread_service_principal.existing[0].object_id
  assignment_required       = local.managed ? azuread_service_principal.mcp[0].app_role_assignment_required : data.azuread_service_principal.existing[0].app_role_assignment_required
  user_impersonation_scope  = local.identifier_uri == null ? null : "${local.identifier_uri}/user_impersonation"
  federated_issuer          = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
  federated_token_audience  = "api://AzureADTokenExchange"
  persona_assignment_inputs = { for name, id in { alice = var.test_user_object_ids.alice, bob = var.test_user_object_ids.bob } : name => id if id != null }
  assignments = merge(
    contains(keys(local.persona_assignment_inputs), "alice") ? {
      "alice-read"  = { principal = local.persona_assignment_inputs.alice, role = "Tools.Read" }
      "alice-write" = { principal = local.persona_assignment_inputs.alice, role = "Tools.Write" }
    } : {},
    contains(keys(local.persona_assignment_inputs), "bob") ? {
      "bob-read" = { principal = local.persona_assignment_inputs.bob, role = "Tools.Read" }
    } : {},
  )
}

# ------------------------------------------------------------------ created path (create_application = true)

resource "azuread_application" "mcp" {
  count                        = local.managed ? 1 : 0
  display_name                 = "Workshop MCP API (${local.stem})"
  description                  = "Governed MCP workshop, level 1. Synthetic data only. Owner ${var.owner}, expires ${var.expiry}."
  sign_in_audience             = "AzureADMyOrg"
  owners                       = [data.azuread_client_config.current.object_id]
  prevent_duplicate_names      = true
  tags                         = local.tags
  notes                        = "Created by infra/entra for workshop ${local.stem}. Delete with modules/03-entra-authentication/cleanup.ps1."
  service_management_reference = var.service_management_reference

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      id                         = local.scope_id
      value                      = "user_impersonation"
      type                       = "User"
      enabled                    = true
      admin_consent_display_name = "Access the workshop MCP server"
      admin_consent_description  = "Allow the client application to call the workshop MCP server for the signed-in user."
      user_consent_display_name  = "Access the workshop MCP server"
      user_consent_description   = "Allow the client application to call the workshop MCP server for you."
    }
  }

  dynamic "app_role" {
    for_each = local.roles
    content {
      id                   = app_role.value.id
      value                = app_role.key
      allowed_member_types = app_role.value.member_types
      display_name         = app_role.value.display_name
      description          = app_role.value.description
      enabled              = true
    }
  }

  # The Application ID URI is managed by azuread_application_identifier_uri below (api://<client-id>).
  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_application_identifier_uri" "mcp" {
  count          = local.managed ? 1 : 0
  application_id = azuread_application.mcp[0].id
  identifier_uri = "api://${azuread_application.mcp[0].client_id}"
}

resource "azuread_service_principal" "mcp" {
  count                        = local.managed ? 1 : 0
  client_id                    = azuread_application.mcp[0].client_id
  app_role_assignment_required = true
  owners                       = [data.azuread_client_config.current.object_id]
  notes                        = "Assignment required: only Alice (Tools.Read, Tools.Write) and Bob (Tools.Read) are assigned. Eve is refused."
}

resource "azuread_application_pre_authorized" "clients" {
  for_each             = local.managed ? toset(var.pre_authorized_client_ids) : toset([])
  application_id       = azuread_application.mcp[0].id
  authorized_client_id = each.value
  permission_ids       = [local.scope_id]
}

# ------------------------------------------------------------------ existing path (create_application = false)

data "azuread_application" "existing" {
  count     = local.managed ? 0 : 1
  client_id = var.existing_application_client_id
}

data "azuread_service_principal" "existing" {
  count     = local.managed ? 0 : 1
  client_id = var.existing_application_client_id
}

# ------------------------------------------------------------------ persona assignments (existing users only)

resource "azuread_app_role_assignment" "personas" {
  for_each            = local.assignments
  app_role_id         = local.app_role_ids[each.value.role]
  principal_object_id = each.value.principal
  resource_object_id  = local.service_principal_id
}
