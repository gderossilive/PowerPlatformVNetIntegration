#!/bin/bash

# Power Platform VNet Integration - Example with Environment ID
# This script demonstrates how to run the updated scripts with a real environment ID

echo "🎯 Power Platform VNet Integration with Environment ID"
echo "======================================================"
echo ""
echo "STEP 1: Get Your Environment ID"
echo "--------------------------------"
echo "1. Go to: https://admin.powerplatform.microsoft.com/"
echo "2. Click 'Environments' in the left navigation"
echo "3. Find your environment (e.g., 'Woodgrove-Prod')"
echo "4. Click on the environment name"
echo "5. Copy the Environment ID (GUID format like: 12345678-1234-1234-1234-123456789abc)"
echo ""
echo "STEP 2: Set Your Environment ID"
echo "--------------------------------"
echo "Replace 'YOUR_ENVIRONMENT_ID_HERE' with your actual environment ID in the commands below:"
echo ""

# Example environment ID (user needs to replace this)
ENVIRONMENT_ID="YOUR_ENVIRONMENT_ID_HERE"

echo "STEP 3: Run Custom Connector Script"
echo "-----------------------------------"
echo "pwsh ./3-CreateCustomConnector.ps1 -EnvironmentId \"$ENVIRONMENT_ID\" -Force"
echo ""

echo "STEP 4: Run Copilot Studio Script"
echo "---------------------------------"
echo "pwsh ./4-SetupCopilotStudio.ps1 -EnvironmentId \"$ENVIRONMENT_ID\" -Force"
echo ""

echo "EXAMPLE WITH REAL ENVIRONMENT ID:"
echo "=================================="
echo "# If your environment ID is: 12345678-1234-1234-1234-123456789abc"
echo "pwsh ./3-CreateCustomConnector.ps1 -EnvironmentId \"12345678-1234-1234-1234-123456789abc\" -Force"
echo "pwsh ./4-SetupCopilotStudio.ps1 -EnvironmentId \"12345678-1234-1234-1234-123456789abc\" -Force"
echo ""

echo "📋 Notes:"
echo "========="
echo "- Without the -EnvironmentId parameter, scripts will export definitions for manual setup"
echo "- With the -EnvironmentId parameter, scripts will attempt automated Power Platform API calls"
echo "- If API calls fail due to permissions, manual setup instructions will be provided"
echo "- Both approaches will work - automated is more convenient when permissions allow"
