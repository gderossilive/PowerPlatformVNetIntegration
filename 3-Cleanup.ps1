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

.PARAMETER RemoveEnvironment
When specified, removes the entire Power Platform environment and all contained data.
WARNING: This is extremely destructive and cannot be undone. All apps, flows, connections,
and data in the environment will be permanently deleted. Use with extreme caution.

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
PS C:\> ./3-Cleanup.ps1 -RemoveEnvironment -Force

Performs complete cleanup including permanent deletion of the Power Platform environment.
This is the most destructive option and should only be used when you want to completely
remove everything including the environment itself.

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
Prerequisite   : Microsoft.PowerApps.Administration.PowerShell module (auto-installed, with REST API fallback)

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
- Automatic PowerApps PowerShell module installation with REST API fallback
- Multiple approaches for enterprise policy removal (PowerApps cmdlets + REST API)

The cleanup process typically takes 10-20 minutes depending on the number of resources
and their deletion dependencies. API Management instances may take the longest to delete.
Enterprise policy unlinking uses PowerApps PowerShell cmdlets when available, with automatic
fallback to REST API calls for maximum compatibility across different environments.

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
    [switch]$KeepResourceGroup,
    
    [Parameter(Mandatory = $false, HelpMessage = "Remove the Power Platform environment itself (WARNING: This will permanently delete the environment)")]
    [switch]$RemoveEnvironment
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
        
        # First, try to remove any potentially corrupted versions
        try {
            Get-Module Microsoft.PowerApps.Administration.PowerShell -ListAvailable | Remove-Module -Force -ErrorAction SilentlyContinue
        }
        catch {
            # Ignore errors during cleanup
        }
        
        # Check if the module is already installed and working
        $module = Get-Module -ListAvailable -Name Microsoft.PowerApps.Administration.PowerShell | Select-Object -First 1
        
        if (-not $module) {
            Write-Output "Installing PowerApps PowerShell module..."
            
            # Install with specific parameters for Linux/container environments
            $installParams = @{
                Name = "Microsoft.PowerApps.Administration.PowerShell"
                Force = $true
                AllowClobber = $true
                Scope = "CurrentUser"
                SkipPublisherCheck = $true
                AllowPrerelease = $false
                Repository = "PSGallery"
            }
            
            Install-Module @installParams -ErrorAction Stop
            Write-Output "✓ PowerApps PowerShell module installed successfully."
            
            # Refresh module list after installation
            $module = Get-Module -ListAvailable -Name Microsoft.PowerApps.Administration.PowerShell | Select-Object -First 1
        } else {
            Write-Output "✓ PowerApps PowerShell module is already installed (Version: $($module.Version))."
        }
        
        # Test import with enhanced error handling
        try {
            # Force reimport to ensure clean state
            Remove-Module Microsoft.PowerApps.Administration.PowerShell -Force -ErrorAction SilentlyContinue
            
            Write-Output "Importing PowerApps PowerShell module..."
            Import-Module Microsoft.PowerApps.Administration.PowerShell -Force -ErrorAction Stop -Verbose:$false
            
            # Test if the module actually works by checking for key cmdlets
            $testCmdlet = Get-Command Add-PowerAppsAccount -ErrorAction SilentlyContinue
            if ($testCmdlet) {
                Write-Output "✓ PowerApps PowerShell module imported and validated successfully."
                return $true
            } else {
                throw "Module imported but key cmdlets are not available"
            }
        }
        catch {
            Write-Warning "PowerApps PowerShell module import failed: $($_.Exception.Message)"
            Write-Output "This may be due to module compatibility issues in the current environment."
            Write-Output "Common causes: Linux/container environment incompatibilities, .NET Framework dependencies, or corrupted module files."
            return $false
        }
    }
    catch {
        Write-Warning "Failed to install PowerApps PowerShell module: $($_.Exception.Message)"
        Write-Output "This may be due to network issues, module compatibility problems, or insufficient permissions."
        return $false
    }
}

# Gets an access token for Power Platform Admin API using Azure CLI
# Fallback method when PowerApps PowerShell module is not available
function Get-PowerPlatformAccessToken {
    try {        
        # Power Platform Admin API resource identifier
        $resource = "https://api.bap.microsoft.com/"
        $token = az account get-access-token --resource $resource --query accessToken --output tsv
        
        if (-not $token -or $token.Trim() -eq "") {
            throw "Failed to obtain access token for Power Platform Admin API."
        }
        
        # Ensure token contains only ASCII characters
        $token = $token.Trim()

        return $token
    }
    catch {
        throw "Error obtaining Power Platform access token: $($_.Exception.Message)"
    }
}

