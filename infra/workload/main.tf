terraform {
  required_version = ">= 1.16.6, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.9.0"
    }
    # Module 04 only: API Management MCP server APIs (api-version 2025-09-01-preview, Preview) have no AzureRM resource.
    azapi = {
      source  = "Azure/azapi"
      version = "= 2.13.0"
    }
  }
}

provider "azapi" {
  use_cli                    = true
  skip_provider_registration = true
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
    resource_group       = coalesce(var.existing_resource_group_name, "rg-${local.stem}")
    storage              = local.legacy_suffix ? "stmcp${var.participant_prefix}${var.resource_suffix}" : "st${local.compact_prefix}${var.resource_suffix}"
    function_app         = local.legacy_suffix ? "func-${local.stem}" : "func-mcp-${local.compact_prefix}-${var.resource_suffix}"
    api_management       = "apim-${local.stem}"
    portal_plan          = "plan-${local.stem}-portal"
    portal_app           = "web-${local.stem}-portal"
    function_plan        = "plan-${local.stem}-func"
    function_identity    = "id-${local.stem}-func"
    obo_identity         = "id-${local.stem}-obo"
    report_identity      = "id-${local.stem}-report"
    log_analytics        = "log-${local.stem}"
    application_insights = "appi-${local.stem}"
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
  description = "Deterministic service names. Module 02 MCP resources exist only when enable_mcp_server is true; later names stay planned. The public portal is optional."
  value       = local.names
}

output "resource_tags" {
  value = local.tags
}
