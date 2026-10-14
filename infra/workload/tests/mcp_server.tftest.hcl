mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_storage_account" {
    defaults = {
      id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.Storage/storageAccounts/stsynthetic"
      primary_blob_endpoint  = "https://stsynthetic.blob.core.windows.net/"
      primary_queue_endpoint = "https://stsynthetic.queue.core.windows.net/"
    }
  }
  mock_resource "azurerm_storage_queue" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.Storage/storageAccounts/stsynthetic/queueServices/default/queues/tickets"
    }
  }
  mock_resource "azurerm_application_insights" {
    defaults = {
      id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.Insights/components/appi-synthetic"
      connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://synthetic.invalid/"
    }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-synthetic"
      client_id    = "11111111-1111-1111-1111-111111111111"
      principal_id = "22222222-2222-2222-2222-222222222222"
    }
  }
  mock_resource "azurerm_function_app_flex_consumption" {
    defaults = {
      default_hostname = "func-mcp-p01-0123456789.azurewebsites.net"
    }
  }
}

variables {
  participant_prefix = "p01"
  resource_suffix    = "0123456789"
  location           = "swedencentral"
  owner              = "alice"
  expiry             = "2099-12-31"
}

run "mcp_server_default_off" {
  command = plan
  assert {
    condition = alltrue([
      length(azurerm_user_assigned_identity.mcp) == 0,
      length(azurerm_storage_account.mcp) == 0,
      length(azurerm_storage_queue.tickets) == 0,
      length(azurerm_function_app_flex_consumption.mcp) == 0,
      length(azurerm_role_assignment.mcp_host_storage) == 0,
      length(azurerm_application_insights.mcp) == 0,
      output.mcp_endpoint == null,
      output.mcp_function_app_name == null,
    ])
    error_message = "Without the module 02 opt-in, the module 00 foundation must stay unchanged."
  }
}

run "mcp_server_enabled" {
  command = plan
  variables {
    enable_mcp_server = true
  }
  assert {
    condition     = azurerm_function_app_flex_consumption.mcp[0].name == output.resource_names.function_app && azurerm_storage_account.mcp[0].name == output.resource_names.storage
    error_message = "MCP resources must use the central deterministic names."
  }
  assert {
    condition = alltrue([
      !azurerm_storage_account.mcp[0].shared_access_key_enabled,
      azurerm_storage_account.mcp[0].default_to_oauth_authentication,
      !azurerm_storage_account.mcp[0].allow_nested_items_to_be_public,
      azurerm_storage_account.mcp[0].min_tls_version == "TLS1_2",
      azurerm_storage_account.mcp[0].https_traffic_only_enabled,
      azurerm_storage_container.mcp_package[0].container_access_type == "private",
    ])
    error_message = "Storage must refuse shared keys and anonymous access and require TLS 1.2."
  }
  assert {
    condition = alltrue([
      azurerm_function_app_flex_consumption.mcp[0].runtime_name == "dotnet-isolated",
      azurerm_function_app_flex_consumption.mcp[0].runtime_version == "10.0",
      azurerm_function_app_flex_consumption.mcp[0].storage_authentication_type == "UserAssignedIdentity",
      azurerm_function_app_flex_consumption.mcp[0].storage_access_key == null,
      azurerm_function_app_flex_consumption.mcp[0].https_only,
      !azurerm_function_app_flex_consumption.mcp[0].webdeploy_publish_basic_authentication_enabled,
      azurerm_function_app_flex_consumption.mcp[0].site_config[0].minimum_tls_version == "1.2",
      azurerm_function_app_flex_consumption.mcp[0].maximum_instance_count == 10,
      azurerm_service_plan.mcp[0].sku_name == "FC1",
    ])
    error_message = "Flex app must run .NET 10 isolated with identity storage, HTTPS only and no basic publishing."
  }
  assert {
    condition = alltrue([
      azurerm_function_app_flex_consumption.mcp[0].app_settings["AzureWebJobsStorage"] == "",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["AzureWebJobsStorage__credential"] == "managedidentity",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["AzureWebJobsStorage__clientId"] == "11111111-1111-1111-1111-111111111111",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_IDENTITY_CLIENT_ID"] == "11111111-1111-1111-1111-111111111111",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["TICKET_QUEUE_NAME"] == "tickets",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["APPLICATIONINSIGHTS_AUTHENTICATION_STRING"] == "ClientId=11111111-1111-1111-1111-111111111111;Authorization=AAD",
      !anytrue([for value in values(azurerm_function_app_flex_consumption.mcp[0].app_settings) : strcontains(lower(value), "accountkey") || strcontains(lower(value), "sig=") || strcontains(lower(value), "sharedaccesssignature")]),
    ])
    error_message = "App settings must be identity-based and contain no key, SAS or connection-string secret."
  }
  assert {
    condition = alltrue([
      azurerm_application_insights.mcp[0].local_authentication_enabled == false,
      azurerm_log_analytics_workspace.mcp[0].local_authentication_enabled == false,
      azurerm_log_analytics_workspace.mcp[0].daily_quota_gb == 1,
    ])
    error_message = "Telemetry must require Entra authentication and keep a bounded ingestion quota."
  }
  assert {
    condition = alltrue([
      azurerm_role_assignment.mcp_host_storage[0].scope == azurerm_storage_account.mcp[0].id,
      azurerm_role_assignment.mcp_host_storage[0].role_definition_name == "Storage Blob Data Owner",
      azurerm_role_assignment.mcp_ticket_sender[0].scope == azurerm_storage_queue.tickets[0].id,
      azurerm_role_assignment.mcp_ticket_sender[0].role_definition_name == "Storage Queue Data Message Sender",
      azurerm_role_assignment.mcp_telemetry[0].scope == azurerm_application_insights.mcp[0].id,
      azurerm_role_assignment.mcp_telemetry[0].role_definition_name == "Monitoring Metrics Publisher",
    ])
    error_message = "Each role assignment must be scoped to one exact resource with the least role for its purpose."
  }
  assert {
    condition = alltrue([for assignment in [azurerm_role_assignment.mcp_host_storage[0], azurerm_role_assignment.mcp_ticket_sender[0], azurerm_role_assignment.mcp_telemetry[0]] :
      assignment.principal_id == "22222222-2222-2222-2222-222222222222" && assignment.principal_type == "ServicePrincipal" &&
    can(regex("/providers/Microsoft\\.(Storage|Insights)/", assignment.scope))])
    error_message = "Only the workshop managed identity receives roles, never at resource group or subscription scope."
  }
  assert {
    condition     = azurerm_function_app_flex_consumption.mcp[0].site_config[0].ip_restriction_default_action == "Allow" && length(azurerm_function_app_flex_consumption.mcp[0].site_config[0].ip_restriction) == 0
    error_message = "Without an allow-list, the endpoint stays reachable and protected only by the system key (level 0)."
  }
}

