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
$randomSuffix = "xwz"

# Set parameters for the deployment
# 2. Create the resource group where the we want to deploy the resources if it does not yet exist
$resourceGroupName = "$env:POWER_PLATFORM_ENVIRONMENT_NAME-$randomSuffix"  # Name of the resource group
$resourceGroupExists = az group exists --name $resourceGroupName --subscription $env:SUBSCRIPTION_ID
if ($resourceGroupExists -eq "false") {
    $resourceGroupLocation = $env:AZURE_LOCATION
    Write-Output "Creating resource group $resourceGroupName in $resourceGroupLocation..."
    $resourceGroup = az group create --name $resourceGroupName --location $resourceGroupLocation --subscription $env:SUBSCRIPTION_ID
} else {
    Write-Output "Resource group $resourceGroupName already exists."
}
# 3. Deploy the resources (VNets, subnets, Power Platform enterprise policy) using Bicep
$deploymentName = "ppvnetint-" + $resourceGroupName  # Name of the deployment
$azureInfrastructureDeploymentOutputs = az deployment group create `
    --subscription $env:SUBSCRIPTION_ID `
    --resource-group $resourceGroupName `
    --name $deploymentName `
    --template-file ".\infra\main.bicep" `
    --parameters `
        environmentGroupName=$env:POWER_PLATFORM_ENVIRONMENT_NAME `
        azureLocation=$env:AZURE_LOCATION `
        enterprisePolicyLocation=$env:POWER_PLATFORM_LOCATION `
        suffix=$randomSuffix `
    --output json | ConvertFrom-Json

#$azureInfrastructureDeploymentOutputs.properties.outputs

# 4. Update APIM configuration to disable public access and enable VNet integration
Write-Output "Updating APIM configuration..."
$apimName = $azureInfrastructureDeploymentOutputs.properties.outputs.apimName.value
$privateEndpointSubnetId = $azureInfrastructureDeploymentOutputs.properties.outputs.privateEndpointSubnetId.value

if ($apimName -and $privateEndpointSubnetId) {
    try {
        Write-Output "Waiting for private endpoint to be fully provisioned..."
        Start-Sleep -Seconds 120
        
        Write-Output "Updating APIM: $apimName in RG: $resourceGroupName"
        
        # Get the APIM instance
        $apim = az apim show --name $apimName --resource-group $resourceGroupName --subscription $env:SUBSCRIPTION_ID | ConvertFrom-Json
        Write-Output "Retrieved APIM instance"
        
        # Update the configuration using Azure CLI
        Write-Output "Disabling public network access..."
        az apim update --name $apimName --resource-group $resourceGroupName --subscription $env:SUBSCRIPTION_ID --public-network-access false
        
        Write-Output "Configuring VNet integration..."
        az apim update --name $apimName --resource-group $resourceGroupName --subscription $env:SUBSCRIPTION_ID --virtual-network None 

        Write-Output "APIM configuration updated successfully"
        
    } catch {
        Write-Warning "Failed to update APIM configuration: $($_.Exception.Message)"
        Write-Output "You may need to manually update the APIM configuration to disable public access and enable VNet integration."
    }
} else {
    Write-Warning "APIM name or subnet ID not found in deployment outputs. Skipping APIM configuration update."
}

# 5. Output the results
Write-Host "Update the .env file with the following values:"
Write-Host "TENANT_ID=$env:TENANT_ID"
Write-Host "SUBSCRIPTION_ID=$env:SUBSCRIPTION_ID"
Write-Host "AZURE_LOCATION=$env:AZURE_LOCATION"
Write-Host "POWER_PLATFORM_ENVIRONMENT_NAME=$env:POWER_PLATFORM_ENVIRONMENT_NAME"
Write-Host "POWER_PLATFORM_LOCATION=$env:POWER_PLATFORM_LOCATION"
Write-Host "RESOURCE_GROUP=$($azureInfrastructureDeploymentOutputs.properties.outputs.resourceGroup.value)"
Write-Host "PRIMARY_VIRTUAL_NETWORK_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.primaryVnetName.value)"
Write-Host "PRIMARY_SUBNET_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.primarySubnetName.value)"
Write-Host "SECONDARY_VIRTUAL_NETWORK_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.failoverVnetName.value)"
Write-Host "SECONDARY_SUBNET_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.failoverSubnetName.value)"
Write-Host "ENTERPRISE_POLICY_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.enterprisePolicyName.value)"
Write-Host "APIM_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.apimName.value)"
Write-Host "APIM_ID=$($azureInfrastructureDeploymentOutputs.properties.outputs.apimId.value)"

# delete .env file and create a new one with the updated values
$envFilePath = ".\.env"
if (Test-Path $envFilePath) {
    Remove-Item $envFilePath
}
    $envContent = @"
TENANT_ID=$env:TENANT_ID
SUBSCRIPTION_ID=$env:SUBSCRIPTION_ID
AZURE_LOCATION=$env:AZURE_LOCATION
POWER_PLATFORM_ENVIRONMENT_NAME=$env:POWER_PLATFORM_ENVIRONMENT_NAME
POWER_PLATFORM_LOCATION=$env:POWER_PLATFORM_LOCATION
RESOURCE_GROUP=$($azureInfrastructureDeploymentOutputs.properties.outputs.resourceGroup.value)
PRIMARY_VIRTUAL_NETWORK_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.primaryVnetName.value)
PRIMARY_SUBNET_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.primarySubnetName.value)
SECONDARY_VIRTUAL_NETWORK_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.failoverVnetName.value)
SECONDARY_SUBNET_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.failoverSubnetName.value)
ENTERPRISE_POLICY_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.enterprisePolicyName.value)
APIM_NAME=$($azureInfrastructureDeploymentOutputs.properties.outputs.apimName.value)
APIM_ID=$($azureInfrastructureDeploymentOutputs.properties.outputs.apimId.value)
"@
Set-Content -Path $envFilePath -Value $envContent
        
