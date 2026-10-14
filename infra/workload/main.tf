terraform {
  required_version = ">= 1.16.6, < 2.0.0"
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
  stem           = "mcp-${var.participant_prefix}-${var.resource_suffix}"
  compact_prefix = substr(var.participant_prefix, 0, 6)
  legacy_suffix  = length(var.resource_suffix) == 10
  names = {
    resource_group = coalesce(var.existing_resource_group_name, "rg-${local.stem}")
    storage        = local.legacy_suffix ? "stmcp${var.participant_prefix}${var.resource_suffix}" : "st${local.compact_prefix}${var.resource_suffix}"
    function_app   = local.legacy_suffix ? "func-${local.stem}" : "func-mcp-${local.compact_prefix}-${var.resource_suffix}"
    api_management = "apim-${local.stem}"
    portal_plan    = "plan-${local.stem}-portal"
    portal_app     = "web-${local.stem}-portal"
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
  description = "Planned MCP service names only. No MCP endpoint is created. The separate public portal is optional."
  value       = local.names
}

output "resource_tags" {
  value = local.tags
}
