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
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.Web/sites/func-mcp-p01-0123456789"
      default_hostname = "func-mcp-p01-0123456789.azurewebsites.net"
    }
  }
  mock_resource "azurerm_api_management" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ApiManagement/service/apim-mcp-p01-0123456789"
    }
  }
  mock_resource "azurerm_api_management_logger" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ApiManagement/service/apim-mcp-p01-0123456789/loggers/appinsights"
    }
  }
}

mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ApiManagement/service/apim-mcp-p01-0123456789/apis/synthetic"
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

# Module 04 mock-only plans: API Management Standard v2 as the only entry point. Synthetic IDs; nothing is contacted.

run "gateway_default_off_keeps_level_1" {
  command = plan
  variables {
    enable_mcp_server           = true
    enable_entra_auth           = true
    entra_tenant_id             = "00000000-0000-4000-8000-000000000000"
    mcp_api_client_id           = "44444444-4444-4444-8444-444444444444"
    mcp_api_identifier_uri      = "api://44444444-4444-4444-8444-444444444444"
    mcp_allowed_client_ids      = ["aebc6443-996d-45c2-90f0-388ff96faa56", "04b07795-8ddb-461a-bbee-02f9e1bf7b46"]
    entra_auth_replace_key_gate = true
  }
  assert {
    condition = alltrue([
      length(azurerm_api_management.gateway) == 0,
      length(azurerm_virtual_network.gateway) == 0,
      length(azurerm_private_endpoint.function) == 0,
      length(azapi_resource.mcp_api) == 0,
      length(azurerm_api_management_diagnostic.gateway) == 0,
      azurerm_function_app_flex_consumption.mcp[0].public_network_access_enabled,
      length(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2) == 1,
      !output.gateway_enabled,
      output.gateway_mcp_endpoint == null,
      !output.gateway_function_public_access_disabled,
    ])
    error_message = "Without the module 04 opt-in, nothing new is planned and module 03 stays exactly as it was."
  }
}

