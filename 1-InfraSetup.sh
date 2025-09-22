#!/bin/bash

# Azure Infrastructure Setup Script
# This script performs complete Azure infrastructure deployment for Power Platform VNet integration
# Includes Azure CLI authentication, azd deployment, and APIM configuration

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

# Step 1: Load environment variables from .env file if it exists
log_info "Loading environment configuration..."

if [[ -f "./.env" ]]; then
    log_info "Loading environment variables from .env file..."
    # Export variables from .env file, handling potential Windows line endings
    set -a  # Automatically export all variables
    source <(sed 's/\r$//' ./.env)
    set +a  # Stop automatically exporting
    log_success "Environment variables loaded successfully."
else
    log_warning ".env file not found. Please ensure required environment variables are set:"
    log_warning "- TENANT_ID"
    log_warning "- AZURE_SUBSCRIPTION_ID" 
    log_warning "- AZURE_LOCATION"
    log_warning "- POWER_PLATFORM_ENVIRONMENT_NAME"
    log_warning "- POWER_PLATFORM_LOCATION"
fi

# Validate required environment variables
required_vars=("TENANT_ID" "AZURE_SUBSCRIPTION_ID" "AZURE_LOCATION" "POWER_PLATFORM_ENVIRONMENT_NAME" "POWER_PLATFORM_LOCATION")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    log_error "Missing required environment variables: ${missing_vars[*]}"
    log_error "Please set these variables and try again."
    exit 1
fi

log_info "Required environment variables validated successfully."

# Step 2: Azure CLI Authentication and Tenant Configuration
log_info "Configuring Azure CLI authentication..."

# Check if already logged in and to correct tenant
current_account=$(az account show --query "tenantId" -o tsv 2>/dev/null || echo "")

if [[ "$current_account" != "$TENANT_ID" ]]; then
    log_info "Logging into Azure with tenant: $TENANT_ID"
    
    # Attempt interactive login first
    if ! az login --tenant "$TENANT_ID" >/dev/null 2>&1; then
        log_error "Azure CLI login failed. Please check your credentials and tenant ID."
        exit 1
    fi
    
    log_success "Successfully logged into Azure."
else
    log_info "Already logged into correct Azure tenant: $TENANT_ID"
fi

# Set the active subscription
log_info "Setting Azure subscription: $AZURE_SUBSCRIPTION_ID"
if ! az account set --subscription "$AZURE_SUBSCRIPTION_ID"; then
    log_error "Failed to set Azure subscription. Please verify the subscription ID and your access."
    exit 1
fi

log_success "Azure CLI configured successfully."

# Step 3: Azure Developer CLI (azd) Infrastructure Deployment
log_info "Starting Azure infrastructure deployment with azd..."

# Check if azd is authenticated
if ! azd auth login --check-status >/dev/null 2>&1; then
    log_info "Azure Developer CLI not authenticated. Performing login..."
    if ! azd auth login; then
        log_error "Azure Developer CLI login failed."
        exit 1
    fi
    log_success "Azure Developer CLI authenticated successfully."
else
    log_info "Azure Developer CLI already authenticated."
fi

# Deploy infrastructure using azd
log_info "Deploying Azure infrastructure..."
if ! azd up --no-prompt; then
    log_error "Azure infrastructure deployment failed."
    log_error "Please check the deployment logs and try again."
    exit 1
fi

log_success "Azure infrastructure deployment completed successfully."

# Step 4: Retrieve deployment outputs and configure APIM
log_info "Retrieving deployment outputs..."

# Get deployment outputs using azd
deployment_outputs=$(azd env get-values 2>/dev/null || echo "")

