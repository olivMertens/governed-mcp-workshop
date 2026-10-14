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
