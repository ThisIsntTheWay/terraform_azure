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
  default     = "2022-datacenter-smalldisk"
}

variable "adminUsername" {
  description = "Username for the administrator account"
  default = "12345678"

  validation {
    condition = length(var.adminUsername) < 8 || length(var.adminUsername) > 123
    error_message = "Value for 'adminUsername' must be between 8-123 characters."
  }
}

variable "adminPassword" {
  description = "Password for the administrator account"
  default = "12345678"

  validation {
    condition = length(var.adminPassword) > 8 && length(var.adminPassword) < 123
    error_message = "Value for 'adminPassword' must be between 8-123 characters."
  }
}

# ===================================================
# General
variable "resourceLocation" {
  default = "switzerlandnorth"
}

variable "author" {}

variable "tenant" {
  validation {
    condition     = length(var.tenant) == 4
    error_message = "Value for 'tenant' must be 4 characters, instead it is ${length(var.tenant)}."
  }
}

# ===================================================