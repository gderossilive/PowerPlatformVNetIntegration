#!/usr/bin/env pwsh
<#
.SYNOPSIS
Gets the Power Platform environment ID for automation scripts.

.DESCRIPTION
This script queries the Power Platform admin API to find and return the environment ID
for the specified environment name. This ID can then be used with the automation scripts.

.PARAMETER EnvironmentName
The display name of the Power Platform environment to find.
Defaults to the environment name from the .env file.
#>

param(
    [string]$EnvironmentName = ""
)

# Load environment variables if EnvironmentName not provided
if ([string]::IsNullOrEmpty($EnvironmentName)) {
    if (Test-Path "./.env") {
        Get-Content "./.env" | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                $name = $matches[1]
                $value = $matches[2]
                Set-Item -Path "env:$name" -Value $value
            }
        }
        $EnvironmentName = $env:POWER_PLATFORM_ENVIRONMENT_NAME
    } else {
        $EnvironmentName = "Woodgrove-Prod"
    }
}

Write-Host "🔍 Searching for Power Platform environment: $EnvironmentName"
Write-Host ""

# Try different API endpoints to find the environment
$endpoints = @(
    "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2023-06-01",
    "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01"
)

foreach ($endpoint in $endpoints) {
    Write-Host "Trying endpoint: $endpoint"
    
    try {
        # Get access token for Business Application Platform
        $token = az account get-access-token --resource "https://api.bap.microsoft.com/" --query accessToken --output tsv
        
        if ($token) {
            $headers = @{
                Authorization = "Bearer $token"
                'Content-Type' = 'application/json'
            }
            
            # Query the environments
            $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get
            
            if ($response.value) {
                Write-Host "✓ Successfully retrieved environments list"
                
                # Look for the environment by display name
                $targetEnv = $response.value | Where-Object { $_.displayName -eq $EnvironmentName }
                
                if ($targetEnv) {
                    Write-Host ""
                    Write-Host "🎉 Found environment!"
                    Write-Host "================================"
                    Write-Host "Display Name: $($targetEnv.displayName)"
                    Write-Host "Environment ID: $($targetEnv.name)"
                    Write-Host "Location: $($targetEnv.location)"
                    Write-Host "State: $($targetEnv.properties.states.runtime.id)"
                    Write-Host ""
                    Write-Host "💡 Use this Environment ID with your scripts:"
                    Write-Host "./3-CreateCustomConnector.ps1 -EnvironmentId '$($targetEnv.name)' -Force"
                    Write-Host "./4-SetupCopilotStudio.ps1 -EnvironmentId '$($targetEnv.name)' -Force"
                    Write-Host ""
                    return $targetEnv.name
                } else {
                    Write-Host "⚠️  Environment '$EnvironmentName' not found in this endpoint"
                    
                    # Show available environments
                    Write-Host ""
                    Write-Host "Available environments:"
                    $response.value | ForEach-Object {
                        Write-Host "- $($_.displayName) (ID: $($_.name))"
                    }
                    Write-Host ""
                }
            }
        }
    } catch {
        Write-Host "❌ Failed to query endpoint: $($_.Exception.Message)"
    }
}

# If we get here, we didn't find the environment
Write-Host ""
Write-Host "❌ Could not find environment '$EnvironmentName'"
Write-Host ""
Write-Host "📋 Manual steps to get your environment ID:"
Write-Host "1. Go to https://admin.powerplatform.microsoft.com/"
Write-Host "2. Click on 'Environments'"
Write-Host "3. Find your environment '$EnvironmentName'"
Write-Host "4. Copy the Environment ID (GUID format)"
Write-Host "5. Run: ./3-CreateCustomConnector.ps1 -EnvironmentId 'YOUR_ID_HERE' -Force"
Write-Host ""

return $null
