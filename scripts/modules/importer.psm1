<#
    .DESCRIPTION
        Module containing all resource conversion
#>

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

# Converts a stub and also displays an appropriate import command
# Uses $env:IMPORTER_outputDir to control the output directory
function Convert-Stub {
    Param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject] $inputStub,
        [Parameter(Mandatory=$true)]
        [string] $name,
        [Parameter(Mandatory=$true)]
        [string] $type,
        [Parameter(Mandatory=$true)]
        [string] $identifier,
        [Parameter(Mandatory=$true)]
        [string] $id
    )

    # Ensures no BOM in encoding
    [IO.File]::WriteAllLines(
        (Join-Path (Resolve-Path $env:IMPORTER_outputDir) "${type}_$name.tf.json"),
        ($stub | ConvertTo-Json -Depth 5)
    )
    
    # Import command
    $importCommand = "terraform import `"$($terraResource."$type").$identifier`" `"$id`""
    Write-Host "$> " -nonewline -f darkgray
        Write-Host $importCommand -f blue

    return $importCommand
}

function Get-ResourceGroups {
    $importCommands = @()

    # Resource groups
    Write-Host "Processing resource groups..." -f cyan
    $rgInv = (az group list | ConvertFrom-Json) | ? name -notlike "NetworkWatcher*"
    $rgInv | % {
        $rgName = $_.name
        Write-Host "> $rgName" -f yellow
        try {
            if ($UseExplicitIdentifiers.IsPresent) {
                $identifier = $rgName -replace "[^a-zA-Z0-9]", ""
            } else {
                $identifier = "rg"
            }

            $stub = (Get-Content ".\json\$($terraResource.rg)-stub.json") `
                -replace "%identifier%", $identifier | `
                ConvertFrom-Json
            $base = $stub.resource."$($terraResource.rg)"."$identifier" # pointer!

            $base.location = $_.location
            $base.name = $rgName

            # Convert
            $splat = @{
                inputStub = $stub
                name = $rgName
                type = "rg"
                identifier = $identifier
                id = $_.id
            }

            $importCommands += Convert-Stub @splat
        } catch {
            Write-Host "Error processing '$rgName': $_" -f red
        }
    }

    return $importCommands
}

function Get-Vms {
    $importCommands = @()

    # Virtual machines
    ''; Write-Host "Processing virtual machines..." -f cyan
    $vmInv = az vm list | ConvertFrom-Json
    $vmInv | % {
        $vmName = $_.name
        Write-Host "> $vmName" -f yellow
        try {
            if ($UseExplicitIdentifiers.IsPresent) {
                $identifier = $vmName -replace "[^a-zA-Z0-9]", ""
            } else {
                $identifier = "vm"
            }

            $stub = (Get-Content ".\json\$($terraResource.vm)-stub.json") `
                -replace "%identifier%", "$identifier" | ConvertFrom-Json
            $base = $stub.resource."$($terraResource.vm)"."$identifier"

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
            if ([String]::IsNullOrEmpty($AdminPassword)) {
                Write-Host "  > Please provide the admin password." -f yellow
                Write-Host "    Leave blank to generate one." -f Yellow
                $pass = Read-Host "  > Password"
        
                if ([String]::IsNullOrEmpty($pass)) {
                    Write-Host "> Randomly generating one..." -f yellow
                    $pass = irm "https://www.passwordrandom.com/query?command=password"
                }
            } else {
                $pass = $AdminPassword
            }

            $base.admin_password = $pass

            $base.source_image_reference.publisher = $_.storageProfile.imageReference.publisher
            $base.source_image_reference.offer = $_.storageProfile.imageReference.offer
            $base.source_image_reference.sku = $_.storageProfile.imageReference.sku
            $base.source_image_reference.version = $_.storageProfile.imageReference.version
        
            # Convert
            $splat = @{
                inputStub = $stub
                name = $vmName
                type = "vm"
                identifier = $identifier
                id = $_.id
            }

            $importCommands += Convert-Stub @splat
        } catch {
            Write-Host "Error processing '$vmName': $_" -f red
        }
    }

    return $importCommands
}

function Get-Vnets {
    $importCommands = @()

    ''; Write-Host "Processing VNET..." -f cyan
    $vnetInv = az network vnet list | ConvertFrom-Json
    $vnetInv | % {
        $vnetName = $_.name
        Write-Host "> $vnetName" -f yellow
        try {
            if ($UseExplicitIdentifiers.IsPresent) {
                $identifier = $vnetName -replace "[^a-zA-Z0-9]", ""
            } else {
                $identifier = "vnet"
            }

            $stub = (Get-Content ".\json\$($terraResource.vnet)-stub.json") `
                -replace "%identifier%", "$identifier" | ConvertFrom-Json
            $base = $stub.resource."$($terraResource.vnet)"."$identifier"

            $base.name = $vnetName
            $base.resource_group_name = $_.resourceGroup
            $base.location = $_.location

            $base.address_space = $_.addressSpace.addressPrefixes

            # Convert
            $splat = @{
                inputStub = $stub
                name = $vnetName
                type = "vnet"
                identifier = $identifier
                id = $_.id
            }

            $importCommands += Convert-Stub @splat
        } catch {
            Write-Host "Error processing '$vnetName': $_" -f red
        }
    }

    return $importCommands
}

Export-ModuleMember -Function Convert-Stub
Export-ModuleMember -Function Get-ResourceGroups
Export-ModuleMember -Function Get-Vms
Export-ModuleMember -Function Get-Vnets
