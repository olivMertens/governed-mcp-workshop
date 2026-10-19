# Module 04 optional part B - expose a REST API managed by API Management as an MCP server (API-first pattern).
# Opt-in with enable_rest_mcp_demo (requires enable_governed_gateway). Same gateway, same Microsoft Entra audience,
# same app roles, same rate limit and the same payload-free logging as part A. No subscription key anywhere.
#
# Resource shapes follow Microsoft Learn "Manage MCP servers programmatically in API Management", section
# "ARM and Bicep templates > REST API-backed MCP server" (last verified 2026-10-19):
#   - Microsoft.ApiManagement/service/apis@2025-09-01-preview with properties.type = "mcp" (Preview), no backend endpoints;
#   - Microsoft.ApiManagement/service/apis/tools@2025-09-01-preview (Preview) whose operationId is the full resource ID
#     of the backing REST API operation.
# Limitations from "Expose REST API in API Management as an MCP server": tools only (no MCP resources or prompts),
# not available in workspaces, never read context.Response.Body in MCP server policies.
#
# The REST API answers with mock-response from the operation examples: synthetic Contoso tickets, no backend, no data.

locals {
  rest_mcp_enabled      = local.gateway_enabled && var.enable_rest_mcp_demo
  rest_api_name         = "contoso-tickets-api"
  rest_api_path         = "contoso-tickets"
  rest_mcp_api_name     = "contoso-tickets-mcp"
  rest_mcp_path         = "contoso-tickets-mcp"
  rest_mcp_url          = "${local.gateway_url}/${local.rest_mcp_path}/mcp"
  rest_mcp_prm_url      = "${local.gateway_url}/.well-known/oauth-protected-resource/${local.rest_mcp_path}/mcp"
  rest_api_url          = "${local.gateway_url}/${local.rest_api_path}"
  rest_mcp_tool_mapping = { list_tickets = "list-tickets", get_ticket = "get-ticket" }

  # Synthetic Contoso tickets. No personal data, no real system.
  rest_mcp_tickets = [
    { id = "CT-1001", title = "VPN gateway reports intermittent timeouts", severity = "high", status = "open", service = "network" },
    { id = "CT-1002", title = "Shared drive close to its quota", severity = "medium", status = "in-progress", service = "storage" },
    { id = "CT-1003", title = "Expense app slow at month end", severity = "low", status = "resolved", service = "expense-app" },
  ]

  rest_mcp_operations = {
    "list-tickets" = {
      displayName = "List tickets"
      description = "Returns the synthetic Contoso support tickets (id, title, severity, status, service). Read-only."
      urlTemplate = "/tickets"
      parameters  = []
      example     = local.rest_mcp_tickets
    }
    "get-ticket" = {
      displayName = "Get ticket"
      description = "Returns one synthetic Contoso support ticket by its ID, for example CT-1001. Read-only."
      urlTemplate = "/tickets/{ticketId}"
      parameters  = [{ name = "ticketId", type = "string", required = true, description = "Ticket ID, for example CT-1001." }]
      example     = local.rest_mcp_tickets[0]
    }
  }

  rest_api_policy = local.rest_mcp_enabled ? templatefile("${local.gateway_policy_dir}/rest-api.xml", {
    tenant_id  = var.entra_tenant_id
    audiences  = local.mcp_auth_audiences # the module 03 MCP API only
    client_ids = var.mcp_allowed_client_ids
  }) : null
  rest_mcp_policy = local.rest_mcp_enabled ? templatefile("${local.gateway_policy_dir}/rest-mcp-server.xml", {
    tenant_id             = var.entra_tenant_id
    audiences             = local.mcp_auth_audiences # the module 03 MCP API only
    client_ids            = var.mcp_allowed_client_ids
    rate_limit_calls      = var.gateway_rate_limit_calls
    rate_limit_period     = var.gateway_rate_limit_period
    ip_ranges             = local.gateway_ip_ranges
    resource_metadata_url = local.rest_mcp_prm_url
  }) : null
  rest_mcp_prm_policy = local.rest_mcp_enabled ? templatefile("${local.gateway_policy_dir}/protected-resource-metadata.xml", {
    resource = local.rest_mcp_url
    issuer   = local.mcp_auth_issuer
    scope    = local.mcp_auth_scope
  }) : null
}

# The backing REST API. It is never anonymous: its own policy validates the same Entra token before mock-response.
resource "azapi_resource" "rest_api" {
  count     = local.rest_mcp_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis@2025-09-01-preview" # Preview API version
  name      = local.rest_api_name
  parent_id = azurerm_api_management.gateway[0].id

  body = {
    properties = {
      type                 = "http"
      displayName          = "Contoso Tickets REST API (synthetic, mocked)"
      description          = "Synthetic Contoso support tickets. Responses come from mock-response; no backend is called."
      path                 = local.rest_api_path
      protocols            = ["https"]
      serviceUrl           = "https://contoso-tickets.invalid" # placeholder: mock-response answers before any backend call
      subscriptionRequired = false                             # access is decided by Entra tokens, never by subscription keys
    }
  }
}

