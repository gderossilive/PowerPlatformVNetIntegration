# Unlink Enterprise Policy from Power Platform Environment
# This script must be run before cleaning up Azure resources

# Load environment variables
$envFile = ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $name = $matches[1]
            $value = $matches[2]
            [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
    Write-Host "Environment variables loaded from .env file" -ForegroundColor Green
} else {
    Write-Host "Error: .env file not found" -ForegroundColor Red
    exit 1
}

# Get required variables
$environmentId = $env:POWER_PLATFORM_ENVIRONMENT_ID
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$resourceGroup = $env:RESOURCE_GROUP
$enterprisePolicyName = $env:ENTERPRISE_POLICY_NAME

if (-not $environmentId -or -not $subscriptionId -or -not $resourceGroup -or -not $enterprisePolicyName) {
    Write-Host "Error: Required environment variables are missing" -ForegroundColor Red
    Write-Host "Required: POWER_PLATFORM_ENVIRONMENT_ID, AZURE_SUBSCRIPTION_ID, RESOURCE_GROUP, ENTERPRISE_POLICY_NAME" -ForegroundColor Red
    exit 1
}

# Construct the policy ARM ID
$policyArmId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.PowerPlatform/enterprisePolicies/$enterprisePolicyName"

Write-Host "Starting policy unlinking process..." -ForegroundColor Yellow
Write-Host "Environment ID: $environmentId" -ForegroundColor Cyan
Write-Host "Policy ARM ID: $policyArmId" -ForegroundColor Cyan

# Load the unlinking script
$scriptPath = "$PSScriptRoot\orig-scripts\SubnetInjection\RevertSubnetInjection.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: RevertSubnetInjection.ps1 not found at $scriptPath" -ForegroundColor Red
    exit 1
}

# Run the unlinking function with the proper parameters
try {
    # Load the script functions
    . "$PSScriptRoot\orig-scripts\Common\EnvironmentEnterprisePolicyOperations.ps1"
    
    # Call the unlinking function directly
    Write-Host "Calling UnLinkPolicyFromEnv..." -ForegroundColor Green
    UnLinkPolicyFromEnv -policyType "vnet" -environmentId $environmentId -policyArmId $policyArmId -endpoint "prod"
    
    Write-Host "Policy unlinking completed. You can now proceed with Azure resource cleanup." -ForegroundColor Green
} catch {
    Write-Host "Error during policy unlinking: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "You may need to unlink the policy manually in the Power Platform Admin Center" -ForegroundColor Yellow
}