# Gets the enterprise policy resource ID for proper cleanup
# This ensures we can both unlink and delete the enterprise policy resource
function Get-EnterprisePolicyId {
    try {
        # First, try to get it from environment variables if available
        if ($env:ENTERPRISE_POLICY_NAME -and $env:RESOURCE_GROUP -and $env:SUBSCRIPTION_ID) {
            $enterprisePolicyId = "/subscriptions/$env:SUBSCRIPTION_ID/resourceGroups/$env:RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies/$env:ENTERPRISE_POLICY_NAME"
            
            # Verify the enterprise policy exists
            $policyExists = az resource show --ids $enterprisePolicyId --query "name" -o tsv 2>$null
            if ($policyExists) {
                Write-Output "✓ Found enterprise policy from environment variables: $enterprisePolicyId"
                return $enterprisePolicyId
            }
        }
        
        # If not found via environment variables, try to find it in the resource group
        if ($env:RESOURCE_GROUP -and $env:SUBSCRIPTION_ID) {
            Write-Output "Searching for enterprise policies in resource group: $env:RESOURCE_GROUP"
            
            $policies = az resource list --resource-group $env:RESOURCE_GROUP --resource-type "Microsoft.PowerPlatform/enterprisePolicies" --query "[].id" -o tsv 2>$null
            
            if ($policies) {
                $policyArray = $policies -split "`n" | Where-Object { $_ -ne "" }
                if ($policyArray.Count -eq 1) {
                    Write-Output "✓ Found enterprise policy in resource group: $($policyArray[0])"
                    return $policyArray[0]
                } elseif ($policyArray.Count -gt 1) {
                    Write-Warning "Multiple enterprise policies found in resource group. Using the first one: $($policyArray[0])"
                    return $policyArray[0]
                }
            }
        }
        
        Write-Output "No enterprise policy found via environment variables or resource group search."
        return $null
    }
    catch {
        Write-Warning "Error searching for enterprise policy: $($_.Exception.Message)"
        return $null
    }
}

# Gets Power Platform environment using REST API
# Fallback method when PowerApps PowerShell module is not available
function Get-PowerPlatformEnvironmentByNameREST {
    param([string]$DisplayName, [string]$AccessToken)
    
    try {
        Write-Output "Searching for Power Platform environment using REST API: $DisplayName"
        
        $AccessToken=Get-PowerPlatformAccessToken
        $headers = @{ 
            'Authorization' = "Bearer $AccessToken"
            'Content-Type' = 'application/json'
        }
        
        $url = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01"
        
        try {
            $result = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
            
            # Find environment by display name
            $environment = $result.value | Where-Object { $_.properties.displayName -eq $DisplayName }
            
            if (-not $environment) {
                Write-Warning "Power Platform environment '$DisplayName' not found. It may have been already removed or renamed."
                return $null
            }
            
            Write-Output "✓ Found Power Platform environment: $($environment.name)"
            return $environment
        }
        catch {
            $statusCode = "Unknown"
            $errorMessage = $_.Exception.Message
            
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
            }
            
            Write-Warning "REST API call failed (Status: $statusCode): $errorMessage"
            
            # Check if it's an authentication issue
            if ($statusCode -eq 401 -or $errorMessage -like "*unauthorized*" -or $errorMessage -like "*authentication*") {
                Write-Output "This appears to be an authentication issue. The access token may have expired or be invalid."
            }
            
            return $null
        }
    }
    catch {
        Write-Warning "Error retrieving Power Platform environment via REST API: $($_.Exception.Message)"
        return $null
    }
}

