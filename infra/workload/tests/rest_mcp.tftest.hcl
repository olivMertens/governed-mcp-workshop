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

# The backing REST API gets its real deterministic ID so the tool mapping can be asserted exactly.
override_resource {
  target          = azapi_resource.rest_api
  override_during = plan
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ApiManagement/service/apim-mcp-p01-0123456789/apis/contoso-tickets-api"
  }
}

variables {
  participant_prefix          = "p01"
  resource_suffix             = "0123456789"
  location                    = "swedencentral"
  owner                       = "alice"
  expiry                      = "2099-12-31"
  enable_mcp_server           = true
  enable_entra_auth           = true
  entra_tenant_id             = "00000000-0000-4000-8000-000000000000"
  mcp_api_client_id           = "44444444-4444-4444-8444-444444444444"
  mcp_api_identifier_uri      = "api://44444444-4444-4444-8444-444444444444"
  mcp_allowed_client_ids      = ["aebc6443-996d-45c2-90f0-388ff96faa56", "04b07795-8ddb-461a-bbee-02f9e1bf7b46"]
  entra_auth_replace_key_gate = true
}

# Module 04 optional part B mock-only plans: a REST API exposed as an MCP server. Synthetic IDs; nothing is contacted.

run "rest_mcp_default_off_creates_nothing" {
  command = plan
  variables {
    enable_governed_gateway = true
  }
  assert {
    condition = alltrue([
      length(azapi_resource.rest_api) == 0,
      length(azapi_resource.rest_operation) == 0,
      length(azapi_resource.rest_api_policy) == 0,
      length(azapi_resource.rest_mcp_api) == 0,
      length(azapi_resource.rest_mcp_tool) == 0,
      length(azapi_resource.rest_mcp_policy) == 0,
      length(azapi_resource.rest_mcp_prm_operation) == 0,
      length(azapi_resource.rest_mcp_prm_operation_policy) == 0,
      length(azapi_resource.mcp_api) == 1,
      !output.rest_mcp_enabled,
      output.rest_mcp_endpoint == null,
      output.rest_api_name == null,
    ])
    error_message = "Without enable_rest_mcp_demo, part B plans nothing and part A is unchanged."
  }
}

run "rest_mcp_requires_the_gateway" {
  command = plan
  variables {
    enable_rest_mcp_demo = true
  }
  expect_failures = [var.enable_rest_mcp_demo]
}

