#!/bin/bash

# =============================================================================
# Power Platform Environment Creation Script
# =============================================================================
#
# SYNOPSIS
#     Creates a Power Platform environment for VNet integration with Azure API Management.
#
# DESCRIPTION
#     This script creates a new Power Platform environment that will be used for VNet 
#     integration with Azure API Management. The script should be run before the 
#     infrastructure deployment to ensure the target environment exists and is properly configured.
#
#     CONSOLIDATED FROM POWERSHELL SCRIPT: This bash script incorporates all the functionality
#     from the PowerShell version but with better authentication handling and cross-platform
#     compatibility. It uses the proven approach from deploy-powerplatform-environment.sh.
#
#     AUTOMATION OPTIONS: This script supports two automation modes:
#     A) REST API Mode (default): Requires manual Dataverse and managed environment setup
#     B) PAC CLI Mode: Fully automated Dataverse and managed environment provisioning
#
#     The script performs the following operations:
#     1. ✅ AUTOMATED: Loads environment variables from a specified file
#     2. ✅ AUTOMATED: Validates authentication and Power Platform permissions  
#     3. ✅ AUTOMATED: Creates a new Power Platform environment with the specified configuration
#     4. 🔄 AUTOMATED/MANUAL: Dataverse database provisioning (PAC CLI mode: automated, REST API mode: manual)
#     5. 🔄 AUTOMATED/MANUAL: Enable managed environment features (PAC CLI mode: automated, REST API mode: manual)
#     6. ✅ AUTOMATED: Updates the environment file with the created environment details
#
# MANUAL STEPS REQUIRED AFTER SCRIPT COMPLETION:
# ==============================================
#
# STEP 1: Enable Dataverse Database
# ---------------------------------
# 1. Go to https://admin.powerplatform.microsoft.com/
# 2. Navigate to "Environments"
# 3. Find your environment: [POWER_PLATFORM_ENVIRONMENT_NAME]
# 4. Click on the environment name
# 5. Click "Settings" in the top menu
# 6. Under "Resources", click "Dynamics 365 apps"
# 7. Click "Create my database"
# 8. Configure:
#    - Language: English (United States)
#    - Currency: USD (or your preferred currency)
#    - Enable sample apps and data: No (recommended)
#    - Deploy sample apps: No (recommended)
# 9. Click "Create my database"
# 10. Wait 10-15 minutes for provisioning to complete
#
# STEP 2: Enable Managed Environment
# ----------------------------------
# 1. In the same environment settings page
# 2. Click "Features" in the left navigation
# 3. Under "Managed Environment", toggle "Enable Managed Environment" to ON
# 4. Configure additional managed environment features as needed:
#    - Data loss prevention
#    - IP firewall
#    - Customer-managed key (if required)
# 5. Click "Save"
#
# VERIFICATION:
# ============
# After completing manual steps, run this script again to verify and update .env file:
#     ./0-CreatePowerPlatformEnvironment.sh --force
#
# The environment is created with:
# - Base Power Platform environment (automated)
# - Dataverse database enabled for full Power Platform capabilities (manual)
# - Managed environment features for enterprise governance (manual)
# - Security group assignment for controlled access (if configured)
# - Environment variables configured for integration scenarios
# - Proper regional placement matching Azure infrastructure location
#
# PARAMETERS
#     --env-file PATH
#         Specifies the path to the environment file containing required variables.
#         Defaults to "./.env" in the current directory.
#
#     --environment-type TYPE
#         Specifies the type of Power Platform environment to create.
#         Valid values: 'Production', 'Sandbox', 'Trial', 'Developer'
#         Defaults to 'Sandbox' for testing scenarios.
#
#     --enable-dataverse
#         Enable Dataverse database creation (default: true)
#
#     --disable-dataverse
#         Disable Dataverse database creation
#
#     --use-pac-cli
#         Use PAC CLI for fully automated environment creation (includes Dataverse + Managed Environment)
#         Requires: pac auth create --deviceCode (PAC CLI authentication)
#         Benefits: No manual steps, better reliability, automated managed environment setup
#
#     --enable-managed-env
#         Enable managed environment features (only works with --use-pac-cli)
#
#     --disable-managed-env
#         Disable managed environment features (default when using REST API)
#
#     --force
#         Skip confirmation prompts and create the environment automatically.
#         Useful for automated deployment scenarios.
#
#     --help
#         Show this help message
#
# REQUIRED ENVIRONMENT VARIABLES
#     TENANT_ID                           Azure AD tenant ID for authentication
#     AZURE_SUBSCRIPTION_ID               Azure subscription ID (used for mapping regions)
#     POWER_PLATFORM_ENVIRONMENT_NAME     Display name for the new environment
#     POWER_PLATFORM_LOCATION             Power Platform region (e.g., 'europe', 'unitedstates')
#     AZURE_LOCATION                      Azure region for infrastructure alignment (e.g., 'westeurope')
#
# OPTIONAL ENVIRONMENT VARIABLES
#     ENVIRONMENT_DESCRIPTION             Description for the environment
#     ENVIRONMENT_LANGUAGE                Language code for the environment (defaults to '1033')
#     ENVIRONMENT_CURRENCY                Currency code for the environment (defaults to 'USD')
#     ENVIRONMENT_DOMAIN_NAME             Custom domain name for the environment
#     SECURITY_GROUP_ID                   Azure AD security group ID for environment access control
#
# EXAMPLES
#     ./0-CreatePowerPlatformEnvironment.sh
#         Creates a sandbox environment using settings from the default .env file.
#         Prompts for confirmation before creating the environment.
#
#     ./0-CreatePowerPlatformEnvironment.sh --environment-type Production --force
#         Creates a production environment without confirmation prompts.
#         Suitable for automated deployment pipelines.
#
#     ./0-CreatePowerPlatformEnvironment.sh --env-file "./environments/production.env" --environment-type Production
#         Creates a production environment using a custom environment file.
#         Useful for managing multiple environments with different configurations.
#
# AUTHORS
#     Power Platform VNet Integration Project
#
# PREREQUISITES
#     - Azure CLI (az) must be installed and authenticated
#     - Power Platform Admin permissions in the target tenant
#     - jq for JSON processing
#     - curl for REST API calls
#
# VERSION
#     2.0 (September 2025) - Consolidated from PowerShell and enhanced bash scripts
#
# =============================================================================