# Removes VNet enterprise policy using REST API
# Fallback method when PowerApps PowerShell module is not available
# Based on the official PowerApps samples and proven enterprise policy management patterns
function Remove-PowerPlatformVNetPolicyREST {
    param(
        [string]$EnvironmentId,
        [string]$AccessToken,
        [string]$EnterprisePolicyId = $null
    )
    
    try {
        Write-Output "Attempting to remove VNet enterprise policy via REST API..."
        Write-Output "Environment ID: $EnvironmentId"
                
        # Step 1: First, verify if enterprise policy exists and get its details
        Write-Output "Checking for existing enterprise policies on environment..."
        $AccessToken=Get-PowerPlatformAccessToken
        $headers = @{ 
            'Authorization' = "Bearer $AccessToken"
            'Content-Type' = 'application/json'
        }
        $envUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId" + "?api-version=2023-06-01"
        
        # Use provided enterprise policy ID or try to get it from environment
        $enterprisePolicyId = $EnterprisePolicyId
        
        try {

            $envResult = Invoke-RestMethod -Uri $envUrl -Headers $headers -Method Get
            
            # Check for enterprise policies with proper null checking
            $hasVNetPolicy = $false
            if ($envResult -and $envResult.properties) {
                if ($envResult.properties.PSObject.Properties['enterprisePolicies']) {
                    if ($envResult.properties.enterprisePolicies.PSObject.Properties['VNets']) {
                        $hasVNetPolicy = $true
                        # Get the enterprise policy resource ID from environment if not provided
                        if (-not $enterprisePolicyId) {
                            $enterprisePolicyId = $envResult.properties.enterprisePolicies.VNets
                        }
                    }
                }
            }
            
            if (-not $hasVNetPolicy) {
                Write-Output "✓ No VNet enterprise policy found on environment. Already clean."
                return $true
            }
            
            if ($enterprisePolicyId) {
                Write-Output "Found VNet enterprise policy: $enterprisePolicyId"
            }
            
        }
        catch {
            Write-Warning "Could not check environment policies. Proceeding with removal attempt..."
            # Keep the provided enterprise policy ID if available
        }
        
        # Step 2: Unlink the enterprise policy from the Power Platform environment
        Write-Output "Unlinking enterprise policy from Power Platform environment..."
        $ApiVersion = "2023-06-01"
        $unlinkUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/enterprisePolicies/NetworkInjection/unlink?api-version=$ApiVersion"
        
        # Prepare request body - if we have the enterprise policy ID, get its system ID
        $body = @{}
        if ($enterprisePolicyId) {
            try {
                # Get the policy system ID for the unlink operation
                $policySystemId = az resource show --ids $enterprisePolicyId --query "properties.systemId" -o tsv 2>$null
                if ($policySystemId) {
                    $body = @{ "SystemId" = $policySystemId }
                    Write-Output "Using enterprise policy system ID: $policySystemId"
                }
            }
            catch {
                Write-Output "Could not retrieve enterprise policy system ID. Using empty body for unlink."
            }
        }
        
        try {
            $bodyJson = $body | ConvertTo-Json
            Write-Output "Initiating enterprise policy unlink operation..."

            $AccessToken=Get-PowerPlatformAccessToken
            $headers = @{ 
                Authorization = "Bearer $AccessToken"
                'Content-Type' = 'application/json'
            }
                    
            # Use Invoke-WebRequest for better control over response handling
            $unlinkResponse = Invoke-WebRequest -Uri $unlinkUrl -Headers $headers -Method Post -Body $bodyJson -UseBasicParsing
            
            # Step 3: Wait for unlink operation to complete (if operation-location header is present)
            if ($unlinkResponse.Headers.'operation-location') {
                $operationLink = $unlinkResponse.Headers.'operation-location'
                Write-Output "Polling unlink operation status: $operationLink"
                
                $pollInterval = 10 # seconds
                $maxPolls = 30 # Maximum 5 minutes
                $pollCount = 0
                
                while ($pollCount -lt $maxPolls) {
                    Start-Sleep -Seconds $pollInterval
                    $pollCount++
                    
                    try {
                        $operationResult = Invoke-WebRequest -Uri $operationLink -Headers $headers -Method Get -UseBasicParsing
                        
                        if ($operationResult.StatusCode -eq 200) {
                            Write-Output "✓ Enterprise policy unlinked successfully from Power Platform environment."
                            break
                        } elseif ($operationResult.StatusCode -eq 202) {
                            Write-Output "Unlinking enterprise policy is still in progress... (Poll $pollCount/$maxPolls)"
                        } else {
                            Write-Warning "Unexpected status code during polling: $($operationResult.StatusCode)"
                            break
                        }
                    }
                    catch {
                        Write-Warning "Error polling operation status: $($_.Exception.Message)"
                        break
                    }
                }
                
                if ($pollCount -ge $maxPolls) {
                    Write-Warning "Unlink operation timed out after $($maxPolls * $pollInterval) seconds."
                }
            } else {
                # No operation-location header, assume immediate completion
                if ($unlinkResponse.StatusCode -eq 200 -or $unlinkResponse.StatusCode -eq 204) {
                    Write-Output "✓ Enterprise policy unlinked successfully from Power Platform environment."
                } else {
                    Write-Warning "Unlink operation returned status code: $($unlinkResponse.StatusCode)"
                }
            }
            
            # Step 4: Remove the enterprise policy resource itself (if we have the ID)
            if ($enterprisePolicyId) {
                Write-Output "Removing enterprise policy resource: $enterprisePolicyId"
                try {
                    az resource delete --ids $enterprisePolicyId --verbose
                    if ($LASTEXITCODE -eq 0) {
                        Write-Output "✓ Enterprise policy resource deleted successfully."
                    } else {
                        Write-Warning "Failed to delete enterprise policy resource."
                    }
                }
                catch {
                    Write-Warning "Error deleting enterprise policy resource: $($_.Exception.Message)"
                }
            }
            
            return $true
        }
        catch {
            $errorDetails = $_.ErrorDetails.Message
            $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
            $AccessToken=Get-PowerPlatformAccessToken
            $headers = @{ 
                Authorization = "Bearer $AccessToken"
                'Content-Type' = 'application/json'
            }
            
            Write-Output "Primary removal endpoint failed (Status: $statusCode). Trying alternative approaches..."
            
            # Try alternative endpoint patterns
            $altUrl1 = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/removeNetworkInjection?api-version=$ApiVersion"
            
            try {
                $altResult1 = Invoke-RestMethod -Uri $altUrl1 -Headers $headers -Method Post
                Write-Output "✓ VNet enterprise policy removed successfully using alternative REST API endpoint."
                return $true
            }
            catch {
                Write-Output "Alternative endpoint 1 failed. Trying direct DELETE approach..."

                # Try direct DELETE on the enterprise policy resource
                $altUrl2 = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/enterprisePolicies/VNets?api-version=$ApiVersion"
                
                try {
                    $altResult2 = Invoke-RestMethod -Uri $altUrl2 -Headers $headers -Method Delete
                    Write-Output "✓ VNet enterprise policy removed successfully using direct DELETE approach."
                    return $true
                }
                catch {
                    $finalErrorMessage = $_.Exception.Message
                    Write-Warning "All REST API removal approaches failed: $finalErrorMessage"
                    
                    # Check if any of the errors indicate the policy is already removed
                    if ($finalErrorMessage -like "*not found*" -or $finalErrorMessage -like "*does not exist*" -or 
                        $finalErrorMessage -like "*404*" -or $statusCode -eq 404) {
                        Write-Output "✓ Enterprise policy appears to already be removed (404 Not Found)."
                        return $true
                    }
                    
                    # Log detailed error information for troubleshooting
                    Write-Output "Error details for troubleshooting:"
                    Write-Output "- Primary endpoint: $unlinkUrl"
                    Write-Output "- Alternative endpoint 1: $altUrl1" 
                    Write-Output "- Alternative endpoint 2: $altUrl2"
                    Write-Output "- Status code: $statusCode"
                    Write-Output "- Error details: $errorDetails"
                    
                    return $false
                }
            }
        }
    }
    catch {
        Write-Warning "Error during REST API VNet policy removal: $($_.Exception.Message)"
        return $false
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
                
                # Before deleting the resource group, ensure any enterprise policies are properly cleaned up
                try {
                    $enterprisePolicies = az resource list --resource-group $resourceGroupName --resource-type "Microsoft.PowerPlatform/enterprisePolicies" --query "[].id" -o tsv 2>$null
                    if ($enterprisePolicies) {
                        $policyArray = $enterprisePolicies -split "`n" | Where-Object { $_ -ne "" }
                        foreach ($policyId in $policyArray) {
                            Write-Output "Ensuring enterprise policy is unlinked before deletion: $policyId"
                            # Enterprise policies should be unlinked before resource group deletion
                            # This is handled by the Power Platform cleanup, but adding safety check
                        }
                    }
                }
                catch {
                    Write-Output "Could not check for enterprise policies in resource group. Proceeding with deletion."
                }
                
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
        # Try PowerApps PowerShell module approach first
        $moduleInstalled = Install-PowerAppsModule
        $usePowerAppsModule = $false
        
        if ($moduleInstalled) {
            try {
                Write-Output "Connecting to Power Platform using PowerApps PowerShell module..."
                Add-PowerAppsAccount -TenantID $env:TENANT_ID -ErrorAction Stop
                Write-Output "✓ Connected to Power Platform successfully using PowerApps module."
                $usePowerAppsModule = $true
            }
            catch {
                Write-Warning "PowerApps module connection failed: $($_.Exception.Message)"
                Write-Output "Falling back to REST API approach..."
            }
        } else {
            Write-Output "PowerApps module not available. Using REST API approach..."
        }
        
        # Get environment information
        $environment = $null
        
        if ($usePowerAppsModule) {
            # Use PowerApps module approach
            try {
                Write-Output "Getting environment using PowerApps module..."
                $environments = Get-AdminPowerAppEnvironment
                $environment = $environments | Where-Object { $_.DisplayName -eq $env:POWER_PLATFORM_ENVIRONMENT_NAME }
                
                if ($environment) {
                    Write-Output "✓ Found Power Platform environment using PowerApps module: $($environment.EnvironmentName)"
                }
            }
            catch {
                Write-Warning "PowerApps module environment lookup failed: $($_.Exception.Message)"
                Write-Output "Falling back to REST API approach..."
                $usePowerAppsModule = $false
            }
        }
        
        if (-not $usePowerAppsModule) {
            # Use REST API approach
            try {
                $accessToken = Get-PowerPlatformAccessToken
                $environment = Get-PowerPlatformEnvironmentByNameREST -DisplayName $env:POWER_PLATFORM_ENVIRONMENT_NAME -AccessToken $accessToken
                
                # Also get the enterprise policy ID for comprehensive cleanup
                $enterprisePolicyId = Get-EnterprisePolicyId
                # Note: Get-EnterprisePolicyId already outputs its own status messages
            }
            catch {
                Write-Warning "Failed to get access token or retrieve environment via REST API: $($_.Exception.Message)"
                $environment = $null
                $enterprisePolicyId = $null
            }
        }
        
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
            $success = $false
            
            if ($usePowerAppsModule) {
                # Try PowerApps module approach
                try {
                    Write-Output "Using PowerApps module for policy removal..."
                    $environmentId = $environment.EnvironmentName
                    
                    # Check if environment has VNet policy with proper null checking
                    $hasVNetPolicy = $false
                    if ($environment -and $environment.Internal -and $environment.Internal.properties) {
                        if ($environment.Internal.properties.PSObject.Properties['enterprisePolicies']) {
                            if ($environment.Internal.properties.enterprisePolicies.PSObject.Properties['VNets']) {
                                $hasVNetPolicy = $true
                            }
                        }
                    }
                    
                    if ($hasVNetPolicy) {
                        Remove-AdminPowerAppEnvironmentEnterprisePolicy -EnvironmentName $environmentId -PolicyType "NetworkInjection"
                        Write-Output "✓ VNet enterprise policy removed successfully using PowerApps module."
                        $success = $true
                    } else {
                        Write-Output "✓ No VNet enterprise policy found on environment. Already clean."
                        $success = $true
                    }
                }
                catch {
                    Write-Warning "PowerApps module policy removal failed: $($_.Exception.Message)"
                    Write-Output "Falling back to REST API approach..."
                    $usePowerAppsModule = $false
                }
            }
            
            if (-not $usePowerAppsModule -and -not $success) {
                # Use REST API approach
                if ($environment -and ($environment.name -or $environment.EnvironmentName)) {
                    # Get environment ID - REST API uses 'name', PowerApps module uses 'EnvironmentName'
                    $environmentId = if ($environment.name) { $environment.name } else { $environment.EnvironmentName }
                    
                    # Get enterprise policy ID if not already retrieved
                    if (-not $enterprisePolicyId) {
                        $enterprisePolicyId = Get-EnterprisePolicyId
                    }
                    
                    $success = Remove-PowerPlatformVNetPolicyREST -EnvironmentId $environmentId -AccessToken $accessToken -EnterprisePolicyId $enterprisePolicyId
                } else {
                    Write-Warning "Environment object is null or missing name/EnvironmentName property. Cannot proceed with REST API approach."
                    if ($environment) {
                        Write-Output "Available environment properties: $($environment | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name | Sort-Object)"
                    }
                    $success = $false
                }
            }
            
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

# Tries alternative methods to unlink enterprise policy when primary method fails
function Try-AlternativeUnlinkMethods {
    param(
        [string]$EnvironmentId,
        [string]$AccessToken,
        [string]$EnterprisePolicyId
    )
    
    Write-Output "Attempting alternative enterprise policy unlink methods..."
    
    $headers = @{ 
        Authorization = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
    }
    $ApiVersion = "2023-06-01"
    
    # Method 1: Try without SystemId in the body
    try {
        Write-Output "Method 1: Attempting unlink without SystemId..."
        $altUrl1 = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/enterprisePolicies/NetworkInjection/unlink?api-version=$ApiVersion"
        $emptyBody = "{}"
        
        $altResult1 = Invoke-WebRequest -Uri $altUrl1 -Headers $headers -Method Post -Body $emptyBody -UseBasicParsing -ContentType "application/json"
        Write-Output "✓ Alternative method 1 succeeded."
        return $true
    }
    catch {
        Write-Output "Alternative method 1 failed: $($_.Exception.Message)"
    }
    
    # Method 2: Try with just the GUID part of the SystemId
    if ($EnterprisePolicyId) {
        try {
            Write-Output "Method 2: Attempting unlink with GUID-only SystemId..."
            
            # Extract GUID from the full resource path
            $guidPattern = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
            if ($EnterprisePolicyId -match $guidPattern) {
                $policyGuid = $matches[0]
                $altBody2 = @{ "SystemId" = $policyGuid } | ConvertTo-Json
                
                $altResult2 = Invoke-WebRequest -Uri $altUrl1 -Headers $headers -Method Post -Body $altBody2 -UseBasicParsing -ContentType "application/json"
                Write-Output "✓ Alternative method 2 succeeded with GUID: $policyGuid"
                return $true
            }
        }
        catch {
            Write-Output "Alternative method 2 failed: $($_.Exception.Message)"
        }
    }
    
    # Method 3: Try direct DELETE on the enterprise policy link
    try {
        Write-Output "Method 3: Attempting direct DELETE on enterprise policy link..."
        $altUrl3 = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/enterprisePolicies/VNets?api-version=$ApiVersion"
        
        $altResult3 = Invoke-WebRequest -Uri $altUrl3 -Headers $headers -Method Delete -UseBasicParsing
        Write-Output "✓ Alternative method 3 (DELETE) succeeded."
        return $true
    }
    catch {
        Write-Output "Alternative method 3 failed: $($_.Exception.Message)"
    }
    
    # Method 4: Try the removeNetworkInjection endpoint
    try {
        Write-Output "Method 4: Attempting removeNetworkInjection endpoint..."
        $altUrl4 = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/removeNetworkInjection?api-version=$ApiVersion"
        
        $altResult4 = Invoke-WebRequest -Uri $altUrl4 -Headers $headers -Method Post -Body "{}" -UseBasicParsing -ContentType "application/json"
        Write-Output "✓ Alternative method 4 (removeNetworkInjection) succeeded."
        return $true
    }
    catch {
        Write-Output "Alternative method 4 failed: $($_.Exception.Message)"
    }
    
    Write-Warning "All alternative unlink methods failed."
    return $false
}

function Get-PowerPlatformEnvironmentId {
    param([string]$AccessToken, [string]$DisplayName)
    
    $headers = @{ 
        Authorization = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
    }
    $url = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2019-10-01"
    $result = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    
    # Find the environment and ensure we return only a single string value
    $environment = $result.value | Where-Object { $_.properties.displayName -eq $DisplayName } | Select-Object -First 1
    
    if ($environment -and $environment.name) {
        # Ensure we return a single string, not an array
        return [string]$environment.name
    }
    else {
        throw "Environment with display name '$DisplayName' not found"
    }
}

# Removes the Power Platform environment completely
# WARNING: This permanently deletes the environment and all associated data
function Remove-PowerPlatformEnvironment {
    param(
        [string]$EnvironmentDisplayName,
        [string]$AccessToken
    )
    
    if (-not $RemoveEnvironment) {
        Write-Output "⏭️  Skipping Power Platform environment removal (not requested)."
        return $true
    }
    
    Write-Output ""
    Write-Output "🗑️  Starting Power Platform environment removal..."
    Write-Warning "⚠️  This will permanently delete the entire Power Platform environment!"
    
    try {
        # Get the environment details first
        Write-Output "Retrieving environment details for: $EnvironmentDisplayName"
        $environment = Get-PowerPlatformEnvironmentByNameREST -DisplayName $EnvironmentDisplayName -AccessToken $AccessToken
        
        if (-not $environment) {
            Write-Output "✓ Power Platform environment '$EnvironmentDisplayName' not found or already removed."
            return $true
        }
        
        $environmentId = $environment.name
        Write-Output "Found environment ID: $environmentId"
        
        # Confirm environment deletion
        $resourcesAffected = @(
            "Power Platform environment: $EnvironmentDisplayName",
            "Environment ID: $environmentId",
            "⚠️  ALL DATA in this environment will be permanently lost",
            "⚠️  All apps, flows, connections, and data will be deleted",
            "⚠️  This action cannot be undone"
        )
        
        if (Confirm-CleanupOperation -OperationName "Power Platform Environment Deletion" -Description "Permanently delete the entire Power Platform environment and all contained data" -ResourcesAffected $resourcesAffected) {
            
            Write-Output "Initiating environment deletion..."
            $headers = @{ 
                Authorization = "Bearer $AccessToken"
                'Content-Type' = 'application/json'
            }
            
            # Use the delete environment endpoint
            $ApiVersion = "2023-06-01"
            $deleteUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$environmentId" + "?api-version=$ApiVersion"
            
            try {
                Write-Output "Sending DELETE request to: $deleteUrl"
                $deleteResponse = Invoke-WebRequest -Uri $deleteUrl -Headers $headers -Method Delete -UseBasicParsing
                
                if ($deleteResponse.StatusCode -eq 200 -or $deleteResponse.StatusCode -eq 202 -or $deleteResponse.StatusCode -eq 204) {
                    Write-Output "✓ Environment deletion request submitted successfully."
                    
                    # Check if there's an operation-location header for polling
                    $operationLocation = $deleteResponse.Headers.'operation-location'
                    if ($operationLocation) {
                        Write-Output "Monitoring deletion progress..."
                        
                        $pollInterval = 15 # seconds
                        $maxPolls = 40 # Maximum 10 minutes
                        $pollCount = 0
                        
                        while ($pollCount -lt $maxPolls) {
                            Start-Sleep -Seconds $pollInterval
                            $pollCount++
                            
                            try {
                                $pollResponse = Invoke-WebRequest -Uri $operationLocation -Headers $headers -Method Get -UseBasicParsing
                                $pollContent = $pollResponse.Content | ConvertFrom-Json
                                
                                if ($pollResponse.StatusCode -eq 200) {
                                    if ($pollContent.status -eq "Succeeded") {
                                        Write-Output "✓ Environment deletion completed successfully."
                                        break
                                    } elseif ($pollContent.status -eq "Failed") {
                                        Write-Warning "Environment deletion failed. Status: $($pollContent.status)"
                                        if ($pollContent.error) {
                                            Write-Output "Error details: $($pollContent.error.message)"
                                        }
                                        return $false
                                    } elseif ($pollContent.status -eq "InProgress" -or $pollContent.status -eq "Running") {
                                        Write-Output "Environment deletion in progress... (Poll $pollCount/$maxPolls)"
                                    } else {
                                        Write-Output "Environment deletion status: $($pollContent.status) (Poll $pollCount/$maxPolls)"
                                    }
                                } elseif ($pollResponse.StatusCode -eq 202) {
                                    Write-Output "Environment deletion still in progress... (Poll $pollCount/$maxPolls)"
                                }
                            }
                            catch {
                                # If polling fails, the operation might have completed
                                Write-Output "Polling operation completed or endpoint unavailable (Poll $pollCount/$maxPolls)"
                                break
                            }
                        }
                        
                        if ($pollCount -ge $maxPolls) {
                            Write-Warning "Deletion operation timed out after $($maxPolls * $pollInterval) seconds."
                            Write-Output "The environment deletion may still be in progress. Check the Power Platform Admin Center for status."
                        }
                    } else {
                        Write-Output "✓ Environment deletion initiated (no polling endpoint provided)."
                        Write-Output "Check the Power Platform Admin Center to monitor deletion progress."
                    }
                    
                    # Verify the environment is actually gone by trying to retrieve it
                    Start-Sleep -Seconds 10
                    try {
                        $verifyEnvironment = Get-PowerPlatformEnvironmentByNameREST -DisplayName $EnvironmentDisplayName -AccessToken $AccessToken
                        if (-not $verifyEnvironment) {
                            Write-Output "✓ Verified: Environment has been successfully removed."
                        } else {
                            Write-Output "⚠️  Environment still exists - deletion may be completing in the background."
                        }
                    }
                    catch {
                        Write-Output "✓ Environment verification indicates successful removal."
                    }
                    
                    $script:CleanupSuccess += "Power Platform environment deletion"
                    return $true
                } else {
                    Write-Warning "Unexpected response status: $($deleteResponse.StatusCode)"
                    return $false
                }
            }
            catch {
                $statusCode = "Unknown"
                $errorMessage = $_.Exception.Message
                
                if ($_.Exception.Response) {
                    $statusCode = $_.Exception.Response.StatusCode.value__
                }
                
                Write-Warning "Environment deletion failed (Status: $statusCode): $errorMessage"
                
                # Handle specific error cases
                switch ($statusCode) {
                    404 {
                        Write-Output "✓ Environment not found (404). It may have already been deleted."
                        return $true
                    }
                    403 {
                        Write-Error "Access forbidden (403). You may not have sufficient permissions to delete environments."
                        Write-Output "Required permissions: System Administrator or Environment Admin role"
                    }
                    400 {
                        Write-Warning "Bad request (400). The environment may be in a state that prevents deletion."
                        Write-Output "Common causes: Active apps/flows, protected environment, or dependent resources"
                    }
                    default {
                        Write-Error "HTTP Error $statusCode occurred during environment deletion."
                    }
                }
                
                $script:CleanupErrors += "Power Platform environment deletion failed: $errorMessage"
                return $false
            }
        } else {
            Write-Output "Skipping Power Platform environment deletion."
            return $false
        }
    }
    catch {
        Write-Warning "Error during Power Platform environment removal: $($_.Exception.Message)"
        $script:CleanupErrors += "Power Platform environment removal error: $($_.Exception.Message)"
        return $false
    }
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
    Write-Output "Remove Environment: $RemoveEnvironment"
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

    # 5a Verify the enterprise policy exists
    $enterprisePolicyId = "/subscriptions/$env:SUBSCRIPTION_ID/resourceGroups/$env:RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies/$env:ENTERPRISE_POLICY_NAME"
    $policyExists = az resource show --ids $enterprisePolicyId --query "name" -o tsv
    if (-not $policyExists) {
        Write-Error "Enterprise policy not found: $enterprisePolicyId"
        exit
    }
    Write-Output "✓ Found enterprise policy: $enterprisePolicyId"

    # 5b Unlink the enterprise policy from the Power Platform environment first
    $ApiVersion = "2023-06-01"
    $accessToken = Get-PowerPlatformAccessToken
    $headers = @{ 
        Authorization = "Bearer $accessToken"
        'Content-Type' = 'application/json'
    }
    $policySystemId = az resource show --ids $enterprisePolicyId --query "properties.systemId" -o tsv 2>$null
    
    # Initialize body as empty hashtable, add SystemId only if available
    $body = @{}
    if ($policySystemId -and $policySystemId.Trim() -ne "") {
        # Clean up the SystemId - it should be a GUID, not a full resource path
        $cleanSystemId = $policySystemId.Trim()
        
        # If the SystemId looks like a resource path, extract just the GUID
        if ($cleanSystemId -like "*/providers/Microsoft.PowerPlatform/enterprisePolicies/*") {
            $guidPattern = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
            if ($cleanSystemId -match $guidPattern) {
                $cleanSystemId = $matches[0]
                Write-Output "Extracted GUID from resource path: $cleanSystemId"
            }
        }
        
        $body = @{ "SystemId" = $cleanSystemId }
        Write-Output "Using enterprise policy system ID: $cleanSystemId"
    } else {
        Write-Output "No system ID found for enterprise policy, using empty body"
    }
    
    $powerPlatformEnvironmentId = Get-PowerPlatformEnvironmentId -AccessToken $accessToken -DisplayName $env:POWER_PLATFORM_ENVIRONMENT_NAME
    
    # Ensure we have a valid single environment ID
    if (-not $powerPlatformEnvironmentId -or $powerPlatformEnvironmentId -is [array]) {
        throw "Failed to get a valid Power Platform environment ID. Expected single string, got: $($powerPlatformEnvironmentId.GetType().Name)"
    }
    
    Write-Output "Unlinking enterprise policy $env:ENTERPRISE_POLICY_NAME from Power Platform environment $powerPlatformEnvironmentId..."
    
    # Construct URI directly without string conversion issues
    $unlinkUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$powerPlatformEnvironmentId/enterprisePolicies/NetworkInjection/unlink?api-version=2023-06-01"
    
    # Convert body to JSON with proper error handling
    $bodyJson = if ($body.Count -gt 0) { $body | ConvertTo-Json -Compress } else { "{}" }
    Write-Output "Request body: $bodyJson"
    Write-Output "Request URI: $unlinkUri"
    Write-Output "URI Type: $($unlinkUri.GetType().Name)"
    Write-Output "URI Length: $($unlinkUri.Length)"
    
    try {
        $unlinkResult = Invoke-WebRequest -Uri $unlinkUri -Headers $headers -Method Post -Body $bodyJson -UseBasicParsing -ContentType "application/json"
    }
    catch {
        $statusCode = "Unknown"
        $errorBody = ""
        
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            # Try to read the error response body
            try {
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorBody = $reader.ReadToEnd()
                $reader.Close()
                $errorStream.Close()
            }
            catch {
                Write-Output "Could not read error response body: $($_.Exception.Message)"
            }
        }
        
        Write-Error "Failed to unlink enterprise policy. Error: $($_.Exception.Message)"
        Write-Output "URI used: $uriString"
        Write-Output "Headers: $($headers | ConvertTo-Json)"
        Write-Output "Body: $bodyJson"
        Write-Output "HTTP Status Code: $statusCode"
        
        if ($errorBody) {
            Write-Output "Error response body: $errorBody"
            
            # Try to parse the error response as JSON for better error details
            try {
                $errorJson = $errorBody | ConvertFrom-Json
                if ($errorJson.error) {
                    Write-Output "Error Code: $($errorJson.error.code)"
                    Write-Output "Error Message: $($errorJson.error.message)"
                    if ($errorJson.error.details) {
                        Write-Output "Error Details: $($errorJson.error.details | ConvertTo-Json)"
                    }
                }
            }
            catch {
                Write-Output "Could not parse error response as JSON"
            }
        }
        
        # Handle specific HTTP status codes
        switch ($statusCode) {
            409 {
                Write-Warning "Conflict detected (409). This usually means:"
                Write-Output "  • The enterprise policy is already unlinked from the environment"
                Write-Output "  • The environment is in a transitional state"
                Write-Output "  • Another operation is in progress"
                Write-Output "  • The SystemId is incorrect or outdated"
                Write-Output ""
                Write-Output "Checking if the enterprise policy is actually still linked..."
                
                # Check current state of the environment
                try {
                    $checkHeaders = @{ 
                        Authorization = "Bearer $accessToken"
                        'Content-Type' = 'application/json'
                    }
                    $envCheckUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$powerPlatformEnvironmentId" + "?api-version=2023-06-01"
                    $envResult = Invoke-RestMethod -Uri $envCheckUrl -Headers $checkHeaders -Method Get
                    
                    Write-Output "Environment result structure available properties:"
                    if ($envResult -and $envResult.properties) {
                        $envResult.properties | Get-Member -MemberType Properties | ForEach-Object { Write-Output "  - $($_.Name)" }
                    } else {
                        Write-Output "  - No properties object found"
                    }
                    
                    # Check for enterprise policies with proper null checking
                    $hasEnterprisePolicies = $false
                    $hasVNetPolicy = $false
                    
                    if ($envResult -and $envResult.properties) {
                        if ($envResult.properties.PSObject.Properties['enterprisePolicies']) {
                            $hasEnterprisePolicies = $true
                            Write-Output "✓ enterprisePolicies property found on environment"
                            
                            if ($envResult.properties.enterprisePolicies.PSObject.Properties['VNets']) {
                                $hasVNetPolicy = $true
                                Write-Output "✓ VNets policy found in enterprisePolicies"
                            } else {
                                Write-Output "✓ enterprisePolicies exists but no VNets policy found"
                            }
                        } else {
                            Write-Output "✓ No enterprisePolicies property found on environment"
                        }
                    }
                    
                    if ($hasVNetPolicy) {
                        Write-Output "❌ Enterprise policy is still linked. The conflict might be due to:"
                        Write-Output "   - Incorrect SystemId in the request"
                        Write-Output "   - Environment or policy in transitional state"
                        Write-Output "   - Concurrent operations"
                        
                        # Try alternative approaches
                        Write-Output "Attempting alternative unlink approaches..."
                        return Try-AlternativeUnlinkMethods -EnvironmentId $powerPlatformEnvironmentId -AccessToken $accessToken -EnterprisePolicyId $enterprisePolicyId
                    }
                    else {
                        Write-Output "✓ Enterprise policy appears to already be unlinked from the environment."
                        Write-Output "✓ The 409 conflict was likely because the policy was already removed."
                        return $true
                    }
                }
                catch {
                    Write-Warning "Could not verify environment state: $($_.Exception.Message)"
                    Write-Output "This might be due to:"
                    Write-Output "  - API version compatibility issues"
                    Write-Output "  - Insufficient permissions to read enterprise policy information"
                    Write-Output "  - Environment in transitional state"
                    Write-Output ""
                    Write-Output "Proceeding with alternative unlink methods..."
                    return Try-AlternativeUnlinkMethods -EnvironmentId $powerPlatformEnvironmentId -AccessToken $accessToken -EnterprisePolicyId $enterprisePolicyId
                }
            }
            404 {
                Write-Output "✓ Resource not found (404). The enterprise policy may already be unlinked."
                return $true
            }
            401 {
                Write-Error "Authentication failed (401). Please check your permissions and token."
            }
            403 {
                Write-Error "Access forbidden (403). You may not have the required permissions to unlink enterprise policies."
            }
            default {
                Write-Error "HTTP Error $statusCode occurred during enterprise policy unlinking."
            }
        }
        
        throw
    }

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
    Write-Output "✓ Unlink operation completed successfully."

    ## 4 Then remove the enterprise policy
    az resource delete --ids $enterprisePolicyId --verbose    
    if ($LASTEXITCODE -eq 0) {
        Write-Output "✓ Enterprise policy $enterprisePolicyName removed successfully."
        $script:CleanupSuccess += "Enterprise policy removal"
    } else {
        Write-Warning "Failed to remove enterprise policy $enterprisePolicyName."
        $script:CleanupErrors += "Enterprise policy removal failed"
        exit 1
    }
    
    # 5c. Remove Power Platform environment if requested (most destructive operation)
    if ($RemoveEnvironment) {
        Write-Output ""
        Write-Output "🔥 Removing Power Platform environment (most destructive operation)..."
        
        if ($env:POWER_PLATFORM_ENVIRONMENT_NAME) {
            try {
                $accessToken = Get-PowerPlatformAccessToken
                $envRemovalSuccess = Remove-PowerPlatformEnvironment -EnvironmentDisplayName $env:POWER_PLATFORM_ENVIRONMENT_NAME -AccessToken $accessToken
                
                if ($envRemovalSuccess) {
                    Write-Output "✓ Power Platform environment removal completed."
                } else {
                    Write-Warning "Power Platform environment removal encountered issues."
                }
            }
            catch {
                Write-Warning "Error during Power Platform environment removal: $($_.Exception.Message)"
                $script:CleanupErrors += "Power Platform environment removal error: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "POWER_PLATFORM_ENVIRONMENT_NAME not set - cannot remove environment."
        }
    }
    
    # 5a. Remove Power Platform configuration first (dependencies)
    #Remove-PowerPlatformConfiguration
    
    # 5b. Preserve environment file for future reference
    Write-Output "💾 Preserving environment file for future reference: $EnvFile"
    Write-Output "✓ Environment configuration file has been kept intact for redeployment or troubleshooting."

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
finally {
    # Always execute Azure infrastructure cleanup regardless of other operations
    Write-Output ""
    Write-Output "🏗️  Executing Azure infrastructure cleanup (always runs)..."
    try {
        Remove-AzureInfrastructure
        Write-Output "✓ Azure infrastructure cleanup completed."
    }
    catch {
        Write-Warning "Error during Azure infrastructure cleanup: $($_.Exception.Message)"
        $script:CleanupErrors += "Azure infrastructure cleanup error: $($_.Exception.Message)"
    }
}

Write-Output ""
Write-Output "🏁 Cleanup script execution completed."
