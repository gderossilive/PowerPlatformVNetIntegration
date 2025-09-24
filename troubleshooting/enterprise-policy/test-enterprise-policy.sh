#!/bin/bash

# =============================================================================
# Test Enterprise Policy Existence and Configuration
# =============================================================================

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/functions.sh"

# Required environment variables
REQUIRED_VARS=(
    "AZURE_SUBSCRIPTION_ID"
    "RESOURCE_GROUP"
    "ENTERPRISE_POLICY_NAME"
)

# Initialize script
init_script "Enterprise Policy Test" "${REQUIRED_VARS[@]}"

# Function to test if enterprise policy exists
test_enterprise_policy_exists() {
    log_info "Testing if enterprise policy exists..."
    
    # Check if the enterprise policy exists
    local policy_info=$(az rest \
        --method GET \
        --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies/$ENTERPRISE_POLICY_NAME?api-version=2020-10-30" \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$policy_info" == "{}" ]] || [[ "$(json_get_value "$policy_info" "error")" != "" ]]; then
        log_error "Enterprise policy not found: $ENTERPRISE_POLICY_NAME"
        log_info "Resource Group: $RESOURCE_GROUP"
        return $EXIT_NOT_FOUND
    fi
    
    local policy_id=$(json_get_value "$policy_info" "id")
    local policy_location=$(json_get_value "$policy_info" "location")
    local policy_kind=$(json_get_value "$policy_info" "kind")
    
    log_success "Enterprise policy found: $ENTERPRISE_POLICY_NAME"
    log_info "Policy ID: $policy_id"
    log_info "Location: $policy_location"
    log_info "Kind: $policy_kind"
    
    return $EXIT_SUCCESS
}

