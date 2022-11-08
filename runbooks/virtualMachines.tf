/*resource "azurerm_managed_disk" "vmDisk" {
  count = length(var.vmConfiguration)

  name = "${var.vmConfiguration[count.index]}-disk"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"

  tags = {
    author = var.author
  }
}*/

resource "azurerm_network_interface" "nic" {
  for_each = var.vmConfiguration

  name = "${each.key}-nic"
  #name                = "${var.tenant}-nic-${var.serverType}-prod-chno-00${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.tags
}

resource "azurerm_windows_virtual_machine" "main" {
  for_each = var.vmConfiguration

  # Bug: "Name" constrained to 15 characters
  name = each.key
  #name  = "${upper(var.tenant)}${upper(var.serverType)}00${count.index}"
  #computer_name         = "${var.tenant}-${var.serverType}-prod-chno-001"

  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]
  size                  = each.value

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

  tags = local.tags
}