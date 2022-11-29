resource "azurerm_virtual_machine_extension" "runnerCommand" {
  name                       = "${azurerm_linux_virtual_machine.runner.name}-cmd"
  publisher                  = "Microsoft.CPlat.Core"
  type                       = "RunCommandLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    commandToExecute = "curl ${var.linuxScriptFile} | bash -"
  })

  virtual_machine_id = azurerm_linux_virtual_machine.runner.id

  lifecycle {
    ignore_changes = all
  }
}