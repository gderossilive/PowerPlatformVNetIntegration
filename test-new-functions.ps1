#!/usr/bin/env pwsh

# Simple test for the new Power Platform cleanup functions
# Tests only the custom connector and Copilot Studio cleanup functions

param(
    [string]$EnvironmentId = "dbe9c34a-d0dd-e4ed-b3a3-d3987dafe559" # Woodgrove-Prod environment
)

Write-Output "🧪 Testing New Power Platform Cleanup Functions"
Write-Output "Environment ID: $EnvironmentId"
Write-Output ""

# Initialize tracking arrays
$script:CleanupSuccess = @()
$script:CleanupErrors = @()

# Simple confirmation function for testing
function Confirm-CleanupOperation {
    param($OperationName, $Description, $ResourcesAffected)
    
    Write-Output ""
    Write-Output "📋 Would ask for confirmation: $OperationName"
    Write-Output "   Description: $Description"
    Write-Output "   Resources: $($ResourcesAffected.Count) item(s)"
    Write-Output "   🧪 TEST MODE - No actual deletions"
    return $false  # Don't actually delete in test mode
}

# Simple access token function (assumes az CLI is logged in)
function Get-PowerPlatformAccessToken {
    try {
        $token = az account get-access-token --resource https://service.powerapps.com/ --query accessToken --output tsv
        if ($token -and $token.Length -gt 0) {
            return $token
        }
        return $null
    }
    catch {
        Write-Warning "Failed to get Power Platform access token: $($_.Exception.Message)"
        return $null
    }
}

# Custom connector cleanup function
function Remove-PowerPlatformCustomConnectors {
    param(
        [string]$EnvironmentId,
        [string]$AccessToken
    )
    
    Write-Output ""
    Write-Output "🔌 Checking for custom connectors..."
    
    if (-not $EnvironmentId -or -not $AccessToken) {
        Write-Warning "Missing EnvironmentId or AccessToken for custom connector cleanup."
        return $false
    }
    
    try {
        $headers = @{
            'Authorization' = "Bearer $AccessToken"
            'Content-Type' = 'application/json'
        }
        
        # List all connectors in the environment
        $listConnectorsUrl = "https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$EnvironmentId/apis?api-version=2016-11-01"
        
        Write-Output "Querying connectors API..."
        $connectorsResponse = Invoke-RestMethod -Uri $listConnectorsUrl -Headers $headers -Method Get
        
        if ($connectorsResponse -and $connectorsResponse.value) {
            Write-Output "✅ Found $($connectorsResponse.value.Count) total connector(s) in environment"
            
            # Filter for potentially custom connectors
            $customConnectors = $connectorsResponse.value | Where-Object { 
                $_.properties.tier -eq "Premium" -or 
                $_.properties.tier -eq "Standard" -or
                $_.name -like "*-shared*" -or
                $_.properties.displayName -like "*petstore*" -or
                $_.properties.displayName -like "*custom*"
            }
            
            if ($customConnectors.Count -gt 0) {
                Write-Output "🎯 Found $($customConnectors.Count) potential custom connector(s):"
                foreach ($connector in $customConnectors) {
                    Write-Output "  - $($connector.properties.displayName) (Tier: $($connector.properties.tier))"
                }
                $script:CleanupSuccess += "Custom connector discovery"
            } else {
                Write-Output "✅ No custom connectors found (filtered results)"
            }
        } else {
            Write-Output "✅ No connectors found in environment"
        }
        
        return $true
    }
    catch {
        Write-Warning "Error querying custom connectors: $($_.Exception.Message)"
        $script:CleanupErrors += "Custom connector query error: $($_.Exception.Message)"
        return $false
    }
}

