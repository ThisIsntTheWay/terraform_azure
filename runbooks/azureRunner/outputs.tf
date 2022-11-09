output "runner_internal_ip" {
  description = "Interal IP of the runner."
  value       = azurerm_linux_virtual_machine.runner.private_ip_address
}

output "runner_public_ip" {
  description = "Public IP of the runner."
  value       = azurerm_public_ip.runnerPublicIp.ip_address
}

output "runner_public_fqdn" {
  description = "Public FQDN of the runner."
  value       = azurerm_public_ip.runnerPublicIp.fqdn
}