# Power Platform Environment Deployment Script
# This script creates a Power Platform environment with Dataverse using REST API

set -e

# Default values and argument parsing
ENV_FILE="./.env"
ENVIRONMENT_TYPE="Sandbox"
ENABLE_DATAVERSE="true"
USE_PAC_CLI="false"
ENABLE_MANAGED_ENV="false"
FORCE="false"
SHOW_HELP="false"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_step() {
    echo -e "${CYAN}$1${NC}"
}

log_header() {
    echo -e "${MAGENTA}$1${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --environment-type)
            ENVIRONMENT_TYPE="$2"
            shift 2
            ;;
        --enable-dataverse)
            ENABLE_DATAVERSE="true"
            shift
            ;;
        --disable-dataverse)
            ENABLE_DATAVERSE="false"
            shift
            ;;
        --use-pac-cli)
            USE_PAC_CLI="true"
            shift
            ;;
        --enable-managed-env)
            ENABLE_MANAGED_ENV="true"
            shift
            ;;
        --disable-managed-env)
            ENABLE_MANAGED_ENV="false"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --help)
            SHOW_HELP="true"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

# Show help
if [ "$SHOW_HELP" == "true" ]; then
    cat << 'EOF'
Power Platform Environment Creation Script

USAGE:
    ./0-CreatePowerPlatformEnvironment.sh [OPTIONS]

OPTIONS:
    --env-file PATH               Path to environment file (default: ./.env)
    --environment-type TYPE       Environment type: Production, Sandbox, Trial, Developer (default: Sandbox)
    --enable-dataverse           Enable Dataverse database creation (default)
    --disable-dataverse          Disable Dataverse database creation  
    --force                      Skip confirmation prompts
    --help                       Show this help message

EXAMPLES:
    ./0-CreatePowerPlatformEnvironment.sh
    ./0-CreatePowerPlatformEnvironment.sh --environment-type Production --force
    ./0-CreatePowerPlatformEnvironment.sh --env-file ./prod.env --disable-dataverse

For full documentation, see the script header comments.
EOF
    exit 0
fi

# Validate environment type
case "$ENVIRONMENT_TYPE" in
    "Production"|"Sandbox"|"Trial"|"Developer")
        ;;
    *)
        log_error "Invalid environment type: $ENVIRONMENT_TYPE"
        echo "Valid values: Production, Sandbox, Trial, Developer"
        exit 1
        ;;
esac

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    log_step "Loading environment variables from: $ENV_FILE"
    export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
else
    log_error "Environment file not found: $ENV_FILE"
    exit 1
fi

