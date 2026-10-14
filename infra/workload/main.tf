terraform {
  required_version = ">= 1.16.5, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.9.0"
    }
  }
}

provider "azurerm" {
  use_cli                         = true
  resource_provider_registrations = "none"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

locals {
  stem = "mcp-${var.participant_prefix}-${var.resource_suffix}"
  names = {
    resource_group = coalesce(var.existing_resource_group_name, "rg-${local.stem}")
    storage        = "stmcp${var.participant_prefix}${var.resource_suffix}"
    function_app   = "func-${local.stem}"
    api_management = "apim-${local.stem}"
  }
  tags = {
    workshop = local.stem
    owner    = var.owner
    expiry   = var.expiry
  }
}

resource "azurerm_resource_group" "workshop" {
  count    = var.existing_resource_group_name == null ? 1 : 0
  name     = local.names.resource_group
  location = var.location
  tags     = local.tags
}

data "azurerm_resource_group" "existing" {
  count = var.existing_resource_group_name == null ? 0 : 1
  name  = var.existing_resource_group_name
}

output "resource_group_name" {
  value = var.existing_resource_group_name == null ? azurerm_resource_group.workshop[0].name : data.azurerm_resource_group.existing[0].name
}

output "resource_names" {
  description = "Planned service names only. This foundation creates no service or MCP endpoint."
  value       = local.names
}

output "resource_tags" {
  value = local.tags
}
