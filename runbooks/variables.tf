# ===================================================
# Virtual Machines
/*variable "serverType" {
  description = "What type of service the VM will provide (ap, dc, db...)"

  validation {
    condition     = can(regex("[^0-9]{2}", var.serverType)) && length(var.serverType) == 2
    error_message = "'serverType' must be 2 characters long and may only contain letters."
  }
}*/

variable "vmConfiguration" {
  description = "VMs to create (Schema: 'name' = 'size')"
  type        = map(string)
  default     = {}
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
  default     = "adminDude"

  validation {
    condition     = !can(regex("^(admin|administrator)$", var.adminUsername)) && length(var.adminUsername) >= 3
    error_message = "Value for 'adminUsername' is illegal or too short (min: 3)."
  }
}

variable "adminPassword" {
  description = "Password for the administrator account"
  default     = "abCD1234"

  validation {
    # ToDo: Implement password complexity regex match: ^(?=.*[0-9])(?=.*[a-zA-Z]).{8,123}$
    condition     = length(var.adminPassword) >= 8 && length(var.adminPassword) <= 123
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