resource "azurerm_network_interface" "nic" {
  count               = length(var.vmNames)

  name = "${var.vmNames[count.index]}-nic"
  #name                = "${var.tenant}-nic-${var.serverType}-prod-chno-00${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "main" {
  count = length(var.vmNames)

  # Bug: "Name" constrained to 15 characters
  name = var.vmNames[count.index]
  #name  = "${upper(var.tenant)}${upper(var.serverType)}00${count.index}"
  #computer_name         = "${var.tenant}-${var.serverType}-prod-chno-001"

  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  size                  = var.serverSize

  admin_username = var.adminUsername
  admin_password = var.adminPassword

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.serverSku
    version   = "latest"
  }
}