if [[ -n "$deployment_outputs" ]]; then
    # Parse azd environment values format (KEY="value")
    apim_name=$(echo "$deployment_outputs" | grep '^apimName=' | cut -d'"' -f2)
    resource_group_name=$(echo "$deployment_outputs" | grep '^resourceGroup=' | cut -d'"' -f2)
    
    if [[ -n "$apim_name" && -n "$resource_group_name" ]]; then
        log_info "Configuring APIM: $apim_name in resource group: $resource_group_name"
        
        # Update APIM configuration to disable public access and configure VNet integration
        log_info "Disabling public network access for APIM..."
        if az apim update --name "$apim_name" --resource-group "$resource_group_name" --subscription "$AZURE_SUBSCRIPTION_ID" --public-network-access false >/dev/null 2>&1; then
            log_success "Public network access disabled for APIM."
        else
            log_warning "Failed to disable public network access for APIM. You may need to configure this manually."
        fi
        
        # Configure VNet integration (set to None initially, will be configured via private endpoints)
        log_info "Configuring VNet integration for APIM..."
        if az apim update --name "$apim_name" --resource-group "$resource_group_name" --subscription "$AZURE_SUBSCRIPTION_ID" --virtual-network None >/dev/null 2>&1; then
            log_success "VNet integration configured for APIM."
        else
            log_warning "Failed to configure VNet integration for APIM. You may need to configure this manually."
        fi
        
        log_success "APIM configuration updated successfully."
    else
        log_warning "APIM name or resource group not found in deployment outputs. Skipping APIM configuration update."
    fi
else
    log_warning "No deployment outputs available. Skipping APIM configuration."
fi

# Step 5: Display and update environment configuration
log_info "Updating environment configuration..."

# Get all deployment outputs for .env file
if [[ -n "$deployment_outputs" ]]; then
    # Extract values from azd environment format (KEY="value")
    RESOURCE_GROUP=$(echo "$deployment_outputs" | grep '^resourceGroup=' | cut -d'"' -f2)
    PRIMARY_VIRTUAL_NETWORK_NAME=$(echo "$deployment_outputs" | grep '^primaryVnetName=' | cut -d'"' -f2)
    PRIMARY_SUBNET_NAME=$(echo "$deployment_outputs" | grep '^primarySubnetName=' | cut -d'"' -f2)
    SECONDARY_VIRTUAL_NETWORK_NAME=$(echo "$deployment_outputs" | grep '^failoverVnetName=' | cut -d'"' -f2)
    SECONDARY_SUBNET_NAME=$(echo "$deployment_outputs" | grep '^failoverSubnetName=' | cut -d'"' -f2)
    ENTERPRISE_POLICY_NAME=$(echo "$deployment_outputs" | grep '^enterprisePolicyName=' | cut -d'"' -f2)
    APIM_NAME=$(echo "$deployment_outputs" | grep '^apimName=' | cut -d'"' -f2)
    APIM_ID=$(echo "$deployment_outputs" | grep '^apimId=' | cut -d'"' -f2)
    APIM_PRIVATE_DNS_ZONE_ID=$(echo "$deployment_outputs" | grep '^apimPrivateDnsZoneId=' | cut -d'"' -f2)
    APIM_PRIVATE_DNS_ZONE_NAME=$(echo "$deployment_outputs" | grep '^apimPrivateDnsZoneName=' | cut -d'"' -f2)
    
    # Display values for user reference
    echo
    log_success "Deployment completed! Update the .env file with the following values:"
    echo "TENANT_ID=$TENANT_ID"
    echo "AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID"
    echo "AZURE_LOCATION=$AZURE_LOCATION"
    echo "POWER_PLATFORM_ENVIRONMENT_NAME=$POWER_PLATFORM_ENVIRONMENT_NAME"
    echo "POWER_PLATFORM_LOCATION=$POWER_PLATFORM_LOCATION"
    [[ -n "$RESOURCE_GROUP" ]] && echo "RESOURCE_GROUP=$RESOURCE_GROUP"
    [[ -n "$PRIMARY_VIRTUAL_NETWORK_NAME" ]] && echo "PRIMARY_VIRTUAL_NETWORK_NAME=$PRIMARY_VIRTUAL_NETWORK_NAME"
    [[ -n "$PRIMARY_SUBNET_NAME" ]] && echo "PRIMARY_SUBNET_NAME=$PRIMARY_SUBNET_NAME"
    [[ -n "$SECONDARY_VIRTUAL_NETWORK_NAME" ]] && echo "SECONDARY_VIRTUAL_NETWORK_NAME=$SECONDARY_VIRTUAL_NETWORK_NAME"
    [[ -n "$SECONDARY_SUBNET_NAME" ]] && echo "SECONDARY_SUBNET_NAME=$SECONDARY_SUBNET_NAME"
    [[ -n "$ENTERPRISE_POLICY_NAME" ]] && echo "ENTERPRISE_POLICY_NAME=$ENTERPRISE_POLICY_NAME"
    [[ -n "$APIM_NAME" ]] && echo "APIM_NAME=$APIM_NAME"
    [[ -n "$APIM_ID" ]] && echo "APIM_ID=$APIM_ID"
    [[ -n "$APIM_PRIVATE_DNS_ZONE_ID" ]] && echo "APIM_PRIVATE_DNS_ZONE_ID=$APIM_PRIVATE_DNS_ZONE_ID"
    [[ -n "$APIM_PRIVATE_DNS_ZONE_NAME" ]] && echo "APIM_PRIVATE_DNS_ZONE_NAME=$APIM_PRIVATE_DNS_ZONE_NAME"
    
    # Create/update .env file
    env_file_path="./.env"
    if [[ -f "$env_file_path" ]]; then
        rm -f "$env_file_path"
        log_info "Deleted existing .env file."
    else
        log_info ".env file does not exist, creating a new one."
    fi
    
    log_info "Creating new .env file with updated values..."
    
    # Create the new .env file with all required environment variables
    cat > "$env_file_path" << EOF
TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
AZURE_LOCATION=$AZURE_LOCATION
POWER_PLATFORM_ENVIRONMENT_NAME=$POWER_PLATFORM_ENVIRONMENT_NAME
POWER_PLATFORM_LOCATION=$POWER_PLATFORM_LOCATION
EOF

    # Add deployment outputs if available
    [[ -n "$RESOURCE_GROUP" ]] && echo "RESOURCE_GROUP=$RESOURCE_GROUP" >> "$env_file_path"
    [[ -n "$PRIMARY_VIRTUAL_NETWORK_NAME" ]] && echo "PRIMARY_VIRTUAL_NETWORK_NAME=$PRIMARY_VIRTUAL_NETWORK_NAME" >> "$env_file_path"
    [[ -n "$PRIMARY_SUBNET_NAME" ]] && echo "PRIMARY_SUBNET_NAME=$PRIMARY_SUBNET_NAME" >> "$env_file_path"
    [[ -n "$SECONDARY_VIRTUAL_NETWORK_NAME" ]] && echo "SECONDARY_VIRTUAL_NETWORK_NAME=$SECONDARY_VIRTUAL_NETWORK_NAME" >> "$env_file_path"
    [[ -n "$SECONDARY_SUBNET_NAME" ]] && echo "SECONDARY_SUBNET_NAME=$SECONDARY_SUBNET_NAME" >> "$env_file_path"
    [[ -n "$ENTERPRISE_POLICY_NAME" ]] && echo "ENTERPRISE_POLICY_NAME=$ENTERPRISE_POLICY_NAME" >> "$env_file_path"
    [[ -n "$APIM_NAME" ]] && echo "APIM_NAME=$APIM_NAME" >> "$env_file_path"
    [[ -n "$APIM_ID" ]] && echo "APIM_ID=$APIM_ID" >> "$env_file_path"
    [[ -n "$APIM_PRIVATE_DNS_ZONE_ID" ]] && echo "APIM_PRIVATE_DNS_ZONE_ID=$APIM_PRIVATE_DNS_ZONE_ID" >> "$env_file_path"
    [[ -n "$APIM_PRIVATE_DNS_ZONE_NAME" ]] && echo "APIM_PRIVATE_DNS_ZONE_NAME=$APIM_PRIVATE_DNS_ZONE_NAME" >> "$env_file_path"
    
    log_success ".env file created successfully with deployment outputs."
else
    log_warning "Could not retrieve deployment outputs. .env file contains only input parameters."
    
    # Create basic .env file with input parameters only
    env_file_path="./.env"
    cat > "$env_file_path" << EOF
TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
AZURE_LOCATION=$AZURE_LOCATION
POWER_PLATFORM_ENVIRONMENT_NAME=$POWER_PLATFORM_ENVIRONMENT_NAME
POWER_PLATFORM_LOCATION=$POWER_PLATFORM_LOCATION
EOF
    
    log_info "Basic .env file created. You may need to manually add deployment outputs."
fi

echo
log_success "Infrastructure setup completed successfully!"
log_info "You can now proceed with the next steps in your Power Platform VNet integration setup."