run "mcp_server_ip_allow_list" {
  command = plan
  variables {
    enable_mcp_server     = true
    mcp_allowed_ip_ranges = ["203.0.113.10/32", "198.51.100.0/24"]
  }
  assert {
    condition = (azurerm_function_app_flex_consumption.mcp[0].site_config[0].ip_restriction_default_action == "Deny" &&
      length(azurerm_function_app_flex_consumption.mcp[0].site_config[0].ip_restriction) == 2 &&
    alltrue([for rule in azurerm_function_app_flex_consumption.mcp[0].site_config[0].ip_restriction : rule.action == "Allow"]))
    error_message = "An allow-list must allow only the listed ranges and deny everything else."
  }
}

run "mcp_server_existing_group" {
  command = plan
  variables {
    enable_mcp_server            = true
    existing_resource_group_name = "rg-synthetic-admin-provided"
  }
  assert {
    condition     = length(azurerm_resource_group.workshop) == 0 && azurerm_function_app_flex_consumption.mcp[0].resource_group_name == "rg-synthetic-admin-provided" && azurerm_storage_account.mcp[0].location == "swedencentral"
    error_message = "MCP resources must be created in, never manage, an approved existing group."
  }
}

run "mcp_server_rejects_open_internet_allow_list" {
  command = plan
  variables {
    enable_mcp_server     = true
    mcp_allowed_ip_ranges = ["0.0.0.0/0"]
  }
  expect_failures = [var.mcp_allowed_ip_ranges]
}

run "mcp_server_rejects_malformed_range" {
  command = plan
  variables {
    enable_mcp_server     = true
    mcp_allowed_ip_ranges = ["not-an-ip"]
  }
  expect_failures = [var.mcp_allowed_ip_ranges]
}

run "mcp_server_rejects_unbounded_scale" {
  command = plan
  variables {
    enable_mcp_server          = true
    mcp_maximum_instance_count = 1000
  }
  expect_failures = [var.mcp_maximum_instance_count]
}
