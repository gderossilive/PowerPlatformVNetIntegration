# Prerequisite: to be logged in to Azure CLI with an account with at least the Contributor role on the considered Azure subscription
# import environment variables from .env file
Get-Content ".\.env" | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}

& az login --tenant $env:TENANT_ID
& az account set --subscription $env:SUBSCRIPTION_ID # M365x16397930 tenant

# Set the execution policy to allow script execution
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 1. Microsoft.PowerPlatform resource provider registration in the considered Azure subscription
if (-not (az provider show --namespace Microsoft.PowerPlatform --query "registrationState" -o tsv)) {
    Write-Output "Registering Microsoft.PowerPlatform resource provider..."
    az provider register --subscription $env:SUBSCRIPTION_ID --namespace Microsoft.PowerPlatform
} else {
    Write-Output "Microsoft.PowerPlatform resource provider is already registered."
}

# create a 3 characters long random string to use as a suffix for the resource group name
$randomSuffix = -join ((97..122) | Get-Random -Count 3 | ForEach-Object { [char]$_ })

# Set parameters for the deployment
# 2. Create the resource group where the we want to deploy the resources if it does not yet exist
$resourceGroupName = "$env:RESOURCE_GROUP-$randomSuffix"  # Name of the resource group
$resourceGroupExists = az group exists --name $resourceGroupName --subscription $env:SUBSCRIPTION_ID
if ($resourceGroupExists -eq "false") {
    $resourceGroupLocation = $env:AZURE_LOCATION
    $resourceGroup = az group create --name $resourceGroupName --location $resourceGroupLocation --subscription $env:SUBSCRIPTION_ID
}
else {
    Write-Output "Resource group $resourceGroupName already exists."
}
# 3. Deploy the resources (VNets, subnets, Power Platform enterprise policy) using Bicep
$deploymentName = "ppvnetint-" + $resourceGroupName  # Name of the deployment
$azureInfrastructureDeploymentOutputs = az deployment group create `
    --subscription $env:SUBSCRIPTION_ID `
    --resource-group $resourceGroupName `
    --name $deploymentName `
    --template-file ".\bicep\main.bicep" `
    --parameters `
        environmentGroupName=$env:POWER_PLATFORM_ENVIRONMENT_NAME `
        azureLocation=$env:AZURE_LOCATION `
        enterprisePolicyLocation=$env:POWER_PLATFORM_LOCATION `
        suffix=$randomSuffix `
    --output json | ConvertFrom-Json

# 4. deploy the Key Vault if it does not yet exist
$deployKeyVaultForTests = $azureInfrastructureDeploymentOutputs.properties.outputs.deployKeyVaultForTests.value
if ($deployKeyVaultForTests -eq "true") {
    $keyVaultName = "kv-" + $resourceGroupName  # Name of the Key Vault
    $keyVaultExists = az keyvault show --name $keyVaultName --subscription $env:SUBSCRIPTION_ID --query "name" -o tsv
    if (-not $keyVaultExists) {
        Write-Output "Creating Key Vault $keyVaultName..."
        $keyVaultDeploy = az deployment group create `
            --subscription $env:SUBSCRIPTION_ID `
            --resource-group $resourceGroupName `
            --name "keyvault-$resourceGroupName" `
            --template-file ".\bicep\kv.bicep" `
            --parameters `
                name=$keyVaultName `
                location=$env:AZURE_LOCATION `
                secretName='MySecret' `
                secretValue='VaultSecretValue' `
            --output json | ConvertFrom-Json
    } else {
        Write-Output "Key Vault $keyVaultName already exists."
    }
}

# 5. Grant Reader role to the enterprise policy to the identity / group that will finalize the configuration - link the enterprise policy to the Power Platform environments
$enterprisePolicyId = $azureInfrastructureDeploymentOutputs.properties.outputs.enterprisePolicyId.value
#$grantEnterprisePolicyReadAccessToPowerPlatformAdminsTeam = az role assignment create --assignee $powerPlatformAdminObjectId --role Reader --scope $enterprisePolicyId

$enterprisePolicyName = $azureInfrastructureDeploymentOutputs.properties.outputs.enterprisePolicyName.value
$policyArmId = "/subscriptions/$env:SUBSCRIPTION_ID/resourceGroups/$resourceGroupName/providers/Microsoft.PowerPlatform/enterprisePolicies/$enterprisePolicyName"
    
# 6. Link the enterprise policy to the Power Platform environment
# The Power Platform environment name is specified in the .env file as POWER_PLATFORM_ENVIRONMENT_NAME
# Prerequisite: to be logged in to Azure CLI with an account with the Power Platform Administrator role or a service principal registered with 'pac admin register'

# 1. Get access token for Power Platform Admin API
$powerPlatformAdminApiUrl = "https://api.bap.microsoft.com/" # URL of the Power Platform Admin API
$powerPlatformAdminApiToken = az account get-access-token --resource $powerPlatformAdminApiUrl --query accessToken --output tsv 

# 2. Link Power Platform network injection enterprise policy to environment
$ApiVersion = "2019-10-01" # Version of the Power Platform Admin API to use to link / unlink an enterprise policy to a Power Platform environment

$body = [pscustomobject]@{
  "SystemId" = az resource show --ids $enterprisePolicyId --query "properties.systemId" -o tsv
}

