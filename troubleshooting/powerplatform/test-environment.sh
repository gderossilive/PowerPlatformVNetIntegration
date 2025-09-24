#!/bin/bash

# =============================================================================
# Test Power Platform Environment Status and Configuration
# =============================================================================

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/functions.sh"

# Required environment variables
REQUIRED_VARS=(
    "POWER_PLATFORM_ENVIRONMENT_ID"
    "POWER_PLATFORM_ENVIRONMENT_NAME"
)

# Initialize script
init_script "Power Platform Environment Test" "${REQUIRED_VARS[@]}"

# Function to test Power Platform CLI availability
test_pac_cli_available() {
    log_info "Testing Power Platform CLI availability..."
    
    if ! command -v pac &> /dev/null; then
        log_warning "Power Platform CLI not found in PATH"
        log_info "Will use REST API for Power Platform operations"
        return $EXIT_SUCCESS  # Changed to success since we can use REST API
    fi
    
    # Test authentication
    if ! pac auth list &> /dev/null; then
        log_warning "Not authenticated to Power Platform CLI"
        log_info "Will use Azure CLI token for REST API operations"
        return $EXIT_SUCCESS  # Changed to success since we can use Azure CLI token
    fi
    
    log_success "Power Platform CLI is available and authenticated"
    return $EXIT_SUCCESS
}

# Function to test environment existence
test_environment_exists() {
    log_info "Testing if Power Platform environment exists..."
    
    # Use REST API to check environment
    local access_token=$(az account get-access-token --resource https://service.powerapps.com/ --query accessToken -o tsv 2>/dev/null)
    
    if [[ -z "$access_token" ]]; then
        log_error "Cannot get Power Platform access token"
        return $EXIT_AUTH_ERROR
    fi
    
    local env_info=$(curl -s -H "Authorization: Bearer $access_token" \
        "https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$POWER_PLATFORM_ENVIRONMENT_ID?api-version=2020-06-01" 2>/dev/null || echo "{}")
    
    if [[ "$env_info" == "{}" ]] || [[ "$(json_get_value "$env_info" "error")" != "" ]]; then
        log_error "Power Platform environment not found or not accessible: $POWER_PLATFORM_ENVIRONMENT_ID"
        log_info "This may be due to permissions or the environment may not exist"
        return $EXIT_NOT_FOUND
    fi
    
    log_success "Power Platform environment found: $POWER_PLATFORM_ENVIRONMENT_NAME"
    log_info "Environment ID: $POWER_PLATFORM_ENVIRONMENT_ID"
    
    return $EXIT_SUCCESS
}

# Function to test environment status
test_environment_status() {
    log_info "Testing Power Platform environment status..."
    
    # Get environment details using REST API
    local env_info=$(curl -s -H "Authorization: Bearer $(az account get-access-token --resource https://service.powerapps.com/ --query accessToken -o tsv)" \
        "https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$POWER_PLATFORM_ENVIRONMENT_ID?api-version=2020-06-01" 2>/dev/null || echo "{}")
    
    if [[ "$env_info" == "{}" ]] || [[ "$(json_get_value "$env_info" "error")" != "" ]]; then
        log_warning "Cannot retrieve environment details via REST API"
        # Fallback to PAC CLI
        local env_status=$(pac admin list --environment "$POWER_PLATFORM_ENVIRONMENT_ID" 2>/dev/null | grep -i "state\|status" || echo "Unknown")
        log_info "Environment status (PAC CLI): $env_status"
        return $EXIT_SUCCESS
    fi
    
    local properties=$(json_get_value "$env_info" "properties")
    local state=$(json_get_value "$properties" "states.lifecycle.id")
    local provisioning_state=$(json_get_value "$properties" "provisioningState")
    local environment_type=$(json_get_value "$properties" "environmentType")
    local region=$(json_get_value "$properties" "azureRegionHint")
    
    log_info "Environment Details:"
    echo "  State: ${state:-Unknown}"
    echo "  Provisioning State: ${provisioning_state:-Unknown}"
    echo "  Type: ${environment_type:-Unknown}"
    echo "  Region: ${region:-Unknown}"
    
    if [[ "$state" == "Ready" ]] || [[ "$provisioning_state" == "Succeeded" ]]; then
        log_success "Environment is in healthy state"
        return $EXIT_SUCCESS
    else
        log_warning "Environment may not be in optimal state"
        return $EXIT_SUCCESS
    fi
}

# Function to test environment connectivity
test_environment_connectivity() {
    log_info "Testing Power Platform environment connectivity..."
    
    # Test connectivity to Power Platform APIs
    local base_url="https://api.powerapps.com"
    local test_url="$base_url/providers/Microsoft.PowerApps/environments?api-version=2020-06-01"
    
    if test_connectivity "$test_url" 10 200; then
        log_success "Power Platform API connectivity successful"
    else
        log_error "Cannot connect to Power Platform APIs"
        return $EXIT_NETWORK_ERROR
    fi
    
    # Test specific environment endpoint
    local env_url="$base_url/providers/Microsoft.PowerApps/environments/$POWER_PLATFORM_ENVIRONMENT_ID?api-version=2020-06-01"
    
    # Get access token for Power Platform
    local access_token=$(az account get-access-token --resource https://service.powerapps.com/ --query accessToken -o tsv 2>/dev/null)
    
    if [[ -z "$access_token" ]]; then
        log_warning "Cannot get Power Platform access token"
        return $EXIT_AUTH_ERROR
    fi
    
    local response=$(curl -s -w "%{http_code}" \
        -H "Authorization: Bearer $access_token" \
        -o /dev/null \
        "$env_url" 2>/dev/null || echo "000")
    
    if [[ "$response" == "200" ]]; then
        log_success "Environment endpoint accessible"
        return $EXIT_SUCCESS
    else
        log_error "Environment endpoint not accessible (HTTP $response)"
        return $EXIT_API_ERROR
    fi
}

# Function to test environment security and permissions
test_environment_permissions() {
    log_info "Testing environment permissions..."
    
    # Try to list apps in the environment (requires read permission)
    local apps_url="https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$POWER_PLATFORM_ENVIRONMENT_ID/apps?api-version=2020-06-01"
    local access_token=$(az account get-access-token --resource https://service.powerapps.com/ --query accessToken -o tsv 2>/dev/null)
    
    if [[ -z "$access_token" ]]; then
        log_warning "Cannot get access token for permission test"
        return $EXIT_AUTH_ERROR
    fi
    
    local response=$(curl -s -w "%{http_code}" \
        -H "Authorization: Bearer $access_token" \
        -o /dev/null \
        "$apps_url" 2>/dev/null || echo "000")
    
    case "$response" in
        200)
            log_success "Have read permissions on environment"
            ;;
        403)
            log_warning "Limited permissions on environment"
            ;;
        404)
            log_error "Environment not found or no access"
            return $EXIT_NOT_FOUND
            ;;
        *)
            log_warning "Unknown permission status (HTTP $response)"
            ;;
    esac
    
    return $EXIT_SUCCESS
}

