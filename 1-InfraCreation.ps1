<#
.SYNOPSIS
Creates Azure infrastructure for Power Platform VNet integration with API Management.

.DESCRIPTION
This script deploys the complete Azure infrastructure needed for Power Platform VNet integration
including virtual networks, subnets, API Management, and enterprise policies. 

The script performs the following operations:
1. Loads environment variables from a specified file
2. Validates Azure CLI authentication and subscription context
3. Registers the Microsoft.PowerPlatform resource provider
4. Deploys infrastructure using Azure Developer CLI (azd):
   - Primary and secondary virtual networks with subnets in different regions
   - Azure API Management instance with Developer SKU
   - Private endpoints for secure connectivity
   - Enterprise policy for Power Platform subnet delegation
5. Configures API Management to disable public access and enable private connectivity
6. Updates the environment file with deployment outputs for subsequent scripts

The infrastructure creates a highly available setup with:
- Primary VNet: 10.10.0.0/23 (injection subnet: 10.10.0.0/24, private endpoints: 10.10.1.0/24)
- Secondary VNet: 10.20.0.0/23 (injection subnet: 10.20.0.0/24, private endpoints: 10.20.1.0/24)
- Failover regions are automatically selected based on the primary location
- All resources use a consistent naming pattern with a unique suffix

.PARAMETER EnvFile
Specifies the path to the environment file containing required variables. 
Defaults to "./.env" in the current directory.

Required variables in the environment file:
- TENANT_ID: Azure AD tenant ID for authentication
- SUBSCRIPTION_ID: Azure subscription ID where resources will be deployed
- AZURE_LOCATION: Primary Azure region (e.g., 'westeurope', 'eastus')
- POWER_PLATFORM_ENVIRONMENT_NAME: Display name of the Power Platform environment
- POWER_PLATFORM_LOCATION: Power Platform region (e.g., 'europe', 'unitedstates')

Optional variables:
- RESOURCE_GROUP: Will be populated after deployment
- APIM_NAME: Will be populated after deployment
- PRIMARY_VIRTUAL_NETWORK_NAME: Will be populated after deployment
- ENTERPRISE_POLICY_NAME: Will be populated after deployment

.EXAMPLE
PS C:\> ./1-InfraCreation.ps1

Uses the default .env file in the current directory to deploy infrastructure.
This is the most common usage pattern for standard deployments.

.EXAMPLE
PS C:\> ./1-InfraCreation.ps1 -EnvFile "./environments/production.env"

Uses a custom environment file for production deployment.
Useful for managing multiple environments (dev, staging, production).

.EXAMPLE
PS C:\> ./1-InfraCreation.ps1 -EnvFile "../shared-config.env"

Uses an environment file from a parent directory.
Demonstrates relative path usage for shared configurations.

.EXAMPLE
PS C:\> Get-Help ./1-InfraCreation.ps1 -Full

Displays this comprehensive help documentation.

.INPUTS
None. This script does not accept pipeline input.

.OUTPUTS
System.String
The script outputs status messages and updates the specified environment file with deployment results.
Key outputs include:
- Resource group name with unique suffix
- APIM instance name and ID
- Virtual network and subnet names
- Enterprise policy name

.NOTES
File Name      : 1-InfraCreation.ps1
Author         : Power Platform VNet Integration Project
Prerequisite   : Azure CLI (az) must be installed and authenticated with Contributor role
Prerequisite   : Azure Developer CLI (azd) must be installed
Prerequisite   : PowerShell Core 7+ (pwsh) for cross-platform compatibility

This script uses:
- Azure CLI for authentication and resource management
- Azure Developer CLI (azd) for streamlined infrastructure deployment
- Bicep templates for Infrastructure as Code
- Cross-platform PowerShell Core for Windows, Linux, and macOS support

The deployment typically takes 15-30 minutes depending on Azure region and resource provisioning times.
API Management instances can take the longest time to provision (10-20 minutes).

Version        : 2.0 (July 2025)
Last Modified  : Enhanced with comprehensive parameter support and cross-platform compatibility

