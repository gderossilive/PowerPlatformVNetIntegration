<#
.SYNOPSIS
Cleans up all Azure infrastructure and Power Platform configurations created for VNet integration.

.DESCRIPTION
This script safely removes all Azure resources and Power Platform configurations that were created
by the Power Platform VNet integration deployment scripts. It performs the following operations:

1. Loads environment variables from a specified file
2. Validates Azure CLI authentication and subscription context
3. Unlinks the enterprise policy from the Power Platform environment
4. Removes all Azure infrastructure using Azure Developer CLI (azd)
5. Optionally removes the resource group and all contained resources
6. Cleans up the environment configuration file

The script includes comprehensive safety checks and confirmation prompts to prevent accidental
deletion of resources. It follows the reverse order of the deployment process to ensure proper
cleanup of dependencies.

IMPORTANT: This script will permanently delete Azure resources and configurations. 
Use with caution and ensure you have proper backups if needed.

.PARAMETER EnvFile
Specifies the path to the environment file containing the deployment configuration.
Defaults to "./.env" in the current directory.

The environment file should contain the variables populated by the deployment scripts:
- TENANT_ID: Azure AD tenant ID for authentication
- SUBSCRIPTION_ID: Azure subscription ID where resources exist
- RESOURCE_GROUP: Azure resource group containing the deployed resources
- ENTERPRISE_POLICY_NAME: Name of the enterprise policy to unlink
- POWER_PLATFORM_ENVIRONMENT_NAME: Display name of the Power Platform environment
- APIM_NAME: Name of the API Management instance (optional)

.PARAMETER Force
When specified, skips interactive confirmation prompts and proceeds with cleanup.
Use this parameter for automated scenarios or when you're certain about the cleanup.

WARNING: Using -Force will delete resources without confirmation prompts.

.PARAMETER SkipPowerPlatform
When specified, skips the Power Platform enterprise policy unlinking step.
Use this when you want to keep the Power Platform configuration but remove Azure resources.

.PARAMETER KeepResourceGroup
When specified, keeps the resource group after removing individual resources.
Use this when the resource group contains other resources not related to this deployment.

.EXAMPLE
PS C:\> ./3-Cleanup.ps1

Performs interactive cleanup using the default .env file with confirmation prompts.
This is the safest way to clean up resources as it provides confirmation at each step.

.EXAMPLE
PS C:\> ./3-Cleanup.ps1 -Force

Performs automated cleanup without confirmation prompts using the default .env file.
Use this for scripted scenarios where you're certain about the cleanup operation.

.EXAMPLE
PS C:\> ./3-Cleanup.ps1 -EnvFile "./config/production.env" -SkipPowerPlatform

Uses a custom environment file and skips Power Platform cleanup.
Useful when you want to remove Azure resources but keep Power Platform configuration.

.EXAMPLE
PS C:\> ./3-Cleanup.ps1 -KeepResourceGroup

Removes all resources but keeps the resource group intact.
Useful when the resource group contains other unrelated resources.

.EXAMPLE
PS C:\> Get-Help ./3-Cleanup.ps1 -Full

Displays this comprehensive help documentation.

.INPUTS
None. This script does not accept pipeline input.

.OUTPUTS
System.String
The script outputs status messages indicating the progress of the cleanup operation.
Upon successful completion, all specified resources and configurations will be removed.

.NOTES
File Name      : 3-Cleanup.ps1
Author         : Power Platform VNet Integration Project
Prerequisite   : Azure CLI (az) must be installed and authenticated with appropriate permissions
Prerequisite   : Azure Developer CLI (azd) must be installed for infrastructure cleanup
Prerequisite   : PowerShell Core 7+ (pwsh) for cross-platform compatibility
Prerequisite   : Microsoft.PowerApps.Administration.PowerShell module (auto-installed if missing)

Required Permissions:
- Contributor role on the Azure subscription for resource deletion
- Power Platform Administrator role for enterprise policy management
- Microsoft.PowerPlatform/enterprisePolicies/unlink/action permission

