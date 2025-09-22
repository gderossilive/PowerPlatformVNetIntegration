#!/usr/bin/env pwsh

# Check existing Power Platform environments
param(
    [string]$EnvironmentDisplayName = "E2E-Test-082141"
)

Write-Output "🔍 Checking Power Platform Environments"
Write-Output "Looking for environment: $EnvironmentDisplayName"
Write-Output ""

try {
    # Get access token
    $accessToken = az account get-access-token --resource https://service.powerapps.com/ --query accessToken --output tsv
    
    if (-not $accessToken) {
        Write-Error "Failed to get access token"
        exit 1
    }
    
    Write-Output "✅ Access token obtained"
    
    # List environments
    $headers = @{
        'Authorization' = "Bearer $accessToken"
        'Content-Type' = 'application/json'
    }
    
    $listUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01"
    
    Write-Output "📋 Listing all environments..."
    $response = Invoke-RestMethod -Uri $listUrl -Headers $headers -Method Get
    
    if ($response -and $response.value) {
        Write-Output "Found $($response.value.Count) total environments:"
        
        foreach ($env in $response.value) {
            $displayName = $env.properties.displayName
            $envId = $env.name
            $state = $env.properties.provisioningState
            $type = $env.properties.environmentSku
            
            Write-Output "  - $displayName ($envId) - $state - $type"
            
            # Check if this is our target environment
            if ($displayName -eq $EnvironmentDisplayName) {
                Write-Output ""
                Write-Output "🎯 FOUND TARGET ENVIRONMENT: $EnvironmentDisplayName"
                Write-Output "   ID: $envId"
                Write-Output "   State: $state"
                Write-Output "   Type: $type"
                Write-Output "   Location: $($env.properties.azureRegion)"
                
                # Update .env file with the found environment ID
                $envFile = "./.env"
                if (Test-Path $envFile) {
                    $envContent = Get-Content $envFile
                    $newContent = @()
                    $foundPowerPlatformId = $false
                    
                    foreach ($line in $envContent) {
                        if ($line -like "POWER_PLATFORM_ENVIRONMENT_ID=*") {
                            $newContent += "POWER_PLATFORM_ENVIRONMENT_ID=$envId"
                            $foundPowerPlatformId = $true
                        } else {
                            $newContent += $line
                        }
                    }
                    
                    if (-not $foundPowerPlatformId) {
                        $newContent += "POWER_PLATFORM_ENVIRONMENT_ID=$envId"
                    }
                    
                    $newContent | Set-Content $envFile
                    Write-Output "✅ Updated .env file with environment ID"
                }
                
                return $true
            }
        }
        
        Write-Output ""
        Write-Output "❌ Environment '$EnvironmentDisplayName' not found"
        Write-Output "Available environments with similar names:"
        
        $similarEnvs = $response.value | Where-Object { $_.properties.displayName -like "*Test*" -or $_.properties.displayName -like "*E2E*" }
        if ($similarEnvs) {
            foreach ($env in $similarEnvs) {
                Write-Output "  - $($env.properties.displayName) ($($env.name))"
            }
        } else {
            Write-Output "  (No similar environments found)"
        }
        
        return $false
    } else {
        Write-Output "❌ No environments found or empty response"
        return $false
    }
}
catch {
    Write-Error "Error checking environments: $($_.Exception.Message)"
    return $false
}