.LINK
https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure

.LINK
https://docs.microsoft.com/en-us/azure/api-management/private-endpoint

.LINK
https://github.com/Azure/azure-dev
#>

param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to the environment file containing required variables")]
    [string]$EnvFile = "./.env"
)

# Import environment variables from the specified .env file
# This parses KEY=VALUE pairs while ignoring comments and empty lines
Write-Output "Loading environment variables from: $EnvFile"
Get-Content $EnvFile | ForEach-Object {
    # Match lines in format KEY=VALUE, ignoring comments (lines starting with #)
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        # Set environment variable with trimmed key and value
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}

# Check platform compatibility for Set-ExecutionPolicy
# Set-ExecutionPolicy is only available on Windows PowerShell
if ($IsLinux -or $IsMacOS) {
    Write-Output "Running on non-Windows platform. Skipping Set-ExecutionPolicy."
} else {
    # Set the execution policy to allow script execution (Windows only)
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
}

# Ensure Azure CLI is logged in
Write-Output "Checking Azure CLI authentication..."
$accountInfo = az account show 2>$null
if (-not $accountInfo) {
    Write-Error "Azure CLI is not logged in. Please login first."
    az login --tenant $env:TENANT_ID
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to log in to Azure CLI. Please check your credentials."
        exit 1
    }
}

# Set the subscription context
Write-Output "Setting Azure subscription context..."
az account set --subscription $env:SUBSCRIPTION_ID
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set subscription context. Please check your subscription ID."
    exit 1
}

# Step 1: Register Microsoft.PowerPlatform resource provider
# This is required for Power Platform enterprise policies and subnet delegation
if (-not (az provider show --namespace Microsoft.PowerPlatform --query "registrationState" -o tsv)) {
    Write-Output "Registering Microsoft.PowerPlatform resource provider..."
    az provider register --subscription $env:SUBSCRIPTION_ID --namespace Microsoft.PowerPlatform
} else {
    Write-Output "Microsoft.PowerPlatform resource provider is already registered."
}

# Remove legacy deployment code - kept for reference only
# This section was replaced by azd-based deployment for better maintainability
# Original approach used direct Bicep deployment with manual resource group creation

# create a 3 characters long random string to use as a suffix for the resource group name
#$randomSuffix = -join ((97..122) | Get-Random -Count 3 | ForEach-Object { [char]$_ })

# Set parameters for the deployment
# 2. Create the resource group where the we want to deploy the resources if it does not yet exist
#$resourceGroupName = "$env:POWER_PLATFORM_ENVIRONMENT_NAME-$randomSuffix"  # Name of the resource group
#$resourceGroupExists = az group exists --name $resourceGroupName --subscription $env:SUBSCRIPTION_ID
#if ($resourceGroupExists -eq "false") {
#    $resourceGroupLocation = $env:AZURE_LOCATION
#    Write-Output "Creating resource group $resourceGroupName in $resourceGroupLocation..."
#    $resourceGroup = az group create --name $resourceGroupName --location $resourceGroupLocation --subscription $env:SUBSCRIPTION_ID
#} else {
#    Write-Output "Resource group $resourceGroupName already exists."
#}
# 3. Deploy the resources (VNets, subnets, Power Platform enterprise policy) using Bicep
#$deploymentName = "ppvnetint-" + $resourceGroupName  # Name of the deployment
#$azureInfrastructureDeploymentOutputs = az deployment group create `
#    --subscription $env:SUBSCRIPTION_ID `
#    --resource-group $resourceGroupName `
#    --name $deploymentName `
#    --template-file ".\infra\main.bicep" `
#    --parameters `
#        environmentGroupName=$env:POWER_PLATFORM_ENVIRONMENT_NAME `
#        azureLocation=$env:AZURE_LOCATION `
#        enterprisePolicyLocation=$env:POWER_PLATFORM_LOCATION `
#        suffix=$randomSuffix `
#    --output json | ConvertFrom-Json

#$azureInfrastructureDeploymentOutputs.properties.outputs

