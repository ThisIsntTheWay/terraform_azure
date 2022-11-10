<#
	.DESCRIPTION
		Properly intializes terraform using tf data in $terraData

		Downloads and installs the following software (if missing):
		- Terraform
		- Terragrub
		- Azure CLI

		If this script is executed with a new tenant, then the infrastructure will be prepared accordingly.
	
	.PARAMETER tenant
		Tenant for which to initalize terraform for.
		This information is ultimately used to load the appropriate json under .\tenantData

	.AUTHOR
		Valentin Klopfenstein
#>

Param(
	[Parameter(Mandatory=$true)]
	[ValidateScript({
		if ($_.length -lt 4) {
			throw "Argument must be at least 4 characters."
		} else { $true }
	})]
	[string] $Tenant
)

# =========================
# 		Variables
# =========================
$terraData = ".\runbooks"

# =========================
# 		FUNCTIONS
# =========================
# Presents the user a simple menu to select a specific resource
# Assumes as input an object generated by the AZ CLI
function Select-Resource ($inputobject) {
	$i = 0; $inputobject | % {
		$i++
		Write-Host "$i" -NoNewline -f green
		Write-Host " - " -NoNewline
		Write-Host "$($_.Name) ($($_.location))" -f yellow
	}
	
	do {
		try {
			$choice = Read-Host "Selection"
	
			if ($choice -match '^[0-9]+$') {
				if (($choice -le 0) -or ($choice -gt $inputobject.count)) {
					throw "Out of range."
				} else {
					break
				}
			} else {
				throw "Not a number."
			}
		} catch {
			Write-Host "Choice invalid: $_" -f red
			Write-Host ""
		}
	} while ($true)

	return $inputobject[[int]$choice - 1]
}

function Decrypt-SecureString ($string) {
	try {
		return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
			[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(
				(convertto-securestring $string)
			)
		)
	} catch {
		throw $_
	}
}

# =========================
# 			MAIN
# =========================

# Prereqs
Write-Host "Checking prerequisites..." -f yellow

# Check for terraform binary
if (-not (gci .\terraform*.exe)) {
	try {
		Write-Warning "Terraform binary (terraform.exe) was not found, acquiring..."

		Start-BitsTransfer https://releases.hashicorp.com/terraform/1.3.4/terraform_1.3.4_windows_amd64.zip .\terra.zip
		Expand-Archive .\terra.zip .\
		
		Write-Host "> Cleanup..." -f yellow
		Remove-Item .\terra.zip -Force -Confirm:$false
		
		.\terraform.exe -install-autocomplete

		Write-Host "Binary acquired." -f green
	} catch {
		throw "Terraform binary setup failure: $_"
	}
}

# Check for terragrunt
if (-not (gci .\terragrunt*.exe)) {
	try {
		$binaryName = "terragrunt_windows_amd64.exe"
		$baseUri = "https://github.com/gruntwork-io/terragrunt"
		$latestTag = (irm $baseUri/releases.atom | sort updated -des)[0].title

		Write-Host "Acquiring terragrunt '$latestTag'..." -f yellow
		Start-BitsTransfer "$baseUri/releases/download/$latestTag/$binaryName" .\terragrunt.exe
	} catch {
		throw "Terraform binary setup failure: $_"
	}
}

# Check for Azure CLI
$ErrorActionPreference = 'continue'
try {
	az --version
} catch {
	''; Write-Warning "Azure CLI is missing, acquiring..."
	
	try {
		Write-Warning "Installation of the Azure CLI requires elevated permissions."
		Start-BitsTransfer https://aka.ms/installazurecliwindows .\AzureCLI.msi
		
		Write-Host "> Beginning installation..." -f yellow
		Start-Process msiexec.exe -Wait -ArgumentList "/I $((get-item .\AzureCLI.msi).FullName) /quiet" -verb runas
		
		Write-Host "> Cleanup..." -f yellow
		Remove-Item .\AzureCLI.msi -Force -Confirm:$false
		Write-Host "Azure CLI installed." -f green
		
		Write-Host "Please open a new terminal." -fore black -back gray
		pause; exit
	} catch {
		throw "Azure CLI installation failure: $_"
	}
}

''; Write-Host "> Prerequisites met." -f green