# Function to display environment summary
display_environment_summary() {
    log_info "Power Platform Environment Summary:"
    
    echo "  Name: $POWER_PLATFORM_ENVIRONMENT_NAME"
    echo "  ID: $POWER_PLATFORM_ENVIRONMENT_ID"
    
    # Try to get additional details
    local access_token=$(az account get-access-token --resource https://service.powerapps.com/ --query accessToken -o tsv 2>/dev/null)
    
    if [[ -n "$access_token" ]]; then
        local env_info=$(curl -s -H "Authorization: Bearer $access_token" \
            "https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$POWER_PLATFORM_ENVIRONMENT_ID?api-version=2020-06-01" 2>/dev/null || echo "{}")
        
        if [[ "$env_info" != "{}" ]] && [[ "$(json_get_value "$env_info" "error")" == "" ]]; then
            local properties=$(json_get_value "$env_info" "properties")
            echo "  Type: $(json_get_value "$properties" "environmentType")"
            echo "  Region: $(json_get_value "$properties" "azureRegionHint")"
            echo "  State: $(json_get_value "$properties" "states.lifecycle.id")"
            echo "  URL: $(json_get_value "$properties" "linkedEnvironmentMetadata.instanceUrl")"
        else
            echo "  Additional details: Not accessible"
        fi
    else
        echo "  Additional details: Authentication required"
    fi
}

# Main execution
main() {
    local exit_code=$EXIT_SUCCESS
    
    # Run environment tests
    test_pac_cli_available || exit_code=$?
    test_environment_exists || exit_code=$?
    test_environment_status || exit_code=$?
    test_environment_connectivity || exit_code=$?
    test_environment_permissions || exit_code=$?
    
    # Display summary
    echo
    display_environment_summary
    
    return $exit_code
}

# Run main function and cleanup
if main; then
    cleanup_script "Power Platform Environment Test" $EXIT_SUCCESS
    exit $EXIT_SUCCESS
else
    cleanup_script "Power Platform Environment Test" $EXIT_GENERAL_ERROR
    exit $EXIT_GENERAL_ERROR
fi