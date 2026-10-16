# Module 02 - optional private storage for tenants whose Azure Policy forces Storage public network access to Disabled.
# Opt-in with mcp_private_storage = true (requires enable_mcp_server). Pattern from Microsoft Learn:
# "Azure Functions networking options" (Flex Consumption: dedicated /27 subnet delegated to Microsoft.App/environments)
# and "Use private endpoints for Azure Storage" (privatelink.blob/queue.core.windows.net).
# Only outbound traffic from the Function App to Storage becomes private. The MCP endpoint and its key gate are unchanged.

locals {
  mcp_private_storage      = local.mcp_enabled && var.mcp_private_storage
  mcp_storage_subresources = local.mcp_private_storage ? toset(["blob", "queue"]) : toset([])
}

# Dedicated to Flex Consumption outbound integration. Outbound Internet access of delegated subnets is managed by the
# service, so the private-subnet setting does not apply here. Names must not contain underscores (Flex limitation).
resource "azurerm_subnet" "mcp_integration" {
  count                = local.mcp_private_storage ? 1 : 0
  name                 = "snet-functions"
  resource_group_name  = local.workload_group
  virtual_network_name = azurerm_virtual_network.gateway[0].name
  address_prefixes     = [local.mcp_integration_subnet]

  delegation {
    name = "flex-consumption-integration"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "storage" {
  for_each            = local.mcp_storage_subresources
  name                = "privatelink.${each.key}.core.windows.net"
  resource_group_name = local.workload_group
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  for_each             = local.mcp_storage_subresources
  name                 = "link-${local.stem}-${each.key}"
  private_dns_zone_id  = azurerm_private_dns_zone.storage[each.key].id
  virtual_network_id   = azurerm_virtual_network.gateway[0].id
  registration_enabled = false
  tags                 = local.tags
}

# One endpoint per Storage service the server uses: blob (host and deployment package) and queue (synthetic tickets).
resource "azurerm_private_endpoint" "storage" {
  for_each            = local.mcp_storage_subresources
  name                = "pe-${local.stem}-st-${each.key}"
  resource_group_name = local.workload_group
  location            = local.workload_location
  subnet_id           = azurerm_subnet.gateway_private_endpoints[0].id
  tags                = local.tags

  private_service_connection {
    name                           = "st-${each.key}"
    private_connection_resource_id = azurerm_storage_account.mcp[0].id
    subresource_names              = [each.key]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-${each.key}"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage[each.key].id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.storage]
}
