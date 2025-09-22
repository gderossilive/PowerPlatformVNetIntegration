#!/usr/bin/env pwsh

# Test script to verify Power Platform environment creation and .env file updates
# Tests the enhanced environment creation script to ensure environment ID is properly added

param(
    [string]$TestEnvFile = "./test-env-backup.env"
)

Write-Output "🧪 Testing Power Platform Environment Creation and .env File Updates"
Write-Output "======================================================================="
Write-Output ""

# Backup current .env file
if (Test-Path "./.env") {
    Copy-Item "./.env" $TestEnvFile
    Write-Output "✅ Backed up current .env file to: $TestEnvFile"
} else {
    Write-Warning "No existing .env file found to backup"
}

# Check current environment variables in .env
Write-Output ""
Write-Output "📋 Current .env file contents:"
Write-Output "================================"
if (Test-Path "./.env") {
    Get-Content "./.env" | ForEach-Object {
        if ($_ -match '^POWER_PLATFORM_ENVIRONMENT') {
            Write-Output "🎯 $_"
        } else {
            Write-Output "   $_"
        }
    }
} else {
    Write-Output "❌ No .env file found"
}

# Check if POWER_PLATFORM_ENVIRONMENT_ID exists
Write-Output ""
Write-Output "🔍 Checking for POWER_PLATFORM_ENVIRONMENT_ID in .env file:"
Write-Output "============================================================="

$envContent = @{}
$environmentIdExists = $false
$environmentId = ""

if (Test-Path "./.env") {
    Get-Content "./.env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $key = $matches[1]
            $value = $matches[2]
            $envContent[$key] = $value
            
            if ($key -eq 'POWER_PLATFORM_ENVIRONMENT_ID') {
                $environmentIdExists = $true
                $environmentId = $value
            }
        }
    }
}

if ($environmentIdExists) {
    Write-Output "✅ POWER_PLATFORM_ENVIRONMENT_ID found: $environmentId"
    
    # Verify the environment exists
    Write-Output ""
    Write-Output "🔍 Verifying environment exists in Power Platform:"
    Write-Output "=================================================="
    
    try {
        $token = az account get-access-token --resource https://service.powerapps.com/ --query accessToken --output tsv
        
        if ($token -and $token.Length -gt 0) {
            $headers = @{
                'Authorization' = "Bearer $token"
                'Content-Type' = 'application/json'
            }
            
            $environmentUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$environmentId" + "?api-version=2023-06-01"
            
            try {
                $envResponse = Invoke-RestMethod -Uri $environmentUrl -Headers $headers -Method Get
                
                Write-Output "✅ Environment verified in Power Platform:"
                Write-Output "   Name: $($envResponse.properties.displayName)"
                Write-Output "   ID: $($envResponse.name)"
                Write-Output "   State: $($envResponse.properties.provisioningState)"
                Write-Output "   Type: $($envResponse.properties.environmentSku)"
                Write-Output "   URL: $($envResponse.properties.webApplicationUrl)"
                
                if ($envResponse.properties.linkedEnvironmentMetadata) {
                    Write-Output "   Dataverse: Enabled"
                    Write-Output "   Instance URL: $($envResponse.properties.linkedEnvironmentMetadata.instanceUrl)"
                }
                
                Write-Output ""
                Write-Output "✅ Environment ID in .env file matches existing Power Platform environment!"
                
            } catch {
                if ($_.Exception.Response.StatusCode -eq 404) {
                    Write-Warning "❌ Environment with ID '$environmentId' not found in Power Platform"
                    Write-Output "This indicates the environment ID in .env file is stale or incorrect"
                } else {
                    Write-Warning "Error verifying environment: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Warning "❌ Could not obtain Power Platform access token"
        }
    } catch {
        Write-Warning "Error during environment verification: $($_.Exception.Message)"
    }
} else {
    Write-Output "❌ POWER_PLATFORM_ENVIRONMENT_ID not found in .env file"
    Write-Output ""
    Write-Output "This indicates either:"
    Write-Output "1. No Power Platform environment has been created yet"
    Write-Output "2. The environment creation script didn't properly update the .env file"
    Write-Output "3. The .env file was manually modified"
    Write-Output ""
    Write-Output "To create a new environment and add the ID, run:"
    Write-Output "   pwsh ./0-CreatePowerPlatformEnvironment.ps1"
}

# Show other relevant environment variables
Write-Output ""
Write-Output "📋 Other Power Platform related variables:"
Write-Output "=========================================="

$ppVars = @('POWER_PLATFORM_ENVIRONMENT_NAME', 'POWER_PLATFORM_LOCATION', 'POWER_PLATFORM_ENVIRONMENT_URL', 'DATAVERSE_INSTANCE_URL', 'DATAVERSE_UNIQUE_NAME')

foreach ($var in $ppVars) {
    if ($envContent.ContainsKey($var)) {
        Write-Output "✅ $var = $($envContent[$var])"
    } else {
        Write-Output "❌ $var = (not set)"
    }
}

Write-Output ""
Write-Output "🏁 Environment ID verification test completed"
Write-Output ""

if ($environmentIdExists) {
    Write-Output "✅ RESULT: Power Platform Environment ID is properly configured"
    Write-Output "   Ready to proceed with next steps (infrastructure setup)"
} else {
    Write-Output "⚠️  RESULT: Power Platform Environment ID needs to be added"
    Write-Output "   Run the environment creation script first"
}

Write-Output ""
Write-Output "💾 Backup file available at: $TestEnvFile"
