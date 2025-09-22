#!/usr/bin/env pwsh

# Simple Power Platform environment creation for end-to-end testing
param(
    [string]$EnvFile = "./.env"
)

Write-Output "🚀 Simple Power Platform Environment Creation"
Write-Output "============================================="

# Load environment variables
if (-not (Test-Path $EnvFile)) {
    Write-Error "Environment file not found: $EnvFile"
    exit 1
}

# Parse .env file
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

Write-Output "✅ Environment variables loaded"
Write-Output "Target environment: $env:POWER_PLATFORM_ENVIRONMENT_NAME"
Write-Output "Target location: $env:POWER_PLATFORM_LOCATION"

try {
    # Get access token
    Write-Output "🔑 Getting Power Platform access token..."
    $accessToken = az account get-access-token --resource https://service.powerapps.com/ --query accessToken --output tsv
    
    if (-not $accessToken) {
        Write-Error "Failed to get access token"
        exit 1
    }
    
    Write-Output "✅ Access token obtained"
    
    # Check if environment exists
    Write-Output "🔍 Checking if environment already exists..."
    $headers = @{
        'Authorization' = "Bearer $accessToken"
        'Content-Type' = 'application/json'
    }
    
    $listUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01"
    $response = Invoke-RestMethod -Uri $listUrl -Headers $headers -Method Get
    
    $existingEnv = $response.value | Where-Object { $_.properties.displayName -eq $env:POWER_PLATFORM_ENVIRONMENT_NAME }
    
    if ($existingEnv) {
        Write-Output "✅ Environment already exists: $($existingEnv.name)"
        Write-Output "   State: $($existingEnv.properties.provisioningState)"
        
        # Update .env file with existing environment details
        $envContent = Get-Content $EnvFile
        $newContent = @()
        $foundId = $false
        
        foreach ($line in $envContent) {
            if ($line -like "POWER_PLATFORM_ENVIRONMENT_ID=*") {
                $newContent += "POWER_PLATFORM_ENVIRONMENT_ID=$($existingEnv.name)"
                $foundId = $true
            } else {
                $newContent += $line
            }
        }
        
        if (-not $foundId) {
            $newContent += "POWER_PLATFORM_ENVIRONMENT_ID=$($existingEnv.name)"
        }
        
        $newContent | Set-Content $EnvFile
        Write-Output "✅ Updated .env file with environment ID"
        
        return $true
    }
    
    # Create new environment
    Write-Output "🏗️  Creating new environment..."
    
    $createBody = @{
        location = $env:POWER_PLATFORM_LOCATION
        properties = @{
            displayName = $env:POWER_PLATFORM_ENVIRONMENT_NAME
            environmentSku = "Sandbox"
            azureRegion = $env:AZURE_LOCATION
            isDefault = $false
        }
    } | ConvertTo-Json -Depth 10
    
    $createUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01"
    
    Write-Output "Sending environment creation request..."
    $createResponse = Invoke-RestMethod -Uri $createUrl -Headers $headers -Method Post -Body $createBody
    
    if ($createResponse) {
        Write-Output "✅ Environment creation initiated"
        
        # Wait for environment to be ready
        $environmentId = $createResponse.name
        Write-Output "Environment ID: $environmentId"
        
        # Poll for completion
        Write-Output "⏳ Waiting for environment to be ready..."
        $maxWaitTime = 300 # 5 minutes
        $waitInterval = 15 # 15 seconds
        $elapsed = 0
        
        while ($elapsed -lt $maxWaitTime) {
            Start-Sleep -Seconds $waitInterval
            $elapsed += $waitInterval
            
            try {
                $statusUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$environmentId" + "?api-version=2023-06-01"
                $statusResponse = Invoke-RestMethod -Uri $statusUrl -Headers $headers -Method Get
                
                $state = $statusResponse.properties.provisioningState
                Write-Output "   Status: $state (elapsed: ${elapsed}s)"
                
                if ($state -eq "Succeeded") {
                    Write-Output "✅ Environment created successfully!"
                    
                    # Update .env file
                    $envContent = Get-Content $EnvFile
                    $newContent = @()
                    $foundId = $false
                    
                    foreach ($line in $envContent) {
                        if ($line -like "POWER_PLATFORM_ENVIRONMENT_ID=*") {
                            $newContent += "POWER_PLATFORM_ENVIRONMENT_ID=$environmentId"
                            $foundId = $true
                        } else {
                            $newContent += $line
                        }
                    }
                    
                    if (-not $foundId) {
                        $newContent += "POWER_PLATFORM_ENVIRONMENT_ID=$environmentId"
                    }
                    
                    $newContent | Set-Content $EnvFile
                    Write-Output "✅ Updated .env file with environment ID"
                    
                    Write-Output ""
                    Write-Output "🎉 Power Platform Environment Ready!"
                    Write-Output "=================================="
                    Write-Output "Name: $env:POWER_PLATFORM_ENVIRONMENT_NAME"
                    Write-Output "ID: $environmentId"
                    Write-Output "Location: $env:POWER_PLATFORM_LOCATION"
                    Write-Output "Type: Sandbox"
                    
                    return $true
                } elseif ($state -eq "Failed") {
                    Write-Error "Environment creation failed"
                    return $false
                }
            }
            catch {
                Write-Output "   Waiting for environment status... (${elapsed}s)"
            }
        }
        
        Write-Warning "Environment creation timed out after $maxWaitTime seconds"
        Write-Output "Check Power Platform Admin Center for status"
        return $false
    } else {
        Write-Error "Failed to create environment"
        return $false
    }
}
catch {
    Write-Error "Error creating environment: $($_.Exception.Message)"
    return $false
}
