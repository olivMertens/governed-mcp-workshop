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

# Module 03 mock-only plans: built-in Microsoft Entra authentication on the MCP Function App.
# Synthetic tenant and client IDs; no tenant or subscription is contacted.

run "entra_auth_default_off_keeps_level_0" {
  command = plan
  variables {
    enable_mcp_server = true
  }
  assert {
    condition = alltrue([
      length(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2) == 0,
      !contains(keys(azurerm_function_app_flex_consumption.mcp[0].app_settings), "AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel"),
      !contains(keys(azurerm_function_app_flex_consumption.mcp[0].app_settings), "WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES"),
      !output.mcp_auth_enabled,
      output.mcp_auth_audience == null,
      output.mcp_auth_scope == null,
    ])
    error_message = "Without the module 03 opt-in, module 02 stays key-protected: no auth block and no anonymous webhook override."
  }
}

run "entra_auth_enabled_requires_token_for_one_audience" {
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
      length(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2) == 1,
      azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].auth_enabled,
      azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].require_authentication,
      azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].unauthenticated_action == "Return401",
      azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].require_https,
      azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].default_provider == "azureactivedirectory",
      try(length(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].excluded_paths), 0) == 0,
    ])
    error_message = "Built-in authentication must require authentication everywhere and return 401 to unauthenticated callers."
  }

  assert {
    condition = alltrue([
      azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].active_directory_v2[0].client_id == "44444444-4444-4444-8444-444444444444",
      azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].active_directory_v2[0].tenant_auth_endpoint == "https://login.microsoftonline.com/00000000-0000-4000-8000-000000000000/v2.0",
      toset(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].active_directory_v2[0].allowed_audiences) == toset(["api://44444444-4444-4444-8444-444444444444", "44444444-4444-4444-8444-444444444444"]),
      toset(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].active_directory_v2[0].allowed_applications) == toset(["aebc6443-996d-45c2-90f0-388ff96faa56", "04b07795-8ddb-461a-bbee-02f9e1bf7b46"]),
      !azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].active_directory_v2[0].www_authentication_disabled,
    ])
    error_message = "Tokens must come from the workshop tenant, for the MCP API audience only, through an allowed client."
  }

  assert {
    condition = alltrue([
      try(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].active_directory_v2[0].client_secret_setting_name, null) == null,
      try(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].active_directory_v2[0].client_secret_certificate_thumbprint, null) == null,
      !azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].login[0].token_store_enabled,
    ])
    error_message = "No client secret or certificate, and no token store: the server only validates bearer tokens."
  }

  assert {
    condition = alltrue([
      azurerm_function_app_flex_consumption.mcp[0].app_settings["AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel"] == "Anonymous",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES"] == "api://44444444-4444-4444-8444-444444444444/user_impersonation",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WEBSITE_AUTH_AAD_ALLOWED_TENANTS"] == "00000000-0000-4000-8000-000000000000",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["AzureWebJobsStorage__credential"] == "managedidentity",
      azurerm_function_app_flex_consumption.mcp[0].app_settings["TICKET_QUEUE_NAME"] == "tickets",
    ])
    error_message = "The key gate is replaced by Entra only together with PRM (Preview) and the tenant restriction; level 0 settings stay."
  }

  assert {
    condition = (
      output.mcp_auth_enabled &&
      output.mcp_auth_audience == "api://44444444-4444-4444-8444-444444444444" &&
      output.mcp_auth_scope == "api://44444444-4444-4444-8444-444444444444/user_impersonation" &&
      output.mcp_auth_issuer == "https://login.microsoftonline.com/00000000-0000-4000-8000-000000000000/v2.0" &&
      output.mcp_key_gate_replaced
    )
    error_message = "Outputs must expose the audience, scope and issuer the validator expects (no secret)."
  }
}

run "entra_auth_requires_the_mcp_server" {
  command = plan
  variables {
    enable_entra_auth      = true
    entra_tenant_id        = "00000000-0000-4000-8000-000000000000"
    mcp_api_client_id      = "44444444-4444-4444-8444-444444444444"
    mcp_api_identifier_uri = "api://44444444-4444-4444-8444-444444444444"
    mcp_allowed_client_ids = ["aebc6443-996d-45c2-90f0-388ff96faa56"]
  }
  expect_failures = [var.enable_entra_auth]
}

