# Module 02 - an "open" MCP server (level 0). Opt-in with enable_mcp_server = true.
# Pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
# 468c518c884ec318e3001b9573254c9e775409c9 (infra/main.bicep, infra/app/api.bicep, infra/app/rbac.bicep),
# MIT License, Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md.
# Workshop changes: Terraform instead of Bicep, Entra authentication only via the module 03 opt-in (entra-auth.tf), no account-wide queue role
# (Streamable HTTP only), a queue-scoped sender role for synthetic tickets and an optional IPv4 allow-list.

locals {
  mcp_enabled         = var.enable_mcp_server
  mcp_package_folder  = "app-package"
  mcp_ticket_queue    = "tickets"
  mcp_ip_restrictions = [for index, range in var.mcp_allowed_ip_ranges : { name = "workshop-allow-${index + 1}", range = range, priority = 100 + index }]
}

resource "azurerm_user_assigned_identity" "mcp" {
  count               = local.mcp_enabled ? 1 : 0
  name                = local.names.function_identity
  resource_group_name = local.workload_group
  location            = local.workload_location
  tags                = local.tags
}

resource "azurerm_storage_account" "mcp" {
  count                            = local.mcp_enabled ? 1 : 0
  name                             = local.names.storage
  resource_group_name              = local.workload_group
  location                         = local.workload_location
  account_kind                     = "StorageV2"
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  local_user_enabled               = false
  sftp_enabled                     = false
  public_network_access            = "Enabled"
  tags                             = local.tags
}

resource "azurerm_storage_container" "mcp_package" {
  count                 = local.mcp_enabled ? 1 : 0
  name                  = local.mcp_package_folder
  storage_account_id    = azurerm_storage_account.mcp[0].id
  container_access_type = "private"
}

resource "azurerm_storage_queue" "tickets" {
  count              = local.mcp_enabled ? 1 : 0
  name               = local.mcp_ticket_queue
  storage_account_id = azurerm_storage_account.mcp[0].id
}

resource "azurerm_log_analytics_workspace" "mcp" {
  count                        = local.mcp_enabled ? 1 : 0
  name                         = local.names.log_analytics
  resource_group_name          = local.workload_group
  location                     = local.workload_location
  sku                          = "PerGB2018"
  retention_in_days            = 30
  daily_quota_gb               = 1
  local_authentication_enabled = false
  tags                         = local.tags
}

resource "azurerm_application_insights" "mcp" {
  count                        = local.mcp_enabled ? 1 : 0
  name                         = local.names.application_insights
  resource_group_name          = local.workload_group
  location                     = local.workload_location
  workspace_id                 = azurerm_log_analytics_workspace.mcp[0].id
  application_type             = "web"
  local_authentication_enabled = false
  tags                         = local.tags
}

