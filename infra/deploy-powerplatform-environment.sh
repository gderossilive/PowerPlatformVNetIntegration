#!/bin/bash

# Power Platform Environment Deployment Script
# This script creates a Power Platform environment with Dataverse using REST API

set -e

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Required variables
: ${POWER_PLATFORM_ENVIRONMENT_NAME:?"POWER_PLATFORM_ENVIRONMENT_NAME environment variable is required"}
: ${POWER_PLATFORM_LOCATION:?"POWER_PLATFORM_LOCATION environment variable is required"}
: ${AZURE_LOCATION:?"AZURE_LOCATION environment variable is required"}

# Optional variables with defaults
ENVIRONMENT_TYPE="${ENVIRONMENT_TYPE:-Sandbox}"
ENVIRONMENT_DESCRIPTION="${ENVIRONMENT_DESCRIPTION:-Power Platform environment for VNet integration with Azure API Management}"
ENVIRONMENT_LANGUAGE="${ENVIRONMENT_LANGUAGE:-1033}"
ENVIRONMENT_CURRENCY="${ENVIRONMENT_CURRENCY:-USD}"
ENABLE_DATAVERSE="${ENABLE_DATAVERSE:-true}"

echo "🚀 Creating Power Platform Environment with Dataverse"
echo "=================================================="
echo "Environment Name: $POWER_PLATFORM_ENVIRONMENT_NAME"
echo "Location: $POWER_PLATFORM_LOCATION"
echo "Type: $ENVIRONMENT_TYPE"
echo "Enable Dataverse: $ENABLE_DATAVERSE"
echo ""

# Check Azure CLI authentication
echo "Checking Azure CLI authentication..."
ACCOUNT=$(az account show --output json 2>/dev/null || echo "null")
if [ "$ACCOUNT" == "null" ]; then
    echo "❌ Please login to Azure CLI first: az login"
    exit 1
fi

USER_NAME=$(echo $ACCOUNT | jq -r '.user.name')
echo "✓ Authenticated as: $USER_NAME"

