<#
	.DESCRIPTION
		Attempts to create .tf.json files for to-be-imported infrastructure.
    
	.AUTHOR
		Valentin Klopfenstein
#>

# =========================
#       VARIABLES
# =========================
$importCommands = @()

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
#       FUNCTIONS
# =========================
# Converts a stub and also displays an appropriate import command
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
        (Join-Path (Resolve-Path $outputDir) "${type}_$name.tf.json"),
        ($stub | ConvertTo-Json -Depth 5)
    )
    
    # Import command
    $importCommand = "terraform import `"$($terraResource."$type").$identifier`" `"$id`""
    Write-Host "$> " -nonewline -f darkgray
    Write-Host $importCommand -f blue

    return $importCommand
}

# =========================
#           MAIN
# =========================
$outputDir = ".\output"
if (-not (Test-Path $outputDir)) {
    mkdir $outputDir | Out-Null
}

# Resource groups
Write-Host "Processing resource groups..." -f cyan
$rgInv = (az group list | convertfrom-json) | ? name -notlike "NetworkWatcher*"
$rgInv | % {
    $rgName = $_.name
    Write-Host "> $rgName" -f yellow
    try {
        $identifier = $rgName -replace "[^a-zA-Z0-9]", ""
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

# Virtual machines
''; Write-Host "Processing virtual machines..." -f cyan
$vmInv = az vm list | convertfrom-json
$vmInv | % {
    $vmName = $_.name
    Write-Host "> $vmName" -f yellow
    try {
        $stub = (Get-Content ".\json\$($terraResource.vm)-stub.json") `
            -replace "%identifier%", "$vmName" | ConvertFrom-Json
        $base = $stub.resource."$($terraResource.vm)"."$vmName"

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
        Write-Host "  > Please provide the admin password." -f yellow
        Write-Host "    Leave blank to generate one." -f Yellow
        $pass = Read-Host "  > Password"

        if ([String]::IsNullOrEmpty($pass)) {
            Write-Host "> Randomly generating one..." -f yellow
            $pass = irm "https://www.passwordrandom.com/query?command=password"
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
            identifier = $vmName
            id = $_.id
        }

        $importCommands += Convert-Stub @splat
    } catch {
        Write-Host "Error processing '$vmName': $_" -f red
    }
}

# Attempt to do import of all
if ($importCommands.count -ne 0) {
    ''; Write-Host "$($importCommands.count) resources are ready to be imported." -f cyan
    Write-Host "> Attempt import?" -f yellow

    if ((Read-Host "y/N") -eq "y") {
        $importCommands | % {
            $identifier = $_.split(" ")[2] -replace '"', ""
            Write-Host "> $identifier" -f cyan

            try {
                # TODO: Get terraform init data to current location
                Invoke-Expression $_
            } catch {
                Write-Host "  > FAIL" -f red
            }
        }
    } else {
        Write-Host "> Aborted" -f DarkGray
    }
}