run "entra_auth_requires_ids" {
  command = plan
  variables {
    enable_mcp_server = true
    enable_entra_auth = true
  }
  expect_failures = [var.enable_entra_auth]
}

run "entra_auth_rejects_non_api_audience" {
  command = plan
  variables {
    mcp_api_identifier_uri = "https://graph.microsoft.com"
  }
  expect_failures = [var.mcp_api_identifier_uri]
}

run "entra_auth_rejects_wildcard_client" {
  command = plan
  variables {
    mcp_allowed_client_ids = ["*"]
  }
  expect_failures = [var.mcp_allowed_client_ids]
}

run "entra_auth_stage_1_keeps_the_key_gate" {
  command = plan
  variables {
    enable_mcp_server      = true
    enable_entra_auth      = true
    entra_tenant_id        = "00000000-0000-4000-8000-000000000000"
    mcp_api_client_id      = "44444444-4444-4444-8444-444444444444"
    mcp_api_identifier_uri = "api://44444444-4444-4444-8444-444444444444"
    mcp_allowed_client_ids = ["aebc6443-996d-45c2-90f0-388ff96faa56"]
  }
  assert {
    condition = alltrue([
      length(azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2) == 1,
      azurerm_function_app_flex_consumption.mcp[0].auth_settings_v2[0].require_authentication,
      !contains(keys(azurerm_function_app_flex_consumption.mcp[0].app_settings), "AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel"),
      azurerm_function_app_flex_consumption.mcp[0].app_settings["WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES"] == "api://44444444-4444-4444-8444-444444444444/user_impersonation",
      !output.mcp_key_gate_replaced,
    ])
    error_message = "Stage 1 enforces Entra in front of the key; the key gate is dropped only in a later apply."
  }
}

run "entra_auth_key_gate_replacement_requires_entra" {
  command = plan
  variables {
    enable_mcp_server           = true
    entra_auth_replace_key_gate = true
  }
  expect_failures = [var.entra_auth_replace_key_gate]
}
# Optional participant portal: prefill only non-secret connection values from this participant's own deployment.

run "portal_prefill_absent_without_mcp_server" {
  command = plan
  variables {
    public_portal_enabled = true
  }
  assert {
    condition = alltrue([
      !contains(keys(azurerm_linux_web_app.portal[0].app_settings), "WORKSHOP_MCP_ENDPOINT"),
      !contains(keys(azurerm_linux_web_app.portal[0].app_settings), "WORKSHOP_MCP_SCOPE"),
    ])
    error_message = "Without a deployed MCP server the portal must not advertise an endpoint."
  }
}

run "portal_prefill_level_0_endpoint_only" {
  command = plan
  variables {
    public_portal_enabled = true
    enable_mcp_server     = true
  }
  assert {
    condition = alltrue([
      azurerm_linux_web_app.portal[0].app_settings["WORKSHOP_MCP_ENDPOINT"] == "https://func-mcp-p01-0123456789.azurewebsites.net/runtime/webhooks/mcp",
      !contains(keys(azurerm_linux_web_app.portal[0].app_settings), "WORKSHOP_MCP_SCOPE"),
    ])
    error_message = "Level 0 prefills only the endpoint URL; the system key is never copied to the portal."
  }
}

run "portal_prefill_entra_scope_without_secrets" {
  command = plan
  variables {
    public_portal_enabled  = true
    enable_mcp_server      = true
    enable_entra_auth      = true
    entra_tenant_id        = "00000000-0000-4000-8000-000000000000"
    mcp_api_client_id      = "44444444-4444-4444-8444-444444444444"
    mcp_api_identifier_uri = "api://44444444-4444-4444-8444-444444444444"
    mcp_allowed_client_ids = ["aebc6443-996d-45c2-90f0-388ff96faa56"]
  }
  assert {
    condition = alltrue([
      azurerm_linux_web_app.portal[0].app_settings["WORKSHOP_MCP_SCOPE"] == "api://44444444-4444-4444-8444-444444444444/user_impersonation",
      toset(keys(azurerm_linux_web_app.portal[0].app_settings)) == toset(["SCM_DO_BUILD_DURING_DEPLOYMENT", "WEBSITE_RUN_FROM_PACKAGE", "WORKSHOP_MCP_ENDPOINT", "WORKSHOP_MCP_SCOPE"]),
    ])
    error_message = "The portal receives only the endpoint and delegated scope: no tenant ID, key, secret or connection string."
  }
}
