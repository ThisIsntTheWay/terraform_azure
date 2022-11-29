<#
	.DESCRIPTION
		Attempts to create .tf.json files for to-be-imported infrastructure.
        Supports:
        - Resource Groups
        - Virtual Machines
        - Virtual Networks
    
    .PARAMETER UseExplicitIdentifiers
        If supplied, the state will use the name of the to-be-imported resource.
        
        E.G: Resource (VM) is called "testVm1"
        Without this parameter, the state would be called:
         > azurerm_windows_virtual_machine. > vm <
        
        With this parameter, it would instead be called:
         > azurerm_windows_virtual_machine. > testVm1 <

    .PARAMETER AdminPassword
        String, if supplied will populate the "admin_password" property automatically.
        If not supplied, will prompt the user for each VM.
    
    .AUTHOR
		Valentin Klopfenstein
#>

Param(
    [Parameter(Mandatory=$false)]
    [switch] $UseExplicitIdentifiers,
    [Parameter(Mandatory=$false)]
    [string] $AdminPassword
)

# =========================
#       VARIABLES
# =========================
$importCommands = @()

$env:IMPORTER_outputDir = ".\output"
$env:IMPORTER_explicitIdentifiers = $UseExplicitIdentifiers.IsPresent

# =========================
#           MAIN
# =========================
try {
    Import-Module .\modules\importer.psm1
} catch {
    throw $_
}

if (-not (Test-Path $env:IMPORTER_outputDir)) {
    mkdir $env:IMPORTER_outputDir | Out-Null
}

# Import
$importCommands += Get-ResourceGroups
''; $importCommands += Get-Vms
''; $importCommands += Get-Vnets

# Clear empty entries
$importCommands = $importCommands | ? { $_ }

# Attempt to import the whole infrastructure in terraform
if ($importCommands.count -ne 0) {
    # Export commands to a file for later execution
    $outFile = ".\output\terraform-import.bat"
    $fileContent = "REM Generated: $(Get-Date)`n$($importCommands -join "`n")"
    $fileContent | Out-File $outFile -Encoding UTF8 -Force

    ''; Write-Host "$($importCommands.count) resources are ready to be imported." -f cyan
    Write-Host "> Attempt import?" -f yellow

    if ((Read-Host "y/N") -eq "y") {
        # Copy terraform init data and import configs to a temp directory
        $suffix = [guid]::NewGuid().guid.split("-")[0]
        $tempLocation = Join-Path $env:TEMP "terraImport_$suffix"
        $thisLocation = Get-Location

        try {
            Write-Host ""
            if (-not (Test-Path $tempLocation)) {
                mkdir $tempLocation |  out-null
            }

            # Assuming we're running in root\scripts
            $requiredItems = @(".terraform", "main.tf", ".terraform.lock.hcl")
            $requiredItems | % {
                $item = "..\runbooks\$_"
                Copy-Item $item $tempLocation -Force -Recurse
            }

            Copy-Item ".\output\*" $tempLocation -Force

            # Attempt import
            Set-Location $tempLocation
            $importCommands | % {
                # terraform import -> "identifier" <- "id"
                $identifier = $_.split(" ")[2] -replace '"', ""
                Write-Host "> $identifier" -f cyan

                #Invoke-Expression "terraform init" | out-null
                try {
                    Invoke-Expression $_
                } catch {
                    Write-Host "  > IMPORT FAIL: $_" -f red
                }
            }
        } catch {
            Write-Host "  > FAIL: $_" -f red
        } finally {
            # Cleanup, first the files then the folder itself
            # This prevents the "... because it is in use." error.
            if (Test-Path $tempLocation) {
                gci $tempLocation | % {
                    Remove-item $_ -Force -Recurse -ea SilentlyContinue
                }
            }
            Remove-item $tempLocation -Force -Recurse -ea SilentlyContinue

            Set-Location $thisLocation
        }
    } else {
        Write-Host "> Aborted" -f DarkGray
    }
}