# Get access token for Power Platform
echo "Getting Power Platform access token..."
ACCESS_TOKEN=$(az account get-access-token --resource https://service.powerapps.com/ --query accessToken --output tsv)
if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get Power Platform access token"
    exit 1
fi
echo "✓ Access token obtained"

# Check if environment already exists
echo "Checking if environment already exists..."
UNIQUE_NAME=$(echo "$POWER_PLATFORM_ENVIRONMENT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
EXISTING_ENV=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01" | \
    jq -r ".value[] | select(.properties.displayName == \"$POWER_PLATFORM_ENVIRONMENT_NAME\") | .name" 2>/dev/null || echo "")

if [ ! -z "$EXISTING_ENV" ]; then
    echo "⚠️  Environment already exists with ID: $EXISTING_ENV"
    echo "Checking if it has Dataverse..."
    
    ENV_DETAILS=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
        "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EXISTING_ENV?api-version=2023-06-01")
    
    HAS_DATAVERSE=$(echo $ENV_DETAILS | jq -r '.properties.linkedEnvironmentMetadata != null')
    
    if [ "$HAS_DATAVERSE" == "true" ]; then
        echo "✓ Environment already has Dataverse enabled"
        ENV_ID="$EXISTING_ENV"
        ENV_URL=$(echo $ENV_DETAILS | jq -r '.properties.webApplicationUrl')
        DATAVERSE_URL=$(echo $ENV_DETAILS | jq -r '.properties.linkedEnvironmentMetadata.instanceUrl // ""')
        DATAVERSE_UNIQUE_NAME=$(echo $ENV_DETAILS | jq -r '.properties.linkedEnvironmentMetadata.uniqueName // ""')
    else
        echo "❌ Existing environment does not have Dataverse. Please delete it first or use a different name."
        exit 1
    fi
else
    echo "Creating new environment..."
    
    # Create shorter domain name - max 32 characters
    SHORT_NAME="e2etest$(date +%m%d%H%M)"
    DOMAIN_NAME="${SHORT_NAME}$(echo $RANDOM | md5sum | head -c 4)"
    
    PAYLOAD=$(cat <<EOF
{
    "location": "$POWER_PLATFORM_LOCATION",
    "properties": {
        "displayName": "$POWER_PLATFORM_ENVIRONMENT_NAME",
        "description": "$ENVIRONMENT_DESCRIPTION",
        "environmentSku": "$ENVIRONMENT_TYPE",
        "azureRegion": "$AZURE_LOCATION"
EOF
)

    if [ "$ENABLE_DATAVERSE" == "true" ]; then
        PAYLOAD="$PAYLOAD,
        \"linkedEnvironmentMetadata\": {
            \"type\": \"Dynamics365Instance\",
            \"resourceId\": \"placeholder\",
            \"friendlyName\": \"$POWER_PLATFORM_ENVIRONMENT_NAME\",
            \"uniqueName\": \"$SHORT_NAME\",
            \"domainName\": \"$DOMAIN_NAME\",
            \"version\": \"9.2\",
            \"currency\": {
                \"code\": \"$ENVIRONMENT_CURRENCY\"
            }"
        
        if [ ! -z "$SECURITY_GROUP_ID" ]; then
            PAYLOAD="$PAYLOAD,
            \"securityGroupId\": \"$SECURITY_GROUP_ID\""
        fi
        
        PAYLOAD="$PAYLOAD
        }"
    fi

    PAYLOAD="$PAYLOAD
    }
}"

    echo "Submitting environment creation request..."
    RESPONSE=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01")
    
    HTTP_CODE="${RESPONSE: -3}"
    RESPONSE_BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        ENV_ID=$(echo $RESPONSE_BODY | jq -r '.name')
        echo "✓ Environment creation initiated successfully"
        echo "Environment ID: $ENV_ID"
        
        # Wait for provisioning to complete
        echo "Waiting for environment provisioning to complete..."
        TIMEOUT=1800  # 30 minutes
        ELAPSED=0
        POLL_INTERVAL=30
        
        while [ $ELAPSED -lt $TIMEOUT ]; do
            sleep $POLL_INTERVAL
            ELAPSED=$((ELAPSED + POLL_INTERVAL))
            
            ENV_STATUS=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
                "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$ENV_ID?api-version=2023-06-01" | \
                jq -r '.properties.provisioningState // "Unknown"')
            
            echo "Current status: $ENV_STATUS (Elapsed: ${ELAPSED}s)"
            
            case "$ENV_STATUS" in
                "Succeeded")
                    echo "✓ Environment provisioning completed successfully"
                    break
                    ;;
                "Failed")
                    echo "❌ Environment provisioning failed"
                    exit 1
                    ;;
                "Canceled")
                    echo "❌ Environment provisioning was canceled"
                    exit 1
                    ;;
                *)
                    if [ $ELAPSED -ge $TIMEOUT ]; then
                        echo "❌ Environment provisioning timeout"
                        exit 1
                    fi
                    ;;
            esac
        done
        
        # Get final environment details
        ENV_DETAILS=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
            "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$ENV_ID?api-version=2023-06-01")
        
        ENV_URL=$(echo $ENV_DETAILS | jq -r '.properties.webApplicationUrl')
        
        if [ "$ENABLE_DATAVERSE" == "true" ]; then
            DATAVERSE_URL=$(echo $ENV_DETAILS | jq -r '.properties.linkedEnvironmentMetadata.instanceUrl // ""')
            DATAVERSE_UNIQUE_NAME=$(echo $ENV_DETAILS | jq -r '.properties.linkedEnvironmentMetadata.uniqueName // ""')
        fi
    else
        echo "❌ Environment creation failed (HTTP $HTTP_CODE)"
        echo "Response: $RESPONSE_BODY"
        exit 1
    fi
fi

# Update .env file with environment details
echo "Updating .env file with environment details..."

# Create backup
cp .env .env.backup.$(date +%Y%m%d-%H%M%S)

# Update or add environment variables
update_env_var() {
    local key=$1
    local value=$2
    
    if grep -q "^$key=" .env; then
        # Update existing variable
        sed -i "s|^$key=.*|$key=$value|" .env
    else
        # Add new variable
        echo "$key=$value" >> .env
    fi
}

update_env_var "POWER_PLATFORM_ENVIRONMENT_ID" "$ENV_ID"
update_env_var "POWER_PLATFORM_ENVIRONMENT_URL" "$ENV_URL"

if [ "$ENABLE_DATAVERSE" == "true" ] && [ ! -z "$DATAVERSE_URL" ]; then
    update_env_var "DATAVERSE_INSTANCE_URL" "$DATAVERSE_URL"
    update_env_var "DATAVERSE_UNIQUE_NAME" "$DATAVERSE_UNIQUE_NAME"
fi

echo ""
echo "🎉 Power Platform Environment Ready!"
echo "=================================="
echo "Environment ID: $ENV_ID"
echo "Environment URL: $ENV_URL"
if [ "$ENABLE_DATAVERSE" == "true" ] && [ ! -z "$DATAVERSE_URL" ]; then
    echo "Dataverse URL: $DATAVERSE_URL"
    echo "Dataverse Unique Name: $DATAVERSE_UNIQUE_NAME"
fi
echo ""
echo "✓ Environment details saved to .env file"
echo "✓ Ready for Copilot Studio and custom connector integration"
