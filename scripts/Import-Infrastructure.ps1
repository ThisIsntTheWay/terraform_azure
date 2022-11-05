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
    Write-Host $_.name -f cyan
    try {
        $stub = (Get-Content ".\json\$($terraResource.vm)-stub.json") `
            -replace "%identifier%", "$($_.name)" | ConvertFrom-Json
        $base = $stub.resource."$($terraResource.vm)"."$($_.name)" # pointer!

        $base.name = $_.name
        $base.location = $_.location
        $base.resource_group_name = $_.resourceGroup
        $base.size = $_.hardwareProfile.vmSize

        $base.os_disk.caching = $_.storageprofile.osDisk.caching
        $base.os_disk.storage_account_type = $_.storageprofile.osDisk.managedDisk.storageAccountType
    
        $base.source_image_reference.publisher = $_.storageProfile.imageReference.publisher
        $base.source_image_reference.offer = $_.storageProfile.imageReference.offer
        $base.source_image_reference.sku = $_.storageProfile.imageReference.sku
        $base.source_image_reference.version = $_.storageProfile.imageReference.version
    
        $stub | ConvertTo-Json -Depth 5 | Out-File (Join-Path $outputDir "vm_$($_.name).tf.json") -Encoding UTF8 -Force
        
        # Import command
        $importCommand = "terraform import `"$($terraResource.vm).$($_.name)`" `"$($_.id)`""
        Write-Host "$> $importCommand" -f yellow
    } catch {
        Write-Host "Error processing '$($_.name)': $_" -f red
    }
}