try {	
	# Check if SP data exists
	$spFile = ".\tenantData\$Tenant.json"
	if (Test-Path $spFile) {
		''; Write-Host "Attempting to read sp data from '$spFile'..." -f cyan
		$sp = Get-Content $spFile -Encoding UTF8 | ConvertFrom-Json

		# verify sp data json
		$requiredProps = @(
			"appId"
			"password"
			"tenant"
			"subscriptionId"
			"storageAccount"
			"storageRg"
			"storageKey"
			"storageContainer"
		)

		$missingProps = @()
		$requiredProps | % { 
			if (-not $sp."$_") {
				$missingProps += $_
			}
		}

		if ($missingProps.count -ne 0) {
			throw "sp data json incomplete: Missing properties: '$($missingProps -join ", ")'."
		}
		
		# Try to decrypt passwords
		try {
			$password = Decrypt-SecureString $sp.password
			$storageKey = Decrypt-SecureString $sp.storageKey
		 }
		catch { throw "Could not decrypt password." }

		Write-host "> Tenant ID       : $($sp.tenant)" -f yellow
		Write-host "> Subscription ID : $($sp.subscriptionId)" -f yellow
		Write-host "> Storage account : $($sp.storageAccount)" -f yellow
	} else {
		# Create SP data
		# Conduct login if no sp data json was found.
		Write-Host "Please log in to your tenant '$Tenant'." -f cyan

		$tenantData = az login | ConvertFrom-Json
		Write-Host "Connected to tenant!" -f green
		Write-Host "> Subscription ID : $($tenantData.id)" -f yellow
		Write-Host "> Tenant ID       : $($tenantData.tenantId)" -f yellow

		''; Write-Host "Acquiring subscription details..." -f cyan
		$subId = (az account show | convertfrom-json).id
		
		''; Write-Host "Creating a service principal with role 'Contributor'..." -f cyan
		Write-Warning "This will store an encrypted password in '.\tenantData\$tenant.json'!"
		$sp = az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subId" | ConvertFrom-Json
		
		# Store sp data for tenant
		if (-not (Test-Path .\tenantData)) {
			mkdir .\tenantData | out-null
		}

		# Store password
		$password = $sp.password
		$sp.password = (ConvertTo-SecureString $password -AsPlainText -Force) | ConvertFrom-SecureString
		$sp | Add-Member -NotePropertyName "subscriptionId" -NotePropertyValue $tenantData.id

		# Create or select resource group for state file
		$terraformRgName = "terraform"
		$resourceGroups = az group list | ConvertFrom-Json
		$terraResourceGroup = $resourceGroups | ? Name -eq $terraformRgName
		if (-not $terraResourceGroup) {
			''; Write-Warning "No resource group for terraform (Name: '$terraformRgName') was found, creating..."

			$terraResourceGroup = az group create -l switzerlandnorth -n $terraformRgName | ConvertFrom-Json
		}

		# Identify or create storage account
		$storageAccounts = az storage account list -g $terraResourceGroup.name | ConvertFrom-Json
		if ($storageAccounts) {
			''; Write-Host "Please select a storage account to store your terraform storage container." -f cyan
			$storageAccount = Select-Resource $storageAccounts
		} else {
			$random = [guid]::NewGuid().guid.split("-")[0]
			$tenantShort = $tenant.Substring(0, 4)
			$name = "$($tenantShort.toLower())terra$random"
			''; Write-Warning "No storage account within '$($terraResourceGroup.name)' was found."

			Write-Host "> Creating account '$name'..." -f yellow
			$storageAccount = (az storage account create -n $name `
				-g $terraResourceGroup.name `
				-l switzerlandnorth `
				--sku Standard_LRS `
				--allow-blob-public-access $true) | ConvertFrom-Json
		}

		# Create storage container
		# Get storage account key
		$storageKey = (az storage account keys list -n $storageAccount.Name | ConvertFrom-Json)[0].value
		
		# Encrypt storage key for json
		$storageKeyEncrypted = ConvertTo-SecureString $storageKey -AsPlainText -Force | ConvertFrom-SecureString

		# Create container
		$storageContainer = "terraform"
		Write-Host "> Creating container '$storageContainer'..." -f yellow
		az storage container create -n $storageContainer `
			--account-name $storageAccount.name `
			--account-key $storageKey `
			--public-access blob | Out-Null

		# Store into sp data json
		$sp | Add-Member -NotePropertyName "storageAccount" -NotePropertyValue $storageAccount.name
		$sp | Add-Member -NotePropertyName "storageKey" -NotePropertyValue $storageKeyEncrypted
		$sp | Add-Member -NotePropertyName "storageRg" -NotePropertyValue $terraResourceGroup.name
		$sp | Add-Member -NotePropertyName "storageContainer" -NotePropertyValue $storageContainer
	

		$sp | ConvertTo-Json | Out-File $spFile -Encoding Utf8
		Write-Host "> Saved to: $spFile" -f yellow
	}
	
	# Set env data
	''; Write-Host "Setting env vars..." -f cyan

	# Terraform AzureRM client stuff
	$env:ARM_CLIENT_ID = $sp.appId
	$env:ARM_CLIENT_SECRET = $password
	$env:ARM_SUBSCRIPTION_ID = $sp.subscriptionId
	$env:ARM_TENANT_ID = $sp.tenant
	$env:ARM_ACCESS_KEY = $storageKey
	
	# Global terraform variables as set in variables.tf
	$env:TF_VAR_tenant = $Tenant
	$env:TF_VAR_author = (whoami)

	# Ensure terraform.exe can be called regardless of location
	$pathDelimiter = if ($env:PATH[-1] -eq ";") { $null } else { ";" }
	$env:PATH += "$pathDelimiter$(Get-Location)"

	''; Write-Host "Initializing terraform..." -f cyan

	$accent = [char]96
	$initCommand = @"
terraform init $accent
	-backend-config="resource_group_name=$($sp.storageRg)" $accent
	-backend-config="storage_account_name=$($sp.storageAccount)" $accent
	-backend-config="container_name=$($sp.storageContainer)"
"@
	Write-Host $initCommand -f yellow

	if (Test-Path $terraData) {
		Set-Location $terraData
		iex $initCommand
	} else {
		Write-Warning "The terraform data directory '$terraData' was not found, manual init is required!"
	}
} catch {
	throw $_
}
