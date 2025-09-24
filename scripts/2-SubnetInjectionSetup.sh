#!/bin/bash

# =============================================================================
# Power Platform Subnet Injection Setup Script (Bash Version)
# =============================================================================
#
# SYNOPSIS
#     Links an Azure enterprise policy to a Power Platform environment for VNet subnet injection.
#
# DESCRIPTION
#     This script connects a Power Platform environment to an Azure enterprise policy that enables 
#     VNet subnet injection. It performs the following operations:
#
#     1. Loads environment variables from .env file
#     2. Validates Azure CLI authentication and subscription context
#     3. Retrieves enterprise policy details from Azure Resource Manager
#     4. Obtains Power Platform Admin API access token
#     5. Links the enterprise policy to the specified Power Platform environment
#     6. Monitors the linking operation until completion
#
#     The script enables Power Platform environments to use Azure Virtual Network subnet injection,
#     allowing Dataverse and other services to run within your Azure network infrastructure for
#     enhanced security and connectivity options.

set -euo pipefail  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🔗 Power Platform Subnet Injection Setup"
echo "========================================"

# Step 1: Load environment variables from .env file
log_info "Loading environment configuration..."

if [[ -f "./.env" ]]; then
    log_info "Loading environment variables from .env file..."
    # Export variables from .env file, handling potential Windows line endings
    set -a  # Automatically export all variables
    source <(sed 's/\r$//' ./.env)
    set +a  # Stop automatically exporting
    log_success "Environment variables loaded successfully."
else
    log_error ".env file not found. Please run the infrastructure setup script first."
    exit 1
fi

# Validate required environment variables
required_vars=("TENANT_ID" "AZURE_SUBSCRIPTION_ID" "RESOURCE_GROUP" "ENTERPRISE_POLICY_NAME" "POWER_PLATFORM_ENVIRONMENT_NAME" "POWER_PLATFORM_ENVIRONMENT_ID")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    log_error "Missing required environment variables: ${missing_vars[*]}"
    log_error "Please ensure the infrastructure setup and Power Platform environment creation completed successfully."
    exit 1
fi

log_info "Required environment variables validated successfully."

# Step 2: Azure CLI Authentication and Subscription Context
log_info "Validating Azure CLI authentication..."

# Check if logged in to correct tenant
current_account=$(az account show --query "tenantId" -o tsv 2>/dev/null || echo "")

if [[ "$current_account" != "$TENANT_ID" ]]; then
    log_error "Not logged into the correct Azure tenant. Expected: $TENANT_ID, Current: $current_account"
    log_error "Please run: az login --tenant $TENANT_ID"
    exit 1
fi

# Set the active subscription
log_info "Setting Azure subscription: $AZURE_SUBSCRIPTION_ID"
if ! az account set --subscription "$AZURE_SUBSCRIPTION_ID"; then
    log_error "Failed to set Azure subscription. Please verify the subscription ID and your access."
    exit 1
fi

log_success "Azure CLI configured successfully."

# Step 3: Retrieve Enterprise Policy Details
log_info "Retrieving enterprise policy details..."

enterprise_policy_id="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies/$ENTERPRISE_POLICY_NAME"

log_info "Enterprise Policy ID: $enterprise_policy_id"

# Verify enterprise policy exists and get SystemId
enterprise_policy_details=$(az resource show --name "$ENTERPRISE_POLICY_NAME" --resource-group "$RESOURCE_GROUP" --resource-type "Microsoft.PowerPlatform/enterprisePolicies" --output json 2>/dev/null)

if [[ -z "$enterprise_policy_details" ]]; then
    log_error "Enterprise policy not found: $ENTERPRISE_POLICY_NAME"
    log_error "Please verify the enterprise policy exists in resource group: $RESOURCE_GROUP"
    exit 1
fi

# Extract SystemId from enterprise policy
system_id=$(echo "$enterprise_policy_details" | jq -r '.properties.systemId // empty')

