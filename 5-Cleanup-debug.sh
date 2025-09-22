#!/bin/bash

#
# Power Platform VNet Integration Cleanup Script
#
# Safely removes all Azure infrastructure and Power Platform configurations created 
# for VNet integration. This script performs the following operations:
#
# 1. Loads environment variables from a specified file
# 2. Validates Azure CLI authentication and subscription context
# 3. Unlinks the enterprise policy from the Power Platform environment
# 4. Removes all Azure infrastructure using Azure Developer CLI (azd)
# 5. Optionally removes the resource group and all contained resources
# 6. Cleans up the environment configuration file
#
# The script includes comprehensive safety checks and confirmation prompts to prevent
# accidental deletion of resources. It follows the reverse order of the deployment
# process to ensure proper cleanup of dependencies.
#
# IMPORTANT: This script will permanently delete Azure resources and configurations.
# Use with caution and ensure you have proper backups if needed.
#
# Usage:
#   ./5-Cleanup.sh [options]
#
# Options:
#   -e, --env-file FILE             Path to environment file (default: ./.env)
#   -f, --force                     Skip confirmation prompts
#   -s, --skip-power-platform       Skip Power Platform enterprise policy unlinking
#   -k, --keep-resource-group       Keep the resource group after cleanup
#   -r, --remove-environment        Remove the Power Platform environment itself
#   -h, --help                      Show this help message
#
# Examples:
#   ./5-Cleanup.sh
#   ./5-Cleanup.sh --force
#   ./5-Cleanup.sh --env-file "./config/production.env" --skip-power-platform
#   ./5-Cleanup.sh --keep-resource-group
#   ./5-Cleanup.sh --remove-environment --force
#
# Prerequisites:
# - Azure CLI logged in with appropriate permissions
# - Azure Developer CLI (azd) installed for infrastructure cleanup
# - jq installed for JSON processing
#
# Required Permissions:
# - Contributor role on the Azure subscription for resource deletion
# - Power Platform Administrator role for enterprise policy management
#
# Cross-Platform Compatibility:
# - Bash for Linux, macOS, and Windows WSL support
# - REST API calls for all Power Platform operations
# - Azure CLI for all Azure operations
#

set -eo pipefail

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="./.env"
FORCE=false
SKIP_POWER_PLATFORM=false
KEEP_RESOURCE_GROUP=false
REMOVE_ENVIRONMENT=false

# Arrays to track cleanup operations
CLEANUP_SUCCESS=()
CLEANUP_ERRORS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${CYAN}$1${NC}"
}

# Help function
show_help() {
    cat << EOF
Power Platform VNet Integration Cleanup Script

SYNOPSIS
    Cleans up all Azure infrastructure and Power Platform configurations created for VNet integration.

USAGE
    ./5-Cleanup.sh [OPTIONS]

OPTIONS
    -e, --env-file FILE             Path to environment file (default: ./.env)
    -f, --force                     Skip interactive confirmation prompts
    -s, --skip-power-platform       Skip Power Platform enterprise policy unlinking
    -k, --keep-resource-group       Keep the resource group after cleanup
    -r, --remove-environment        Remove the Power Platform environment itself
    -h, --help                      Show this help message

EXAMPLES
    ./5-Cleanup.sh
        Performs interactive cleanup using the default .env file with confirmation prompts.

    ./5-Cleanup.sh --force
        Performs automated cleanup without confirmation prompts.

    ./5-Cleanup.sh --env-file "./config/production.env" --skip-power-platform
        Uses a custom environment file and skips Power Platform cleanup.

    ./5-Cleanup.sh --keep-resource-group
        Removes all resources but keeps the resource group intact.

    ./5-Cleanup.sh --remove-environment --force
        Performs complete cleanup including permanent deletion of the Power Platform environment.

DESCRIPTION
    This script safely removes all Azure resources and Power Platform configurations that were created
    by the Power Platform VNet integration deployment scripts. It performs operations in reverse order
    of deployment to ensure proper cleanup of dependencies.

    The cleanup process typically takes 10-20 minutes depending on the number of resources
    and their deletion dependencies. API Management instances may take the longest to delete.

    IMPORTANT: This script will permanently delete Azure resources and configurations.
    Use with caution and ensure you have proper backups if needed.

PREREQUISITES
    - Azure CLI (az) must be installed and authenticated
    - Azure Developer CLI (azd) must be installed for infrastructure cleanup
    - jq must be installed for JSON processing
    - Contributor role on the Azure subscription for resource deletion
    - Power Platform Administrator role for enterprise policy management

FILES
    The environment file should contain variables populated by the deployment scripts:
    - TENANT_ID: Azure AD tenant ID for authentication
    - AZURE_SUBSCRIPTION_ID: Azure subscription ID where resources exist
    - RESOURCE_GROUP: Azure resource group containing the deployed resources
    - ENTERPRISE_POLICY_NAME: Name of the enterprise policy to unlink
    - POWER_PLATFORM_ENVIRONMENT_NAME: Display name of the Power Platform environment
    - APIM_NAME: Name of the API Management instance (optional)

EXIT CODES
    0    Success
    1    General error
    2    Invalid arguments
    3    Missing prerequisites
    4    Authentication failure
    5    Resource not found

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env-file)
                ENV_FILE="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -s|--skip-power-platform)
                SKIP_POWER_PLATFORM=true
                shift
                ;;
            -k|--keep-resource-group)
                KEEP_RESOURCE_GROUP=true
                shift
                ;;
            -r|--remove-environment)
                REMOVE_ENVIRONMENT=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 2
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v az &> /dev/null; then
        missing_tools+=("azure-cli")
    fi
    
    if ! command -v azd &> /dev/null; then
        missing_tools+=("azure-developer-cli")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 3
    fi
    
    log_success "All required tools are available."
}

