# ===================================================
# Virtual Machines
variable "serverType" {
  description = "What type of service the VM will provide (ap, dc, db...)"
}

variable "serverSize" {
  description = "Size of the VM, as defined here:\nhttps://azureprice.net/?region=switzerlandnorth"
  default     = "Standard_A2_v2"
}

variable "serverSku" {
  description = "SKU of the VM, as defined under 'Image SKU':\nhttps://learn.microsoft.com/en-us/azure/backup/backup-azure-policy-supported-skus#supported-vms"
  default     = "2022-datacenter-azure-edition-smalldisk"
}

variable "adminUsername" {
  description = "Username for the administrator account"
}
variable "adminPassword" {
  description = "Password for the administrator account"
}

# ===================================================
# General
variable "resourceLocation" {
  default = "switzerlandnorth"
}

variable "tenant" {}
variable "author" {}

# ===================================================