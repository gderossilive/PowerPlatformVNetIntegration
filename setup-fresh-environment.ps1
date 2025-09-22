#!/usr/bin/env pwsh

# End-to-End Test Setup Script
# Creates a fresh environment for complete testing of the Power Platform VNet Integration

param(
    [string]$EnvironmentName = "E2E-Test-$(Get-Date -Format 'MMdd')",
    [string]$Location = "westeurope",
    [string]$PowerPlatformLocation = "europe"
)

Write-Output "🚀 Setting up fresh environment for end-to-end testing"
Write-Output "Environment Name: $EnvironmentName"
Write-Output "Azure Location: $Location"
Write-Output "Power Platform Location: $PowerPlatformLocation"
Write-Output ""

# Generate unique suffixes for resources
$timestamp = Get-Date -Format "HHmm"
$resourceSuffix = "$timestamp"

# Create the new environment configuration
$envConfig = @"
TENANT_ID=86d068c0-1c9f-4b9e-939d-15146ccf2ad6
AZURE_SUBSCRIPTION_ID=06dbbc7b-2363-4dd4-9803-95d07f1a8d3e
AZURE_LOCATION=$Location
POWER_PLATFORM_ENVIRONMENT_NAME=$EnvironmentName
POWER_PLATFORM_LOCATION=$PowerPlatformLocation
RESOURCE_GROUP=$EnvironmentName-$resourceSuffix
PRIMARY_VIRTUAL_NETWORK_NAME=az-vnet-WE-primary-$resourceSuffix
PRIMARY_SUBNET_NAME=snet-injection-WE-primary-$resourceSuffix
SECONDARY_VIRTUAL_NETWORK_NAME=az-vnet-NE-secondary-$resourceSuffix
SECONDARY_SUBNET_NAME=snet-injection-NE-secondary-$resourceSuffix
ENTERPRISE_POLICY_NAME=ep-$EnvironmentName-$resourceSuffix
APIM_NAME=az-apim-$resourceSuffix
"@

# Backup current .env file
if (Test-Path ".env") {
    $backupName = ".env.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item ".env" $backupName
    Write-Output "✅ Backed up current .env to: $backupName"
}

# Write new .env file
$envConfig | Out-File -FilePath ".env" -Encoding UTF8
Write-Output "✅ Created new .env file for $EnvironmentName"

# Clean up any existing azd state for the new environment
try {
    $azdEnvExists = azd env list --output json | ConvertFrom-Json | Where-Object { $_.Name -eq $EnvironmentName }
    if ($azdEnvExists) {
        Write-Output "🧹 Removing existing azd environment: $EnvironmentName"
        azd env remove $EnvironmentName --force
    }
}
catch {
    Write-Output "No existing azd environment to remove"
}

# Initialize new azd environment
Write-Output "🏗️  Initializing new azd environment: $EnvironmentName"
azd env new $EnvironmentName

# Set as default environment
azd env select $EnvironmentName

Write-Output ""
Write-Output "✅ Fresh environment setup complete!"
Write-Output ""
Write-Output "📋 Environment Details:"
Write-Output "   Name: $EnvironmentName"
Write-Output "   Resource Group: $EnvironmentName-$resourceSuffix"
Write-Output "   Location: $Location"
Write-Output "   Power Platform Location: $PowerPlatformLocation"
Write-Output ""
Write-Output "🎯 Next Steps:"
Write-Output "1. Run: ./0-CreatePowerPlatformEnvironment.ps1"
Write-Output "2. Run: ./1-InfraSetup.ps1" 
Write-Output "3. Run: ./2-SubnetInjectionSetup.ps1"
Write-Output "4. Run: ./3-CreateCustomConnector.ps1"
Write-Output "5. Run: ./4-SetupCopilotStudio.ps1"
Write-Output "6. Test: ./5-Cleanup.ps1 (without -RemoveEnvironment first)"
Write-Output "7. Test: ./5-Cleanup.ps1 -RemoveEnvironment (complete cleanup)"
Write-Output ""
Write-Output "📁 Configuration saved to: .env"
Write-Output "🔙 Previous config backed up to: $backupName"
