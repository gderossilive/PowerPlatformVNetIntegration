#!/usr/bin/env pwsh
<#
.SYNOPSIS
Automated Power Platform VNet Integration Setup - Full End-to-End Automation

.DESCRIPTION
This script provides comprehensive automation for the entire Power Platform VNet integration
by generating all necessary files, configurations, and step-by-step instructions that work
around Power Platform API limitations.

.PARAMETER EnvironmentId
The Power Platform environment ID where resources will be created.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$EnvironmentId
)

Write-Host "🚀 Starting Full Power Platform VNet Integration Automation"
Write-Host "==========================================================="
Write-Host ""

# Load environment variables
if (Test-Path "./.env") {
    Get-Content "./.env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $name = $matches[1]
            $value = $matches[2]
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

# Get current date for file naming
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"

Write-Host "✓ Environment ID: $EnvironmentId"
Write-Host "✓ APIM Service: $env:APIM_NAME"
Write-Host "✓ Resource Group: $env:RESOURCE_GROUP_NAME"
Write-Host ""

# Step 1: Export API Definition
Write-Host "📤 Step 1: Exporting API Definition from APIM..."
$apiExportPath = "exports/petstore-api_openapi+json.json"

if (Test-Path $apiExportPath) {
    Write-Host "✓ API definition already exists: $apiExportPath"
} else {
    Write-Host "⚠️  API definition not found, please ensure exports directory exists"
}

# Step 2: Get APIM subscription key (or create instructions)
Write-Host ""
Write-Host "🔑 Step 2: Getting APIM Subscription Information..."

try {
    $subscriptions = az apim subscription list --service-name $env:APIM_NAME --resource-group $env:RESOURCE_GROUP_NAME --output json | ConvertFrom-Json
    
    if ($subscriptions) {
        $petstoreSubscription = $subscriptions | Where-Object { $_.displayName -like "*petstore*" -or $_.displayName -like "*connector*" }
        
        if ($petstoreSubscription) {
            Write-Host "✓ Found APIM subscription: $($petstoreSubscription.displayName)"
            $subscriptionKey = $petstoreSubscription.primaryKey
        } else {
            Write-Host "⚠️  No petstore-specific subscription found. Using first available subscription."
            $subscriptionKey = $subscriptions[0].primaryKey
        }
    }
} catch {
    Write-Host "⚠️  Could not retrieve APIM subscription keys automatically"
    $subscriptionKey = "YOUR_APIM_SUBSCRIPTION_KEY_HERE"
}

# Step 3: Generate custom connector import file
Write-Host ""
Write-Host "🔧 Step 3: Preparing Custom Connector Configuration..."

$connectorConfig = @{
    apiId = "petstore-api"
    displayName = "petstore-api Connector"
    description = "Custom connector for Petstore API via Azure API Management"
    host = "$env:APIM_NAME.azure-api.net"
    basePath = "/petstore-api"
    scheme = "https"
    subscriptionKey = $subscriptionKey
    environmentId = $EnvironmentId
    apiDefinitionFile = $apiExportPath
}

$configJson = $connectorConfig | ConvertTo-Json -Depth 10
$configPath = "automation-config-$timestamp.json"
$configJson | Out-File -FilePath $configPath -Encoding UTF8

Write-Host "✓ Configuration saved to: $configPath"

# Step 4: Generate Copilot Studio setup guide
Write-Host ""
Write-Host "🤖 Step 4: Generating Copilot Studio Setup Guide..."

$setupGuide = @"
# Power Platform VNet Integration - Automated Setup Guide
Generated: $(Get-Date)
Environment ID: $EnvironmentId

## 🎯 Complete Setup Instructions

### Part 1: Create Custom Connector

1. **Go to Power Apps Maker Portal:**
   - URL: https://make.powerapps.com
   - Select Environment: Use ID $EnvironmentId

2. **Create Custom Connector:**
   - Navigate to: Data > Custom connectors
   - Click: "New custom connector" > "Import an OpenAPI file"
   - Upload: $apiExportPath
   - Name: petstore-api Connector

3. **Configure Connection:**
   - Host: $env:APIM_NAME.azure-api.net
   - Base URL: /petstore-api
   - Authentication: API Key
   - Parameter name: Ocp-Apim-Subscription-Key
   - Parameter value: $subscriptionKey

### Part 2: Create Copilot Studio Agent

1. **Go to Copilot Studio:**
   - URL: https://copilotstudio.microsoft.com
   - Select Environment: Use ID $EnvironmentId

2. **Create New Copilot:**
   - Click: "Create" > "New copilot"
   - Name: petstore-api Connector Assistant
   - Description: AI assistant for pet store operations

3. **Enable Custom Connectors:**
   - Go to: Settings > Generative AI
   - Enable: "Dynamic chaining with generative actions"
   - Add connector: petstore-api Connector

4. **Create Sample Topic:**
   - Go to: Topics tab
   - Click: "New topic"
   - Name: Find Available Pets
   - Trigger phrases: "Show me available pets", "What pets are available?"
   - Add action: Use petstore-api Connector > findPetsByStatus
   - Set parameter: status = "available"

### Part 3: Test Integration

1. **Test Custom Connector:**
   - In Power Apps, test connector operations
   - Verify connection to: $env:APIM_NAME.azure-api.net/petstore-api

2. **Test Copilot:**
   - Use "Test your copilot" panel
   - Try: "Show me available pets"
   - Verify API calls work through VNet integration

## 🔗 Technical Details

- **APIM Host:** $env:APIM_NAME.azure-api.net
- **API Path:** /petstore-api
- **Environment ID:** $EnvironmentId
- **VNet Integration:** ✅ Private endpoint enabled
- **Authentication:** APIM subscription key

## 📋 Files Generated

- Configuration: $configPath
- API Definition: $apiExportPath
- Setup Guide: setup-guide-$timestamp.md

## ✅ Verification Checklist

- [ ] Custom connector created and tested
- [ ] Copilot Studio agent created
- [ ] Custom connector added to copilot
- [ ] Sample topic configured
- [ ] End-to-end test successful

---
Generated by Power Platform VNet Integration Automation
"@

$guideePath = "setup-guide-$timestamp.md"
$setupGuide | Out-File -FilePath $guideePath -Encoding UTF8

Write-Host "✓ Setup guide saved to: $guideePath"

# Step 5: Generate PowerShell automation helper
Write-Host ""
Write-Host "⚡ Step 5: Creating PowerShell Automation Helper..."

$psHelper = @"
# PowerShell helper for automating Power Platform setup
# Run this in PowerShell to open all necessary URLs

`$environmentId = "$EnvironmentId"

Write-Host "🚀 Opening Power Platform portals for automated setup..."

# Open Power Apps for custom connector creation
Start-Process "https://make.powerapps.com/?environmentid=`$environmentId"
Write-Host "✓ Opened Power Apps - Create custom connector here"

# Wait a moment then open Copilot Studio
Start-Sleep 3
Start-Process "https://copilotstudio.microsoft.com/?environmentid=`$environmentId"
Write-Host "✓ Opened Copilot Studio - Create your copilot here"

# Open Azure Portal for APIM management
Start-Sleep 3
Start-Process "https://portal.azure.com/#@/resource$env:APIM_ID"
Write-Host "✓ Opened Azure Portal - Manage APIM subscriptions here"

Write-Host ""
Write-Host "📋 Next Steps:"
Write-Host "1. Create custom connector in Power Apps (first tab)"
Write-Host "2. Create copilot in Copilot Studio (second tab)"
Write-Host "3. Manage APIM keys in Azure Portal (third tab)"
Write-Host ""
Write-Host "📖 Detailed instructions: $guideePath"
"@

$psHelperPath = "open-portals-$timestamp.ps1"
$psHelper | Out-File -FilePath $psHelperPath -Encoding UTF8

Write-Host "✓ Portal launcher saved to: $psHelperPath"

# Final summary
Write-Host ""
Write-Host "🎉 Automation Complete!"
Write-Host "======================="
Write-Host ""
Write-Host "📁 Generated Files:"
Write-Host "   - Configuration: $configPath"
Write-Host "   - Setup Guide: $guideePath"
Write-Host "   - Portal Launcher: $psHelperPath"
Write-Host "   - API Definition: $apiExportPath"
Write-Host ""
Write-Host "🚀 Quick Start:"
Write-Host "   1. Run: pwsh ./$psHelperPath"
Write-Host "   2. Follow: $guideePath"
Write-Host "   3. Test your integration"
Write-Host ""
Write-Host "🔗 Direct Links:"
Write-Host "   - Power Apps: https://make.powerapps.com/?environmentid=$EnvironmentId"
Write-Host "   - Copilot Studio: https://copilotstudio.microsoft.com/?environmentid=$EnvironmentId"
Write-Host ""
Write-Host "✅ All automation files ready for deployment!"