# Import environment variables from .env file
import_env_file() {
    local env_file="$1"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file '$env_file' not found."
        log_info "Please ensure the file exists and contains the deployment configuration."
        exit 1
    fi
    
    log_info "Loading environment variables from: $env_file"
    local variable_count=0
    
    # Read the file line by line
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Match lines in format KEY=VALUE
        if [[ "$line" =~ ^[[:space:]]*([^#][^=]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Trim whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            # Export the variable
            export "$key"="$value"
            ((variable_count++))
        fi
    done < "$env_file"
    
    log_success "Loaded $variable_count environment variables from configuration file."
}

# Validate environment variables
validate_environment_variables() {
    log_info "Validating environment variables..."
    
    # Core required variables for any cleanup operation
    local required_vars=("TENANT_ID" "AZURE_SUBSCRIPTION_ID")
    
    # Additional variables needed for specific cleanup operations
    if [[ "$SKIP_POWER_PLATFORM" != "true" ]]; then
        required_vars+=("POWER_PLATFORM_ENVIRONMENT_NAME")
    fi
    
    local missing_vars=()
    local available_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        else
            available_vars+=("$var")
        fi
    done
    
    # Check optional variables and warn if missing
    local optional_vars=("RESOURCE_GROUP" "ENTERPRISE_POLICY_NAME" "APIM_NAME")
    local missing_optional_vars=()
    
    for var in "${optional_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_optional_vars+=("$var")
        else
            available_vars+=("$var")
        fi
    done
    
    # Report validation results
    if [[ ${#available_vars[@]} -gt 0 ]]; then
        log_success "Available environment variables: ${available_vars[*]}"
    fi
    
    if [[ ${#missing_optional_vars[@]} -gt 0 ]]; then
        log_warning "Optional environment variables not set: ${missing_optional_vars[*]}"
        log_info "Some cleanup operations may be skipped due to missing configuration."
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Required environment variables are missing: ${missing_vars[*]}"
        log_info "Please check your environment file."
        exit 1
    fi
    
    log_success "Environment variable validation completed successfully."
}

# Ensure Azure CLI authentication
ensure_azure_login() {
    log_info "Validating Azure CLI authentication..."
    
    # Check if Azure CLI is already authenticated
    if ! az account show &>/dev/null; then
        log_info "Azure CLI not logged in. Attempting to log in..."
        if [[ -n "${TENANT_ID:-}" ]]; then
            # Use specific tenant if provided
            az login --tenant "$TENANT_ID" >/dev/null
        else
            # Use default tenant
            az login >/dev/null
        fi
        
        # Verify login was successful
        if ! az account show &>/dev/null; then
            log_error "Failed to authenticate with Azure CLI."
            log_info "Please check your credentials and try again."
            exit 4
        fi
    fi
    
    # Set subscription context if provided
    if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
        log_info "Setting Azure subscription context to: $AZURE_SUBSCRIPTION_ID"
        az account set --subscription "$AZURE_SUBSCRIPTION_ID"
        
        # Verify subscription context
        local current_sub
        current_sub=$(az account show --query "id" -o tsv)
        if [[ "$current_sub" != "$AZURE_SUBSCRIPTION_ID" ]]; then
            log_error "Subscription context mismatch."
            log_info "Expected: $AZURE_SUBSCRIPTION_ID, Current: $current_sub"
            exit 4
        fi
    else
        log_error "AZURE_SUBSCRIPTION_ID environment variable is not set."
        log_info "Cannot proceed with cleanup."
        exit 1
    fi
    
    log_success "Azure CLI authentication validated successfully."
}

# Get Power Platform access token
get_power_platform_access_token() {
    log_info "Getting Power Platform access token..."
    
    local resource="https://api.bap.microsoft.com/"
    local token
    token=$(az account get-access-token --resource "$resource" --query accessToken --output tsv)
    
    if [[ -z "$token" || "$token" == "null" ]]; then
        log_error "Failed to obtain access token for Power Platform Admin API."
        return 1
    fi
    
    echo "$token"
}

# Get Power Platform environment ID
get_power_platform_environment_id() {
    local display_name="$1"
    local access_token="$2"
    
    log_info "Searching for Power Platform environment: $display_name"
    
    local url="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2023-06-01"
    
    local response
    response=$(curl -s -H "Authorization: Bearer $access_token" \
                     -H "Content-Type: application/json" \
                     "$url")
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to retrieve Power Platform environments."
        return 1
    fi
    
    # Parse response and find environment by display name
    local environment_id
    environment_id=$(echo "$response" | jq -r ".value[] | select(.properties.displayName == \"$display_name\") | .name")
    
    if [[ -z "$environment_id" || "$environment_id" == "null" ]]; then
        log_warning "Power Platform environment '$display_name' not found."
        log_info "It may have been already removed or renamed."
        return 1
    fi
    
    log_success "Found Power Platform environment: $environment_id"
    echo "$environment_id"
}

# Get enterprise policy ID
get_enterprise_policy_id() {
    local enterprise_policy_id
    
    # Try to get it from environment variables if available
    if [[ -n "${ENTERPRISE_POLICY_NAME:-}" && -n "${RESOURCE_GROUP:-}" && -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
        enterprise_policy_id="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies/$ENTERPRISE_POLICY_NAME"
        
        # Verify the enterprise policy exists
        local policy_exists
        policy_exists=$(az resource show --ids "$enterprise_policy_id" --query "name" -o tsv 2>/dev/null || echo "")
        if [[ -n "$policy_exists" ]]; then
            log_success "Found enterprise policy from environment variables: $enterprise_policy_id"
            echo "$enterprise_policy_id"
            return 0
        fi
    fi
    
    # If not found via environment variables, try to find it in the resource group
    if [[ -n "${RESOURCE_GROUP:-}" && -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
        log_info "Searching for enterprise policies in resource group: $RESOURCE_GROUP"
        
        local policies
        policies=$(az resource list --resource-group "$RESOURCE_GROUP" \
                                   --resource-type "Microsoft.PowerPlatform/enterprisePolicies" \
                                   --query "[].id" -o tsv 2>/dev/null || echo "")
        
        if [[ -n "$policies" ]]; then
            # Take the first policy if multiple exist
            enterprise_policy_id=$(echo "$policies" | head -n1)
            log_success "Found enterprise policy in resource group: $enterprise_policy_id"
            echo "$enterprise_policy_id"
            return 0
        fi
    fi
    
    log_info "No enterprise policy found via environment variables or resource group search."
    return 1
}

# Confirmation prompt
confirm_operation() {
    local operation_name="$1"
    local description="$2"
    shift 2
    local resources_affected=("$@")
    
    if [[ "$FORCE" == "true" ]]; then
        log_info "Force mode enabled - proceeding with $operation_name without confirmation."
        return 0
    fi
    
    echo
    log_header "⚠️  CONFIRMATION REQUIRED ⚠️"
    echo -e "${WHITE}Operation: $operation_name${NC}"
    echo -e "${WHITE}Description: $description${NC}"
    
    if [[ ${#resources_affected[@]} -gt 0 ]]; then
        echo -e "${WHITE}Resources that will be affected:${NC}"
        for resource in "${resources_affected[@]}"; do
            echo -e "${CYAN}  • $resource${NC}"
        done
    fi
    
    echo
    log_error "WARNING: This operation cannot be undone!"
    echo
    
    local response
    while true; do
        read -p "Do you want to proceed? (yes/no/y/n): " response
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]' | xargs)
        case "$response" in
            yes|y)
                log_success "User confirmed - proceeding with $operation_name."
                return 0
                ;;
            no|n)
                log_info "User cancelled - skipping $operation_name."
                return 1
                ;;
            *)
                echo "Please answer yes, no, y, or n."
                ;;
        esac
    done
}

# Remove Power Platform VNet policy using REST API
remove_power_platform_vnet_policy() {
    local environment_id="$1"
    local access_token="$2"
    local enterprise_policy_id="${3:-}"
    
    log_info "Attempting to remove VNet enterprise policy via REST API..."
    log_info "Environment ID: $environment_id"
    
    # Step 1: Check current environment state
    local env_url="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$environment_id?api-version=2023-06-01"
    
    local env_result
    env_result=$(curl -s -H "Authorization: Bearer $access_token" \
                      -H "Content-Type: application/json" \
                      "$env_url")
    
    if [[ $? -ne 0 ]]; then
        log_warning "Could not check environment policies. Proceeding with removal attempt..."
    else
        # Check for VNet policy
        local has_vnet_policy
        has_vnet_policy=$(echo "$env_result" | jq -r '.properties.enterprisePolicies.VNets // empty')
        
        if [[ -z "$has_vnet_policy" || "$has_vnet_policy" == "null" ]]; then
            log_success "No VNet enterprise policy found on environment. Already clean."
            return 0
        fi
        
        log_info "Found VNet enterprise policy: $has_vnet_policy"
        if [[ -z "$enterprise_policy_id" ]]; then
            enterprise_policy_id="$has_vnet_policy"
        fi
    fi
    
    # Step 2: Unlink the enterprise policy
    log_info "Unlinking enterprise policy from Power Platform environment..."
    local api_version="2023-06-01"
    local unlink_url="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$environment_id/enterprisePolicies/NetworkInjection/unlink?api-version=$api_version"
    
    # Prepare request body
    local body="{}"
    if [[ -n "$enterprise_policy_id" ]]; then
        # Get the policy system ID for the unlink operation
        local policy_system_id
        policy_system_id=$(az resource show --ids "$enterprise_policy_id" --query "properties.systemId" -o tsv 2>/dev/null || echo "")
        if [[ -n "$policy_system_id" && "$policy_system_id" != "null" ]]; then
            body=$(jq -n --arg systemId "$policy_system_id" '{SystemId: $systemId}')
            log_info "Using enterprise policy system ID: $policy_system_id"
        else
            log_info "No system ID found for enterprise policy, using empty body"
        fi
    fi
    
    local unlink_response
    unlink_response=$(curl -s -w "%{http_code}" -X POST \
                           -H "Authorization: Bearer $access_token" \
                           -H "Content-Type: application/json" \
                           -d "$body" \
                           "$unlink_url")
    
    local http_code="${unlink_response: -3}"
    local response_body="${unlink_response%???}"
    
    if [[ "$http_code" =~ ^(200|202|204)$ ]]; then
        log_success "Enterprise policy unlink operation initiated successfully."
        
        # Check for operation-location header for long-running operations
        local operation_location
        operation_location=$(curl -s -I -X POST \
                                  -H "Authorization: Bearer $access_token" \
                                  -H "Content-Type: application/json" \
                                  -d "$body" \
                                  "$unlink_url" | grep -i "operation-location" | cut -d' ' -f2 | tr -d '\r')
        
        if [[ -n "$operation_location" ]]; then
            log_info "Polling unlink operation status..."
            local poll_interval=10
            local max_polls=30
            local poll_count=0
            
            while [[ $poll_count -lt $max_polls ]]; do
                sleep $poll_interval
                ((poll_count++))
                
                local operation_result
                operation_result=$(curl -s -w "%{http_code}" \
                                        -H "Authorization: Bearer $access_token" \
                                        "$operation_location")
                
                local operation_code="${operation_result: -3}"
                
                if [[ "$operation_code" == "200" ]]; then
                    log_success "Enterprise policy unlinked successfully from Power Platform environment."
                    break
                elif [[ "$operation_code" == "202" ]]; then
                    log_info "Unlinking enterprise policy is still in progress... (Poll $poll_count/$max_polls)"
                else
                    log_warning "Unexpected status code during polling: $operation_code"
                    break
                fi
            done
            
            if [[ $poll_count -ge $max_polls ]]; then
                log_warning "Unlink operation timed out after $((max_polls * poll_interval)) seconds."
            fi
        else
            log_success "Enterprise policy unlinked successfully from Power Platform environment."
        fi
        
        # Step 3: Remove the enterprise policy resource itself
        if [[ -n "$enterprise_policy_id" ]]; then
            log_info "Removing enterprise policy resource: $enterprise_policy_id"
            if az resource delete --ids "$enterprise_policy_id" --verbose; then
                log_success "Enterprise policy resource deleted successfully."
            else
                log_warning "Failed to delete enterprise policy resource."
                CLEANUP_ERRORS+=("Enterprise policy resource deletion failed")
                return 1
            fi
        fi
        
        return 0
    else
        log_error "Failed to unlink enterprise policy. HTTP status: $http_code"
        log_info "Response: $response_body"
        
        # Handle specific error cases
        case "$http_code" in
            404)
                log_success "Resource not found (404). The enterprise policy may already be unlinked."
                return 0
                ;;
            409)
                log_warning "Conflict detected (409). The enterprise policy may already be unlinked."
                return 0
                ;;
            401)
                log_error "Authentication failed (401). Please check your permissions and token."
                ;;
            403)
                log_error "Access forbidden (403). You may not have the required permissions."
                ;;
        esac
        
        CLEANUP_ERRORS+=("Power Platform VNet policy removal failed")
        return 1
    fi
}

# Remove Power Platform configuration
remove_power_platform_configuration() {
    if [[ "$SKIP_POWER_PLATFORM" == "true" ]]; then
        log_info "Skipping Power Platform configuration cleanup as requested."
        return 0
    fi
    
    echo
    log_header "🔗 Starting Power Platform enterprise policy cleanup..."
    
    if [[ -z "${POWER_PLATFORM_ENVIRONMENT_NAME:-}" ]]; then
        log_warning "POWER_PLATFORM_ENVIRONMENT_NAME not set - skipping Power Platform cleanup."
        return 0
    fi
    
    # Get access token
    local access_token
    if ! access_token=$(get_power_platform_access_token); then
        log_error "Failed to get Power Platform access token."
        CLEANUP_ERRORS+=("Power Platform access token retrieval failed")
        return 1
    fi
    
    # Get environment ID
    local environment_id
    if ! environment_id=$(get_power_platform_environment_id "$POWER_PLATFORM_ENVIRONMENT_NAME" "$access_token"); then
        log_success "Power Platform environment not found or already cleaned up."
        return 0
    fi
    
    # Get enterprise policy ID
    local enterprise_policy_id
    enterprise_policy_id=$(get_enterprise_policy_id || echo "")
    
    # Confirm enterprise policy unlinking
    local resources_affected=(
        "Power Platform environment: $POWER_PLATFORM_ENVIRONMENT_NAME"
        "Enterprise policy: VNet/NetworkInjection"
        "VNet integration configuration will be removed"
    )
    
    if confirm_operation "Power Platform VNet Policy Removal" \
                        "Remove VNet integration from Power Platform environment" \
                        "${resources_affected[@]}"; then
        
        log_info "Removing VNet enterprise policy from Power Platform environment..."
        
        if remove_power_platform_vnet_policy "$environment_id" "$access_token" "$enterprise_policy_id"; then
            log_success "VNet enterprise policy removed successfully from Power Platform environment."
            CLEANUP_SUCCESS+=("Power Platform VNet policy removal")
        else
            log_warning "VNet enterprise policy removal did not complete successfully."
            CLEANUP_ERRORS+=("Power Platform VNet policy removal failed")
            return 1
        fi
    else
        log_info "Skipping Power Platform VNet policy cleanup."
        return 1
    fi
    
    return 0
}

# Remove Azure infrastructure using azd
remove_azure_infrastructure() {
    echo
    log_header "🗑️  Starting Azure infrastructure cleanup..."
    
    # Check if azd environment exists
    local azd_env_name="${POWER_PLATFORM_ENVIRONMENT_NAME:-}"
    if [[ -z "$azd_env_name" ]]; then
        log_warning "POWER_PLATFORM_ENVIRONMENT_NAME not set - cannot use azd for cleanup."
        log_info "Will attempt direct resource group cleanup instead."
        remove_resource_group_directly
        return $?
    fi
    
    # Attempt azd cleanup first (preferred method)
    log_info "Checking azd environment: $azd_env_name"
    
    local azd_environments
    if azd_environments=$(azd env list --output json 2>/dev/null); then
        local target_env
        target_env=$(echo "$azd_environments" | jq -r ".[] | select(.Name == \"$azd_env_name\") | .Name")
        
        if [[ -n "$target_env" && "$target_env" != "null" ]]; then
            log_success "Found azd environment: $azd_env_name"
            
            # Confirm azd cleanup
            local resources_affected=(
                "azd environment: $azd_env_name"
                "All resources deployed by azd for this environment"
                "Resource group: ${RESOURCE_GROUP:-<determined by azd>}"
            )
            
            if confirm_operation "Azure Infrastructure Cleanup (azd)" \
                                "Remove all Azure resources deployed by azd" \
                                "${resources_affected[@]}"; then
                
                log_info "Executing azd down to remove infrastructure..."
                
                if azd down --environment "$azd_env_name" --force --purge; then
                    log_success "Azure infrastructure removed successfully using azd."
                    CLEANUP_SUCCESS+=("Azure infrastructure (azd)")
                    return 0
                else
                    log_warning "azd down failed. Attempting manual resource group cleanup..."
                    CLEANUP_ERRORS+=("azd down operation failed")
                fi
            else
                log_info "Skipping Azure infrastructure cleanup."
                return 1
            fi
        else
            log_info "azd environment '$azd_env_name' not found. Attempting direct resource group cleanup..."
        fi
    else
        log_info "No azd environments found. Attempting direct resource group cleanup..."
    fi
    
    # Fallback to direct resource group cleanup
    remove_resource_group_directly
    return $?
}

# Remove resource group directly
remove_resource_group_directly() {
    if [[ -z "${RESOURCE_GROUP:-}" ]]; then
        log_warning "RESOURCE_GROUP environment variable not set - cannot perform direct cleanup."
        log_info "Please specify the resource group name in your environment file or use manual cleanup."
        return 1
    fi
    
    local resource_group_name="$RESOURCE_GROUP"
    
    # Check if resource group exists
    log_info "Checking if resource group exists: $resource_group_name"
    local rg_exists
    rg_exists=$(az group exists --name "$resource_group_name" --subscription "$AZURE_SUBSCRIPTION_ID")
    
    if [[ "$rg_exists" == "false" ]]; then
        log_success "Resource group '$resource_group_name' does not exist or has already been removed."
        return 0
    fi
    
    # List resources in the group for confirmation
    log_info "Retrieving resources in resource group: $resource_group_name"
    local resources
    resources=$(az resource list --resource-group "$resource_group_name" \
                                --query "[].{Name:name, Type:type}" \
                                --output json 2>/dev/null || echo "[]")
    
    local resources_affected=("Resource group: $resource_group_name")
    local resource_count
    resource_count=$(echo "$resources" | jq '. | length')
    
    if [[ "$resource_count" -gt 0 ]]; then
        resources_affected+=("Resources to be deleted:")
        while IFS= read -r resource; do
            local name
            local type
            name=$(echo "$resource" | jq -r '.Name')
            type=$(echo "$resource" | jq -r '.Type')
            resources_affected+=("  • $name ($type)")
        done < <(echo "$resources" | jq -c '.[]')
    else
        resources_affected+=("  (Resource group appears to be empty)")
    fi
    
    # Confirm resource group deletion
    local operation_name
    local description
    if [[ "$KEEP_RESOURCE_GROUP" == "true" ]]; then
        operation_name="Resource Cleanup (keep group)"
        description="Remove all resources but keep the resource group"
    else
        operation_name="Resource Group Deletion"
        description="Delete the entire resource group and all contained resources"
    fi
    
    if confirm_operation "$operation_name" "$description" "${resources_affected[@]}"; then
        
        if [[ "$KEEP_RESOURCE_GROUP" == "true" ]]; then
            # Delete individual resources but keep the group
            log_info "Removing individual resources from resource group..."
            
            if [[ "$resource_count" -gt 0 ]]; then
                while IFS= read -r resource; do
                    local name
                    local type
                    name=$(echo "$resource" | jq -r '.Name')
                    type=$(echo "$resource" | jq -r '.Type')
                    
                    log_info "Deleting resource: $name"
                    if az resource delete --resource-group "$resource_group_name" \
                                         --name "$name" \
                                         --resource-type "$type" \
                                         --subscription "$AZURE_SUBSCRIPTION_ID"; then
                        log_success "Deleted: $name"
                    else
                        log_warning "Failed to delete: $name"
                        CLEANUP_ERRORS+=("Failed to delete resource: $name")
                    fi
                done < <(echo "$resources" | jq -c '.[]')
                
                log_success "Individual resource cleanup completed. Resource group '$resource_group_name' has been preserved."
            else
                log_success "No resources found to delete. Resource group '$resource_group_name' is already empty."
            fi
            
            CLEANUP_SUCCESS+=("Individual resources (resource group preserved)")
        else
            # Delete the entire resource group
            log_info "Deleting resource group: $resource_group_name"
            log_info "This operation may take several minutes depending on the resources..."
            
            if az group delete --name "$resource_group_name" \
                              --subscription "$AZURE_SUBSCRIPTION_ID" \
                              --yes --no-wait; then
                log_success "Resource group deletion initiated successfully."
                log_info "Note: Deletion is running in the background and may take 10-20 minutes to complete."
                CLEANUP_SUCCESS+=("Resource group deletion initiated")
            else
                log_warning "Failed to initiate resource group deletion."
                CLEANUP_ERRORS+=("Resource group deletion failed")
                return 1
            fi
        fi
        
        return 0
    else
        log_info "Skipping resource group cleanup."
        return 1
    fi
}

# Remove Power Platform environment
remove_power_platform_environment() {
    local environment_display_name="$1"
    local access_token="$2"
    
    log_header "🔥 Removing Power Platform environment (most destructive operation)..."
    
    # Get environment ID
    local environment_id
    if ! environment_id=$(get_power_platform_environment_id "$environment_display_name" "$access_token"); then
        log_success "Power Platform environment not found. May have already been deleted."
        return 0
    fi
    
    # Confirm environment deletion
    local resources_affected=(
        "Power Platform environment: $environment_display_name"
        "ALL data, apps, flows, connections, and custom connectors in the environment"
        "This action CANNOT be undone"
    )
    
    if confirm_operation "Power Platform Environment Deletion" \
                        "PERMANENTLY DELETE the entire Power Platform environment and ALL contained data" \
                        "${resources_affected[@]}"; then
        
        log_info "Deleting Power Platform environment: $environment_id"
        
        local delete_url="https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$environment_id?api-version=2023-06-01"
        
        local delete_response
        delete_response=$(curl -s -w "%{http_code}" -X DELETE \
                               -H "Authorization: Bearer $access_token" \
                               -H "Content-Type: application/json" \
                               "$delete_url")
        
        local http_code="${delete_response: -3}"
        local response_body="${delete_response%???}"
        
        case "$http_code" in
            200|202|204)
                log_success "Power Platform environment deletion initiated successfully."
                log_info "Environment deletion may take several minutes to complete."
                CLEANUP_SUCCESS+=("Power Platform environment deletion")
                return 0
                ;;
            404)
                log_success "Environment not found (404). It may have already been deleted."
                return 0
                ;;
            403)
                log_error "Access forbidden (403). You may not have sufficient permissions to delete environments."
                log_info "Required permissions: System Administrator or Environment Admin role"
                ;;
            400)
                log_warning "Bad request (400). The environment may be in a state that prevents deletion."
                log_info "Common causes: Active apps/flows, protected environment, or dependent resources"
                ;;
            *)
                log_error "HTTP Error $http_code occurred during environment deletion."
                log_info "Response: $response_body"
                ;;
        esac
        
        CLEANUP_ERRORS+=("Power Platform environment deletion failed")
        return 1
    else
        log_info "Skipping Power Platform environment deletion."
        return 1
    fi
}

# Show cleanup summary
show_cleanup_summary() {
    echo
    log_header "📋 CLEANUP SUMMARY"
    log_header "===================="
    
    if [[ ${#CLEANUP_SUCCESS[@]} -gt 0 ]]; then
        echo
        echo -e "${GREEN}✅ SUCCESSFUL OPERATIONS:${NC}"
        for success in "${CLEANUP_SUCCESS[@]}"; do
            echo -e "${GREEN}  ✓ $success${NC}"
        done
    fi
    
    if [[ ${#CLEANUP_ERRORS[@]} -gt 0 ]]; then
        echo
        echo -e "${RED}❌ ISSUES ENCOUNTERED:${NC}"
        for error in "${CLEANUP_ERRORS[@]}"; do
            echo -e "${RED}  ✗ $error${NC}"
        done
        
        echo
        log_warning "Some cleanup operations encountered issues. Please review the errors above."
        log_info "You may need to manually clean up remaining resources through the Azure Portal."
    fi
    
    if [[ ${#CLEANUP_SUCCESS[@]} -gt 0 && ${#CLEANUP_ERRORS[@]} -eq 0 ]]; then
        echo
        log_success "All cleanup operations completed successfully!"
        log_success "The Power Platform VNet integration has been fully removed."
    fi
    
    echo
    log_info "Cleanup operation completed at $(date '+%Y-%m-%d %H:%M:%S')"
}

# Main execution function
main() {
    echo -e "${CYAN}🧹 Power Platform VNet Integration Cleanup Script${NC}"
    echo -e "${CYAN}=================================================${NC}"
    log_info "Starting cleanup process at $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Import and validate environment configuration
    import_env_file "$ENV_FILE"
    validate_environment_variables
    
    # Ensure Azure CLI authentication and subscription context
    ensure_azure_login
    
    # Display cleanup plan
    echo
    log_header "🎯 CLEANUP PLAN"
    log_header "==============="
    log_info "Environment File: $ENV_FILE"
    log_info "Force Mode: $FORCE"
    log_info "Skip Power Platform: $SKIP_POWER_PLATFORM"
    log_info "Keep Resource Group: $KEEP_RESOURCE_GROUP"
    log_info "Remove Environment: $REMOVE_ENVIRONMENT"
    echo
    
    if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
        log_info "Target Subscription: $AZURE_SUBSCRIPTION_ID"
    fi
    if [[ -n "${RESOURCE_GROUP:-}" ]]; then
        log_info "Target Resource Group: $RESOURCE_GROUP"
    fi
    if [[ -n "${POWER_PLATFORM_ENVIRONMENT_NAME:-}" && "$SKIP_POWER_PLATFORM" != "true" ]]; then
        log_info "Target PP Environment: $POWER_PLATFORM_ENVIRONMENT_NAME"
    fi
    
    echo
    
    # Final confirmation for the entire cleanup process
    if [[ "$FORCE" != "true" ]]; then
        echo -e "${RED}⚠️  This will permanently remove Azure resources and Power Platform configurations!${NC}"
        echo -e "${RED}⚠️  Make sure you have proper backups if needed.${NC}"
        echo
        
        local response
        while true; do
            read -p "Are you sure you want to proceed with the complete cleanup? (yes/no): " response
            response=$(echo "$response" | tr '[:upper:]' '[:lower:]' | xargs)
            case "$response" in
                yes|y)
                    log_success "User confirmed complete cleanup - proceeding..."
                    break
                    ;;
                no|n)
                    log_info "Cleanup cancelled by user."
                    exit 0
                    ;;
                *)
                    echo "Please answer yes, no, y, or n."
                    ;;
            esac
        done
    fi
    
    # Execute cleanup operations in reverse order of deployment
    
    # Step 1: Remove Power Platform configuration first (dependencies)
    remove_power_platform_configuration
    
    # Step 2: Remove Power Platform environment if requested (most destructive operation)
    if [[ "$REMOVE_ENVIRONMENT" == "true" ]]; then
        if [[ -n "${POWER_PLATFORM_ENVIRONMENT_NAME:-}" ]]; then
            local access_token
            if access_token=$(get_power_platform_access_token); then
                if remove_power_platform_environment "$POWER_PLATFORM_ENVIRONMENT_NAME" "$access_token"; then
                    log_success "Power Platform environment removal completed."
                    CLEANUP_SUCCESS+=("Power Platform environment removal")
                else
                    log_warning "Power Platform environment removal encountered issues."
                    CLEANUP_ERRORS+=("Power Platform environment removal failed")
                fi
            else
                log_error "Failed to get access token for environment removal."
                CLEANUP_ERRORS+=("Power Platform access token for environment removal failed")
            fi
        else
            log_warning "POWER_PLATFORM_ENVIRONMENT_NAME not set - cannot remove environment."
            CLEANUP_ERRORS+=("POWER_PLATFORM_ENVIRONMENT_NAME not set")
        fi
    else
        echo
        log_info "Skipping Power Platform environment removal (not requested)."
        log_info "To remove the environment, use: ./5-Cleanup.sh --remove-environment"
    fi
    
    # Step 3: Remove Azure infrastructure
    remove_azure_infrastructure
    
    # Step 4: Preserve environment file for future reference
    echo
    log_info "Preserving environment file for future reference: $ENV_FILE"
    log_success "Environment configuration file has been kept intact for redeployment or troubleshooting."
    
    # Step 5: Display comprehensive summary
    show_cleanup_summary
    
    # Exit with appropriate code
    if [[ ${#CLEANUP_ERRORS[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Execute main function with all arguments
main "$@"
