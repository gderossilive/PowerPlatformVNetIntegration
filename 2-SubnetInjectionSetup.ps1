# Prerequisites: Azure CLI (az) must be installed and authenticated
# This script uses Azure CLI commands instead of Azure PowerShell modules for cross-platform compatibility

Set-StrictMode -Version Latest

# Loads environment variables from a .env file into the current process
function Import-EnvFile {
    param([string]$Path)
    if (-Not (Test-Path $Path)) {
        throw "Environment file '$Path' not found."
    }
    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
        }
    }
}

# Ensures the user is logged in to Azure and sets the correct subscription
function Ensure-AzLogin {
    # Check if already logged in
    $accountInfo = az account show 2>$null
    if (-not $accountInfo) {
        Write-Output "Azure CLI not logged in. Attempting to log in..."
        if ($env:TENANT_ID) {
            az login --tenant $env:TENANT_ID | Out-Null
        } else {
            az login | Out-Null
        }
    }
    
    # Set subscription if provided
    if ($env:SUBSCRIPTION_ID) {
        Write-Output "Setting Azure subscription to: $env:SUBSCRIPTION_ID"
        az account set --subscription $env:SUBSCRIPTION_ID
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set Azure subscription. Please check your subscription ID."
        }
    } else {
        throw "SUBSCRIPTION_ID environment variable is not set."
    }
}

# Registers the Microsoft.PowerPlatform resource provider if not already registered
function Ensure-ResourceProviderRegistered {
    $state = az provider show --namespace Microsoft.PowerPlatform --query "registrationState" -o tsv
    if ($state -ne "Registered") {
        Write-Host "Registering Microsoft.PowerPlatform resource provider..."
        az provider register --subscription $env:SUBSCRIPTION_ID --namespace Microsoft.PowerPlatform | Out-Null
    } else {
        Write-Host "Microsoft.PowerPlatform resource provider is already registered."
    }
}

# Generates a random 3-character alphanumeric suffix
function New-RandomSuffix {
    return -join ((97..122) | Get-Random -Count 3 | ForEach-Object { [char]$_ })
}

# Creates the resource group if it does not exist
function Ensure-ResourceGroup {
    param([string]$Name, [string]$Location)
    $exists = az group exists --name $Name --subscription $env:SUBSCRIPTION_ID
    if ($exists -eq "false") {
        Write-Host "Creating resource group $Name in $Location..."
        az group create --name $Name --location $Location --subscription $env:SUBSCRIPTION_ID | Out-Null
    } else {
        Write-Host "Resource group $Name already exists."
    }
}

# Deploys a Bicep template to the specified resource group
function Deploy-BicepTemplate {
    param(
        [string]$ResourceGroupName,
        [string]$DeploymentName,
        [string]$TemplateFile,
        [hashtable]$Parameters
    )
    $params = $Parameters.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    $output = az deployment group create `
        --subscription $env:SUBSCRIPTION_ID `
        --resource-group $ResourceGroupName `
        --name $DeploymentName `
        --template-file $TemplateFile `
        --parameters $params `
        --output json | ConvertFrom-Json
    return $output
}

# Ensures the Key Vault exists, deploying it if necessary
function Ensure-KeyVault {
    param([string]$Name, [string]$ResourceGroup, [string]$Location)
    $exists = az keyvault show --name $Name --subscription $env:SUBSCRIPTION_ID --query "name" -o tsv
    if (-not $exists) {
        Write-Host "Creating Key Vault $Name..."
        Deploy-BicepTemplate -ResourceGroupName $ResourceGroup -DeploymentName "keyvault-$ResourceGroup" `
            -TemplateFile ".\bicep\kv.bicep" `
            -Parameters @{ name = $Name; location = $Location; secretName = 'MySecret'; secretValue = 'VaultSecretValue' } | Out-Null
    } else {
        Write-Host "Key Vault $Name already exists."
    }
}

# Retrieves an access token for the Power Platform Admin API
function Get-PowerPlatformAccessToken {
    $resource = "https://api.bap.microsoft.com/"
    return az account get-access-token --resource $resource --query accessToken --output tsv
}

# Gets the Power Platform environment ID by display name
function Get-PowerPlatformEnvironmentId {
    param([string]$AccessToken, [string]$DisplayName)
    $headers = @{ Authorization = "Bearer $AccessToken" }
    $url = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2019-10-01"
    $result = iwr -Uri $url -Headers $headers -Method Get | ConvertFrom-Json
    return ($result.value | Where-Object { $_.properties.displayName -eq $DisplayName } | Select-Object -ExpandProperty name)
}

# Links the enterprise policy to the Power Platform environment
function Link-EnterprisePolicyToEnvironment {
    param(
        [string]$AccessToken,
        [string]$EnvironmentId,
        [string]$SystemId,
        [string]$ApiVersion = "2019-10-01" # Update to the latest API version as needed
    )
    $headers = @{ Authorization = "Bearer $AccessToken" }
    $body = @{ "SystemId" = $SystemId } | ConvertTo-Json
    $uri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/enterprisePolicies/NetworkInjection/link?&api-version=$ApiVersion"
    return iwr -Uri $uri -Headers $headers -Method Post -ContentType "application/json" -Body $body -UseBasicParsing
}

