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
    condition = (output.resource_names.function_app == "func-mcp-p01-0123456789" &&
    output.resource_names.api_management == "apim-mcp-p01-0123456789")
    error_message = "Every legacy service name must remain byte-for-byte unchanged."
  }
  assert {
    condition     = output.resource_tags.owner == "alice" && output.resource_tags.expiry == "2099-12-31"
    error_message = "Required ownership tags are missing."
  }
  assert {
    condition     = !contains(keys(output.resource_names), "portal_plan") && !contains(keys(output.resource_names), "portal_app")
    error_message = "GitHub Pages hosting must not advertise Azure portal resources."
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

run "new_suffix_maximum_prefix" {
  command = plan
  variables {
    participant_prefix = "abcdefgh"
    resource_suffix    = "0123456789abcdef"
  }
  assert {
    condition     = output.resource_names.storage == "stabcdef0123456789abcdef" && length(output.resource_names.storage) == 24 && can(regex("^[a-z0-9]{3,24}$", output.resource_names.storage))
    error_message = "Keep all 64 random bits and fit the global Storage name into 24 lowercase alphanumeric characters."
  }
  assert {
    condition     = output.resource_names.function_app == "func-mcp-abcdef-0123456789abcdef" && length(output.resource_names.function_app) == 32
    error_message = "Keep all random bits within the first 32 Function host-ID characters."
  }
  assert {
    condition     = output.resource_group_name == "rg-mcp-abcdefgh-0123456789abcdef" && length(output.resource_group_name) <= 90 && length(output.resource_names.api_management) <= 50
    error_message = "Group and API Management names must preserve the participant identity and fit Azure limits."
  }
  assert {
    condition = alltrue([
      for name in [output.resource_names.function_app, output.resource_names.api_management] :
      length(name) <= 60 && can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", name))
    ])
    error_message = "Service names must use valid DNS-compatible characters without trailing hyphens."
  }
}

run "new_suffix_minimum_prefix" {
  command = plan
  variables {
    participant_prefix = "ab"
    resource_suffix    = "fedcba9876543210"
  }
  assert {
    condition     = output.resource_names.storage == "stabfedcba9876543210" && length(output.resource_names.storage) == 20 && length(output.resource_names.function_app) == 28
    error_message = "The shortest allowed participant prefix must still retain all random bits and valid service lengths."
  }
}

run "shared_group_first_participant" {
  command = plan
  variables {
    participant_prefix           = "abcdefgh"
    resource_suffix              = "0123456789abcdef"
    existing_resource_group_name = "rg-synthetic-shared"
  }
  assert {
    condition     = length(azurerm_resource_group.workshop) == 0 && output.resource_names.resource_group == "rg-synthetic-shared"
    error_message = "A shared administrator-owned group must not be managed."
  }
}

run "shared_group_second_participant" {
  command = plan
  variables {
    participant_prefix           = "abcdefgh"
    resource_suffix              = "fedcba9876543210"
    existing_resource_group_name = "rg-synthetic-shared"
  }
  assert {
    condition = alltrue([
      for key in ["storage", "function_app", "api_management"] :
      output.resource_names[key] != run.shared_group_first_participant.resource_names[key]
    ])
    error_message = "Identical participant labels in one shared group must still have different names for every service."
  }
  assert {
    condition     = output.resource_names.resource_group == run.shared_group_first_participant.resource_names.resource_group && length(azurerm_resource_group.workshop) == 0
    error_message = "Different participant resources must neither rename nor manage the shared group."
  }
}

run "invalid_prefix_length" {
  command = plan
  variables {
    participant_prefix = "abcdefghi"
    resource_suffix    = "0123456789abcdef"
  }
  expect_failures = [var.participant_prefix]
}

run "invalid_intermediate_suffix" {
  command = plan
  variables {
    resource_suffix = "0123456789abcd"
  }
  expect_failures = [var.resource_suffix]
}
