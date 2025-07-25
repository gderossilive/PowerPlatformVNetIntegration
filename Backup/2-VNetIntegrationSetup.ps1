# RunME.ps1
# This script sets up the environment for running the Power Platform VNet Integration scripts.

# import environment variables from .env file
Get-Content ".\.env" | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}

write-host "Environment variables loaded from .env file." -ForegroundColor Green
write-host "Starting with Authentication..." -ForegroundColor Green
write-host "TENANT_ID: $env:TENANT_ID" -ForegroundColor Green
write-host "SUBSCRIPTION_ID: $env:SUBSCRIPTION_ID" -ForegroundColor Green
& az login --scope https://management.core.windows.net//.default --tenant $env:TENANT_ID
& az account set --subscription $env:SUBSCRIPTION_ID # MCAPS tenant

# Set the execution policy to allow script execution
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Ensure that your Azure subscription is registered for the Microsoft.PowerPlatform resource provider
write-host "STEP 1: Ensuring Microsoft.PowerPlatform resource provider is registered..." -ForegroundColor Green
write-host "Subscription ID: $env:SUBSCRIPTION_ID" -ForegroundColor Green
& ".\orig-scripts\SetupSubscriptionForPowerPlatform.ps1" -subscriptionId $env:SUBSCRIPTION_ID

# Delegate each subnet to Microsoft.PowerPlatform/enterprisePolicies
write-host "STEP 2: Delegating the subnet to Microsoft.PowerPlatform/enterprisePolicies..." -ForegroundColor Green
write-host "Subscription ID: $env:SUBSCRIPTION_ID" -ForegroundColor Green
write-host "Virtual Network Name: $env:PRIMARY_VIRTUAL_NETWORK_NAME" -ForegroundColor Green
write-host "Subnet Name: $env:PRIMARY_SUBNET_NAME" -ForegroundColor Green
& ".\orig-scripts\SubnetInjection\SetupVnetForSubnetDelegation.ps1" `
    -virtualNetworkSubscriptionId "$env:SUBSCRIPTION_ID" `
    -virtualNetworkName "$env:PRIMARY_VIRTUAL_NETWORK_NAME" `
    -subnetName "$env:PRIMARY_SUBNET_NAME"
# Delegate the secondary subnet if it exists
write-host "STEP 2: Delegating the subnet to Microsoft.PowerPlatform/enterprisePolicies..." -ForegroundColor Green
write-host "Subscription ID: $env:SUBSCRIPTION_ID" -ForegroundColor Green
write-host "Virtual Network Name: $env:SECONDARY_VIRTUAL_NETWORK_NAME" -ForegroundColor Green
write-host "Subnet Name: $env:SECONDARY_SUBNET_NAME" -ForegroundColor Green
& ".\orig-scripts\SubnetInjection\SetupVnetForSubnetDelegation.ps1" `
    -virtualNetworkSubscriptionId "$env:SUBSCRIPTION_ID" `
    -virtualNetworkName "$env:SECONDARY_VIRTUAL_NETWORK_NAME" `
    -subnetName "$env:SECONDARY_SUBNET_NAME"

# get the primary virtual network resource id
$primaryVnetId = (Get-AzVirtualNetwork -Name "$env:PRIMARY_VIRTUAL_NETWORK_NAME" -ResourceGroupName "$env:RESOURCE_GROUP").Id
$secondaryVnetId = (Get-AzVirtualNetwork -Name "$env:SECONDARY_VIRTUAL_NETWORK_NAME" -ResourceGroupName "$env:RESOURCE_GROUP").Id

# Create the enterprise policy
write-host "STEP 3: Creating the subnet injection enterprise policy..." -ForegroundColor Green
write-host "Subscription ID: $env:SUBSCRIPTION_ID" -ForegroundColor Green
write-host "Resource Group: $env:RESOURCE_GROUP" -ForegroundColor Green
write-host "Enterprise Policy Name: "$env:ENTERPRISE_POLICY_NAME"" -ForegroundColor Green
write-host "Enterprise Policy Location: $env:LOCATION" -ForegroundColor Green
write-host "Primary Virtual Network ID: $primaryVnetId" -ForegroundColor Green
write-host "Primary Subnet Name: $env:PRIMARY_SUBNET_NAME" -ForegroundColor Green
write-host "Secondary Virtual Network ID: $secondaryVnetId" -ForegroundColor Green
write-host "Secondary Subnet Name: $env:SECONDARY_SUBNET_NAME" -ForegroundColor Green
& ".\orig-scripts\SubnetInjection\CreateSubnetInjectionEnterprisePolicy.ps1" `
    -subscriptionId "$env:SUBSCRIPTION_ID" `
    -resourceGroup "$env:RESOURCE_GROUP" `
    -enterprisePolicyName "$env:ENTERPRISE_POLICY_NAME" `
    -enterprisePolicyLocation "$env:POWER_PLATFORM_LOCATION" `
    -primaryVnetId "$primaryVnetId" `
    -primarySubnetName "$env:PRIMARY_SUBNET_NAME" `
    -secondaryVnetId $secondaryVnetId `
    -secondarySubnetName "$env:SECONDARY_SUBNET_NAME"

# Grant Reader role to the enterprise policy to the identity / group that will finalize the configuration - link the enterprise policy to the Power Platform environments
write-host "STEP 4: Granting Reader role to the enterprise policy identity..." -ForegroundColor Green

# Link enterprise policy to the Power Platform environment
write-host "STEP 5: Linking the enterprise policy to the Power Platform environment..." -ForegroundColor Green
#$environmentName = (Get-AdminPowerAppEnvironment "$env:POWER_PLATFORM_ENVIRONMENT_NAME").EnvironmentName
$environmentId = (Get-AdminPowerAppEnvironment "$env:POWER_PLATFORM_ENVIRONMENT_NAME").EnvironmentName
$policyArmId = (Get-AzResource -Name "$env:ENTERPRISE_POLICY_NAME" -ResourceGroupName "$env:RESOURCE_GROUP").ResourceId
$endpoint = "prod"
write-host "Power Platform Environment ID: $environmentId" -ForegroundColor Green
write-host "Policy ARM ID: $policyArmId" -ForegroundColor Green
write-host "Power Platform endpoint: $endpoint" -ForegroundColor Green
& ".\orig-scripts\SubnetInjection\NewSubnetInjection.ps1" `
    -environmentId "$environmentId" `
    -policyArmId "$policyArmId" `
    -endpoint "$endpoint"


