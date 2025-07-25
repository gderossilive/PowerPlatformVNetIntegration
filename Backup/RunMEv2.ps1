# Requires -Modules Az.Accounts, Az.Resources, Az.KeyVault

Set-StrictMode -Version Latest

param (
    [string]$EnvFile = ".\.env" # Path to the environment variables file
)

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
    if (-not (az account show 2>$null)) {
        & az login --tenant $env:TENANT_ID | Out-Null
    }
    & az account set --subscription $env:SUBSCRIPTION_ID
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
Import-EnvFile -Path $EnvFile

# Step 2: Ensure Azure login and set the correct subscription
Ensure-AzLogin

# Step 3: Set execution policy for the current process (bypass restrictions)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Step 4: Register Microsoft.PowerPlatform resource provider if needed
Ensure-ResourceProviderRegistered

# Step 9: Extract enterprise policy details 
#$environmentId = (Get-AdminPowerAppEnvironment "$env:POWER_PLATFORM_ENVIRONMENT_NAME").EnvironmentName
#$enterprisePolicyId = (Get-AzResource -Name "$env:ENTERPRISE_POLICY_NAME" -ResourceGroupName "$env:RESOURCE_GROUP").ResourceId
#$enterprisePolicyName = (Get-AzResource -Name "$env:ENTERPRISE_POLICY_NAME" -ResourceGroupName "$env:RESOURCE_GROUP").Name
#$policyArmId = "/subscriptions/$env:SUBSCRIPTION_ID/resourceGroups/$resourceGroupName/providers/Microsoft.PowerPlatform/enterprisePolicies/$enterprisePolicyName"
$policyArmId = (Get-AzResource -Name "$env:ENTERPRISE_POLICY_NAME" -ResourceGroupName "$env:RESOURCE_GROUP").ResourceId

# Step 10: Get an access token for the Power Platform Admin API
$powerPlatformAdminApiToken = Get-PowerPlatformAccessToken

# Step 11: Get the Power Platform environment ID by display name
$powerPlatformEnvironmentId = Get-PowerPlatformEnvironmentId -AccessToken $powerPlatformAdminApiToken -DisplayName $env:POWER_PLATFORM_ENVIRONMENT_NAME

# Step 12: Get the SystemId for the enterprise policy resource
$systemId = az resource show --ids $policyArmId --query "properties.systemId" -o tsv

# Step 13: Link the enterprise policy to the Power Platform environment
$linkResult = Link-EnterprisePolicyToEnvironment -AccessToken $powerPlatformAdminApiToken -EnvironmentId $powerPlatformEnvironmentId -SystemId $systemId 

($linkResult.Content | ConvertFrom-Json).state

# Step 14: Wait for link operation to complete
$operationLink = $linkResult.Headers.'operation-location'
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