Safety Features:
- Interactive confirmation prompts (unless -Force is specified)
- Comprehensive validation of environment variables
- Error handling with meaningful messages
- Graceful handling of missing resources
- Detailed logging of cleanup operations
- Automatic PowerApps PowerShell module installation

The cleanup process typically takes 10-20 minutes depending on the number of resources
and their deletion dependencies. API Management instances may take the longest to delete.
Enterprise policy unlinking is performed using PowerApps PowerShell cmdlets for reliability.

Version        : 1.0 (July 2025)
Last Modified  : Initial creation with comprehensive cleanup functionality

.LINK
https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure

.LINK
https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/delete-resource-group

.LINK
https://github.com/Azure/azure-dev
#>

param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to the environment file containing deployment configuration")]
    [string]$EnvFile = "./.env",
    
    [Parameter(Mandatory = $false, HelpMessage = "Skip interactive confirmation prompts")]
    [switch]$Force,
    
    [Parameter(Mandatory = $false, HelpMessage = "Skip Power Platform enterprise policy unlinking")]
    [switch]$SkipPowerPlatform,
    
    [Parameter(Mandatory = $false, HelpMessage = "Keep the resource group after cleanup")]
    [switch]$KeepResourceGroup
)

# Enable strict mode for better error handling and debugging
Set-StrictMode -Version Latest

# Global variables for error tracking and cleanup state
$script:CleanupErrors = @()
$script:CleanupSuccess = @()

# Import environment variables from the specified .env file
# Parses KEY=VALUE pairs while ignoring comments and empty lines
function Import-EnvFile {
    param([string]$Path)
    
    if (-Not (Test-Path $Path)) {
        throw "Environment file '$Path' not found. Please ensure the file exists and contains the deployment configuration."
    }
    
    Write-Output "Loading environment variables from: $Path"
    $variableCount = 0
    
    Get-Content $Path | ForEach-Object {
        # Match lines in format KEY=VALUE, ignoring comments (lines starting with #)
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
            # Set environment variable with trimmed key and value
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
            $variableCount++
        }
    }
    
    Write-Output "Loaded $variableCount environment variables from configuration file."
}

# Ensures the user is logged in to Azure and sets the correct subscription
# Handles authentication flow and subscription context management
function Ensure-AzLogin {
    Write-Output "Validating Azure CLI authentication..."
    
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
        
        # Verify login was successful
        $accountInfo = az account show 2>$null
        if (-not $accountInfo) {
            throw "Failed to authenticate with Azure CLI. Please check your credentials and try again."
        }
    }
    
    # Set subscription context if provided
    if ($env:SUBSCRIPTION_ID) {
        Write-Output "Setting Azure subscription context to: $env:SUBSCRIPTION_ID"
        az account set --subscription $env:SUBSCRIPTION_ID
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set Azure subscription context. Please verify the subscription ID and your access permissions."
        }
        
        # Verify subscription context
        $currentSub = az account show --query "id" -o tsv
        if ($currentSub -ne $env:SUBSCRIPTION_ID) {
            throw "Subscription context mismatch. Expected: $env:SUBSCRIPTION_ID, Current: $currentSub"
        }
    } else {
        throw "SUBSCRIPTION_ID environment variable is not set. Cannot proceed with cleanup."
    }
    
    Write-Output "✓ Azure CLI authentication validated successfully."
}

# Installs PowerApps PowerShell module if not already installed
# Required for Power Platform enterprise policy operations
function Install-PowerAppsModule {
    try {
        Write-Output "Checking PowerApps PowerShell module..."
        
        # Check if the module is already installed
        $module = Get-Module -ListAvailable -Name Microsoft.PowerApps.Administration.PowerShell
        
        if (-not $module) {
            Write-Output "Installing PowerApps PowerShell module..."
            Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force -AllowClobber -Scope CurrentUser
            Write-Output "✓ PowerApps PowerShell module installed successfully."
        } else {
            Write-Output "✓ PowerApps PowerShell module is already installed."
        }
        
        # Import the module
        Import-Module Microsoft.PowerApps.Administration.PowerShell -Force
        return $true
    }
    catch {
        Write-Warning "Failed to install/import PowerApps PowerShell module: $($_.Exception.Message)"
        return $false
    }
}