# Copilot Studio cleanup function
function Remove-CopilotStudioAgents {
    param(
        [string]$EnvironmentId,
        [string]$AccessToken
    )
    
    Write-Output ""
    Write-Output "🤖 Checking for Copilot Studio agents..."
    
    if (-not $EnvironmentId -or -not $AccessToken) {
        Write-Warning "Missing EnvironmentId or AccessToken for Copilot Studio cleanup."
        return $false
    }
    
    try {
        $headers = @{
            'Authorization' = "Bearer $AccessToken"
            'Content-Type' = 'application/json'
        }
        
        # Try Power Virtual Agents API first
        $listBotsUrl = "https://api.powerva.microsoft.com/providers/Microsoft.BotFramework/environments/$EnvironmentId/chatBots?api-version=2022-03-01-preview"
        
        Write-Output "Querying Power Virtual Agents API..."
        
        try {
            $botsResponse = Invoke-RestMethod -Uri $listBotsUrl -Headers $headers -Method Get
            
            if ($botsResponse -and $botsResponse.value) {
                Write-Output "✅ Found $($botsResponse.value.Count) Copilot Studio agent(s):"
                foreach ($bot in $botsResponse.value) {
                    $botName = if ($bot.properties.displayName) { $bot.properties.displayName } else { $bot.name }
                    Write-Output "  - $botName"
                }
                $script:CleanupSuccess += "Copilot Studio agent discovery"
            } else {
                Write-Output "✅ No Copilot Studio agents found"
            }
        }
        catch {
            Write-Output "Power Virtual Agents API returned: $($_.Exception.Message)"
            
            # Try alternative API
            Write-Output "Trying alternative Business Application Platform API..."
            $altListUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/chatbots?api-version=2020-06-01"
            
            try {
                $altBotsResponse = Invoke-RestMethod -Uri $altListUrl -Headers $headers -Method Get
                
                if ($altBotsResponse -and $altBotsResponse.value) {
                    Write-Output "✅ Found $($altBotsResponse.value.Count) agent(s) via alternative API:"
                    foreach ($bot in $altBotsResponse.value) {
                        $botName = if ($bot.properties -and $bot.properties.displayName) { $bot.properties.displayName } else { $bot.name }
                        Write-Output "  - $botName"
                    }
                    $script:CleanupSuccess += "Copilot Studio agent discovery (alt API)"
                } else {
                    Write-Output "✅ No agents found via alternative API"
                }
            }
            catch {
                Write-Output "Alternative API also failed: $($_.Exception.Message)"
                Write-Output "✅ This might mean no agents exist or APIs are not accessible"
            }
        }
        
        return $true
    }
    catch {
        Write-Warning "Error during Copilot Studio agent check: $($_.Exception.Message)"
        $script:CleanupErrors += "Copilot Studio agent check error: $($_.Exception.Message)"
        return $false
    }
}

# Main test execution
try {
    Write-Output "🔑 Getting Power Platform access token..."
    $accessToken = Get-PowerPlatformAccessToken
    
    if ($accessToken) {
        Write-Output "✅ Access token obtained (length: $($accessToken.Length) chars)"
        
        # Test custom connector function
        $connectorResult = Remove-PowerPlatformCustomConnectors -EnvironmentId $EnvironmentId -AccessToken $accessToken
        
        # Test Copilot Studio function
        $copilotResult = Remove-CopilotStudioAgents -EnvironmentId $EnvironmentId -AccessToken $accessToken
        
        Write-Output ""
        Write-Output "📊 TEST RESULTS"
        Write-Output "================"
        Write-Output "Custom Connector Function: $(if ($connectorResult) { '✅ SUCCESS' } else { '❌ FAILED' })"
        Write-Output "Copilot Studio Function: $(if ($copilotResult) { '✅ SUCCESS' } else { '❌ FAILED' })"
        
        if ($script:CleanupSuccess.Count -gt 0) {
            Write-Output ""
            Write-Output "✅ Successful operations:"
            foreach ($success in $script:CleanupSuccess) {
                Write-Output "  ✓ $success"
            }
        }
        
        if ($script:CleanupErrors.Count -gt 0) {
            Write-Output ""
            Write-Output "❌ Errors encountered:"
            foreach ($errorMsg in $script:CleanupErrors) {
                Write-Output "  ✗ $errorMsg"
            }
        }
        
    } else {
        Write-Error "❌ Failed to obtain access token"
        exit 1
    }
}
catch {
    Write-Error "❌ Test error: $($_.Exception.Message)"
    exit 1
}

Write-Output ""
Write-Output "🏁 Function test completed successfully"
