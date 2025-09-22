#!/usr/bin/env pwsh

# Test script for Woodgrove-Prod environment deletion
# Verifies the enhanced cleanup script can properly delete the Power Platform environment

param(
    [switch]$DryRun = $true,  # Default to dry run to avoid accidental deletion
    [switch]$Force = $false   # Force deletion without additional prompts
)

Write-Output "🧪 Testing Woodgrove-Prod Environment Deletion"
Write-Output "Dry Run Mode: $DryRun"
Write-Output "Force Mode: $Force"
Write-Output ""

# Set the required environment variables
$env:POWER_PLATFORM_ENVIRONMENT_NAME = "Woodgrove-Prod"
$environmentId = "dbe9c34a-d0dd-e4ed-b3a3-d3987dafe559"

if ($DryRun) {
    Write-Output "🔍 DRY RUN: Checking if Woodgrove-Prod environment exists..."
    
    # Test authentication and environment lookup
    try {
        Write-Output "Getting Power Platform access token..."
        $token = az account get-access-token --resource https://service.powerapps.com/ --query accessToken --output tsv
        
        if ($token -and $token.Length -gt 0) {
            Write-Output "✅ Access token obtained (length: $($token.Length) chars)"
            
            # Check if environment exists
            $headers = @{
                'Authorization' = "Bearer $token"
                'Content-Type' = 'application/json'
            }
            
            $environmentUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$environmentId" + "?api-version=2023-06-01"
            
            try {
                Write-Output "Checking environment existence..."
                $envResponse = Invoke-RestMethod -Uri $environmentUrl -Headers $headers -Method Get
                
                if ($envResponse) {
                    Write-Output "✅ Environment found:"
                    Write-Output "   Name: $($envResponse.properties.displayName)"
                    Write-Output "   ID: $($envResponse.name)"
                    Write-Output "   State: $($envResponse.properties.provisioningState)"
                    Write-Output "   Type: $($envResponse.properties.environmentSku)"
                    
                    if ($envResponse.properties.linkedEnvironmentMetadata) {
                        Write-Output "   Dataverse: $($envResponse.properties.linkedEnvironmentMetadata.type)"
                    }
                    
                    Write-Output ""
                    Write-Output "🔥 In REAL mode, this environment would be PERMANENTLY DELETED!"
                    Write-Output "   All apps, flows, connections, and data would be lost."
                    Write-Output ""
                    Write-Output "To actually delete the environment, run:"
                    Write-Output "   pwsh ./test-environment-deletion.ps1 -DryRun:`$false -Force"
                } else {
                    Write-Output "❌ Environment not found or not accessible"
                }
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq 404) {
                    Write-Output "✅ Environment not found (404) - it may have already been deleted"
                } else {
                    Write-Warning "Error checking environment: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Error "❌ Failed to obtain access token"
            exit 1
        }
    }
    catch {
        Write-Error "❌ Error during environment check: $($_.Exception.Message)"
        exit 1
    }
} else {
    # Real deletion mode
    Write-Output "⚠️  REAL DELETION MODE - This will permanently delete the Woodgrove-Prod environment!"
    Write-Output ""
    
    if (-not $Force) {
        Write-Output "This will permanently delete:"
        Write-Output "  🎯 Environment: Woodgrove-Prod"
        Write-Output "  🎯 Environment ID: $environmentId"
        Write-Output "  ⚠️  ALL DATA in this environment"
        Write-Output "  ⚠️  All apps, flows, connections, custom connectors"
        Write-Output "  ⚠️  All Copilot Studio agents"
        Write-Output "  ⚠️  This action CANNOT BE UNDONE"
        Write-Output ""
        
        $confirmation = Read-Host "Type 'DELETE-WOODGROVE-PROD' to confirm deletion"
        
        if ($confirmation -ne "DELETE-WOODGROVE-PROD") {
            Write-Output "❌ Confirmation failed. Environment deletion cancelled."
            exit 1
        }
    }
    
    Write-Output ""
    Write-Output "🚀 Running cleanup script with environment deletion..."
    
    # Run the actual cleanup script with RemoveEnvironment flag
    $cleanupArgs = @(
        "-RemoveEnvironment"
    )
    
    if ($Force) {
        $cleanupArgs += "-Force"
    }
    
    try {
        & pwsh ./5-Cleanup.ps1 @cleanupArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Output ""
            Write-Output "✅ Cleanup script completed successfully"
            Write-Output "🗑️  Woodgrove-Prod environment deletion initiated"
        } else {
            Write-Warning "❌ Cleanup script encountered issues (exit code: $LASTEXITCODE)"
        }
    }
    catch {
        Write-Error "❌ Error running cleanup script: $($_.Exception.Message)"
        exit 1
    }
}

Write-Output ""
Write-Output "🏁 Environment deletion test completed"
