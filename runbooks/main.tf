# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  backend "azurerm" {
    # The following should be provided with -backend-config
    #resource_group_name  = var.storageAccountRg
    #storage_account_name = var.storageAccountName
    #container_name       = var.storageAccountContainer

    key = "terraform.tfstate"
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

module "runner" {
  source = "./azureRunner"
  # terraform apply "-target=module.runner.azurerm_linux_virtual_machine.runner"
}