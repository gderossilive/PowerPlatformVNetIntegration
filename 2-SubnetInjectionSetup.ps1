<#
.SYNOPSIS
Links an Azure enterprise policy to a Power Platform environment for VNet subnet injection.

.DESCRIPTION
This script connects a Power Platform environment to an Azure enterprise policy that enables 
VNet subnet injection. It performs the following operations:

1. Loads environment variables from a specified file
2. Validates Azure CLI authentication and subscription context
3. Retrieves enterprise policy details from Azure Resource Manager
4. Obtains Power Platform Admin API access token
5. Links the enterprise policy to the specified Power Platform environment
6. Monitors the linking operation until completion

The script enables Power Platform environments to use Azure Virtual Network subnet injection,
allowing Dataverse and other services to run within your Azure network infrastructure for
enhanced security and connectivity options.

This script uses Azure CLI commands instead of Azure PowerShell modules for cross-platform
compatibility and consistent authentication experience.

.PARAMETER EnvFile
Specifies the path to the environment file containing required variables. 
Defaults to "./.env" in the current directory.

Required variables in the environment file:
- TENANT_ID: Azure AD tenant ID for authentication
- SUBSCRIPTION_ID: Azure subscription ID where the enterprise policy exists
- RESOURCE_GROUP: Azure resource group containing the enterprise policy
- ENTERPRISE_POLICY_NAME: Name of the enterprise policy resource
- POWER_PLATFORM_ENVIRONMENT_NAME: Display name of the Power Platform environment

All variables must be present in the environment file for the script to execute successfully.

.EXAMPLE
PS C:\> ./2-SubnetInjectionSetup.ps1

Uses the default .env file in the current directory to link the enterprise policy.
This is the most common usage after running the infrastructure creation script.

.EXAMPLE
PS C:\> ./2-SubnetInjectionSetup.ps1 -EnvFile "./config/production.env"

Uses a custom environment file for production deployment.
Useful when managing multiple environments with different configurations.

.EXAMPLE
PS C:\> ./2-SubnetInjectionSetup.ps1 -EnvFile "../shared-config.env"

Uses an environment file from a parent directory.
Demonstrates relative path usage for shared configurations.

.INPUTS
None. This script does not accept pipeline input.

.OUTPUTS
System.String
The script outputs status messages indicating the progress of the linking operation.
Upon successful completion, the Power Platform environment will be linked to the enterprise policy.

.NOTES
File Name      : 2-SubnetInjectionSetup.ps1
Author         : Power Platform VNet Integration Project
Prerequisite   : Azure CLI (az) must be installed and authenticated with appropriate permissions
Prerequisite   : PowerShell Core 7+ (pwsh) for cross-platform compatibility
Prerequisite   : Infrastructure must be deployed first using 1-InfraCreation.ps1

Required Permissions:
- Reader role on the Azure subscription for enterprise policy access
- Power Platform Administrator role for environment management
- Microsoft.PowerPlatform/enterprisePolicies/link/action permission

The linking operation typically takes 2-5 minutes to complete.
The script polls the operation status every 10 seconds until completion.

Version        : 2.0 (July 2025)
Last Modified  : Enhanced with comprehensive parameter support and cross-platform compatibility

.LINK
https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure

.LINK
https://docs.microsoft.com/en-us/power-platform/admin/api/overview

.LINK
https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers
#>

# Cross-platform PowerShell script for Power Platform VNet integration
# Uses Azure CLI instead of Azure PowerShell modules for consistent cross-platform experience
# Prerequisites: Azure CLI (az) must be installed and authenticated with appropriate permissions

param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to the environment file containing required variables")]
    [string]$EnvFile = "./.env"
)

# Enable strict mode for better error handling and debugging
Set-StrictMode -Version Latest

# Loads environment variables from a .env file into the current process
# Parses KEY=VALUE pairs while ignoring comments and empty lines
function Import-EnvFile {
    param([string]$Path)
    if (-Not (Test-Path $Path)) {
        throw "Environment file '$Path' not found."
    }
    Get-Content $Path | ForEach-Object {
        # Match lines in format KEY=VALUE, ignoring comments (lines starting with #)
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
        }
    }
}

