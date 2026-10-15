# Module 04 - Azure API Management as the only entry point (level 2). Opt-in with enable_governed_gateway (stage 1),
# then gateway_lock_function (stage 2) disables public access on the Function App (see network.tf and mcp-server.tf).
# The MCP server API uses Microsoft.ApiManagement/service/apis@2025-09-01-preview with type "mcp" (Preview) through AzAPI,
# as documented in Microsoft Learn "Manage MCP servers programmatically in API Management" (Terraform section).
# Policies live in modules/04-governed-gateway/policies and are rendered with non-secret values only.
# No subscription key is required or issued: Microsoft Entra tokens and app roles are the only access mechanism.

locals {
  gateway_policy_dir  = "${path.module}/../../modules/04-governed-gateway/policies"
  gateway_url         = "https://${local.names.api_management}.azure-api.net"
  gateway_mcp_url     = "${local.gateway_url}/${var.gateway_mcp_path}/mcp"
  gateway_prm_url     = "${local.gateway_url}/.well-known/oauth-protected-resource/${var.gateway_mcp_path}/mcp"
  gateway_api_name    = "workshop-mcp"
  gateway_prm_api     = "workshop-mcp-prm"
  gateway_ip_ranges   = [for range in var.gateway_allowed_ip_ranges : { from = cidrhost(range, 0), to = cidrhost(range, -1) }]
  gateway_backend_url = local.mcp_enabled ? "https://${azurerm_function_app_flex_consumption.mcp[0].default_hostname}/runtime/webhooks" : null

  # Rendered here so the mock tests can assert the exact policy that would be deployed.
  gateway_mcp_policy = local.gateway_enabled ? templatefile("${local.gateway_policy_dir}/mcp-server.xml", {
    tenant_id             = var.entra_tenant_id
    audiences             = local.mcp_auth_audiences # the module 03 MCP API only: one logical resource, one audience
    client_ids            = var.mcp_allowed_client_ids
    rate_limit_calls      = var.gateway_rate_limit_calls
    rate_limit_period     = var.gateway_rate_limit_period
    ip_ranges             = local.gateway_ip_ranges
    resource_metadata_url = local.gateway_prm_url
  }) : null
  gateway_prm_policy = local.gateway_enabled ? templatefile("${local.gateway_policy_dir}/protected-resource-metadata.xml", {
    resource = local.gateway_mcp_url
    issuer   = local.mcp_auth_issuer
    scope    = local.mcp_auth_scope
  }) : null

  # Zero body bytes everywhere (invariant 7). No header is logged, so Authorization never reaches telemetry.
  gateway_payload_free = {
    request  = { headers = [], body = { bytes = 0 } }
    response = { headers = [], body = { bytes = 0 } }
  }
}

resource "azurerm_user_assigned_identity" "gateway" {
  count               = local.gateway_enabled ? 1 : 0
  name                = local.gateway_names.apim_identity
  resource_group_name = local.workload_group
  location            = local.workload_location
  tags                = local.tags
}

# Least privilege: the gateway identity may only publish telemetry to this one Application Insights resource.
resource "azurerm_role_assignment" "gateway_telemetry" {
  count                            = local.gateway_enabled ? 1 : 0
  scope                            = azurerm_application_insights.mcp[0].id
  role_definition_name             = "Monitoring Metrics Publisher"
  principal_id                     = azurerm_user_assigned_identity.gateway[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Workshop module 04: API Management Entra-authenticated telemetry ingestion."
}

# Standard v2 is provisioned capacity billed per hour while it exists: get cost approval before applying.
resource "azurerm_api_management" "gateway" {
  count                         = local.gateway_enabled ? 1 : 0
  name                          = local.names.api_management
  resource_group_name           = local.workload_group
  location                      = local.workload_location
  sku_name                      = "StandardV2_1"
  publisher_name                = "Governed MCP workshop"
  publisher_email               = var.gateway_publisher_email
  public_network_access_enabled = true       # the gateway is the public entry point
  virtual_network_type          = "External" # Standard v2 outbound virtual network integration
  tags                          = local.tags

  virtual_network_configuration {
    subnet_id = azurerm_subnet.gateway_apim[0].id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.gateway[0].id]
  }

  depends_on = [azurerm_subnet_network_security_group_association.gateway_apim]
}

