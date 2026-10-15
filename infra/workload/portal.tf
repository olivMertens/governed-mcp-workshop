locals {
  workload_group    = var.existing_resource_group_name == null ? azurerm_resource_group.workshop[0].name : data.azurerm_resource_group.existing[0].name
  workload_location = var.existing_resource_group_name == null ? azurerm_resource_group.workshop[0].location : var.location

  # Non-secret values that let the participant's own portal prefill its connection page.
  # Allowlisted again by scripts/portal-server.mjs. Never keys, tokens, tenant IDs or connection strings.
  # Level 2 (module 04): advertise only the gateway endpoint, never the private Function host.
  portal_participant_settings = merge(
    local.mcp_enabled ? { WORKSHOP_MCP_ENDPOINT = local.gateway_enabled ? local.gateway_mcp_url : "https://${azurerm_function_app_flex_consumption.mcp[0].default_hostname}/runtime/webhooks/mcp" } : {},
    local.mcp_auth_enabled ? { WORKSHOP_MCP_SCOPE = local.mcp_auth_scope } : {},
  )
}

resource "azurerm_service_plan" "portal" {
  count               = var.public_portal_enabled ? 1 : 0
  name                = local.names.portal_plan
  resource_group_name = local.workload_group
  location            = local.workload_location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.tags
}

resource "azurerm_linux_web_app" "portal" {
  count                                          = var.public_portal_enabled ? 1 : 0
  name                                           = local.names.portal_app
  resource_group_name                            = local.workload_group
  location                                       = local.workload_location
  service_plan_id                                = azurerm_service_plan.portal[0].id
  https_only                                     = true
  public_network_access_enabled                  = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  client_affinity_enabled                        = false
  tags                                           = local.tags

  site_config {
    always_on                         = true
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version           = "1.2"
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    app_command_line                  = "node server.mjs"
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 2
    application_stack {
      node_version = "22-lts"
    }
  }

  app_settings = merge({
    SCM_DO_BUILD_DURING_DEPLOYMENT = "false"
    WEBSITE_RUN_FROM_PACKAGE       = "1"
  }, local.portal_participant_settings)
}

output "public_portal_url" {
  description = "Public documentation only, not an authenticated MCP endpoint. Null until explicitly opted in."
  value       = var.public_portal_enabled ? "https://${azurerm_linux_web_app.portal[0].default_hostname}" : null
}