# Least privilege: three assignments, each scoped to one exact resource.
resource "azurerm_role_assignment" "mcp_host_storage" {
  count                            = local.mcp_enabled ? 1 : 0
  scope                            = azurerm_storage_account.mcp[0].id
  role_definition_name             = "Storage Blob Data Owner"
  principal_id                     = azurerm_user_assigned_identity.mcp[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Workshop module 02: Functions host storage and Flex deployment package (blob only)."
}

resource "azurerm_role_assignment" "mcp_ticket_sender" {
  count                            = local.mcp_enabled ? 1 : 0
  scope                            = azurerm_storage_queue.tickets[0].id
  role_definition_name             = "Storage Queue Data Message Sender"
  principal_id                     = azurerm_user_assigned_identity.mcp[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Workshop module 02: send synthetic tickets to this one queue only."
}

resource "azurerm_role_assignment" "mcp_telemetry" {
  count                            = local.mcp_enabled ? 1 : 0
  scope                            = azurerm_application_insights.mcp[0].id
  role_definition_name             = "Monitoring Metrics Publisher"
  principal_id                     = azurerm_user_assigned_identity.mcp[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Workshop module 02: Entra-authenticated telemetry ingestion."
}

resource "azurerm_service_plan" "mcp" {
  count               = local.mcp_enabled ? 1 : 0
  name                = local.names.function_plan
  resource_group_name = local.workload_group
  location            = local.workload_location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azurerm_function_app_flex_consumption" "mcp" {
  count                                          = local.mcp_enabled ? 1 : 0
  name                                           = local.names.function_app
  resource_group_name                            = local.workload_group
  location                                       = local.workload_location
  service_plan_id                                = azurerm_service_plan.mcp[0].id
  runtime_name                                   = "dotnet-isolated"
  runtime_version                                = "10.0"
  instance_memory_in_mb                          = 2048
  maximum_instance_count                         = var.mcp_maximum_instance_count
  storage_container_type                         = "blobContainer"
  storage_container_endpoint                     = "${azurerm_storage_account.mcp[0].primary_blob_endpoint}${azurerm_storage_container.mcp_package[0].name}"
  storage_authentication_type                    = "UserAssignedIdentity"
  storage_user_assigned_identity_id              = azurerm_user_assigned_identity.mcp[0].id
  https_only                                     = true
  public_network_access_enabled                  = !local.gateway_function_locked # module 04 stage 2: private endpoint only
  webdeploy_publish_basic_authentication_enabled = false
  client_certificate_enabled                     = false
  tags                                           = local.tags

  identity {
    type = "UserAssigned"
    # Module 05 adds its two separate identities (OBO assertion and app-only reader); none when disabled.
    identity_ids = concat([azurerm_user_assigned_identity.mcp[0].id], local.delegated_identity_ids)
  }

  site_config {
    minimum_tls_version                    = "1.2"
    scm_minimum_tls_version                = "1.2"
    http2_enabled                          = true
    application_insights_connection_string = azurerm_application_insights.mcp[0].connection_string
    ip_restriction_default_action          = length(local.mcp_ip_restrictions) == 0 ? "Allow" : "Deny"

    dynamic "ip_restriction" {
      for_each = local.mcp_ip_restrictions
      content {
        name       = ip_restriction.value.name
        ip_address = ip_restriction.value.range
        priority   = ip_restriction.value.priority
        action     = "Allow"
      }
    }
  }

  app_settings = merge({
    # AzureRM 5.9.0 otherwise writes a key-less AzureWebJobsStorage connection string for identity storage.
    # An empty value lets the host use the identity-based AzureWebJobsStorage__* settings below.
    # The provider does not read this key back, so later plans show an in-place app_settings update; expected.
    # Do not add ignore_changes: an update would then restore the key-less connection string.
    AzureWebJobsStorage                       = ""
    AzureWebJobsStorage__credential           = "managedidentity"
    AzureWebJobsStorage__clientId             = azurerm_user_assigned_identity.mcp[0].client_id
    AzureWebJobsStorage__blobServiceUri       = azurerm_storage_account.mcp[0].primary_blob_endpoint
    APPLICATIONINSIGHTS_AUTHENTICATION_STRING = "ClientId=${azurerm_user_assigned_identity.mcp[0].client_id};Authorization=AAD"
    TICKET_QUEUE_SERVICE_URI                  = azurerm_storage_account.mcp[0].primary_queue_endpoint
    TICKET_QUEUE_NAME                         = azurerm_storage_queue.tickets[0].name
    WORKSHOP_IDENTITY_CLIENT_ID               = azurerm_user_assigned_identity.mcp[0].client_id
  }, local.mcp_auth_app_settings, local.delegated_app_settings) # module 03 (entra-auth.tf) and module 05 (delegated-access.tf) settings, empty unless enabled

  # Module 03: Microsoft Entra built-in authentication (App Service Authentication v2). Absent at level 0.
  dynamic "auth_settings_v2" {
    for_each = local.mcp_auth_enabled ? [1] : []
    content {
      auth_enabled             = true
      require_authentication   = true
      unauthenticated_action   = "Return401"
      default_provider         = "azureactivedirectory"
      require_https            = true
      runtime_version          = "~1"
      http_route_api_prefix    = "/.auth"
      forward_proxy_convention = "NoProxy"

      active_directory_v2 {
        client_id                   = var.mcp_api_client_id
        tenant_auth_endpoint        = local.mcp_auth_issuer
        allowed_audiences           = local.mcp_auth_audiences
        allowed_applications        = var.mcp_allowed_client_ids
        www_authentication_disabled = false
      }

      login {
        token_store_enabled = false
      }
    }
  }

  lifecycle {
    precondition {
      condition     = !contains(keys(local.mcp_auth_app_settings), local.mcp_webhook_level_setting) || local.mcp_auth_enabled
      error_message = "Security invariant 9: the MCP webhook may drop the system key only when built-in authentication is enforced."
    }
  }

  depends_on = [
    azurerm_role_assignment.mcp_host_storage,
    azurerm_role_assignment.mcp_ticket_sender,
    azurerm_role_assignment.mcp_telemetry,
    azurerm_role_assignment.report_app_reader,
  ]
}

output "mcp_function_app_name" {
  description = "Module 02 Function App name, or null when enable_mcp_server is false. No key is ever output."
  value       = local.mcp_enabled ? azurerm_function_app_flex_consumption.mcp[0].name : null
}

output "mcp_endpoint" {
  description = "Streamable HTTP endpoint. Level 0: requires the mcp_extension system key, read at runtime only. Level 1 (module 03): requires a Microsoft Entra token for the MCP API audience instead."
  value       = local.mcp_enabled ? "https://${azurerm_function_app_flex_consumption.mcp[0].default_hostname}/runtime/webhooks/mcp" : null
}

output "mcp_ticket_queue" {
  description = "Synthetic ticket queue name, or null when module 02 is disabled."
  value       = local.mcp_enabled ? azurerm_storage_queue.tickets[0].name : null
}