run "gateway_stage_1_standard_v2_private_path" {
  command = plan
  variables {
    enable_mcp_server           = true
    enable_entra_auth           = true
    entra_tenant_id             = "00000000-0000-4000-8000-000000000000"
    mcp_api_client_id           = "44444444-4444-4444-8444-444444444444"
    mcp_api_identifier_uri      = "api://44444444-4444-4444-8444-444444444444"
    mcp_allowed_client_ids      = ["aebc6443-996d-45c2-90f0-388ff96faa56", "04b07795-8ddb-461a-bbee-02f9e1bf7b46"]
    entra_auth_replace_key_gate = true
    enable_governed_gateway     = true
  }

  assert {
    condition = alltrue([
      azurerm_api_management.gateway[0].name == "apim-mcp-p01-0123456789",
      azurerm_api_management.gateway[0].sku_name == "StandardV2_1",
      azurerm_api_management.gateway[0].virtual_network_type == "External",
      azurerm_api_management.gateway[0].public_network_access_enabled,
      azurerm_api_management.gateway[0].identity[0].type == "UserAssigned",
      length(azurerm_api_management.gateway[0].virtual_network_configuration) == 1,
    ])
    error_message = "Standard v2 gateway, public entry point, outbound virtual network integration, managed identity."
  }

  assert {
    condition = alltrue([
      azurerm_subnet.gateway_apim[0].address_prefixes[0] == "10.42.0.0/24",
      azurerm_subnet.gateway_apim[0].delegation[0].service_delegation[0].name == "Microsoft.Web/serverFarms",
      azurerm_subnet.gateway_private_endpoints[0].address_prefixes[0] == "10.42.1.0/27",
      length(azurerm_subnet_network_security_group_association.gateway_apim) == 1,
      one([for rule in azurerm_network_security_group.gateway_apim[0].security_rule : rule.destination_address_prefix if rule.direction == "Outbound"]) == "AzureKeyVault",
      azurerm_private_dns_zone.functions[0].name == "privatelink.azurewebsites.net",
      azurerm_private_dns_zone_virtual_network_link.functions[0].registration_enabled == false,
      azurerm_private_endpoint.function[0].private_service_connection[0].subresource_names[0] == "sites",
      !azurerm_private_endpoint.function[0].private_service_connection[0].is_manual_connection,
    ])
    error_message = "Delegated /24 API Management subnet with NSG, separate /27 private endpoint subnet, private DNS zone and a sites private endpoint."
  }

  assert {
    condition = alltrue([
      azurerm_function_app_flex_consumption.mcp[0].public_network_access_enabled,
      !output.gateway_function_public_access_disabled,
    ])
    error_message = "Stage 1 keeps the Function reachable (still Entra-protected) until the private path is proven; stage 2 locks it."
  }

  assert {
    condition = alltrue([
      azapi_resource.mcp_api[0].type == "Microsoft.ApiManagement/service/apis@2025-09-01-preview",
      azapi_resource.mcp_api[0].body.properties.type == "mcp",
      azapi_resource.mcp_api[0].body.properties.mcpProperties.transportType == "streamable",
      azapi_resource.mcp_api[0].body.properties.mcpProperties.endpoints.message.uriTemplate == "/mcp",
      azapi_resource.mcp_api[0].body.properties.serviceUrl == "https://func-mcp-p01-0123456789.azurewebsites.net/runtime/webhooks",
      azapi_resource.mcp_api[0].body.properties.backendId == "workshop-mcp-function",
      azapi_resource.mcp_backend[0].body.properties.url == "https://func-mcp-p01-0123456789.azurewebsites.net/runtime/webhooks",
      azapi_resource.mcp_api[0].body.properties.subscriptionRequired == false,
      azapi_resource.mcp_api[0].body.properties.path == "workshop-mcp",
    ])
    error_message = "The MCP server API (Preview) proxies the Function's /runtime/webhooks/mcp with Streamable HTTP and no subscription key."
  }

  assert {
    condition = alltrue([
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<validate-azure-ad-token tenant-id=\"00000000-0000-4000-8000-000000000000\""),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<audience>api://44444444-4444-4444-8444-444444444444</audience>"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<audience>44444444-4444-4444-8444-444444444444</audience>"),
      length(regexall("<audience>", azapi_resource.mcp_api_policy[0].body.properties.value)) == 2,
      !strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "azure-api.net</audience>"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<application-id>aebc6443-996d-45c2-90f0-388ff96faa56</application-id>"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<claim name=\"scp\" match=\"any\" separator=\" \">"),
    ])
    error_message = "Gateway token validation: workshop tenant, the MCP API audience only (no broadened gateway audience), allowed clients and the delegated scope."
  }

  assert {
    condition = alltrue([
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "As<JObject>(preserveContent: true)"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "if (tool == \"create_ticket\") { return \"Tools.Write|create_ticket\"; }"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "return \"deny:400|malformed\";"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "return \"deny:403|unknown-tool\";"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<rate-limit-by-key calls=\"30\" renewal-period=\"60\" counter-key=\"@(\"workshop-mcp-oid-\" + (string)context.Variables[\"mcp-caller-oid\"])\" />"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "resource_metadata=\"https://apim-mcp-p01-0123456789.azure-api.net/.well-known/oauth-protected-resource/workshop-mcp/mcp\""),
      !strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<ip-filter"),
      !strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "context.Response.Body"),
      !strcontains(lower(azapi_resource.mcp_api_policy[0].body.properties.value), "subscription-key"),
      !strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "azurewebsites.net"),
    ])
    error_message = "Per-tool roles from the preserved JSON-RPC body, safe denials, per-oid rate limit, gateway PRM challenge; no IP filter by default, no response body access, no key, no private host."
  }

  assert {
    condition = alltrue([
      azapi_resource.prm_api[0].body.properties.path == ".well-known/oauth-protected-resource",
      azapi_resource.prm_api[0].body.properties.subscriptionRequired == false,
      azapi_resource.prm_operation[0].body.properties.urlTemplate == "/workshop-mcp/mcp",
      strcontains(azapi_resource.prm_operation_policy[0].body.properties.value, "\"resource\":\"https://apim-mcp-p01-0123456789.azure-api.net/workshop-mcp/mcp\""),
      strcontains(azapi_resource.prm_operation_policy[0].body.properties.value, "\"authorization_servers\":[\"https://login.microsoftonline.com/00000000-0000-4000-8000-000000000000/v2.0\"]"),
      strcontains(azapi_resource.prm_operation_policy[0].body.properties.value, "\"scopes_supported\":[\"api://44444444-4444-4444-8444-444444444444/user_impersonation\"]"),
      !strcontains(azapi_resource.prm_operation_policy[0].body.properties.value, "azurewebsites.net"),
    ])
    error_message = "Protected Resource Metadata is served by the gateway, names the tenant and the module 03 scope, never the private Function host."
  }

  assert {
    condition = alltrue([
      azurerm_api_management_diagnostic.gateway[0].frontend_request[0].body_bytes == 0,
      azurerm_api_management_diagnostic.gateway[0].frontend_response[0].body_bytes == 0,
      azurerm_api_management_diagnostic.gateway[0].backend_request[0].body_bytes == 0,
      azurerm_api_management_diagnostic.gateway[0].backend_response[0].body_bytes == 0,
      length(azurerm_api_management_diagnostic.gateway[0].frontend_request[0].headers_to_log) == 0,
      length(azurerm_api_management_diagnostic.gateway[0].backend_request[0].headers_to_log) == 0,
      !azurerm_api_management_diagnostic.gateway[0].log_client_ip,
      azapi_resource.mcp_api_diagnostic[0].body.properties.frontend.request.body.bytes == 0,
      azapi_resource.mcp_api_diagnostic[0].body.properties.frontend.response.body.bytes == 0,
      azapi_resource.mcp_api_diagnostic[0].body.properties.backend.request.body.bytes == 0,
      azapi_resource.mcp_api_diagnostic[0].body.properties.backend.response.body.bytes == 0,
      length(azapi_resource.mcp_api_diagnostic[0].body.properties.frontend.request.headers) == 0,
      azapi_resource.mcp_api_diagnostic[0].body.properties.logClientIp == false,
    ])
    error_message = "Zero body bytes and no logged header (Authorization included) at both the all-APIs and the MCP API scopes."
  }

  assert {
    condition = alltrue([
      azurerm_api_management_logger.gateway[0].application_insights[0].identity_client_id == "11111111-1111-1111-1111-111111111111",
      azurerm_role_assignment.gateway_telemetry[0].role_definition_name == "Monitoring Metrics Publisher",
      azurerm_role_assignment.gateway_telemetry[0].scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.Insights/components/appi-synthetic",
    ])
    error_message = "Telemetry uses the gateway managed identity with one role scoped to the one Application Insights resource."
  }

  assert {
    condition = alltrue([
      output.gateway_enabled,
      output.gateway_mcp_endpoint == "https://apim-mcp-p01-0123456789.azure-api.net/workshop-mcp/mcp",
      output.gateway_resource_metadata_url == "https://apim-mcp-p01-0123456789.azure-api.net/.well-known/oauth-protected-resource/workshop-mcp/mcp",
      output.gateway_rate_limit.calls == 30,
    ])
    error_message = "Outputs expose the deterministic gateway endpoint and metadata URL for the validator (no secret)."
  }
}

