#!/bin/bash

# =============================================================================
# Test Azure CLI Authentication and Access
# =============================================================================

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/functions.sh"

# Required environment variables
REQUIRED_VARS=(
    "AZURE_SUBSCRIPTION_ID"
)

# Initialize script
init_script "Azure Authentication Test" "${REQUIRED_VARS[@]}"

# Function to test basic Azure CLI authentication
test_basic_auth() {
    log_info "Testing basic Azure CLI authentication..."
    
    # Test Azure CLI is available
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not found in PATH"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Test Azure CLI login status
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure CLI"
        log_info "Please run: az login"
        return $EXIT_AUTH_ERROR
    fi
    
    # Get current account info
    local account_info=$(az account show --output json)
    local subscription_id=$(json_get_value "$account_info" "id")
    local user_name=$(json_get_value "$account_info" "user.name")
    local tenant_id=$(json_get_value "$account_info" "tenantId")
    
    log_success "Authenticated as: $user_name"
    log_info "Current subscription: $subscription_id"
    log_info "Tenant ID: $tenant_id"
    
    return $EXIT_SUCCESS
}

# Function to test subscription access
test_subscription_access() {
    log_info "Testing subscription access..."
    
    # Check if we can access the required subscription
    if ! az account set --subscription "$AZURE_SUBSCRIPTION_ID" &> /dev/null; then
        log_error "Cannot access subscription: $AZURE_SUBSCRIPTION_ID"
        return $EXIT_PERMISSION_ERROR
    fi
    
    # Test basic read operations
    if ! az group list --query "[].name" --output tsv &> /dev/null; then
        log_error "Cannot list resource groups in subscription"
        return $EXIT_PERMISSION_ERROR
    fi
    
    local group_count=$(az group list --query "length(@)" --output tsv)
    log_success "Can access subscription with $group_count resource groups"
    
    return $EXIT_SUCCESS
}

# Function to test Power Platform CLI authentication
test_power_platform_auth() {
    log_info "Testing Power Platform CLI authentication..."
    
    # Test Power Platform CLI is available
    if ! command -v pac &> /dev/null; then
        log_warning "Power Platform CLI not found in PATH"
        log_info "Power Platform operations can still be performed via REST API"
        log_info "Optional: Install PAC CLI with dotnet tool install --global Microsoft.PowerApps.CLI.Tool"
        return $EXIT_SUCCESS  # Changed from EXIT_GENERAL_ERROR to EXIT_SUCCESS
    fi
    
    # Test Power Platform CLI authentication
    if ! pac auth list &> /dev/null; then
        log_warning "Not authenticated to Power Platform CLI"
        log_info "Please run: pac auth create"
        return $EXIT_SUCCESS  # Changed from EXIT_AUTH_ERROR to EXIT_SUCCESS
    fi
    
    # Get authentication profiles
    local auth_output=$(pac auth list 2>/dev/null || echo "")
    if [[ -n "$auth_output" ]]; then
        log_success "Power Platform CLI authentication found"
        echo "$auth_output" | while read -r line; do
            if [[ "$line" == *"*"* ]]; then
                log_info "Active profile: $(echo "$line" | sed 's/\*//g' | trim_whitespace)"
            fi
        done
    fi
    
    return $EXIT_SUCCESS
}

# Function to test required permissions
test_required_permissions() {
    log_info "Testing required Azure permissions..."
    
    local permissions_ok=true
    
    # Test ability to read resource groups
    if ! az group list --query "[0].name" --output tsv &> /dev/null; then
        log_error "Missing permission: Cannot read resource groups"
        permissions_ok=false
    fi
    
    # Test ability to read role assignments
    if ! az role assignment list --subscription "$AZURE_SUBSCRIPTION_ID" --query "[0].roleDefinitionName" --output tsv &> /dev/null; then
        log_error "Missing permission: Cannot read role assignments"
        permissions_ok=false
    fi
    
    # Test ability to read network resources
    if ! az network vnet list --query "[0].name" --output tsv &> /dev/null; then
        log_error "Missing permission: Cannot read virtual networks"
        permissions_ok=false
    fi
    
    if [[ "$permissions_ok" == true ]]; then
        log_success "All required permissions available"
        return $EXIT_SUCCESS
    else
        log_error "Some required permissions are missing"
        return $EXIT_PERMISSION_ERROR
    fi
}

# Function to display authentication summary
display_auth_summary() {
    log_info "Authentication Summary:"
    
    # Azure CLI info
    local account_info=$(az account show --output json 2>/dev/null || echo "{}")
    if [[ "$account_info" != "{}" ]]; then
        echo "  Azure CLI:"
        echo "    User: $(json_get_value "$account_info" "user.name")"
        echo "    Subscription: $(json_get_value "$account_info" "name") ($(json_get_value "$account_info" "id"))"
        echo "    Tenant: $(json_get_value "$account_info" "tenantId")"
    else
        echo "  Azure CLI: Not authenticated"
    fi
    
    # Power Platform CLI info
    local pac_auth=$(pac auth list 2>/dev/null || echo "")
    if [[ -n "$pac_auth" ]]; then
        echo "  Power Platform CLI: Authenticated"
        echo "$pac_auth" | while read -r line; do
            if [[ "$line" == *"*"* ]]; then
                echo "    Active: $(echo "$line" | sed 's/\*//g' | trim_whitespace)"
            fi
        done
    else
        echo "  Power Platform CLI: Not authenticated"
    fi
}

# Main execution
main() {
    local exit_code=$EXIT_SUCCESS
    
    # Run authentication tests
    test_basic_auth || exit_code=$?
    test_subscription_access || exit_code=$?
    test_power_platform_auth || exit_code=$?
    test_required_permissions || exit_code=$?
    
    # Display summary
    echo
    display_auth_summary
    
    return $exit_code
}

# Run main function and cleanup
if main; then
    cleanup_script "Azure Authentication Test" $EXIT_SUCCESS
    exit $EXIT_SUCCESS
else
    cleanup_script "Azure Authentication Test" $EXIT_GENERAL_ERROR
    exit $EXIT_GENERAL_ERROR
fi