run "rest_mcp_on_renders_governed_tools" {
  command = plan
  variables {
    enable_governed_gateway = true
    enable_rest_mcp_demo    = true
  }

  assert {
    condition = alltrue([
      azapi_resource.rest_api[0].type == "Microsoft.ApiManagement/service/apis@2025-09-01-preview",
      azapi_resource.rest_api[0].name == "contoso-tickets-api",
      azapi_resource.rest_api[0].body.properties.path == "contoso-tickets",
      azapi_resource.rest_api[0].body.properties.subscriptionRequired == false,
      azapi_resource.rest_api[0].body.properties.protocols == ["https"],
      azapi_resource.rest_operation["list-tickets"].body.properties.urlTemplate == "/tickets",
      azapi_resource.rest_operation["get-ticket"].body.properties.urlTemplate == "/tickets/{ticketId}",
      azapi_resource.rest_operation["get-ticket"].body.properties.templateParameters[0].name == "ticketId",
      azapi_resource.rest_operation["get-ticket"].body.properties.templateParameters[0].required == true,
      length(azapi_resource.rest_operation["list-tickets"].body.properties.responses[0].representations[0].examples.default.value) == 3,
      azapi_resource.rest_operation["list-tickets"].body.properties.responses[0].representations[0].contentType == "application/json",
      azapi_resource.rest_operation["get-ticket"].body.properties.responses[0].representations[0].examples.default.value.id == "CT-1001",
    ])
    error_message = "A synthetic REST API with GET /tickets (3 tickets) and GET /tickets/{ticketId}, JSON examples for mock-response, no subscription key."
  }

  assert {
    condition = alltrue([
      strcontains(azapi_resource.rest_api_policy[0].body.properties.value, "<validate-azure-ad-token tenant-id=\"00000000-0000-4000-8000-000000000000\""),
      strcontains(azapi_resource.rest_api_policy[0].body.properties.value, "<audience>api://44444444-4444-4444-8444-444444444444</audience>"),
      length(regexall("<audience>", azapi_resource.rest_api_policy[0].body.properties.value)) == 2,
      !strcontains(azapi_resource.rest_api_policy[0].body.properties.value, "azure-api.net</audience>"),
      strcontains(azapi_resource.rest_api_policy[0].body.properties.value, "<application-id>aebc6443-996d-45c2-90f0-388ff96faa56</application-id>"),
      strcontains(azapi_resource.rest_api_policy[0].body.properties.value, "<value>user_impersonation</value>"),
      strcontains(azapi_resource.rest_api_policy[0].body.properties.value, "<mock-response status-code=\"200\" content-type=\"application/json\" />"),
      !strcontains(lower(azapi_resource.rest_api_policy[0].body.properties.value), "subscription-key"),
    ])
    error_message = "The backing REST API is never anonymous: MCP API audience only, allowed clients, user_impersonation, then mock-response; no key."
  }

  assert {
    condition = alltrue([
      azapi_resource.rest_mcp_api[0].type == "Microsoft.ApiManagement/service/apis@2025-09-01-preview",
      azapi_resource.rest_mcp_api[0].body.properties.type == "mcp",
      azapi_resource.rest_mcp_api[0].body.properties.path == "contoso-tickets-mcp",
      azapi_resource.rest_mcp_api[0].body.properties.subscriptionRequired == false,
      azapi_resource.rest_mcp_api[0].body.properties.displayName == "Contoso Tickets (REST API exposed as MCP)",
      !can(azapi_resource.rest_mcp_api[0].body.properties.mcpProperties),
      length(azapi_resource.rest_mcp_tool) == 2,
      azapi_resource.rest_mcp_tool["list_tickets"].type == "Microsoft.ApiManagement/service/apis/tools@2025-09-01-preview",
      azapi_resource.rest_mcp_tool["list_tickets"].body.properties.operationId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ApiManagement/service/apim-mcp-p01-0123456789/apis/contoso-tickets-api/operations/list-tickets",
      azapi_resource.rest_mcp_tool["get_ticket"].body.properties.operationId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ApiManagement/service/apim-mcp-p01-0123456789/apis/contoso-tickets-api/operations/get-ticket",
      azapi_resource.rest_mcp_tool["get_ticket"].body.properties.displayName == "get_ticket",
    ])
    error_message = "The REST-backed MCP server (Preview, no backend endpoints, no key) exposes list_tickets and get_ticket mapped to the right operations."
  }

  assert {
    condition = alltrue([
      strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "<validate-azure-ad-token tenant-id=\"00000000-0000-4000-8000-000000000000\""),
      length(regexall("<audience>", azapi_resource.rest_mcp_policy[0].body.properties.value)) == 2,
      strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "<audience>44444444-4444-4444-8444-444444444444</audience>"),
      !strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "azure-api.net</audience>"),
      strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "<claim name=\"scp\" match=\"any\" separator=\" \">"),
      strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "Array.IndexOf(roles, \"Tools.Read\") >= 0 || Array.IndexOf(roles, \"Tools.Write\") >= 0"),
      strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "<rate-limit-by-key calls=\"30\" renewal-period=\"60\" counter-key=\"@(\"workshop-rest-mcp-oid-\" + (string)context.Variables[\"mcp-caller-oid\"])\" />"),
      strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "<trace source=\"workshop-rest-mcp\""),
      strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "resource_metadata=\"https://apim-mcp-p01-0123456789.azure-api.net/.well-known/oauth-protected-resource/contoso-tickets-mcp/mcp\""),
      !strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "<ip-filter"),
      !strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "context.Response.Body"),
      !strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "context.Request.Body"),
      !strcontains(lower(azapi_resource.rest_mcp_policy[0].body.properties.value), "subscription-key"),
    ])
    error_message = "MCP server policy: MCP audience only, scope, Tools.Read or Tools.Write, per-oid rate limit, payload-free trace, PRM challenge; no body access, no key."
  }

  assert {
    condition = alltrue([
      azapi_resource.rest_mcp_prm_operation[0].body.properties.urlTemplate == "/contoso-tickets-mcp/mcp",
      strcontains(azapi_resource.rest_mcp_prm_operation_policy[0].body.properties.value, "\"resource\":\"https://apim-mcp-p01-0123456789.azure-api.net/contoso-tickets-mcp/mcp\""),
      strcontains(azapi_resource.rest_mcp_prm_operation_policy[0].body.properties.value, "\"authorization_servers\":[\"https://login.microsoftonline.com/00000000-0000-4000-8000-000000000000/v2.0\"]"),
      strcontains(azapi_resource.rest_mcp_prm_operation_policy[0].body.properties.value, "\"scopes_supported\":[\"api://44444444-4444-4444-8444-444444444444/user_impersonation\"]"),
      azapi_resource.prm_operation[0].body.properties.urlTemplate == "/workshop-mcp/mcp",
    ])
    error_message = "A second PRM operation on the existing metadata API names the part B resource, the tenant and the module 03 scope; part A metadata is unchanged."
  }

  assert {
    condition = alltrue([
      azurerm_api_management_diagnostic.gateway[0].frontend_response[0].body_bytes == 0,
      azurerm_api_management_diagnostic.gateway[0].backend_response[0].body_bytes == 0,
      output.rest_mcp_enabled,
      output.rest_mcp_endpoint == "https://apim-mcp-p01-0123456789.azure-api.net/contoso-tickets-mcp/mcp",
      output.rest_mcp_resource_metadata_url == "https://apim-mcp-p01-0123456789.azure-api.net/.well-known/oauth-protected-resource/contoso-tickets-mcp/mcp",
      output.rest_api_name == "contoso-tickets-api",
      output.rest_api_endpoint == "https://apim-mcp-p01-0123456789.azure-api.net/contoso-tickets",
    ])
    error_message = "The all-APIs diagnostic keeps 0 body bytes for part B; outputs expose deterministic endpoints (no secret)."
  }
}

run "rest_mcp_follows_ip_filter_and_rate_limit" {
  command = plan
  variables {
    enable_governed_gateway   = true
    enable_rest_mcp_demo      = true
    gateway_allowed_ip_ranges = ["203.0.113.0/24"]
    gateway_rate_limit_calls  = 10
    gateway_rate_limit_period = 30
  }
  assert {
    condition = alltrue([
      strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "<address-range from=\"203.0.113.0\" to=\"203.0.113.255\" />"),
      strcontains(azapi_resource.rest_mcp_policy[0].body.properties.value, "<rate-limit-by-key calls=\"10\" renewal-period=\"30\""),
    ])
    error_message = "Part B follows the same optional IP filter and rate limit as part A."
  }
}