run "gateway_stage_2_locks_the_function" {
  command = plan
  variables {
    enable_mcp_server           = true
    enable_entra_auth           = true
    entra_tenant_id             = "00000000-0000-4000-8000-000000000000"
    mcp_api_client_id           = "44444444-4444-4444-8444-444444444444"
    mcp_api_identifier_uri      = "api://44444444-4444-4444-8444-444444444444"
    mcp_allowed_client_ids      = ["aebc6443-996d-45c2-90f0-388ff96faa56"]
    entra_auth_replace_key_gate = true
    enable_governed_gateway     = true
    gateway_lock_function       = true
  }
  assert {
    condition = alltrue([
      !azurerm_function_app_flex_consumption.mcp[0].public_network_access_enabled,
      output.gateway_function_public_access_disabled,
      length(azurerm_private_endpoint.function) == 1,
      length(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2) == 1,
    ])
    error_message = "Stage 2 disables public access on the Function; the private endpoint remains and built-in authentication still validates the token."
  }
}

run "gateway_ip_filter_renders_ranges" {
  command = plan
  variables {
    enable_mcp_server           = true
    enable_entra_auth           = true
    entra_tenant_id             = "00000000-0000-4000-8000-000000000000"
    mcp_api_client_id           = "44444444-4444-4444-8444-444444444444"
    mcp_api_identifier_uri      = "api://44444444-4444-4444-8444-444444444444"
    mcp_allowed_client_ids      = ["aebc6443-996d-45c2-90f0-388ff96faa56"]
    entra_auth_replace_key_gate = true
    enable_governed_gateway     = true
    gateway_allowed_ip_ranges   = ["203.0.113.0/24", "198.51.100.7/32"]
    gateway_rate_limit_calls    = 10
    gateway_rate_limit_period   = 30
  }
  assert {
    condition = alltrue([
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<ip-filter action=\"allow\">"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<address-range from=\"203.0.113.0\" to=\"203.0.113.255\" />"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<address-range from=\"198.51.100.7\" to=\"198.51.100.7\" />"),
      strcontains(azapi_resource.mcp_api_policy[0].body.properties.value, "<rate-limit-by-key calls=\"10\" renewal-period=\"30\""),
    ])
    error_message = "The optional ip-filter allows only the listed ranges, and the rate limit follows the variables."
  }
}

run "gateway_requires_module_03_stage_2" {
  command = plan
  variables {
    enable_mcp_server       = true
    enable_entra_auth       = true
    entra_tenant_id         = "00000000-0000-4000-8000-000000000000"
    mcp_api_client_id       = "44444444-4444-4444-8444-444444444444"
    mcp_api_identifier_uri  = "api://44444444-4444-4444-8444-444444444444"
    mcp_allowed_client_ids  = ["aebc6443-996d-45c2-90f0-388ff96faa56"]
    enable_governed_gateway = true
  }
  expect_failures = [var.enable_governed_gateway]
}

run "gateway_lock_requires_the_gateway" {
  command = plan
  variables {
    enable_mcp_server     = true
    gateway_lock_function = true
  }
  expect_failures = [var.gateway_lock_function]
}

run "gateway_rejects_open_ip_filter" {
  command = plan
  variables {
    gateway_allowed_ip_ranges = ["0.0.0.0/0"]
  }
  expect_failures = [var.gateway_allowed_ip_ranges]
}

run "gateway_rejects_long_rate_window" {
  command = plan
  variables {
    gateway_rate_limit_period = 600
  }
  expect_failures = [var.gateway_rate_limit_period]
}

run "gateway_rejects_tiny_address_space" {
  command = plan
  variables {
    gateway_vnet_address_space = "10.42.0.0/26"
  }
  expect_failures = [var.gateway_vnet_address_space]
}
