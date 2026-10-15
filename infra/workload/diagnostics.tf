# Module 04 - payload-free gateway telemetry to the module 02 Application Insights (invariant 7).
# Microsoft Learn ("Expose and govern an existing MCP server", prerequisites): with diagnostic logging at the global
# (all APIs) scope, the frontend response payload bytes must be 0 or MCP streaming can break. The workshop goes further:
# 0 bytes for frontend/backend requests and responses at BOTH the all-APIs scope and the MCP API scope, and no header
# at all (so Authorization is never logged). The caller object ID and fixed tool label come from the policy trace.

locals {
  gateway_diagnostic_sampling = 100
}

# All-APIs scope.
resource "azurerm_api_management_diagnostic" "gateway" {
  count                     = local.gateway_enabled ? 1 : 0
  identifier                = "applicationinsights"
  api_management_name       = azurerm_api_management.gateway[0].name
  resource_group_name       = local.workload_group
  api_management_logger_id  = azurerm_api_management_logger.gateway[0].id
  sampling_percentage       = local.gateway_diagnostic_sampling
  always_log_errors         = true
  log_client_ip             = false
  verbosity                 = "information"
  http_correlation_protocol = "W3C"
  operation_name_format     = "Name"

  frontend_request {
    body_bytes     = 0
    headers_to_log = []
  }
  frontend_response {
    body_bytes     = 0
    headers_to_log = []
  }
  backend_request {
    body_bytes     = 0
    headers_to_log = []
  }
  backend_response {
    body_bytes     = 0
    headers_to_log = []
  }
}

# MCP API scope (a more specific logger setting overrides the all-APIs one, so it repeats the same zero-byte rules).
resource "azapi_resource" "mcp_api_diagnostic" {
  count     = local.gateway_enabled ? 1 : 0
  type      = "Microsoft.ApiManagement/service/apis/diagnostics@2025-09-01-preview"
  name      = "applicationinsights"
  parent_id = azapi_resource.mcp_api[0].id

  body = {
    properties = {
      loggerId                = azurerm_api_management_logger.gateway[0].id
      alwaysLog               = "allErrors"
      httpCorrelationProtocol = "W3C"
      logClientIp             = false
      verbosity               = "information"
      metrics                 = true
      sampling                = { samplingType = "fixed", percentage = local.gateway_diagnostic_sampling }
      frontend                = local.gateway_payload_free
      backend                 = local.gateway_payload_free
    }
  }
}