# Connects to Power Platform using PowerApps PowerShell cmdlets
# Uses Azure CLI credentials for authentication
function Connect-PowerPlatform {
    try {
        Write-Output "Connecting to Power Platform..."
        
        # Use Azure CLI token for authentication
        $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
        if ($context.Account) {
            # Add Power Platform account using existing Azure CLI context
            Add-PowerAppsAccount -TenantID $env:TENANT_ID
            Write-Output "✓ Connected to Power Platform successfully."
            return $true
        } else {
            Write-Warning "No Azure CLI context found. Please ensure you are logged in with Azure CLI."
            return $false
        }
    }
    catch {
        Write-Warning "Failed to connect to Power Platform: $($_.Exception.Message)"
        Write-Output "Attempting alternative authentication method..."
        
        try {
            # Alternative: Connect using tenant ID
            Add-PowerAppsAccount -TenantID $env:TENANT_ID
            Write-Output "✓ Connected to Power Platform using alternative method."
            return $true
        }
        catch {
            Write-Warning "Failed to connect to Power Platform with alternative method: $($_.Exception.Message)"
            return $false
        }
    }
}

# Gets the Power Platform environment by display name
# Uses PowerApps PowerShell cmdlets for reliable environment lookup
function Get-PowerPlatformEnvironmentByName {
    param([string]$DisplayName)
    
    try {
        Write-Output "Searching for Power Platform environment: $DisplayName"
        
        # Get all environments and find by display name
        $environments = Get-AdminPowerAppEnvironment
        $targetEnvironment = $environments | Where-Object { $_.DisplayName -eq $DisplayName }
        
        if (-not $targetEnvironment) {
            Write-Warning "Power Platform environment '$DisplayName' not found. It may have been already removed or renamed."
            return $null
        }
        
        Write-Output "✓ Found Power Platform environment: $($targetEnvironment.EnvironmentName)"
        return $targetEnvironment
    }
    catch {
        Write-Warning "Error retrieving Power Platform environment: $($_.Exception.Message)"
        return $null
    }
}

# Unlinks the VNet enterprise policy from the Power Platform environment
# Uses the proper PowerApps PowerShell approach for enterprise policy management
function Remove-PowerPlatformVNetPolicy {
    param(
        [string]$EnvironmentId,
        [string]$PolicyArmId
    )
    
    try {
        Write-Output "Attempting to unlink VNet enterprise policy from environment..."
        Write-Output "Environment ID: $EnvironmentId"
        Write-Output "Policy ARM ID: $PolicyArmId"
        
        # Check if the environment has the enterprise policy linked
        $environment = Get-AdminPowerAppEnvironment -EnvironmentName $EnvironmentId
        
        if (-not $environment) {
            Write-Warning "Environment $EnvironmentId not found or inaccessible."
            return $false
        }
        
        # Check if the environment has enterprise policies
        if (-not $environment.Internal.properties.enterprisePolicies) {
            Write-Output "✓ No enterprise policies found on environment. Already clean."
            return $true
        }
        
        # Check for VNet policy specifically
        $vnetPolicy = $environment.Internal.properties.enterprisePolicies.VNets
        if (-not $vnetPolicy) {
            Write-Output "✓ No VNet enterprise policy found on environment. Already clean."
            return $true
        }
        
        Write-Output "VNet enterprise policy found. Attempting removal..."
        
        # Use the Remove-AdminPowerAppEnvironmentEnterprisePolicy cmdlet
        Remove-AdminPowerAppEnvironmentEnterprisePolicy -EnvironmentName $EnvironmentId -PolicyType "NetworkInjection"
        
        Write-Output "✓ VNet enterprise policy removal initiated successfully."
        return $true
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Warning "Error removing VNet enterprise policy: $errorMessage"
        
        # Check if error indicates policy is already removed or doesn't exist
        if ($errorMessage -like "*not found*" -or $errorMessage -like "*does not exist*" -or $errorMessage -like "*already removed*") {
            Write-Output "✓ Enterprise policy appears to already be removed."
            return $true
        }
        
        # For other errors, check if we can use alternative approach
        Write-Output "Attempting alternative removal approach..."
        try {
            # Alternative approach using REST API directly
            $result = Remove-AdminPowerAppEnvironmentEnterprisePolicy -EnvironmentName $EnvironmentId -PolicyType "VNets"
            Write-Output "✓ VNet enterprise policy removed using alternative approach."
            return $true
        }
        catch {
            Write-Warning "Alternative removal approach also failed: $($_.Exception.Message)"
            return $false
        }
    }
}

