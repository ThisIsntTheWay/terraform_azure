# Author: Valentin Klopfenstein

Param(
	[Parameter(Mandatory=$true)]
	[string] $Tenant
)

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
		
		Write-Host "Binary acquired." -f green
	} catch {
		throw "Terraform binary setup failure: $_"
	}
}

# Check for Azure CLI
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
		)
		$requiredProps | % { 
			if (-not $sp."$_") {
				throw "sp data json is incomplete: Missing property: '$_'."
			}
		}
		
		Write-host "> Tenant ID       : $($sp.tenant)" -f yellow
		Write-host "> Subscription ID : $($sp.subscriptionId)" -f yellow
	} else {
		# Conduct login if no sp data json was found.
		Write-Host "Please log in to your tenant '$Tenant'." -f cyan

		$tenantData = az login | ConvertFrom-Json
		Write-Host "Connected to tenant!" -f green
		Write-Host "> Subscription ID : $($tenantData.id)" -f yellow
		Write-Host "> Tenant ID       : $($tenantData.homeTenantId)" -f yellow

		''; Write-Host "Acquiring subscription details..." -f cyan
		$subId = (az account show | convertfrom-json).id
		
		''; Write-Host "Creating a service principal with role 'Contributor'..." -f cyan
		Write-Warning "This will store a plaintext password in .\tenantData!"
		$sp = az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subId" | ConvertFrom-Json
		
		# Store sp data for tenant
		if (-not (Test-Path .\tenantData)) {
			mkdir .\tenantData | out-null
		}
		
		$sp | Add-Member -NotePropertyName "subscriptionId" -NotePropertyValue $tenantData.homeTenantId
		$sp | ConvertTo-Json | Out-File $spFile -Encoding Utf8
		Write-Host "> Saved to: $spFile" -f yellow
	}
	
	# Set env data
	''; Write-Host "Setting env vars..." -f cyan
	$env:ARM_CLIENT_ID = $spData.appId
	$env:ARM_CLIENT_SECRET = $spData.password
	$env:ARM_SUBSCRIPTION_ID = $spData.subscriptionId
	$env:ARM_TENANT_ID = $spData.tenant

	# Global terraform varaibles as set in variables.tf
	$env:TF_VAR_tenant = $Tenant
	$env:TF_VAR_author = (whoami)

	# Ensure terraform.exe can be called regardless of location
	$pathDelimiter = if ($env:PATH[-1] -eq ";") { $null } else { ";" }
	$env:PATH += "$pathDelimiter$(Get-Location)"

	if (Test-Path .\runbooks) {
		''; Write-Host "Initializing terraform..." -f cyan

		Set-Location .\runbooks
		terraform init
	} else {
		''; Write-Host "Terraform for Azure may now be used." -f green
		Write-Host "To get started, navigate to a dir with .tf files and do: 'terraform init'" -f yellow
	}
} catch {
	throw $_
}