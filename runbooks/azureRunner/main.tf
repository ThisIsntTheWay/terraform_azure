locals {
  location = {
    name = "switzerlandnorth"
    id   = "chno"
  }

  resourcegroup = "terraform"
  adminname     = "azureGuy"

  pubkey = file("${path.module}/azure.pub")
}

resource "azurerm_virtual_network" "runnerVnet" {
  name                = "runner-${local.location.id}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = local.location.name
  resource_group_name = local.resourcegroup
}

resource "azurerm_subnet" "runnerSnet" {
  name                 = "internal"
  resource_group_name  = local.resourcegroup
  virtual_network_name = azurerm_virtual_network.runnerVnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "runnerPublicIp" {
  name                = "runner-${local.location.id}-ip"
  resource_group_name = local.resourcegroup
  location            = local.location.name
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "runnerNic" {
  name                = "terraform-runner-${local.location.id}-nic"
  location            = local.location.name
  resource_group_name = local.resourcegroup

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.runnerSnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.runnerPublicIp.id
  }
}

resource "azurerm_network_security_group" "runnerNsg" {
  name                = "terraform-runner-${local.location.id}-nsg"
  location            = local.location.name
  resource_group_name = local.resourcegroup

  security_rule {
    name                       = "AllowSSHInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "runnerNsgAssociation" {
  subnet_id                 = azurerm_subnet.runnerSnet.id
  network_security_group_id = azurerm_network_security_group.runnerNsg.id
}

resource "azurerm_linux_virtual_machine" "runner" {
  name                = "runner-${local.location.id}-vm"
  resource_group_name = local.resourcegroup
  location            = local.location.name

  size = "Standard_B1s"

  admin_username = local.adminname
  network_interface_ids = [
    azurerm_network_interface.runnerNic.id
  ]

  admin_ssh_key {
    username   = local.adminname
    public_key = local.pubkey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    # Use ARM template for reference
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}