# Validates that required environment variables are present
# Ensures all necessary configuration is available for cleanup operations
function Test-EnvironmentVariables {
    Write-Output "Validating environment variables..."
    
    # Core required variables for any cleanup operation
    $requiredVars = @('TENANT_ID', 'SUBSCRIPTION_ID')
    
    # Additional variables needed for specific cleanup operations
    if (-not $SkipPowerPlatform) {
        $requiredVars += @('POWER_PLATFORM_ENVIRONMENT_NAME')
    }
    
    $missingVars = @()
    $availableVars = @()
    
    foreach ($var in $requiredVars) {
        if (-not (Get-Item -Path "env:$var" -ErrorAction SilentlyContinue) -or 
            [string]::IsNullOrWhiteSpace((Get-Item -Path "env:$var" -ErrorAction SilentlyContinue).Value)) {
            $missingVars += $var
        } else {
            $availableVars += $var
        }
    }
    
    # Check optional variables and warn if missing
    $optionalVars = @('RESOURCE_GROUP', 'ENTERPRISE_POLICY_NAME', 'APIM_NAME')
    $missingOptionalVars = @()
    
    foreach ($var in $optionalVars) {
        if (-not (Get-Item -Path "env:$var" -ErrorAction SilentlyContinue) -or 
            [string]::IsNullOrWhiteSpace((Get-Item -Path "env:$var" -ErrorAction SilentlyContinue).Value)) {
            $missingOptionalVars += $var
        } else {
            $availableVars += $var
        }
    }
    
    # Report validation results
    if ($availableVars.Count -gt 0) {
        Write-Output "✓ Available environment variables: $($availableVars -join ', ')"
    }
    
    if ($missingOptionalVars.Count -gt 0) {
        Write-Warning "⚠️  Optional environment variables not set: $($missingOptionalVars -join ', ')"
        Write-Output "Some cleanup operations may be skipped due to missing configuration."
    }
    
    if ($missingVars.Count -gt 0) {
        throw "❌ Required environment variables are missing: $($missingVars -join ', '). Please check your environment file."
    }
    
    Write-Output "✓ Environment variable validation completed successfully."
}

