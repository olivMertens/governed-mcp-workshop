mock_provider "azurerm" {}

variables {
  participant_prefix = "p01"
  resource_suffix    = "0123456789"
  location           = "westeurope"
  owner              = "alice"
  expiry             = "2099-12-31"
}

run "dedicated_group" {
  command = plan
  assert {
    condition     = length(azurerm_resource_group.workshop) == 1 && length(data.azurerm_resource_group.existing) == 0
    error_message = "Default mode must manage exactly one dedicated resource group."
  }
  assert {
    condition     = output.resource_group_name == "rg-mcp-p01-0123456789" && output.resource_names.storage == "stmcpp010123456789"
    error_message = "Names must use the saved participant prefix and suffix."
  }
  assert {
    condition     = output.resource_tags.owner == "alice" && output.resource_tags.expiry == "2099-12-31"
    error_message = "Required ownership tags are missing."
  }
  assert {
    condition     = length(azurerm_service_plan.portal) == 0 && length(azurerm_linux_web_app.portal) == 0 && output.public_portal_url == null
    error_message = "Default mode must create no billable portal or pretend that a URL exists."
  }
}

run "existing_group" {
  command = plan
  variables {
    existing_resource_group_name = "rg-synthetic-admin-provided"
  }
  assert {
    condition     = length(azurerm_resource_group.workshop) == 0 && length(data.azurerm_resource_group.existing) == 1
    error_message = "Existing group mode must read, never manage, the administrator's group."
  }
  assert {
    condition     = output.resource_names.resource_group == "rg-synthetic-admin-provided"
    error_message = "Name outputs must preserve the administrator-provided group."
  }
}

run "different_participant" {
  command = plan
  variables {
    resource_suffix = "abcdef0123"
  }
  assert {
    condition     = output.resource_names.storage != run.dedicated_group.resource_names.storage && output.resource_group_name != run.dedicated_group.resource_group_name
    error_message = "Different participant suffixes must produce different group and global service names."
  }
}

run "invalid_suffix" {
  command = plan
  variables {
    resource_suffix = "same"
  }
  expect_failures = [var.resource_suffix]
}

run "public_portal_opt_in" {
  command = plan
  variables {
    public_portal_enabled = true
  }
  assert {
    condition     = length(azurerm_service_plan.portal) == 1 && azurerm_service_plan.portal[0].sku_name == "B1" && azurerm_service_plan.portal[0].os_type == "Linux"
    error_message = "An opt-in must provision exactly one B1 Linux plan."
  }
  assert {
    condition     = azurerm_linux_web_app.portal[0].https_only && !azurerm_linux_web_app.portal[0].ftp_publish_basic_authentication_enabled && !azurerm_linux_web_app.portal[0].webdeploy_publish_basic_authentication_enabled
    error_message = "Portal TLS and secretless publishing protections must remain enabled."
  }
  assert {
    condition     = azurerm_linux_web_app.portal[0].site_config[0].ftps_state == "Disabled" && azurerm_linux_web_app.portal[0].site_config[0].application_stack[0].node_version == "22-lts" && azurerm_linux_web_app.portal[0].site_config[0].app_command_line == "node server.mjs"
    error_message = "Use the selected supported runtime and read-only server; do not add FTP or implicit build/start behavior."
  }
}