resource "azurerm_api_management_logger" "gateway" {
  count               = local.gateway_enabled ? 1 : 0
  name                = "appinsights"
  api_management_name = azurerm_api_management.gateway[0].name
  resource_group_name = local.workload_group
  resource_id         = azurerm_application_insights.mcp[0].id
  buffered            = true

  # Connection string plus managed identity (Learn recommendation); local authentication stays disabled on the component.
  application_insights {
    connection_string  = azurerm_application_insights.mcp[0].connection_string
    identity_client_id = azurerm_user_assigned_identity.gateway[0].client_id
  }

  depends_on = [azurerm_role_assignment.gateway_telemetry]
}

# The MCP server: a passthrough to the Function's Streamable HTTP endpoint (/runtime/webhooks/mcp). Preview API version.
resource "azapi_resource" "mcp_api" {
  count     = local.gateway_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis@2025-09-01-preview" # Preview
  name      = local.gateway_api_name
  parent_id = azurerm_api_management.gateway[0].id

  body = {
    properties = {
      type                 = "mcp"
      displayName          = "Workshop MCP server (governed)"
      description          = "Synthetic workshop MCP server on Azure Functions, reachable only through this gateway."
      path                 = var.gateway_mcp_path
      protocols            = ["https"]
      serviceUrl           = local.gateway_backend_url
      subscriptionRequired = false # access is decided by Entra tokens and app roles, never by subscription keys
      mcpProperties = {
        transportType = "streamable"
        endpoints = [
          { name = "message", uriTemplate = "/mcp" }
        ]
      }
    }
  }
}

resource "azapi_resource" "mcp_api_policy" {
  count     = local.gateway_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis/policies@2025-09-01-preview" # Preview
  name      = "policy"
  parent_id = azapi_resource.mcp_api[0].id

  body = {
    properties = {
      format = "rawxml"
      value  = local.gateway_mcp_policy
    }
  }
}

# Protected Resource Metadata (RFC 9728) on the gateway, at the path named by the 401 challenge.
resource "azapi_resource" "prm_api" {
  count     = local.gateway_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis@2025-09-01-preview"
  name      = local.gateway_prm_api
  parent_id = azurerm_api_management.gateway[0].id

  body = {
    properties = {
      displayName          = "Workshop MCP protected resource metadata"
      description          = "Anonymous RFC 9728 metadata: where to sign in and which scope to request. No data."
      path                 = ".well-known/oauth-protected-resource"
      protocols            = ["https"]
      subscriptionRequired = false
    }
  }
}

resource "azapi_resource" "prm_operation" {
  count     = local.gateway_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis/operations@2025-09-01-preview"
  name      = "get-mcp-metadata"
  parent_id = azapi_resource.prm_api[0].id

  body = {
    properties = {
      displayName = "Protected Resource Metadata"
      method      = "GET"
      urlTemplate = "/${var.gateway_mcp_path}/mcp"
      description = "RFC 9728 metadata of the governed MCP server."
    }
  }
}

resource "azapi_resource" "prm_operation_policy" {
  count     = local.gateway_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis/operations/policies@2025-09-01-preview"
  name      = "policy"
  parent_id = azapi_resource.prm_operation[0].id

  body = {
    properties = {
      format = "rawxml"
      value  = local.gateway_prm_policy
    }
  }
}

output "gateway_enabled" {
  description = "True when module 04 stage 1 deployed the governed gateway."
  value       = local.gateway_enabled
}

output "gateway_name" {
  description = "API Management service name, or null when module 04 is off."
  value       = local.gateway_enabled ? azurerm_api_management.gateway[0].name : null
}

output "gateway_mcp_endpoint" {
  description = "The only MCP endpoint clients should use at level 2. Requires a Microsoft Entra token for the MCP API audience."
  value       = local.gateway_enabled ? local.gateway_mcp_url : null
}

output "gateway_resource_metadata_url" {
  description = "Protected Resource Metadata URL named in the gateway's 401 challenge."
  value       = local.gateway_enabled ? local.gateway_prm_url : null
}

output "gateway_mcp_api_name" {
  description = "API Management MCP server (API) name, for diagnostics and validation."
  value       = local.gateway_enabled ? local.gateway_api_name : null
}

output "gateway_rate_limit" {
  description = "Calls per caller object ID and renewal period (seconds) enforced by the gateway."
  value       = local.gateway_enabled ? { calls = var.gateway_rate_limit_calls, period = var.gateway_rate_limit_period } : null
}