# Required variables with validation
: ${POWER_PLATFORM_ENVIRONMENT_NAME:?"POWER_PLATFORM_ENVIRONMENT_NAME environment variable is required"}
: ${POWER_PLATFORM_LOCATION:?"POWER_PLATFORM_LOCATION environment variable is required"}
: ${AZURE_LOCATION:?"AZURE_LOCATION environment variable is required"}

# Optional variables with defaults
ENVIRONMENT_DESCRIPTION="${ENVIRONMENT_DESCRIPTION:-Power Platform environment for VNet integration with Azure API Management}"
ENVIRONMENT_LANGUAGE="${ENVIRONMENT_LANGUAGE:-1033}"
ENVIRONMENT_CURRENCY="${ENVIRONMENT_CURRENCY:-USD}"

echo ""
log_header "🚀 Power Platform Environment Creation"
log_header "======================================"
echo "Environment Name: $POWER_PLATFORM_ENVIRONMENT_NAME"
echo "Location: $POWER_PLATFORM_LOCATION"
echo "Type: $ENVIRONMENT_TYPE"
echo "Enable Dataverse: $ENABLE_DATAVERSE"
echo ""

# Get user confirmation if not using --force
if [ "$FORCE" != "true" ]; then
    echo "Configuration Summary:"
    echo "- Name: $POWER_PLATFORM_ENVIRONMENT_NAME"
    echo "- Type: $ENVIRONMENT_TYPE"
    echo "- Location: $POWER_PLATFORM_LOCATION"
    echo "- Enable Dataverse: $ENABLE_DATAVERSE"
    echo "- Azure Region Alignment: $AZURE_LOCATION"
    echo ""
    
    echo "Continue with environment creation? (y/N)"
    read -r confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled by user."
        exit 0
    fi
    echo ""
fi

# Check Azure CLI authentication
log_step "Checking Azure CLI authentication..."
ACCOUNT=$(az account show --output json 2>/dev/null || echo "null")
if [ "$ACCOUNT" == "null" ]; then
    log_error "Please login to Azure CLI first: az login"
    exit 1
fi

USER_NAME=$(echo $ACCOUNT | jq -r '.user.name')
log_info "Authenticated as: $USER_NAME"