# Function to test enterprise policy configuration
test_enterprise_policy_config() {
    log_info "Testing enterprise policy configuration..."
    
    # Get detailed policy configuration
    local policy_info=$(az rest \
        --method GET \
        --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies/$ENTERPRISE_POLICY_NAME?api-version=2020-10-30" \
        --output json 2>/dev/null)
    
    if [[ -z "$policy_info" ]] || [[ "$policy_info" == "{}" ]]; then
        log_error "Cannot retrieve enterprise policy configuration"
        return $EXIT_NOT_FOUND
    fi
    
    # Extract configuration details
    local properties=$(json_get_value "$policy_info" "properties")
    local network_injection=$(json_get_value "$properties" "networkInjection")
    local subnet_id=$(json_get_value "$network_injection" "subnets[0].name")
    local virtual_network_id=$(json_get_value "$network_injection" "virtualNetworks[0].id")
    
    log_info "Network Injection Configuration:"
    if [[ -n "$virtual_network_id" ]]; then
        log_success "Virtual Network configured: $virtual_network_id"
    else
        log_warning "No virtual network configured"
    fi
    
    if [[ -n "$subnet_id" ]]; then
        log_success "Subnet configured: $subnet_id"
    else
        log_warning "No subnet configured"
    fi
    
    # Check health status if available
    local health_status=$(json_get_value "$properties" "healthStatus")
    if [[ -n "$health_status" ]]; then
        log_info "Health Status: $health_status"
    fi
    
    return $EXIT_SUCCESS
}

# Function to list all enterprise policies in resource group
list_enterprise_policies() {
    log_info "Listing all enterprise policies in resource group..."
    
    local policies=$(az rest \
        --method GET \
        --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies?api-version=2020-10-30" \
        --output json 2>/dev/null || echo '{"value": []}')
    
    local policy_count=$(json_get_value "$policies" "value | length")
    
    if [[ "$policy_count" == "0" ]]; then
        log_warning "No enterprise policies found in resource group: $RESOURCE_GROUP"
        return $EXIT_SUCCESS
    fi
    
    log_info "Found $policy_count enterprise policies:"
    
    # List each policy
    echo "$policies" | jq -r '.value[] | "\(.name) (\(.location)) - \(.properties.healthStatus // "Unknown")"' 2>/dev/null | while read -r line; do
        echo "  - $line"
    done
    
    return $EXIT_SUCCESS
}

# Function to test enterprise policy network connectivity
test_enterprise_policy_network() {
    log_info "Testing enterprise policy network connectivity..."
    
    # Get policy configuration
    local policy_info=$(az rest \
        --method GET \
        --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies/$ENTERPRISE_POLICY_NAME?api-version=2020-10-30" \
        --output json 2>/dev/null)
    
    if [[ -z "$policy_info" ]] || [[ "$policy_info" == "{}" ]]; then
        log_error "Cannot retrieve enterprise policy for network test"
        return $EXIT_NOT_FOUND
    fi
    
    # Extract network configuration
    local properties=$(json_get_value "$policy_info" "properties")
    local virtual_network_id=$(json_get_value "$properties" "networkInjection.virtualNetworks[0].id")
    
    if [[ -z "$virtual_network_id" ]]; then
        log_warning "No virtual network configured for enterprise policy"
        return $EXIT_SUCCESS
    fi
    
    # Extract VNet details from resource ID
    local vnet_subscription=$(echo "$virtual_network_id" | cut -d'/' -f3)
    local vnet_resource_group=$(echo "$virtual_network_id" | cut -d'/' -f5)
    local vnet_name=$(echo "$virtual_network_id" | cut -d'/' -f9)
    
    # Test if VNet exists and is accessible
    local vnet_info=$(az network vnet show \
        --subscription "$vnet_subscription" \
        --resource-group "$vnet_resource_group" \
        --name "$vnet_name" \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$vnet_info" == "{}" ]]; then
        log_error "Cannot access virtual network: $vnet_name"
        log_info "VNet Resource Group: $vnet_resource_group"
        log_info "VNet Subscription: $vnet_subscription"
        return $EXIT_NOT_FOUND
    fi
    
    local vnet_state=$(json_get_value "$vnet_info" "provisioningState")
    log_success "Virtual network accessible: $vnet_name"
    log_info "VNet provisioning state: $vnet_state"
    
    return $EXIT_SUCCESS
}

# Function to display enterprise policy summary
display_enterprise_policy_summary() {
    log_info "Enterprise Policy Summary:"
    
    local policy_info=$(az rest \
        --method GET \
        --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.PowerPlatform/enterprisePolicies/$ENTERPRISE_POLICY_NAME?api-version=2020-10-30" \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$policy_info" != "{}" ]] && [[ "$(json_get_value "$policy_info" "error")" == "" ]]; then
        echo "  Name: $(json_get_value "$policy_info" "name")"
        echo "  Resource Group: $(json_get_value "$policy_info" "id" | cut -d'/' -f5)"
        echo "  Location: $(json_get_value "$policy_info" "location")"
        echo "  Kind: $(json_get_value "$policy_info" "kind")"
        
        local properties=$(json_get_value "$policy_info" "properties")
        local health_status=$(json_get_value "$properties" "healthStatus")
        local virtual_network_id=$(json_get_value "$properties" "networkInjection.virtualNetworks[0].id")
        
        echo "  Health Status: ${health_status:-Unknown}"
        if [[ -n "$virtual_network_id" ]]; then
            echo "  Virtual Network: $(basename "$virtual_network_id")"
        else
            echo "  Virtual Network: Not configured"
        fi
    else
        echo "  Status: Not found or inaccessible"
    fi
}

# Main execution
main() {
    local exit_code=$EXIT_SUCCESS
    
    # Run enterprise policy tests
    test_enterprise_policy_exists || exit_code=$?
    test_enterprise_policy_config || exit_code=$?
    list_enterprise_policies || exit_code=$?
    test_enterprise_policy_network || exit_code=$?
    
    # Display summary
    echo
    display_enterprise_policy_summary
    
    return $exit_code
}

# Run main function and cleanup
if main; then
    cleanup_script "Enterprise Policy Test" $EXIT_SUCCESS
    exit $EXIT_SUCCESS
else
    cleanup_script "Enterprise Policy Test" $EXIT_GENERAL_ERROR
    exit $EXIT_GENERAL_ERROR
fi