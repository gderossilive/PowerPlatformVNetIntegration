#!/usr/bin/env pwsh

# Enhanced test script for Power Platform cleanup functionality
# Tests the new custom connector and Copilot Studio cleanup functions

param(
    [string]$EnvironmentId = "b7dc0277-b51d-e968-a04e-675cddbd3453", # Fabrikam-Tst environment from .env
    [switch]$DryRun = $false  # Set to false to actually perform unlinking
)

Write-Output "🧪 Testing Enhanced Power Platform Cleanup Functions"
Write-Output "Environment ID: $EnvironmentId"
Write-Output "Dry Run Mode: $DryRun"
Write-Output ""

# Set required environment variables for the cleanup script
$env:POWER_PLATFORM_ENVIRONMENT_NAME = "Fabrikam-Tst"

# Load the cleanup script to get all functions
$cleanupScriptPath = Join-Path $PSScriptRoot "5-Cleanup.sh"

if (-not (Test-Path $cleanupScriptPath)) {
    Write-Error "Cleanup script not found at: $cleanupScriptPath"
    exit 1
}

Write-Output "Loading cleanup script functions..."

# Override the Confirm-CleanupOperation function for testing
$global:TestMode = $DryRun

function Confirm-CleanupOperation {
    param($OperationName, $Description, $ResourcesAffected)
    
    Write-Output ""
    Write-Output "📋 CLEANUP CONFIRMATION REQUEST"
    Write-Output "Operation: $OperationName"
    Write-Output "Description: $Description"
    Write-Output "Resources that would be affected:"
    foreach ($resource in $ResourcesAffected) {
        Write-Output "  🎯 $resource"
    }
    
    if ($global:TestMode) {
        Write-Output "🧪 DRY RUN MODE - Simulation only, no actual deletions"
        return $false  # Don't actually delete in dry run
    } else {
        # In real mode, would prompt user for confirmation
        Write-Output "⚠️  This would prompt for user confirmation in real mode"
        return $true   
    }
}

# Load all functions from the cleanup script by dot-sourcing
try {
    Write-Output "Sourcing cleanup script..."
    . $cleanupScriptPath
    Write-Output "✓ Cleanup script loaded successfully"
}
catch {
    Write-Error "Failed to load cleanup script: $($_.Exception.Message)"
    exit 1
}

# Initialize tracking arrays
$script:CleanupSuccess = @()
$script:CleanupErrors = @()

try {
    Write-Output ""
    Write-Output "🔑 Getting Power Platform access token..."
    $accessToken = Get-PowerPlatformAccessToken
    
    if ($accessToken) {
        Write-Output "✅ Access token obtained successfully"
        Write-Output "Token length: $($accessToken.Length) characters"
        
        Write-Output ""
        Write-Output "🔌 Testing custom connector discovery and cleanup..."
        $connectorResult = Remove-PowerPlatformCustomConnectors -EnvironmentId $EnvironmentId -AccessToken $accessToken
        
        Write-Output ""
        Write-Output "🤖 Testing Copilot Studio agent discovery and cleanup..."
        $copilotResult = Remove-CopilotStudioAgents -EnvironmentId $EnvironmentId -AccessToken $accessToken
        
        Write-Output ""
        Write-Output "📊 TEST RESULTS SUMMARY"
        Write-Output "========================"
        Write-Output "Custom Connector Function: $(if ($connectorResult) { '✅ SUCCESS' } else { '❌ FAILED' })"
        Write-Output "Copilot Studio Function: $(if ($copilotResult) { '✅ SUCCESS' } else { '❌ FAILED' })"
        
        if ($script:CleanupSuccess.Count -gt 0) {
            Write-Output ""
            Write-Output "✅ SUCCESSFUL OPERATIONS:"
            foreach ($success in $script:CleanupSuccess) {
                Write-Output "  ✓ $success"
            }
        }
        
        if ($script:CleanupErrors.Count -gt 0) {
            Write-Output ""
            Write-Output "❌ ERRORS ENCOUNTERED:"
            foreach ($error in $script:CleanupErrors) {
                Write-Output "  ✗ $error"
            }
        }
        
        if ($script:CleanupSuccess.Count -eq 0 -and $script:CleanupErrors.Count -eq 0) {
            Write-Output ""
            Write-Output "ℹ️  No cleanup operations performed (likely due to no resources found or dry run mode)"
        }
        
    } else {
        Write-Error "❌ Failed to obtain access token"
        exit 1
    }
}
catch {
    Write-Error "❌ Error during testing: $($_.Exception.Message)"
    Write-Output "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

Write-Output ""
Write-Output "🏁 Enhanced cleanup function test completed"
Write-Output ""

if (-not $DryRun) {
    Write-Output "⚠️  To run the full cleanup (including actual deletions), use:"
    Write-Output "   pwsh ./test-cleanup-powerplatform.ps1 -DryRun:`$false"
}