# Displays a confirmation prompt for destructive operations
# Provides safety check to prevent accidental resource deletion
function Confirm-CleanupOperation {
    param(
        [string]$OperationName,
        [string]$Description,
        [string[]]$ResourcesAffected
    )
    
    if ($Force) {
        Write-Output "🚀 Force mode enabled - proceeding with $OperationName without confirmation."
        return $true
    }
    
    Write-Host ""
    Write-Host "⚠️  CONFIRMATION REQUIRED ⚠️" -ForegroundColor Yellow
    Write-Host "Operation: $OperationName" -ForegroundColor White
    Write-Host "Description: $Description" -ForegroundColor White
    
    if ($ResourcesAffected.Count -gt 0) {
        Write-Host "Resources that will be affected:" -ForegroundColor White
        foreach ($resource in $ResourcesAffected) {
            Write-Host "  • $resource" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    Write-Host "⚠️  WARNING: This operation cannot be undone!" -ForegroundColor Red
    Write-Host ""
    
    do {
        $response = Read-Host "Do you want to proceed? (yes/no/y/n)"
        $response = $response.Trim().ToLower()
    } while ($response -notin @('yes', 'y', 'no', 'n'))
    
    $proceed = $response -in @('yes', 'y')
    
    if ($proceed) {
        Write-Output "✓ User confirmed - proceeding with $OperationName."
    } else {
        Write-Output "❌ User cancelled - skipping $OperationName."
    }
    
    return $proceed
}

# Safely removes Azure resources using azd or direct Azure CLI commands
# Handles resource dependencies and provides detailed feedback
function Remove-AzureInfrastructure {
    Write-Output ""
    Write-Output "🗑️  Starting Azure infrastructure cleanup..."
    
    # Check if azd environment exists
    $azdEnvName = $env:POWER_PLATFORM_ENVIRONMENT_NAME
    if (-not $azdEnvName) {
        Write-Warning "POWER_PLATFORM_ENVIRONMENT_NAME not set - cannot use azd for cleanup."
        Write-Output "Will attempt direct resource group cleanup instead."
        return Remove-ResourceGroupDirectly
    }
    
    # Attempt azd cleanup first (preferred method)
    try {
        Write-Output "Checking azd environment: $azdEnvName"
        $azdList = azd env list --output json 2>$null
        
        if ($azdList) {
            $environments = $azdList | ConvertFrom-Json
            $targetEnv = $environments | Where-Object { $_.Name -eq $azdEnvName }
            
            if ($targetEnv) {
                Write-Output "✓ Found azd environment: $azdEnvName"
                
                # Confirm azd cleanup
                $resourcesAffected = @(
                    "azd environment: $azdEnvName",
                    "All resources deployed by azd for this environment",
                    "Resource group: $env:RESOURCE_GROUP (if specified)"
                )
                
                if (Confirm-CleanupOperation -OperationName "Azure Infrastructure Cleanup (azd)" -Description "Remove all Azure resources deployed by azd" -ResourcesAffected $resourcesAffected) {
                    Write-Output "Executing azd down to remove infrastructure..."
                    
                    # Use azd down to remove all resources
                    azd down --environment $azdEnvName --force --purge
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Output "✓ Azure infrastructure removed successfully using azd."
                        $script:CleanupSuccess += "Azure infrastructure (azd)"
                        return $true
                    } else {
                        Write-Warning "azd down failed. Attempting manual resource group cleanup..."
                        $script:CleanupErrors += "azd down operation failed"
                    }
                } else {
                    Write-Output "Skipping Azure infrastructure cleanup."
                    return $false
                }
            } else {
                Write-Output "azd environment '$azdEnvName' not found. Attempting direct resource group cleanup..."
            }
        } else {
            Write-Output "No azd environments found. Attempting direct resource group cleanup..."
        }
    }
    catch {
        Write-Warning "Error during azd cleanup: $($_.Exception.Message)"
        Write-Output "Falling back to direct resource group cleanup..."
        $script:CleanupErrors += "azd cleanup error: $($_.Exception.Message)"
    }
    
    # Fallback to direct resource group cleanup
    return Remove-ResourceGroupDirectly
}

# Removes the resource group and all contained resources directly
# Used as fallback when azd cleanup is not available
function Remove-ResourceGroupDirectly {
    if (-not $env:RESOURCE_GROUP) {
        Write-Warning "RESOURCE_GROUP environment variable not set - cannot perform direct cleanup."
        Write-Output "Please specify the resource group name in your environment file or use manual cleanup."
        return $false
    }
    
    $resourceGroupName = $env:RESOURCE_GROUP
    
    # Check if resource group exists
    try {
        Write-Output "Checking if resource group exists: $resourceGroupName"
        $rgExists = az group exists --name $resourceGroupName --subscription $env:SUBSCRIPTION_ID
        
        if ($rgExists -eq "false") {
            Write-Output "✓ Resource group '$resourceGroupName' does not exist or has already been removed."
            return $true
        }
        
        # List resources in the group for confirmation
        Write-Output "Retrieving resources in resource group: $resourceGroupName"
        $resources = az resource list --resource-group $resourceGroupName --query "[].{Name:name, Type:type}" --output json | ConvertFrom-Json
        
        $resourcesAffected = @("Resource group: $resourceGroupName")
        if ($resources.Count -gt 0) {
            $resourcesAffected += "Resources to be deleted:"
            foreach ($resource in $resources) {
                $resourcesAffected += "  • $($resource.Name) ($($resource.Type))"
            }
        } else {
            $resourcesAffected += "  (Resource group appears to be empty)"
        }
        
        # Confirm resource group deletion
        $operationName = if ($KeepResourceGroup) { "Resource Cleanup (keep group)" } else { "Resource Group Deletion" }
        $description = if ($KeepResourceGroup) { "Remove all resources but keep the resource group" } else { "Delete the entire resource group and all contained resources" }
        
        if (Confirm-CleanupOperation -OperationName $operationName -Description $description -ResourcesAffected $resourcesAffected) {
            
            if ($KeepResourceGroup) {
                # Delete individual resources but keep the group
                Write-Output "Removing individual resources from resource group..."
                
                if ($resources.Count -gt 0) {
                    foreach ($resource in $resources) {
                        try {
                            Write-Output "Deleting resource: $($resource.Name)"
                            az resource delete --resource-group $resourceGroupName --name $resource.Name --resource-type $resource.Type --subscription $env:SUBSCRIPTION_ID
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Output "✓ Deleted: $($resource.Name)"
                            } else {
                                Write-Warning "Failed to delete: $($resource.Name)"
                                $script:CleanupErrors += "Failed to delete resource: $($resource.Name)"
                            }
                        }
                        catch {
                            Write-Warning "Error deleting resource $($resource.Name): $($_.Exception.Message)"
                            $script:CleanupErrors += "Error deleting $($resource.Name): $($_.Exception.Message)"
                        }
                    }
                    
                    Write-Output "✓ Individual resource cleanup completed. Resource group '$resourceGroupName' has been preserved."
                } else {
                    Write-Output "✓ No resources found to delete. Resource group '$resourceGroupName' is already empty."
                }
                
                $script:CleanupSuccess += "Individual resources (resource group preserved)"
            } else {
                # Delete the entire resource group
                Write-Output "Deleting resource group: $resourceGroupName"
                Write-Output "This operation may take several minutes depending on the resources..."
                
                az group delete --name $resourceGroupName --subscription $env:SUBSCRIPTION_ID --yes --no-wait
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Output "✓ Resource group deletion initiated successfully."
                    Write-Output "Note: Deletion is running in the background and may take 10-20 minutes to complete."
                    $script:CleanupSuccess += "Resource group deletion initiated"
                } else {
                    Write-Warning "Failed to initiate resource group deletion."
                    $script:CleanupErrors += "Resource group deletion failed"
                    return $false
                }
            }
            
            return $true
        } else {
            Write-Output "Skipping resource group cleanup."
            return $false
        }
    }
    catch {
        Write-Warning "Error during resource group cleanup: $($_.Exception.Message)"
        $script:CleanupErrors += "Resource group cleanup error: $($_.Exception.Message)"
        return $false
    }
}

