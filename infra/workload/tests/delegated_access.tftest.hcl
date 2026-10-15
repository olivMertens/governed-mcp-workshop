mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_storage_account" {
    defaults = {
      id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.Storage/storageAccounts/stsynthetic"
      primary_blob_endpoint  = "https://stsynthetic.blob.core.windows.net/"
      primary_queue_endpoint = "https://stsynthetic.queue.core.windows.net/"
    }
  }
  mock_resource "azurerm_storage_container" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.Storage/storageAccounts/stsynthetic/blobServices/default/containers/reports"
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
  mock_data "azurerm_client_config" {
    defaults = {
      object_id = "9b000000-0000-4000-8000-0000000000b9"
      tenant_id = "00000000-0000-4000-8000-000000000000"
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

# Distinct synthetic identities, so the tests prove that the three identities are never mixed.
override_resource {
  target          = azurerm_user_assigned_identity.delegated_obo
  override_during = plan
  values = {
    id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-obo"
    client_id    = "55555555-5555-4555-8555-555555555555"
    principal_id = "0b0a5500-0000-4000-8000-000000000005"
  }
}

override_resource {
  target          = azurerm_user_assigned_identity.delegated_report
  override_during = plan
  values = {
    id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-report"
    client_id    = "66666666-6666-4666-8666-666666666666"
    principal_id = "7e9047a0-0000-4000-8000-000000000007"
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

# Module 05 mock-only plans: On-Behalf-Of vs app-only. Synthetic IDs; nothing is contacted or created.

run "delegated_default_off_keeps_modules_02_to_04" {
  command = plan

  assert {
    condition = alltrue([
      length(azurerm_user_assigned_identity.delegated_obo) == 0,
      length(azurerm_user_assigned_identity.delegated_report) == 0,
      length(azurerm_storage_container.reports) == 0,
      length(azurerm_role_assignment.report_app_reader) == 0,
      length(azurerm_role_assignment.report_persona_reader) == 0,
      length(azurerm_role_assignment.report_publisher) == 0,
      length(data.azurerm_client_config.delegated) == 0,
      length(azurerm_function_app_flex_consumption.mcp[0].identity[0].identity_ids) == 1,
      [for key in keys(azurerm_function_app_flex_consumption.mcp[0].app_settings) : key if startswith(key, "WORKSHOP_")] == ["WORKSHOP_IDENTITY_CLIENT_ID"],
      !output.delegated_access_enabled,
      output.entra_module05_tfvars == null,
    ])
    error_message = "Without enable_delegated_access nothing new is planned and the server keeps the module 02 demonstrations."
  }
}

run "delegated_two_separate_identities_one_container_and_container_scoped_roles" {
  command = plan
  variables {
    enable_delegated_access = true
    delegated_persona_object_ids = {
      alice = "a11ce000-0000-4000-8000-000000000001"
      bob   = "b0b00000-0000-4000-8000-000000000002"
    }
  }

  assert {
    condition = alltrue([
      azurerm_user_assigned_identity.delegated_obo[0].name == "id-mcp-p01-0123456789-obo",
      azurerm_user_assigned_identity.delegated_report[0].name == "id-mcp-p01-0123456789-report",
      azurerm_storage_container.reports[0].name == "reports",
      azurerm_storage_container.reports[0].container_access_type == "private",
      toset(azurerm_function_app_flex_consumption.mcp[0].identity[0].identity_ids) == toset([
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-synthetic",
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-obo",
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-report",
      ]),
    ])
    error_message = "Module 05 adds exactly two new identities (OBO assertion, app-only reader) and one private report container."
  }

  assert {
    condition = alltrue([
      azurerm_role_assignment.report_app_reader[0].role_definition_name == "Storage Blob Data Reader",
      azurerm_role_assignment.report_app_reader[0].principal_id == "7e9047a0-0000-4000-8000-000000000007",
      azurerm_role_assignment.report_persona_reader["alice"].role_definition_name == "Storage Blob Data Reader",
      azurerm_role_assignment.report_persona_reader["alice"].principal_id == "a11ce000-0000-4000-8000-000000000001",
      azurerm_role_assignment.report_persona_reader["alice"].principal_type == "User",
      toset(keys(azurerm_role_assignment.report_persona_reader)) == toset(["alice"]),
      azurerm_role_assignment.report_publisher[0].role_definition_name == "Storage Blob Data Contributor",
      azurerm_role_assignment.report_publisher[0].principal_id == "9b000000-0000-4000-8000-0000000000b9",
      alltrue([for scope in concat(azurerm_role_assignment.report_app_reader[*].scope, [for role in values(azurerm_role_assignment.report_persona_reader) : role.scope], azurerm_role_assignment.report_publisher[*].scope) :
      scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synthetic/providers/Microsoft.Storage/storageAccounts/stsynthetic/blobServices/default/containers/reports"]),
    ])
    error_message = "Every module 05 role is scoped to the one report container: app-only identity and Alice read, the publisher writes, Bob gets nothing."
  }

  assert {
    condition = !anytrue([
      for role in concat(azurerm_role_assignment.report_app_reader, values(azurerm_role_assignment.report_persona_reader), azurerm_role_assignment.report_publisher) :
      contains(["0b0a5500-0000-4000-8000-000000000005", "22222222-2222-2222-2222-222222222222", "b0b00000-0000-4000-8000-000000000002"], role.principal_id)
    ])
    error_message = "The OBO assertion identity, the module 02 host identity and Bob never receive a module 05 Storage role."
  }

  assert {
    condition = alltrue([
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_DELEGATED_ACCESS"] == "enabled",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_TENANT_ID"] == "00000000-0000-4000-8000-000000000000",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_MCP_API_CLIENT_ID"] == "44444444-4444-4444-8444-444444444444",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_OBO_ASSERTION_CLIENT_ID"] == "55555555-5555-4555-8555-555555555555",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_REPORT_IDENTITY_CLIENT_ID"] == "66666666-6666-4666-8666-666666666666",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_REPORT_CONTAINER_URL"] == "https://stsynthetic.blob.core.windows.net/reports",
      jsondecode(azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_PERSONA_OBJECT_IDS"]) == { alice = "a11ce000-0000-4000-8000-000000000001", bob = "b0b00000-0000-4000-8000-000000000002" },
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_IDENTITY_CLIENT_ID"] == "11111111-1111-1111-1111-111111111111",
    ])
    error_message = "The server gets the tenant, MCP API client ID, both new identity client IDs, the container URL and the persona map, and keeps the host identity for tickets."
  }

  assert {
    condition = !anytrue([
      for key, value in azurerm_function_app_flex_consumption.mcp[0].app_settings :
      can(regex("(?i)secret|password|AccountKey=|SharedAccessSignature|[?&]sig=", "${key}=${value}"))
    ]) && !contains(keys(azurerm_function_app_flex_consumption.mcp[0].app_settings), "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET")
    error_message = "No client secret, key or SAS in the app settings: the federated credential replaces any secret."
  }

  assert {
    condition = alltrue([
      output.delegated_access_enabled,
      output.delegated_obo_identity_principal_id == "0b0a5500-0000-4000-8000-000000000005",
      output.entra_module05_tfvars.obo_identity_principal_id == "0b0a5500-0000-4000-8000-000000000005",
      output.entra_module05_tfvars.enable_delegated_access,
      output.delegated_report_container_url == "https://stsynthetic.blob.core.windows.net/reports",
      output.delegated_report_blob_name == "monthly-usage.json",
      length(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2) == 1,
    ])
    error_message = "The identity administrator receives the OBO identity principal ID for the federated credential subject; module 03 authentication stays in place."
  }
}

run "delegated_explicit_publisher_and_no_personas" {
  command = plan
  variables {
    enable_delegated_access              = true
    delegated_report_publisher_object_id = "9c000000-0000-4000-8000-0000000000c9"
  }

  assert {
    condition = alltrue([
      length(data.azurerm_client_config.delegated) == 0,
      azurerm_role_assignment.report_publisher[0].principal_id == "9c000000-0000-4000-8000-0000000000c9",
      length(azurerm_role_assignment.report_persona_reader) == 0,
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_PERSONA_OBJECT_IDS"] == "{}",
    ])
    error_message = "An explicit publisher replaces the signed-in user; without persona IDs no user role is planned."
  }
}

run "delegated_works_with_the_governed_gateway" {
  command = plan
  variables {
    enable_delegated_access = true
    enable_governed_gateway = true
    gateway_lock_function   = true
  }

  assert {
    condition     = !azurerm_function_app_flex_consumption.mcp[0].public_network_access_enabled && azurerm_function_app_flex_consumption.mcp[0].app_settings["WORKSHOP_DELEGATED_ACCESS"] == "enabled"
    error_message = "Module 05 changes no network setting: behind the module 04 gateway the Function stays private."
  }
}

run "delegated_requires_module_03" {
  command = plan
  variables {
    enable_entra_auth           = false
    entra_auth_replace_key_gate = false
    enable_delegated_access     = true
  }
  expect_failures = [var.enable_delegated_access]
}

run "delegated_rejects_bob_sharing_alices_account" {
  command = plan
  variables {
    enable_delegated_access = true
    delegated_persona_object_ids = {
      alice = "a11ce000-0000-4000-8000-000000000001"
      bob   = "a11ce000-0000-4000-8000-000000000001"
    }
  }
  expect_failures = [var.delegated_persona_object_ids]
}

run "delegated_rejects_non_canonical_object_ids" {
  command = plan
  variables {
    enable_delegated_access = true
    delegated_persona_object_ids = {
      alice = "alice@contoso.example"
    }
  }
  expect_failures = [var.delegated_persona_object_ids]
}