resource "azapi_resource" "rest_operation" {
  for_each  = local.rest_mcp_enabled ? toset(keys(local.rest_mcp_operations)) : toset([])
  type      = "Microsoft.ApiManagement/service/apis/operations@2025-09-01-preview" # Preview API version
  name      = each.key
  parent_id = azapi_resource.rest_api[0].id

  body = {
    properties = {
      displayName        = local.rest_mcp_operations[each.key].displayName
      description        = local.rest_mcp_operations[each.key].description
      method             = "GET"
      urlTemplate        = local.rest_mcp_operations[each.key].urlTemplate
      templateParameters = local.rest_mcp_operations[each.key].parameters
      responses = [{
        statusCode  = 200
        description = "Synthetic tickets (mocked)."
        representations = [{
          contentType = "application/json"
          examples    = { default = { summary = "Synthetic Contoso data", value = local.rest_mcp_operations[each.key].example } }
        }]
      }]
    }
  }
}

resource "azapi_resource" "rest_api_policy" {
  count     = local.rest_mcp_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis/policies@2025-09-01-preview" # Preview API version
  name      = "policy"
  parent_id = azapi_resource.rest_api[0].id

  body = {
    properties = {
      format = "rawxml"
      value  = local.rest_api_policy
    }
  }
}

# The MCP server: type "mcp" without mcpProperties endpoints (REST-backed, not passthrough). Preview.
resource "azapi_resource" "rest_mcp_api" {
  count     = local.rest_mcp_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis@2025-09-01-preview" # Preview
  name      = local.rest_mcp_api_name
  parent_id = azurerm_api_management.gateway[0].id

  body = {
    properties = {
      type                 = "mcp"
      displayName          = "Contoso Tickets (REST API exposed as MCP)"
      description          = "Synthetic Contoso tickets REST API exposed as MCP tools by the governed gateway (part B, API-first)."
      path                 = local.rest_mcp_path
      protocols            = ["https"]
      subscriptionRequired = false # access is decided by Entra tokens and app roles, never by subscription keys
    }
  }
}

# One tool per backing operation. Both tools are read-only.
resource "azapi_resource" "rest_mcp_tool" {
  for_each  = local.rest_mcp_enabled ? local.rest_mcp_tool_mapping : {}
  type      = "Microsoft.ApiManagement/service/apis/tools@2025-09-01-preview" # Preview
  name      = each.key
  parent_id = azapi_resource.rest_mcp_api[0].id
  # The Preview tools type may be missing from the provider's embedded schema; the service validates the body.
  schema_validation_enabled = false

  body = {
    properties = {
      displayName = each.key
      description = local.rest_mcp_operations[each.value].description
      operationId = "${azapi_resource.rest_api[0].id}/operations/${each.value}"
    }
  }

  depends_on = [azapi_resource.rest_operation]
}

resource "azapi_resource" "rest_mcp_policy" {
  count     = local.rest_mcp_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis/policies@2025-09-01-preview" # Preview
  name      = "policy"
  parent_id = azapi_resource.rest_mcp_api[0].id

  body = {
    properties = {
      format = "rawxml"
      value  = local.rest_mcp_policy
    }
  }
}

# Protected Resource Metadata (RFC 9728) for the second MCP server, on the existing anonymous metadata API.
resource "azapi_resource" "rest_mcp_prm_operation" {
  count     = local.rest_mcp_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis/operations@2025-09-01-preview"
  name      = "get-rest-mcp-metadata"
  parent_id = azapi_resource.prm_api[0].id

  body = {
    properties = {
      displayName = "Protected Resource Metadata (Contoso Tickets MCP)"
      method      = "GET"
      urlTemplate = "/${local.rest_mcp_path}/mcp"
      description = "RFC 9728 metadata of the REST-backed MCP server (part B)."
    }
  }
}

resource "azapi_resource" "rest_mcp_prm_operation_policy" {
  count     = local.rest_mcp_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis/operations/policies@2025-09-01-preview"
  name      = "policy"
  parent_id = azapi_resource.rest_mcp_prm_operation[0].id

  body = {
    properties = {
      format = "rawxml"
      value  = local.rest_mcp_prm_policy
    }
  }
}

# Logging: the all-APIs diagnostic in diagnostics.tf (0 body bytes, no header) applies to both part B APIs.
# No API-scope diagnostic is added here, so nothing can override those zero-byte rules.

output "rest_mcp_enabled" {
  description = "True when module 04 part B (REST API exposed as an MCP server) is deployed."
  value       = local.rest_mcp_enabled
}

output "rest_mcp_endpoint" {
  description = "Part B MCP endpoint. Requires a Microsoft Entra token for the MCP API audience and an app role."
  value       = local.rest_mcp_enabled ? local.rest_mcp_url : null
}

output "rest_mcp_resource_metadata_url" {
  description = "Protected Resource Metadata URL named in the part B 401 challenge."
  value       = local.rest_mcp_enabled ? local.rest_mcp_prm_url : null
}

output "rest_mcp_api_name" {
  description = "API Management name of the part B MCP server."
  value       = local.rest_mcp_enabled ? local.rest_mcp_api_name : null
}

output "rest_api_name" {
  description = "API Management name of the synthetic backing REST API."
  value       = local.rest_mcp_enabled ? local.rest_api_name : null
}

output "rest_api_endpoint" {
  description = "Base URL of the backing REST API (still requires an Entra token for the MCP API audience)."
  value       = local.rest_mcp_enabled ? local.rest_api_url : null
}