# Step 2: Deploy infrastructure using Azure Developer CLI (azd)
# azd provides streamlined deployment with integrated Bicep templates
Write-Output "Running azd up to deploy infrastructure..."
azd up --environment $env:POWER_PLATFORM_ENVIRONMENT_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Error "azd up failed. Please check the error messages above."
    exit 1
}

# Step 3: Extract deployment outputs from azd environment
# Convert azd outputs to match expected Azure deployment structure
Write-Output "Getting deployment outputs..."
$azdEnvValues = azd env get-values --environment $env:POWER_PLATFORM_ENVIRONMENT_NAME --output json | ConvertFrom-Json

# Create a structure similar to Azure deployment outputs for compatibility
# This ensures backward compatibility with existing scripts that expect Azure deployment format
$azureInfrastructureDeploymentOutputs = @{
    properties = @{
        outputs = @{
            resourceGroup = @{ value = $azdEnvValues.resourceGroup }
            primaryVnetName = @{ value = $azdEnvValues.primaryVnetName }
            primarySubnetName = @{ value = $azdEnvValues.primarySubnetName }
            failoverVnetName = @{ value = $azdEnvValues.failoverVnetName }
            failoverSubnetName = @{ value = $azdEnvValues.failoverSubnetName }
            enterprisePolicyName = @{ value = $azdEnvValues.enterprisePolicyName }
            apimName = @{ value = $azdEnvValues.apimName }
            apimId = @{ value = $azdEnvValues.apimId }
            privateEndpointSubnetId = @{ value = $azdEnvValues.privateEndpointSubnetId }
        }
    }
}

# Step 4: Configure API Management for private connectivity
# Disable public access and configure VNet integration for enhanced security
Write-Output "Updating APIM configuration..."
$apimName = $azureInfrastructureDeploymentOutputs.properties.outputs.apimName.value
$privateEndpointSubnetId = $azureInfrastructureDeploymentOutputs.properties.outputs.privateEndpointSubnetId.value
$resourceGroupName = $azureInfrastructureDeploymentOutputs.properties.outputs.resourceGroup.value

if ($apimName -and $resourceGroupName) {
    try {
        # Wait for private endpoint to be fully provisioned before configuration
        # 120 seconds allows sufficient time for Azure private endpoint deployment
        Write-Output "Waiting for private endpoint to be fully provisioned..."
        Start-Sleep -Seconds 120
        
        Write-Output "Updating APIM: $apimName in RG: $resourceGroupName"
        
        # Verify APIM instance exists and is accessible
        $apim = az apim show --name $apimName --resource-group $resourceGroupName --subscription $env:SUBSCRIPTION_ID | ConvertFrom-Json
        Write-Output "Retrieved APIM instance"
        
        # Disable public network access for enhanced security
        Write-Output "Disabling public network access..."
        az apim update --name $apimName --resource-group $resourceGroupName --subscription $env:SUBSCRIPTION_ID --public-network-access false
        
        # Configure VNet integration (set to None initially, will be configured via private endpoints)
        Write-Output "Configuring VNet integration..."
        az apim update --name $apimName --resource-group $resourceGroupName --subscription $env:SUBSCRIPTION_ID --virtual-network None 

        Write-Output "APIM configuration updated successfully"
        
    } catch {
        Write-Warning "Failed to update APIM configuration: $($_.Exception.Message)"
        Write-Output "You may need to manually update the APIM configuration to disable public access and enable VNet integration."
    }
} else {
    Write-Warning "APIM name or resource group not found in deployment outputs. Skipping APIM configuration update."
}

# Step 5: Display and update environment configuration
# Output deployment results for user reference and update .env file
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

# Replace existing .env file with updated configuration
# This ensures all deployment outputs are available for subsequent scripts
$envFilePath = "./.env"
if (Test-Path $envFilePath) {
    Remove-Item $envFilePath -Force
    Write-Output "Deleted existing .env file."
} else {
    Write-Output ".env file does not exist, creating a new one."
}

# Create the new .env file with all required environment variables
# Include both input parameters and deployment outputs
Write-Output "Creating new .env file with updated values..."
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