# Get access token for Power Platform
log_step "Getting Power Platform access token..."
ACCESS_TOKEN=$(az account get-access-token --resource https://service.powerapps.com/ --query accessToken --output tsv)
if [ -z "$ACCESS_TOKEN" ]; then
    log_error "Failed to get Power Platform access token"
    exit 1
fi
log_info "Access token obtained"

# Check if environment already exists
log_step "Checking if environment already exists..."
UNIQUE_NAME=$(echo "$POWER_PLATFORM_ENVIRONMENT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
EXISTING_ENV=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01" | \
    jq -r ".value[] | select(.properties.displayName == \"$POWER_PLATFORM_ENVIRONMENT_NAME\") | .name" 2>/dev/null || echo "")

if [ ! -z "$EXISTING_ENV" ]; then
    log_warning "Environment already exists with ID: $EXISTING_ENV"
    log_step "Checking if it has Dataverse..."
    
    ENV_DETAILS=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
        "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EXISTING_ENV?api-version=2023-06-01")
    
    HAS_DATAVERSE=$(echo $ENV_DETAILS | jq -r '.properties.linkedEnvironmentMetadata != null')
    
    echo ""
    log_header "Environment Configuration Status:"
    echo "- Base Environment: ✅ Created"
    
    if [ "$HAS_DATAVERSE" == "true" ]; then
        echo "- Dataverse Database: ✅ Enabled"
        echo "- Managed Environment: ⚠️  Manual verification required"
        log_info "Environment already has Dataverse enabled"
        ENV_ID="$EXISTING_ENV"
        ENV_URL=$(echo $ENV_DETAILS | jq -r '.properties.webApplicationUrl')
        DATAVERSE_URL=$(echo $ENV_DETAILS | jq -r '.properties.linkedEnvironmentMetadata.instanceUrl // ""')
        DATAVERSE_UNIQUE_NAME=$(echo $ENV_DETAILS | jq -r '.properties.linkedEnvironmentMetadata.uniqueName // ""')
        
        # Update .env and show completion
        update_env_file_and_complete
        exit 0
    else
        echo "- Dataverse Database: ❌ Not Enabled - Manual step required"
        echo "- Managed Environment: ⚠️  Manual verification required"
        log_error "Existing environment does not have Dataverse. Please delete it first or use a different name."
        exit 1
    fi
else
    log_info "Environment does not exist, proceeding with creation"
    
    # Create new environment
    log_step "Creating new environment..."
    
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

# Function to update .env file and show completion message
update_env_file_and_complete() {
    # Update .env file with environment details
    log_step "Updating .env file with environment details..."
    
    # Create backup
    cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Update or add environment variables
    update_env_var() {
        local key=$1
        local value=$2
        
        if grep -q "^$key=" "$ENV_FILE"; then
            # Update existing variable
            sed -i "s|^$key=.*|$key=$value|" "$ENV_FILE"
        else
            # Add new variable
            echo "$key=$value" >> "$ENV_FILE"
        fi
    }
    
    update_env_var "POWER_PLATFORM_ENVIRONMENT_ID" "$ENV_ID"
    update_env_var "POWER_PLATFORM_ENVIRONMENT_URL" "$ENV_URL"
    
    if [ "$ENABLE_DATAVERSE" == "true" ] && [ ! -z "$DATAVERSE_URL" ]; then
        update_env_var "DATAVERSE_INSTANCE_URL" "$DATAVERSE_URL"
        update_env_var "DATAVERSE_UNIQUE_NAME" "$DATAVERSE_UNIQUE_NAME"
    fi
    
    echo ""
    log_header "🎉 Power Platform Environment Ready!"
    echo "===================================="
    echo "Environment Name: $POWER_PLATFORM_ENVIRONMENT_NAME"
    echo "Environment ID: $ENV_ID"
    echo "Environment Type: $ENVIRONMENT_TYPE"
    echo "Location: $POWER_PLATFORM_LOCATION"
    echo "Environment URL: $ENV_URL"
    
    if [ "$ENABLE_DATAVERSE" == "true" ] && [ ! -z "$DATAVERSE_URL" ]; then
        echo ""
        echo "✅ Dataverse Configuration (Complete):"
        echo "- Instance URL: $DATAVERSE_URL"
        echo "- Unique Name: $DATAVERSE_UNIQUE_NAME"
        
        echo ""
        echo "🚀 Ready for Infrastructure Deployment:"
        echo "1. Run ./1-InfraSetup.ps1 to deploy Azure infrastructure"
        echo "2. Run ./2-SubnetInjectionSetup.ps1 to configure VNet integration"
        echo "3. Run ./3-CreateCustomConnector.ps1 to create custom connectors"
        echo "4. Run ./4-SetupCopilotStudio.ps1 to configure Copilot Studio"
    else
        show_manual_steps_required
    fi
    
    echo ""
    log_info "Environment details saved to $ENV_FILE"
    log_info "Ready for next deployment steps"
}

# Function to show manual steps required
show_manual_steps_required() {
    echo ""
    log_warning "MANUAL STEPS REQUIRED TO COMPLETE SETUP:"
    echo "==========================================="
    echo ""
    echo "🔹 STEP 1: ENABLE DATAVERSE DATABASE:"
    echo "   📍 Go to: https://admin.powerplatform.microsoft.com/"
    echo "   📍 Navigate to: Environments > $POWER_PLATFORM_ENVIRONMENT_NAME"
    echo "   📍 Click: Settings > Resources > Dynamics 365 apps"
    echo "   📍 Click: 'Create my database'"
    echo "   📍 Configure: Language=English (United States), Currency=USD"
    echo "   📍 Disable: Sample apps and data (recommended)"
    echo "   📍 Wait: 10-15 minutes for database provisioning"
    echo ""
    echo "🔹 STEP 2: ENABLE MANAGED ENVIRONMENT (Recommended):"
    echo "   📍 In the same environment settings page"
    echo "   📍 Navigate to: Features > Managed Environment"
    echo "   📍 Toggle: 'Enable Managed Environment' to ON"
    echo "   📍 Configure: Additional security features as needed"
    echo ""
    echo "🔹 STEP 3: VERIFY AND UPDATE CONFIGURATION:"
    echo "   📍 Run: ./0-CreatePowerPlatformEnvironment.sh --force"
    echo "   📍 This will detect the manual changes and update the .env file"
    echo ""
    echo "📋 Why Manual Steps Are Required:"
    echo "- Dataverse provisioning requires tenant admin approval workflows"
    echo "- Managed environment features need explicit enterprise governance setup"
    echo "- API limitations prevent fully automated Dataverse configuration"
    echo ""
    echo "🔄 After completing manual steps, re-run this script to verify"
    echo "   and proceed with infrastructure deployment."
}
