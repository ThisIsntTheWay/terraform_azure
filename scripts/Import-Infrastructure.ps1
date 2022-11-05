<#
	.DESCRIPTION
		Attempts to create .tf.json files for to-be-imported infrastructure.
    
	.AUTHOR
		Valentin Klopfenstein
#>

# =========================
#       VARIABLES
# =========================
# Browse the docs for other types: 
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
[pscustomobject]$terraResource = @{
    "vm" = "azurerm_windows_virtual_machine"
    "rg" = "azurerm_resource_group"
    "nsg" = "azurerm_network_security_group"
    "nic" = "azurerm_network_interface"
    "vnet" = "azurerm_virtual_network"
    "snet" = "azurerm_subnet"
}

# =========================
#           MAIN
# =========================
$outputDir = ".\output"
if (-not (Test-Path $outputDir)) {
    mkdir $outputDir | Out-Null
}

# Virtual machines
$vmInv = az vm list | convertfrom-json
$vmInv | % {
    $vmName = $_.name
    Write-Host $vmName -f cyan
    try {
        $stub = (Get-Content ".\json\$($terraResource.vm)-stub.json") `
            -replace "%identifier%", "$vmName" | ConvertFrom-Json
        $base = $stub.resource."$($terraResource.vm)"."$vmName" # pointer!

        $base.name = $_.name
        $base.location = $_.location
        $base.resource_group_name = $_.resourceGroup
        $base.size = $_.hardwareProfile.vmSize

        $base.os_disk.caching = $_.storageprofile.osDisk.caching
        $base.os_disk.storage_account_type = $_.storageprofile.osDisk.managedDisk.storageAccountType
    
        $_.networkProfile.networkInterfaces | % {
            $base.network_interface_ids += $_.id
        }

        $base.admin_username = $_.osProfile.adminUsername

        # The admin password is irretrievable
        Write-Host "> Please provide the admin password." -f yellow
        Write-Host "  Leave blank to generate one." -f Yellow
        $pass = Read-Host "Password"

        if ([String]::IsNullOrEmpty($pass)) {
            Write-Host "> Randomly generating one..." -f yellow
            $pass = irm "https://www.passwordrandom.com/query?command=password"
        }

        $base.admin_password = $pass

        $base.source_image_reference.publisher = $_.storageProfile.imageReference.publisher
        $base.source_image_reference.offer = $_.storageProfile.imageReference.offer
        $base.source_image_reference.sku = $_.storageProfile.imageReference.sku
        $base.source_image_reference.version = $_.storageProfile.imageReference.version
    
        # Ensures no BOM in encoding
        [IO.File]::WriteAllLines(
            ((Join-Path $outputDir "vm_$vmName.tf.json") | Resolve-Path),
            ($stub | ConvertTo-Json -Depth 5)
        )
        
        # Import command
        $importCommand = "terraform import `"$($terraResource.vm).$vmName`" `"$($_.id)`""
        Write-Host "$> " -nonewline -f darkgray
        Write-Host $importCommand -f blue
    } catch {
        Write-Host "Error processing '$vmName': $_" -f red
    }
}