# Ensures the user is logged in to Azure and sets the correct subscription
# Handles authentication flow and subscription context management
function Ensure-AzLogin {
    # Check if Azure CLI is already authenticated
    $accountInfo = az account show 2>$null
    if (-not $accountInfo) {
        Write-Output "Azure CLI not logged in. Attempting to log in..."
        if ($env:TENANT_ID) {
            # Use specific tenant if provided
            az login --tenant $env:TENANT_ID | Out-Null
        } else {
            # Use default tenant
            az login | Out-Null
        }
    }
    
    # Set subscription context if provided
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
# Required for Power Platform enterprise policy operations
function Ensure-ResourceProviderRegistered {
    $state = az provider show --namespace Microsoft.PowerPlatform --query "registrationState" -o tsv
    if ($state -ne "Registered") {
        Write-Host "Registering Microsoft.PowerPlatform resource provider..."
        az provider register --subscription $env:SUBSCRIPTION_ID --namespace Microsoft.PowerPlatform | Out-Null
    } else {
        Write-Host "Microsoft.PowerPlatform resource provider is already registered."
    }
}

# Retrieves an access token for the Power Platform Admin API
# Uses Azure CLI to get access token for the Business Application Platform service
function Get-PowerPlatformAccessToken {
    # Power Platform Admin API resource identifier
    $resource = "https://api.bap.microsoft.com/"
    return az account get-access-token --resource $resource --query accessToken --output tsv
}

# Gets the Power Platform environment ID by display name
# Searches through all environments to find the one matching the display name
function Get-PowerPlatformEnvironmentId {
    param([string]$AccessToken, [string]$DisplayName)
    $headers = @{ Authorization = "Bearer $AccessToken" }
    $url = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2019-10-01"
    $result = iwr -Uri $url -Headers $headers -Method Get | ConvertFrom-Json
    # Find environment by display name and return the internal environment ID
    return ($result.value | Where-Object { $_.properties.displayName -eq $DisplayName } | Select-Object -ExpandProperty name)
}

# Links the enterprise policy to the Power Platform environment
# Initiates the NetworkInjection enterprise policy linking operation
function Link-EnterprisePolicyToEnvironment {
    param(
        [string]$AccessToken,
        [string]$EnvironmentId,
        [string]$SystemId,
        [string]$ApiVersion = "2019-10-01" # API version for Power Platform Admin operations
    )
    $headers = @{ Authorization = "Bearer $AccessToken" }
    $body = @{ "SystemId" = $SystemId } | ConvertTo-Json
    # NetworkInjection is the specific enterprise policy type for VNet subnet injection
    $uri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/enterprisePolicies/NetworkInjection/link?&api-version=$ApiVersion"
    return iwr -Uri $uri -Headers $headers -Method Post -ContentType "application/json" -Body $body -UseBasicParsing
}

# Polls the operation status until completion or timeout
# Provides generic polling functionality for long-running Azure operations
function Wait-ForOperation {
    param(
        [string]$OperationUri,
        [hashtable]$Headers,
        [string]$SuccessMessage,
        [string]$InProgressMessage,
        [string]$FailureMessage,
        [int]$PollInterval = 10,    # seconds between status checks
        [int]$MaxRetries = 30       # maximum polling attempts (5 minutes total)
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

# --- Main Script Execution ---

# Step 1: Import and validate environment variables from .env file
Write-Output "Loading environment variables from: $EnvFile"
Import-EnvFile -Path $EnvFile

# Validate that all required environment variables are present
# These variables are essential for the linking operation to succeed
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

# Step 2: Ensure Azure CLI authentication and subscription context
Ensure-AzLogin

# Step 3: Handle cross-platform execution policy settings
# Set-ExecutionPolicy is only available on Windows PowerShell
if ($IsLinux -or $IsMacOS) {
    Write-Output "Running on non-Windows platform. Skipping Set-ExecutionPolicy."
} else {
    # Set the execution policy to allow script execution (Windows only)
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}


# Step 4: Retrieve enterprise policy details from Azure Resource Manager
# Get enterprise policy details using Azure CLI instead of PowerShell modules
# Legacy PowerShell approach (commented for reference):
# $environmentId = (Get-AdminPowerAppEnvironment "$env:POWER_PLATFORM_ENVIRONMENT_NAME").EnvironmentName
# $enterprisePolicyId = (Get-AzResource -Name "$env:ENTERPRISE_POLICY_NAME" -ResourceGroupName "$env:RESOURCE_GROUP").ResourceId

Write-Output "Retrieving enterprise policy details..."
$enterprisePolicyJson = az resource show --name "$env:ENTERPRISE_POLICY_NAME" --resource-group "$env:RESOURCE_GROUP" --resource-type "Microsoft.PowerPlatform/enterprisePolicies" --output json | ConvertFrom-Json
$enterprisePolicyName = $enterprisePolicyJson.name
$policyArmId = $enterprisePolicyJson.id

Write-Output "Enterprise Policy Name: $enterprisePolicyName"
Write-Output "Enterprise Policy ARM ID: $policyArmId"

# Step 5: Obtain Power Platform Admin API access token
Write-Output "Getting Power Platform Admin API access token..."
$powerPlatformAdminApiToken = Get-PowerPlatformAccessToken

# Step 6: Resolve Power Platform environment ID from display name
Write-Output "Resolving Power Platform environment ID..."
$powerPlatformEnvironmentId = Get-PowerPlatformEnvironmentId -AccessToken $powerPlatformAdminApiToken -DisplayName $env:POWER_PLATFORM_ENVIRONMENT_NAME

if (-not $powerPlatformEnvironmentId) {
    throw "Power Platform environment '$env:POWER_PLATFORM_ENVIRONMENT_NAME' not found. Please check the environment name."
}
Write-Output "Power Platform Environment ID: $powerPlatformEnvironmentId"

# Step 7: Extract SystemId from the enterprise policy resource
# The SystemId is required for linking the policy to the Power Platform environment
Write-Output "Extracting enterprise policy SystemId..."
$systemId = az resource show --ids $policyArmId --query "properties.systemId" -o tsv

if (-not $systemId) {
    throw "SystemId not found in enterprise policy properties. The policy may not be properly configured."
}
Write-Output "Enterprise Policy SystemId: $systemId"

# Step 8: Initiate enterprise policy linking operation
Write-Output "Initiating enterprise policy linking operation..."
$linkResult = Link-EnterprisePolicyToEnvironment -AccessToken $powerPlatformAdminApiToken -EnvironmentId $powerPlatformEnvironmentId -SystemId $systemId

# Step 9: Monitor linking operation progress until completion
# Extract operation location from response headers for status polling
$operationLocationHeader = $linkResult.Headers.'operation-location'

# Handle potential array response from headers (ensure we get a single string)
if ($operationLocationHeader -is [array]) {
    $operationLink = $operationLocationHeader[0]
} else {
    $operationLink = $operationLocationHeader
}

Write-Output "Operation link: $operationLink"

# Validate the operation link before proceeding
if (-not $operationLink -or $operationLink -eq "") {
    throw "No operation-location header found in the link response. The linking operation may have failed."
}

# Ensure the operation link is a valid URI
try {
    $uri = [System.Uri]::new($operationLink)
    Write-Output "Polling operation status at: $($uri.AbsoluteUri)"
} catch {
    throw "Invalid operation link URI: $operationLink. Error: $($_.Exception.Message)"
}

# Poll the operation status until completion
# Power Platform operations are asynchronous and require status monitoring
$pollInterval = 10 # seconds between status checks
$run = $true
Write-Output "Starting operation status polling (checking every $pollInterval seconds)..."

while ($run) {
    Start-Sleep -Seconds $pollInterval
    
    # Refresh access token to ensure it hasn't expired during long operations
    $powerPlatformAdminApiToken = Get-PowerPlatformAccessToken
    $headers = @{ 
        Authorization = "Bearer $powerPlatformAdminApiToken" 
        "Content-Type" = "application/json"
    }
    
    $linkResult = Invoke-WebRequest -Uri $operationLink -Headers $headers -Method Get -UseBasicParsing
    
    if ($linkResult.StatusCode -eq 200) {
        Write-Output "✓ Enterprise policy '$enterprisePolicyName' successfully linked to Power Platform environment '$env:POWER_PLATFORM_ENVIRONMENT_NAME'."
        Write-Output "VNet subnet injection is now configured for this environment."
        $run = $false
    } elseif ($linkResult.StatusCode -eq 202) {
        Write-Output "⏳ Linking enterprise policy '$enterprisePolicyName' to Power Platform environment '$env:POWER_PLATFORM_ENVIRONMENT_NAME' is still in progress..."
    } else {
        Write-Output "❌ Failed to link enterprise policy '$enterprisePolicyName' to Power Platform environment '$env:POWER_PLATFORM_ENVIRONMENT_NAME'. Status code: $($linkResult.StatusCode)"
        Write-Output "Response content: $($linkResult.Content)"
        $run = $false
    }
}