# get the power platform environment id
# list the Power Platform environments via Power Platform Admin API
$powerPlatformAdminApiToken = az account get-access-token --resource $powerPlatformAdminApiUrl --query accessToken --output tsv
$headers = @{ Authorization = "Bearer $powerPlatformAdminApiToken" }
$environmentsApiUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2019-10-01"
$environmentsResult = iwr -Uri $environmentsApiUrl -Headers $headers -Method Get | ConvertFrom-Json
# extract from $environmentsResult the name, display name and id of the environment specified in $powerPlatformEnvironmentId
#$targetEnvironment = $environmentsResult.value | Where-Object { $_.properties.displayName -eq $env:POWER_PLATFORM_ENVIRONMENT_NAME }

$powerPlatformEnvironmentId = ($environmentsResult.value | Where-Object { $_.properties.displayName -eq $env:POWER_PLATFORM_ENVIRONMENT_NAME } | Select-Object -ExpandProperty name)
$linkEnterprisePolicyUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$powerPlatformEnvironmentId/enterprisePolicies/NetworkInjection/link?&api-version=$ApiVersion"
$headers = @{ Authorization = "Bearer $powerPlatformAdminApiToken" }
$linkEnterprisePolicyResult = iwr -Uri $linkEnterprisePolicyUri -Headers $headers -Method Post -ContentType "application/json" -Body ($body | ConvertTo-Json) -UseBasicParsing

# check if the link operation was successful
if ($linkEnterprisePolicyResult.StatusCode -eq 200) {
    Write-Output "Enterprise policy $enterprisePolicyName linked to Power Platform environment $powerPlatformEnvironmentId successfully."
} elseif ($linkEnterprisePolicyResult.StatusCode -eq 202) {
    Write-Output "Linking enterprise policy $enterprisePolicyName to Power Platform environment $powerPlatformEnvironmentId is in progress."
} else {
    Write-Output "Failed to link enterprise policy $enterprisePolicyName to Power Platform environment $powerPlatformEnvironmentId. Status code: $($linkEnterprisePolicyResult.StatusCode)"
}
# 7. Poll the link operation
$operationLink = $linkEnterprisePolicyResult.Headers.Location
$pollInterval = 10 # seconds
$run = $true
while ($run) {
    Start-Sleep -Seconds $pollInterval
    $linkEnterprisePolicyResult = iwr -Uri $operationLink -Headers $headers -Method Get -UseBasicParsing
    if ($linkEnterprisePolicyResult.StatusCode -eq 200) {
        Write-Output "Enterprise policy $enterprisePolicyName linked to Power Platform environment $powerPlatformEnvironmentId successfully."
        $run = $false
    } elseif ($linkEnterprisePolicyResult.StatusCode -eq 202) {
        Write-Output "Linking enterprise policy $enterprisePolicyName to Power Platform environment $powerPlatformEnvironmentId is still in progress."
    } else {
        Write-Output "Failed to link enterprise policy $enterprisePolicyName to Power Platform environment $powerPlatformEnvironmentId. Status code: $($linkEnterprisePolicyResult.StatusCode)"
        $run = $false
    }
}



## ----------- Remove the enterprise policy ------------------------------------
## 1 Verify the enterprise policy exists
$policyExists = az resource show --ids $enterprisePolicyId --query "name" -o tsv
if (-not $policyExists) {
    Write-Error "Enterprise policy not found: $enterprisePolicyId"
    exit
}

## 2 Unlink the enterprise policy from the Power Platform environment first
$powerPlatformAdminApiToken = az account get-access-token --resource $powerPlatformAdminApiUrl --query accessToken --output tsv
$headers = @{ 
    Authorization = "Bearer $powerPlatformAdminApiToken" 
    "Content-Type" = "application/json"
}
$enterprisePolicyId = "/subscriptions/06dbbc7b-2363-4dd4-9803-95d07f1a8d3e/resourceGroups/SPOT-PROD-BYN/providers/Microsoft.PowerPlatform/enterprisePolicies/ep-SPOT-PROD"
$ApiVersion = "2019-10-01"
$policySystemId = az resource show --ids $enterprisePolicyId --query "properties.systemId" -o tsv
$body = [pscustomobject]@{
    "SystemId" = $policySystemId
}
$powerPlatformEnvironmentId = "a0c726e4-20e9-e867-a4f2-2c9214614140"
$unlinkUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$powerPlatformEnvironmentId/enterprisePolicies/NetworkInjection/unlink?api-version=$ApiVersion"
#$linkEnterprisePolicyUri = "https://{bapEndpoint}/providers/Microsoft.BusinessAppPlatform/environments/{environmentId}/enterprisePolicies/{policyTypeInUrl}/{operationName}?&api-version={apiVersion}" 
$unlinkResult = Invoke-WebRequest -Uri $unlinkUri -Headers $headers -Method Post -Body ($body | ConvertTo-Json) -UseBasicParsing

## 3 Wait for unlink operation to complete
$operationLink = $unlinkResult.Headers.'operation-location'
$pollInterval = 10 # seconds
$run = $true
while ($run) {
    Start-Sleep -Seconds $pollInterval
    $unlinkResult = Invoke-WebRequest -Uri $operationLink -Headers $headers -Method Get -UseBasicParsing
    if ($unlinkResult.StatusCode -eq 200) {
        Write-Output "Enterprise policy $enterprisePolicyName unlinked from Power Platform environment $powerPlatformEnvironmentId successfully."
        $run = $false
    } elseif ($unlinkResult.StatusCode -eq 202) {
        Write-Output "Unlinking enterprise policy $enterprisePolicyName from Power Platform environment $powerPlatformEnvironmentId is still in progress."
    } else {
        Write-Output "Failed to unlink enterprise policy $enterprisePolicyName from Power Platform environment $powerPlatformEnvironmentId. Status code: $($unlinkResult.StatusCode)"
        $run = $false
    }
}
## 4 Then remove the enterprise policy
az resource delete --ids $enterprisePolicyId --verbose