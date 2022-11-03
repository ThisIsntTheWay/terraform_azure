# Prereqs
Write-Host "Checking prerequisites..." -f yellow

# Check for terraform binary
if (-not (gci .\terraform*.exe)) {
	try {
		Write-Warning "Terraform binary (terraform.exe) was not found, acquiring..."
		Start-BitsTransfer https://releases.hashicorp.com/terraform/1.3.4/terraform_1.3.4_windows_amd64.zip .\terra.zip
		Expand-Archive .\terra.zip .\
		
		Write-Host "Cleanup..." -f yellow
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
		Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet' -Verb runAs
		
		Write-Host "Cleanup..." -f yellow
		Remove-Item .\AzureCLI.msi -Force -Confirm:$false
		Write-Host "Azure CLI installed." -f green
		
		Write-Host "Please open a new terminal." -fore black -back gray
		pause; exit
	} catch {
		throw "Azure CLI installation failure: $_"
	}
}

''; Write-Host "> Prerequisites (now) met." -f green

# Conduct login
try {
	Write-Host "Please log in to your tenant." -f cyan
	$tenantData = az login | ConvertFrom-Json
	Write-Host "> Connected to tenant!" -f green
	Write-Host "  > Subscription ID : $($tenantData.id)" -f gray
	Write-Host "  > Tenant ID       : $($tenantData.homeTenantId)" -f gray
	
	# Check if SP data exists
	$spFile = ".\tenantData\$($tenantData.homeTenantId).json"
	if (Test-Path $spFile) {
		Write-Host "Attempting to read sp data from '$spFile'..." -f cyan
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
		
		Write-host "> Got sp: $($sp.displayName)" -f green
	} else {
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
} catch {
	throw $_
}