if [[ -z "$system_id" ]]; then
    log_error "Failed to retrieve SystemId from enterprise policy"
    exit 1
fi

log_success "Enterprise policy found: $ENTERPRISE_POLICY_NAME"
log_info "System ID: $system_id"

# Step 4: Get Power Platform Admin API Access Token
log_info "Obtaining Power Platform Admin API access token..."

access_token=$(az account get-access-token --resource "https://service.powerapps.com/" --query accessToken --output tsv)

if [[ -z "$access_token" ]]; then
    log_error "Failed to obtain Power Platform access token"
    log_error "Please verify you have sufficient permissions to manage Power Platform environments"
    exit 1
fi

log_success "Power Platform access token obtained successfully."

# Step 5: Link Enterprise Policy to Power Platform Environment
log_info "Linking enterprise policy to Power Platform environment..."

# Prepare the request payload with SystemId
policy_link_payload=$(cat <<EOF
{
    "SystemId": "$system_id"
}
EOF
)

log_info "Environment ID: $POWER_PLATFORM_ENVIRONMENT_ID"
log_info "System ID: $system_id"

# Use the correct API endpoint for linking enterprise policies
# This is a POST request to the link endpoint, not a PATCH to the environment
api_url="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$POWER_PLATFORM_ENVIRONMENT_ID/enterprisePolicies/NetworkInjection/link?api-version=2019-10-01"

response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -d "$policy_link_payload" \
    "$api_url")

# Parse response
http_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | head -n -1)

if [[ "$http_code" == "200" ]]; then
    log_success "Enterprise policy linking completed successfully (HTTP $http_code)"
elif [[ "$http_code" == "202" ]]; then
    log_success "Enterprise policy linking initiated successfully (HTTP $http_code)"
    log_info "Operation is running asynchronously..."
else
    log_error "Failed to link enterprise policy (HTTP $http_code)"
    log_error "Response: $response_body"
    exit 1
fi

# Step 6: Verify the linkage
log_info "Verifying enterprise policy linkage..."

# Wait a moment for the operation to complete
sleep 5

# Check the link status using the status endpoint
status_url="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$POWER_PLATFORM_ENVIRONMENT_ID/enterprisePolicies/NetworkInjection?api-version=2019-10-01"

status_response=$(curl -s -H "Authorization: Bearer $access_token" "$status_url")
link_status=$(echo "$status_response" | jq -r '.properties.status // "Unknown"' 2>/dev/null || echo "Unknown")

case "$link_status" in
    "Linked"|"Active"|"Enabled")
        log_success "✅ Enterprise policy successfully linked to Power Platform environment!"
        log_success "Environment: $POWER_PLATFORM_ENVIRONMENT_NAME"
        log_success "Enterprise Policy: $ENTERPRISE_POLICY_NAME"
        log_success "Link Status: $link_status"
        
        echo
        log_success "🎉 Subnet injection setup completed successfully!"
        log_info "Your Power Platform environment can now use Azure Virtual Network subnet injection."
        log_info "You can proceed with creating custom connectors and configuring Copilot Studio."
        ;;
    "Linking"|"InProgress"|"Pending")
        log_warning "⚠️  Enterprise policy linkage is still in progress"
        log_info "Status: $link_status"
        log_info "The linkage may take a few more minutes to complete."
        log_info "Please check the Power Platform Admin Center for final status."
        ;;
    "Failed"|"Error")
        log_error "❌ Enterprise policy linkage failed"
        log_error "Status: $link_status"
        log_error "Please check the Power Platform Admin Center for error details."
        exit 1
        ;;
    *)
        log_warning "⚠️  Enterprise policy linkage status unclear"
        log_info "Status: $link_status"
        log_info "Please check the Power Platform Admin Center to verify the linkage."
        ;;
esac

echo
log_success "Subnet injection setup script completed!"
