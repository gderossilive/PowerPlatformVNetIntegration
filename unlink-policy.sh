#!/bin/bash

# Unlink Enterprise Policy using Azure CLI REST API calls
# This script must be run before cleaning up Azure resources

set -e

# Load environment variables from .env file
if [ -f ".env" ]; then
    source .env
    echo "Environment variables loaded from .env file"
else
    echo "Error: .env file not found"
    exit 1
fi

# Check required variables
if [ -z "$POWER_PLATFORM_ENVIRONMENT_ID" ] || [ -z "$AZURE_SUBSCRIPTION_ID" ] || [ -z "$RESOURCE_GROUP" ] || [ -z "$ENTERPRISE_POLICY_NAME" ]; then
    echo "Error: Required environment variables are missing"
    echo "Required: POWER_PLATFORM_ENVIRONMENT_ID, AZURE_SUBSCRIPTION_ID, RESOURCE_GROUP, ENTERPRISE_POLICY_NAME"
    exit 1
fi

# Construct the policy ARM ID
POLICY_ARM_ID="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies/$ENTERPRISE_POLICY_NAME"

echo "Starting policy unlinking process..."
echo "Environment ID: $POWER_PLATFORM_ENVIRONMENT_ID"
echo "Policy ARM ID: $POLICY_ARM_ID"

# Check if the environment exists and has the policy linked
echo "Checking current environment policy status..."

# Use Power Platform API to check environment
PP_API_URL="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$POWER_PLATFORM_ENVIRONMENT_ID"

echo "Querying environment details..."
ENV_RESPONSE=$(az rest --method get --url "$PP_API_URL?api-version=2023-06-01" --resource "https://api.bap.microsoft.com/" 2>/dev/null || echo "ERROR")

if [ "$ENV_RESPONSE" = "ERROR" ]; then
    echo "Warning: Could not retrieve environment details. This might be due to permissions or the environment may not exist."
    echo "Proceeding with unlinking attempt..."
else
    echo "Environment found. Checking for linked policies..."
fi

# Attempt to unlink the policy
echo "Attempting to unlink VNet policy from environment..."

# Construct the unlink request body
UNLINK_BODY=$(cat <<EOF
{
    "properties": {
        "enterprisePolicies": {
            "vNets": null
        }
    }
}
EOF
)

# Attempt to unlink using PATCH request
echo "Sending unlink request..."
UNLINK_RESPONSE=$(az rest --method patch --url "$PP_API_URL?api-version=2023-06-01" --resource "https://api.bap.microsoft.com/" --body "$UNLINK_BODY" 2>/dev/null || echo "ERROR")

if [ "$UNLINK_RESPONSE" = "ERROR" ]; then
    echo "Warning: Could not unlink policy using API. This might be due to:"
    echo "1. Insufficient permissions"
    echo "2. Policy is not linked"
    echo "3. Environment does not exist"
    echo ""
    echo "Please manually unlink the policy in Power Platform Admin Center:"
    echo "1. Go to https://admin.powerplatform.microsoft.com/"
    echo "2. Navigate to Environments"
    echo "3. Select your environment: $POWER_PLATFORM_ENVIRONMENT_NAME"
    echo "4. Go to Settings > Network settings"
    echo "5. Remove any VNet integration"
    echo ""
    echo "Proceeding with Azure resource cleanup..."
else
    echo "Policy unlinking request submitted successfully."
    echo "The unlinking operation may take a few minutes to complete."
    echo ""
    echo "You can now proceed with Azure resource cleanup."
fi

echo "Policy unlinking script completed."
