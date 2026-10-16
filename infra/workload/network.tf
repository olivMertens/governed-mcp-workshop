# Module 04 - private path from API Management to the MCP Function App (level 2). Opt-in with enable_governed_gateway.
# The virtual network and private endpoint subnet are shared with the module 02 private storage opt-in (private-storage.tf).
# Pattern from Microsoft Learn: "Integrate an Azure API Management instance with a private virtual network for outbound
# connections" (Standard v2: dedicated subnet delegated to Microsoft.Web/serverFarms, NSG required, Key Vault outbound rule)
# and "Use private endpoints for Azure App Service apps" (privatelink.azurewebsites.net, public access disabled).
# The gateway stays public; only its outbound calls enter the virtual network. Clients never see the private path.

locals {
  gateway_enabled         = local.mcp_auth_enabled && var.enable_governed_gateway
  gateway_function_locked = local.gateway_enabled && var.gateway_lock_function
  # Module 02 private storage and module 04 share one virtual network and one private endpoint subnet.
  network_enabled        = local.gateway_enabled || local.mcp_private_storage
  gateway_apim_subnet    = cidrsubnet(var.gateway_vnet_address_space, 24 - tonumber(split("/", var.gateway_vnet_address_space)[1]), 0)
  gateway_pe_subnet      = cidrsubnet(var.gateway_vnet_address_space, 27 - tonumber(split("/", var.gateway_vnet_address_space)[1]), 8)
  mcp_integration_subnet = cidrsubnet(var.gateway_vnet_address_space, 27 - tonumber(split("/", var.gateway_vnet_address_space)[1]), 9)
  gateway_names = {
    virtual_network         = "vnet-${local.stem}"
    apim_subnet             = "snet-apim"
    private_endpoint_subnet = "snet-private-endpoints"
    apim_nsg                = "nsg-${local.stem}-apim"
    function_endpoint       = "pe-${local.stem}-func"
    apim_identity           = "id-${local.stem}-apim"
  }
}

resource "azurerm_virtual_network" "gateway" {
  count               = local.network_enabled ? 1 : 0
  name                = local.gateway_names.virtual_network
  resource_group_name = local.workload_group
  location            = local.workload_location
  address_space       = [var.gateway_vnet_address_space]
  tags                = local.tags
}

# Dedicated to one API Management instance, delegated to Microsoft.Web/serverFarms (Standard v2 outbound integration).
resource "azurerm_subnet" "gateway_apim" {
  count                           = local.gateway_enabled ? 1 : 0
  name                            = local.gateway_names.apim_subnet
  resource_group_name             = local.workload_group
  virtual_network_name            = azurerm_virtual_network.gateway[0].name
  address_prefixes                = [local.gateway_apim_subnet]
  default_outbound_access_enabled = false

  delegation {
    name = "apim-outbound-integration"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "gateway_private_endpoints" {
  count                             = local.network_enabled ? 1 : 0
  name                              = local.gateway_names.private_endpoint_subnet
  resource_group_name               = local.workload_group
  virtual_network_name              = azurerm_virtual_network.gateway[0].name
  address_prefixes                  = [local.gateway_pe_subnet]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Enabled"
}

# Required by the Standard v2 integration. Inbound rules do not apply to outbound integration (documented);
# the outbound rule is the documented Key Vault dependency. Default rules keep virtual network traffic to the endpoint.
resource "azurerm_network_security_group" "gateway_apim" {
  count               = local.gateway_enabled ? 1 : 0
  name                = local.gateway_names.apim_nsg
  resource_group_name = local.workload_group
  location            = local.workload_location
  tags                = local.tags

  security_rule {
    name                       = "AllowKeyVaultOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureKeyVault"
    description                = "API Management dependency on Azure Key Vault (Standard v2 outbound integration)."
  }
}

resource "azurerm_subnet_network_security_group_association" "gateway_apim" {
  count                     = local.gateway_enabled ? 1 : 0
  subnet_id                 = azurerm_subnet.gateway_apim[0].id
  network_security_group_id = azurerm_network_security_group.gateway_apim[0].id
}

resource "azurerm_private_dns_zone" "functions" {
  count               = local.gateway_enabled ? 1 : 0
  name                = "privatelink.azurewebsites.net"
  resource_group_name = local.workload_group
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "functions" {
  count                = local.gateway_enabled ? 1 : 0
  name                 = "link-${local.stem}"
  private_dns_zone_id  = azurerm_private_dns_zone.functions[0].id
  virtual_network_id   = azurerm_virtual_network.gateway[0].id
  registration_enabled = false
  tags                 = local.tags
}

# Inbound private endpoint of the Function App ("sites"). The zone group writes the app and scm A records.
resource "azurerm_private_endpoint" "function" {
  count               = local.gateway_enabled ? 1 : 0
  name                = local.gateway_names.function_endpoint
  resource_group_name = local.workload_group
  location            = local.workload_location
  subnet_id           = azurerm_subnet.gateway_private_endpoints[0].id
  tags                = local.tags

  private_service_connection {
    name                           = "func-sites"
    private_connection_resource_id = azurerm_function_app_flex_consumption.mcp[0].id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "functions"
    private_dns_zone_ids = [azurerm_private_dns_zone.functions[0].id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.functions]
}

output "gateway_function_public_access_disabled" {
  description = "True once module 04 stage 2 disabled public network access on the Function App (only the private endpoint remains)."
  value       = local.mcp_enabled ? !azurerm_function_app_flex_consumption.mcp[0].public_network_access_enabled : false
}
