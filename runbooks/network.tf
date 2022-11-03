resource "azurerm_virtual_network" "vnet" {
  name                = "${var.tenant}-vnet-lan-prod-chno-001"
  address_space       = ["10.40.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "snet" {
  name                 = "${var.tenant}-snet-lan-prod-chno-001"
  address_prefixes     = ["10.40.10.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.tenant}-nsg-lan-prod-chno-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRDPInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = 3389
    destination_port_range     = 3389
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Tenant = var.tenant
    Author = var.author
  }
}

