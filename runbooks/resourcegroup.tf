
resource "azurerm_resource_group" "rg" {
  name     = "${var.tenant}-chno-prod-001"
  location = var.resourceLocation

  tags = {
    Environment = "prod"
    Author      = var.author
  }
}