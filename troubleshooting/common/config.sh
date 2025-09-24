#!/bin/bash

# =============================================================================
# Common Configuration Functions for Power Platform VNet Integration Troubleshooting
# =============================================================================

# Source logging functions
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMON_DIR/logging.sh"

# Default configuration values
export DEFAULT_AZURE_LOCATION="westeurope"
export DEFAULT_POWER_PLATFORM_LOCATION="europe"

# Configuration validation
validate_env_vars() {
    local required_vars=("$@")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

# Load environment configuration
load_env_config() {
    local env_file="${1:-".env"}"
    
    # Try to find .env file in current directory or parent directories
    local search_dir="$(pwd)"
    while [[ "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/$env_file" ]]; then
            env_file="$search_dir/$env_file"
            break
        fi
        search_dir="$(dirname "$search_dir")"
    done
    
    if [[ -f "$env_file" ]]; then
        log_debug "Loading environment variables from: $env_file"
        # Export variables from .env file, handling potential Windows line endings
        set -a  # Automatically export all variables
        source <(sed 's/\r$//' "$env_file")
        set +a  # Stop automatically exporting
        log_success "Environment variables loaded from $env_file"
        return 0
    else
        log_warning "Environment file not found: $env_file"
        return 1
    fi
}

# Get Azure resource group from environment or AZD
get_resource_group() {
    if [[ -n "${RESOURCE_GROUP:-}" ]]; then
        echo "$RESOURCE_GROUP"
        return 0
    fi
    
    # Try to get from AZD environment
    if command -v azd >/dev/null 2>&1; then
        local azd_rg=$(azd env get-values 2>/dev/null | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')
        if [[ -n "$azd_rg" ]]; then
            echo "$azd_rg"
            return 0
        fi
    fi
    
    # Try to construct from environment name
    if [[ -n "${POWER_PLATFORM_ENVIRONMENT_NAME:-}" ]]; then
        echo "${POWER_PLATFORM_ENVIRONMENT_NAME}-vdu"
        return 0
    fi
    
    log_error "Could not determine resource group"
    return 1
}

# Get enterprise policy name
get_enterprise_policy_name() {
    if [[ -n "${ENTERPRISE_POLICY_NAME:-}" ]]; then
        echo "$ENTERPRISE_POLICY_NAME"
        return 0
    fi
    
    # Try to construct from environment name
    if [[ -n "${POWER_PLATFORM_ENVIRONMENT_NAME:-}" ]]; then
        echo "ep-${POWER_PLATFORM_ENVIRONMENT_NAME}-vdu"
        return 0
    fi
    
    log_error "Could not determine enterprise policy name"
    return 1
}

# Get APIM service name
get_apim_name() {
    if [[ -n "${APIM_NAME:-}" ]]; then
        echo "$APIM_NAME"
        return 0
    fi
    
    # Try to construct from environment name
    local resource_group=$(get_resource_group)
    if [[ $? -eq 0 ]]; then
        local apim_name=$(az apim list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null)
        if [[ -n "$apim_name" && "$apim_name" != "null" ]]; then
            echo "$apim_name"
            return 0
        fi
    fi
    
    # Default naming pattern
    echo "az-apim-vdu"
    return 0
}

# Validate Azure CLI authentication
validate_azure_auth() {
    local required_tenant_id="${1:-$TENANT_ID}"
    
    if ! command -v az >/dev/null 2>&1; then
        log_error "Azure CLI is not installed"
        return 1
    fi
    
    # Check if logged in
    local current_account=$(az account show --query "tenantId" -o tsv 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "Not logged into Azure CLI. Please run: az login"
        return 1
    fi
    
    # Check correct tenant
    if [[ -n "$required_tenant_id" && "$current_account" != "$required_tenant_id" ]]; then
        log_error "Logged into wrong tenant. Expected: $required_tenant_id, Current: $current_account"
        log_info "Please run: az login --tenant $required_tenant_id"
        return 1
    fi
    
    # Set subscription if provided
    if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
        if ! az account set --subscription "$AZURE_SUBSCRIPTION_ID" 2>/dev/null; then
            log_error "Failed to set Azure subscription: $AZURE_SUBSCRIPTION_ID"
            return 1
        fi
    fi
    
    log_success "Azure CLI authentication validated"
    return 0
}

# Get Power Platform access token
get_pp_access_token() {
    local token=$(az account get-access-token \
        --resource https://service.powerapps.com/ \
        --query accessToken \
        --output tsv 2>/dev/null)
    
    if [[ -z "$token" || "$token" == "null" ]]; then
        log_error "Failed to get Power Platform access token"
        return 1
    fi
    
    echo "$token"
    return 0
}

# Get Azure Management access token
get_azure_mgmt_token() {
    local token=$(az account get-access-token \
        --resource https://management.azure.com/ \
        --query accessToken \
        --output tsv 2>/dev/null)
    
    if [[ -z "$token" || "$token" == "null" ]]; then
        log_error "Failed to get Azure Management access token"
        return 1
    fi
    
    echo "$token"
    return 0
}

# Check if resource exists
resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_group="${3:-$(get_resource_group)}"
    
    if [[ -z "$resource_group" ]]; then
        log_error "Resource group not specified"
        return 1
    fi
    
    local exists=$(az resource list \
        --resource-group "$resource_group" \
        --resource-type "$resource_type" \
        --name "$resource_name" \
        --query "length(@)" -o tsv 2>/dev/null)
    
    if [[ "$exists" == "1" ]]; then
        return 0
    else
        return 1
    fi
}

# Wait for operation to complete
wait_for_operation() {
    local check_command="$1"
    local success_condition="$2"
    local timeout="${3:-300}" # 5 minutes default
    local interval="${4:-10}" # 10 seconds default
    
    local elapsed=0
    
    log_info "Waiting for operation to complete (timeout: ${timeout}s)..."
    
    while [[ $elapsed -lt $timeout ]]; do
        local result=$(eval "$check_command" 2>/dev/null)
        
        if [[ "$result" == "$success_condition" ]]; then
            log_success "Operation completed successfully"
            return 0
        fi
        
        log_debug "Current status: $result (expected: $success_condition)"
        sleep $interval
        elapsed=$((elapsed + interval))
        
        # Show progress
        if [[ $((elapsed % 60)) -eq 0 ]]; then
            log_info "Still waiting... (${elapsed}s elapsed)"
        fi
    done
    
    log_warning "Operation did not complete within timeout period"
    return 1
}

# Export all functions
export -f validate_env_vars
export -f load_env_config
export -f get_resource_group
export -f get_enterprise_policy_name
export -f get_apim_name
export -f validate_azure_auth
export -f get_pp_access_token
export -f get_azure_mgmt_token
export -f resource_exists
export -f wait_for_operation