# Polls the operation status until completion or timeout
function Wait-ForOperation {
    param(
        [string]$OperationUri,
        [hashtable]$Headers,
        [string]$SuccessMessage,
        [string]$InProgressMessage,
        [string]$FailureMessage,
        [int]$PollInterval = 10,
        [int]$MaxRetries = 30
    )
    $retries = 0
    while ($retries -lt $MaxRetries) {
        Start-Sleep -Seconds $PollInterval
        $result = iwr -Uri $OperationUri -Headers $Headers -Method Get -UseBasicParsing
        if ($result.StatusCode -eq 200) {
            Write-Host $SuccessMessage
            return $true
        } elseif ($result.StatusCode -eq 202) {
            Write-Host $InProgressMessage
        } else {
            Write-Host "$FailureMessage Status code: $($result.StatusCode)"
            return $false
        }
        $retries++
    }
    Write-Host "Operation timed out after $MaxRetries attempts."
    return $false
}

# --- Main Script ---

# Step 1: Import environment variables from .env file
$EnvFile = "./.env"
Import-EnvFile -Path $EnvFile

# Validate required environment variables
$requiredVars = @('TENANT_ID', 'SUBSCRIPTION_ID', 'RESOURCE_GROUP', 'ENTERPRISE_POLICY_NAME', 'POWER_PLATFORM_ENVIRONMENT_NAME')
foreach ($var in $requiredVars) {
    if (-not (Get-Item -Path "env:$var" -ErrorAction SilentlyContinue)) {
        throw "Required environment variable '$var' is not set. Please check your .env file."
    }
}

Write-Output "Environment variables loaded successfully:"
Write-Output "  TENANT_ID: $env:TENANT_ID"
Write-Output "  SUBSCRIPTION_ID: $env:SUBSCRIPTION_ID"
Write-Output "  RESOURCE_GROUP: $env:RESOURCE_GROUP"
Write-Output "  ENTERPRISE_POLICY_NAME: $env:ENTERPRISE_POLICY_NAME"
Write-Output "  POWER_PLATFORM_ENVIRONMENT_NAME: $env:POWER_PLATFORM_ENVIRONMENT_NAME"

# Step 2: Ensure Azure login and set the correct subscription
Ensure-AzLogin

# Step 3: Set execution policy for the current process (bypass restrictions) - Windows only
if ($IsLinux -or $IsMacOS) {
    Write-Output "Running on non-Windows platform. Skipping Set-ExecutionPolicy."
} else {
    # Set the execution policy to allow script execution (Windows only)
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}


# Step 4: Extract enterprise policy details using Azure CLI
#$environmentId = (Get-AdminPowerAppEnvironment "$env:POWER_PLATFORM_ENVIRONMENT_NAME").EnvironmentName
#$enterprisePolicyId = (Get-AzResource -Name "$env:ENTERPRISE_POLICY_NAME" -ResourceGroupName "$env:RESOURCE_GROUP").ResourceId

# Get enterprise policy details using Azure CLI
$enterprisePolicyJson = az resource show --name "$env:ENTERPRISE_POLICY_NAME" --resource-group "$env:RESOURCE_GROUP" --resource-type "Microsoft.PowerPlatform/enterprisePolicies" --output json | ConvertFrom-Json
$enterprisePolicyName = $enterprisePolicyJson.name
$policyArmId = $enterprisePolicyJson.id

Write-Output "Enterprise Policy Name: $enterprisePolicyName"
Write-Output "Enterprise Policy ARM ID: $policyArmId"

# Step 5: Get an access token for the Power Platform Admin API
$powerPlatformAdminApiToken = Get-PowerPlatformAccessToken

# Step 6: Get the Power Platform environment ID by display name
$powerPlatformEnvironmentId = Get-PowerPlatformEnvironmentId -AccessToken $powerPlatformAdminApiToken -DisplayName $env:POWER_PLATFORM_ENVIRONMENT_NAME

# Step 7: Get the SystemId for the enterprise policy resource
$systemId = az resource show --ids $policyArmId --query "properties.systemId" -o tsv

# Step 8: Link the enterprise policy to the Power Platform environment
$linkResult = Link-EnterprisePolicyToEnvironment -AccessToken $powerPlatformAdminApiToken -EnvironmentId $powerPlatformEnvironmentId -SystemId $systemId

# Step 9: Wait for link operation to complete
$operationLocationHeader = $linkResult.Headers.'operation-location'
if ($operationLocationHeader -is [array]) {
    $operationLink = $operationLocationHeader[0]
} else {
    $operationLink = $operationLocationHeader
}

Write-Output "Operation link: $operationLink"

# Validate the operation link
if (-not $operationLink -or $operationLink -eq "") {
    throw "No operation-location header found in the link response. The linking operation may have failed."
}

# Ensure it's a valid URI string
try {
    $uri = [System.Uri]::new($operationLink)
    Write-Output "Polling operation status at: $($uri.AbsoluteUri)"
} catch {
    throw "Invalid operation link URI: $operationLink. Error: $($_.Exception.Message)"
}

$pollInterval = 10 # seconds
$run = $true
while ($run) {
    Start-Sleep -Seconds $pollInterval
    $powerPlatformAdminApiToken = Get-PowerPlatformAccessToken
    $headers = @{ 
        Authorization = "Bearer $powerPlatformAdminApiToken" 
        "Content-Type" = "application/json"
    }
    $linkResult = Invoke-WebRequest -Uri $operationLink -Headers $headers -Method Get -UseBasicParsing
    if ($linkResult.StatusCode -eq 200) {
        Write-Output "Enterprise policy $enterprisePolicyName linked to Power Platform environment $powerPlatformEnvironmentId successfully."
        $run = $false
    } elseif ($linkResult.StatusCode -eq 202) {
        Write-Output "Linking enterprise policy $enterprisePolicyName to Power Platform environment $powerPlatformEnvironmentId is still in progress."
    } else {
        Write-Output "Failed to link enterprise policy $enterprisePolicyName to Power Platform environment $powerPlatformEnvironmentId. Status code: $($linkResult.StatusCode)"
        $run = $false
    }
}