# Unlinks enterprise policy from Power Platform environment
# Removes the VNet integration configuration from Power Platform
function Remove-PowerPlatformConfiguration {
    if ($SkipPowerPlatform) {
        Write-Output "⏭️  Skipping Power Platform configuration cleanup as requested."
        return $true
    }
    
    Write-Output ""
    Write-Output "🔗 Starting Power Platform enterprise policy cleanup..."
    
    if (-not $env:POWER_PLATFORM_ENVIRONMENT_NAME) {
        Write-Warning "POWER_PLATFORM_ENVIRONMENT_NAME not set - skipping Power Platform cleanup."
        return $true
    }
    
    try {
        # Install and connect to PowerApps PowerShell module
        $moduleInstalled = Install-PowerAppsModule
        if (-not $moduleInstalled) {
            Write-Warning "Failed to install PowerApps PowerShell module. Skipping Power Platform cleanup."
            $script:CleanupErrors += "PowerApps module installation failed"
            return $false
        }
        
        $connected = Connect-PowerPlatform
        if (-not $connected) {
            Write-Warning "Failed to connect to Power Platform. Skipping Power Platform cleanup."
            $script:CleanupErrors += "Power Platform connection failed"
            return $false
        }
        
        # Get environment by display name
        Write-Output "Resolving Power Platform environment..."
        $environment = Get-PowerPlatformEnvironmentByName -DisplayName $env:POWER_PLATFORM_ENVIRONMENT_NAME
        
        if (-not $environment) {
            Write-Output "✓ Power Platform environment not found or already cleaned up."
            return $true
        }
        
        # Confirm enterprise policy unlinking
        $resourcesAffected = @(
            "Power Platform environment: $env:POWER_PLATFORM_ENVIRONMENT_NAME",
            "Enterprise policy: VNet/NetworkInjection",
            "VNet integration configuration will be removed"
        )
        
        if (Confirm-CleanupOperation -OperationName "Power Platform VNet Policy Removal" -Description "Remove VNet integration from Power Platform environment" -ResourcesAffected $resourcesAffected) {
            
            Write-Output "Removing VNet enterprise policy from Power Platform environment..."
            $success = Remove-PowerPlatformVNetPolicy -EnvironmentId $environment.EnvironmentName -PolicyArmId $env:ENTERPRISE_POLICY_NAME
            
            if ($success) {
                Write-Output "✓ VNet enterprise policy removed successfully from Power Platform environment."
                $script:CleanupSuccess += "Power Platform VNet policy removal"
            } else {
                Write-Warning "VNet enterprise policy removal did not complete successfully."
                $script:CleanupErrors += "Power Platform VNet policy removal failed"
                return $false
            }
        } else {
            Write-Output "Skipping Power Platform VNet policy cleanup."
            return $false
        }
        
        return $true
    }
    catch {
        Write-Warning "Error during Power Platform cleanup: $($_.Exception.Message)"
        $script:CleanupErrors += "Power Platform cleanup error: $($_.Exception.Message)"
        return $false
    }
}

# Cleans up the environment configuration file
# Removes or resets the .env file to prevent confusion
function Remove-EnvironmentFile {
    if (-not (Test-Path $EnvFile)) {
        Write-Output "✓ Environment file '$EnvFile' does not exist or has already been removed."
        return $true
    }
    
    # Confirm environment file cleanup
    $resourcesAffected = @(
        "Environment file: $EnvFile",
        "All deployment configuration will be removed"
    )
    
    if (Confirm-CleanupOperation -OperationName "Environment File Cleanup" -Description "Remove the deployment configuration file" -ResourcesAffected $resourcesAffected) {
        
        try {
            Remove-Item $EnvFile -Force
            Write-Output "✓ Environment file '$EnvFile' removed successfully."
            $script:CleanupSuccess += "Environment file cleanup"
            return $true
        }
        catch {
            Write-Warning "Failed to remove environment file '$EnvFile': $($_.Exception.Message)"
            $script:CleanupErrors += "Environment file cleanup error: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-Output "Skipping environment file cleanup."
        return $false
    }
}

# Displays a comprehensive summary of cleanup operations
# Provides detailed feedback on what was accomplished and any issues encountered
function Show-CleanupSummary {
    Write-Output ""
    Write-Output "📋 CLEANUP SUMMARY"
    Write-Output "===================="
    
    if ($script:CleanupSuccess.Count -gt 0) {
        Write-Output ""
        Write-Host "✅ SUCCESSFUL OPERATIONS:" -ForegroundColor Green
        foreach ($success in $script:CleanupSuccess) {
            Write-Host "  ✓ $success" -ForegroundColor Green
        }
    }
    
    if ($script:CleanupErrors.Count -gt 0) {
        Write-Output ""
        Write-Host "❌ ISSUES ENCOUNTERED:" -ForegroundColor Red
        foreach ($error in $script:CleanupErrors) {
            Write-Host "  ✗ $error" -ForegroundColor Red
        }
        
        Write-Output ""
        Write-Host "⚠️  Some cleanup operations encountered issues. Please review the errors above." -ForegroundColor Yellow
        Write-Host "You may need to manually clean up remaining resources through the Azure Portal." -ForegroundColor Yellow
    }
    
    if ($script:CleanupSuccess.Count -gt 0 -and $script:CleanupErrors.Count -eq 0) {
        Write-Output ""
        Write-Host "🎉 All cleanup operations completed successfully!" -ForegroundColor Green
        Write-Host "The Power Platform VNet integration has been fully removed." -ForegroundColor Green
    }
    
    Write-Output ""
    Write-Output "Cleanup operation completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

# --- Main Script Execution ---

Write-Output "🧹 Power Platform VNet Integration Cleanup Script"
Write-Output "================================================="
Write-Output "Starting cleanup process at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output ""

try {
    # Step 1: Handle cross-platform execution policy settings
    # Set-ExecutionPolicy is only available on Windows PowerShell
    if ($IsLinux -or $IsMacOS) {
        Write-Output "Running on non-Windows platform. Skipping Set-ExecutionPolicy."
    } else {
        # Set the execution policy to allow script execution (Windows only)
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    }

    # Step 2: Import and validate environment configuration
    Import-EnvFile -Path $EnvFile
    Test-EnvironmentVariables

    # Step 3: Ensure Azure CLI authentication and subscription context
    Ensure-AzLogin

    # Step 4: Display cleanup plan
    Write-Output ""
    Write-Output "🎯 CLEANUP PLAN"
    Write-Output "==============="
    Write-Output "Environment File: $EnvFile"
    Write-Output "Force Mode: $Force"
    Write-Output "Skip Power Platform: $SkipPowerPlatform"
    Write-Output "Keep Resource Group: $KeepResourceGroup"
    Write-Output ""
    
    if ($env:SUBSCRIPTION_ID) { Write-Output "Target Subscription: $env:SUBSCRIPTION_ID" }
    if ($env:RESOURCE_GROUP) { Write-Output "Target Resource Group: $env:RESOURCE_GROUP" }
    if ($env:POWER_PLATFORM_ENVIRONMENT_NAME -and -not $SkipPowerPlatform) { 
        Write-Output "Target PP Environment: $env:POWER_PLATFORM_ENVIRONMENT_NAME" 
    }
    
    Write-Output ""
    
    # Final confirmation for the entire cleanup process
    if (-not $Force) {
        Write-Host "⚠️  This will permanently remove Azure resources and Power Platform configurations!" -ForegroundColor Red
        Write-Host "⚠️  Make sure you have proper backups if needed." -ForegroundColor Red
        Write-Output ""
        
        do {
            $response = Read-Host "Are you sure you want to proceed with the complete cleanup? (yes/no)"
            $response = $response.Trim().ToLower()
        } while ($response -notin @('yes', 'y', 'no', 'n'))
        
        if ($response -in @('no', 'n')) {
            Write-Output "❌ Cleanup cancelled by user."
            exit 0
        }
        
        Write-Output "✓ User confirmed complete cleanup - proceeding..."
    }

    # Step 5: Execute cleanup operations in reverse order of deployment
    
    # 5a. Remove Power Platform configuration first (dependencies)
    Remove-PowerPlatformConfiguration
    
    # 5b. Remove Azure infrastructure
    Remove-AzureInfrastructure
    
    # 5c. Clean up environment file (optional)
    if (Confirm-CleanupOperation -OperationName "Environment File Cleanup" -Description "Remove the deployment configuration file" -ResourcesAffected @($EnvFile)) {
        Remove-EnvironmentFile
    }

    # Step 6: Display comprehensive summary
    Show-CleanupSummary

}
catch {
    Write-Error "❌ Fatal error during cleanup: $($_.Exception.Message)"
    Write-Output "Cleanup process terminated due to critical error."
    
    # Add the fatal error to our tracking
    $script:CleanupErrors += "Fatal error: $($_.Exception.Message)"
    Show-CleanupSummary
    
    exit 1
}

Write-Output ""
Write-Output "🏁 Cleanup script execution completed."
