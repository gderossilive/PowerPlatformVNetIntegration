#!/bin/bash

# =============================================================================
# Test APIM Service Status and Configuration
# =============================================================================

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/functions.sh"

# Required environment variables
REQUIRED_VARS=(
    "AZURE_SUBSCRIPTION_ID"
    "RESOURCE_GROUP"
    "APIM_SERVICE_NAME"
)

# Initialize script
init_script "APIM Service Test" "${REQUIRED_VARS[@]}"

# Function to test APIM service existence
test_apim_service_exists() {
    log_info "Testing if APIM service exists..."
    
    local apim_info=$(az apim show \
        --name "$APIM_SERVICE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --subscription "$AZURE_SUBSCRIPTION_ID" \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$apim_info" == "{}" ]]; then
        log_error "APIM service not found: $APIM_SERVICE_NAME"
        log_info "Resource Group: $RESOURCE_GROUP"
        return $EXIT_NOT_FOUND
    fi
    
    local apim_state=$(json_get_value "$apim_info" "provisioningState")
    local apim_sku=$(json_get_value "$apim_info" "sku.name")
    local apim_location=$(json_get_value "$apim_info" "location")
    
    log_success "APIM service found: $APIM_SERVICE_NAME"
    log_info "Provisioning State: $apim_state"
    log_info "SKU: $apim_sku"
    log_info "Location: $apim_location"
    
    if [[ "$apim_state" != "Succeeded" ]]; then
        log_warning "APIM service is not in 'Succeeded' state"
        return $EXIT_GENERAL_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Function to test APIM connectivity
test_apim_connectivity() {
    log_info "Testing APIM connectivity..."
    
    # Get APIM gateway URL
    local apim_info=$(az apim show \
        --name "$APIM_SERVICE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --subscription "$AZURE_SUBSCRIPTION_ID" \
        --output json 2>/dev/null)
    
    local gateway_url=$(json_get_value "$apim_info" "gatewayUrl")
    
    if [[ -z "$gateway_url" ]]; then
        log_error "Cannot determine APIM gateway URL"
        return $EXIT_GENERAL_ERROR
    fi
    
    log_info "Testing APIM gateway: $gateway_url"
    
    # Test basic connectivity
    if test_connectivity "$gateway_url" 15 404; then
        log_success "APIM gateway is accessible (expected 404 for root path)"
    else
        log_error "APIM gateway connectivity test failed"
        return $EXIT_NETWORK_ERROR
    fi
    
    # Test management API endpoint
    local mgmt_url=$(echo "$gateway_url" | sed 's/\.azure-api\.net/.management.azure-api.net/')
    
    if test_connectivity "$mgmt_url" 10 401; then
        log_success "APIM management endpoint is accessible (expected 401 without auth)"
    else
        log_warning "APIM management endpoint may not be accessible"
    fi
    
    return $EXIT_SUCCESS
}

# Function to test APIM APIs
test_apim_apis() {
    log_info "Testing APIM APIs..."
    
    # List APIs in APIM
    local apis=$(az apim api list \
        --service-name "$APIM_SERVICE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --subscription "$AZURE_SUBSCRIPTION_ID" \
        --output json 2>/dev/null || echo "[]")
    
    local api_count=$(echo "$apis" | jq '. | length' 2>/dev/null || echo "0")
    
    log_info "Found $api_count APIs in APIM service"
    
    if [[ "$api_count" -gt 0 ]]; then
        echo "$apis" | jq -r '.[] | "  - \(.displayName // .name) (\(.path))"' 2>/dev/null | head -10
        
        # Test specific Petstore API if configured
        if [[ -n "${APIM_API_NAME:-}" ]]; then
            log_info "Testing specific API: $APIM_API_NAME"
            
            local api_info=$(az apim api show \
                --api-id "$APIM_API_NAME" \
                --service-name "$APIM_SERVICE_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --subscription "$AZURE_SUBSCRIPTION_ID" \
                --output json 2>/dev/null || echo "{}")
            
            if [[ "$api_info" != "{}" ]]; then
                local api_path=$(json_get_value "$api_info" "path")
                local service_url=$(json_get_value "$api_info" "serviceUrl")
                
                log_success "API found: $APIM_API_NAME"
                log_info "API Path: $api_path"
                log_info "Service URL: $service_url"
            else
                log_warning "Specific API not found: $APIM_API_NAME"
            fi
        fi
    else
        log_warning "No APIs found in APIM service"
    fi
    
    return $EXIT_SUCCESS
}

# Function to test APIM subscriptions
test_apim_subscriptions() {
    log_info "Testing APIM subscriptions..."
    
    # List subscriptions
    local subscriptions=$(az apim subscription list \
        --service-name "$APIM_SERVICE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --subscription "$AZURE_SUBSCRIPTION_ID" \
        --output json 2>/dev/null || echo "[]")
    
    local sub_count=$(echo "$subscriptions" | jq '. | length' 2>/dev/null || echo "0")
    
    log_info "Found $sub_count APIM subscriptions"
    
    if [[ "$sub_count" -gt 0 ]]; then
        echo "$subscriptions" | jq -r '.[] | "  - \(.displayName // .name) (\(.state))"' 2>/dev/null | head -5
        
        # Check for active subscriptions
        local active_count=$(echo "$subscriptions" | jq '[.[] | select(.state == "active")] | length' 2>/dev/null || echo "0")
        
        if [[ "$active_count" -gt 0 ]]; then
            log_success "$active_count active subscriptions found"
        else
            log_warning "No active subscriptions found"
        fi
    else
        log_warning "No subscriptions found in APIM service"
    fi
    
    return $EXIT_SUCCESS
}

# Function to test APIM network configuration
test_apim_network_config() {
    log_info "Testing APIM network configuration..."
    
    local apim_info=$(az apim show \
        --name "$APIM_SERVICE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --subscription "$AZURE_SUBSCRIPTION_ID" \
        --output json 2>/dev/null)
    
    local virtual_network_type=$(json_get_value "$apim_info" "virtualNetworkType")
    local vnet_config=$(json_get_value "$apim_info" "virtualNetworkConfiguration")
    
    log_info "Virtual Network Type: ${virtual_network_type:-None}"
    
    if [[ "$virtual_network_type" == "Internal" ]] || [[ "$virtual_network_type" == "External" ]]; then
        local subnet_id=$(json_get_value "$vnet_config" "subnetResourceId")
        log_info "VNet Configuration: $virtual_network_type"
        log_info "Subnet ID: $subnet_id"
        
        # Test if subnet exists and is accessible
        if [[ -n "$subnet_id" ]]; then
            local subnet_subscription=$(echo "$subnet_id" | cut -d'/' -f3)
            local subnet_rg=$(echo "$subnet_id" | cut -d'/' -f5)
            local vnet_name=$(echo "$subnet_id" | cut -d'/' -f9)
            local subnet_name=$(echo "$subnet_id" | cut -d'/' -f11)
            
            local subnet_info=$(az network vnet subnet show \
                --subscription "$subnet_subscription" \
                --resource-group "$subnet_rg" \
                --vnet-name "$vnet_name" \
                --name "$subnet_name" \
                --output json 2>/dev/null || echo "{}")
            
            if [[ "$subnet_info" != "{}" ]]; then
                log_success "APIM subnet is accessible"
                local subnet_state=$(json_get_value "$subnet_info" "provisioningState")
                log_info "Subnet provisioning state: $subnet_state"
            else
                log_error "APIM subnet is not accessible"
                return $EXIT_NETWORK_ERROR
            fi
        fi
    else
        log_info "APIM is not configured for VNet integration"
    fi
    
    return $EXIT_SUCCESS
}

# Function to display APIM summary
display_apim_summary() {
    log_info "APIM Service Summary:"
    
    local apim_info=$(az apim show \
        --name "$APIM_SERVICE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --subscription "$AZURE_SUBSCRIPTION_ID" \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$apim_info" != "{}" ]]; then
        echo "  Name: $(json_get_value "$apim_info" "name")"
        echo "  Resource Group: $(json_get_value "$apim_info" "resourceGroup")"
        echo "  SKU: $(json_get_value "$apim_info" "sku.name")"
        echo "  Location: $(json_get_value "$apim_info" "location")"
        echo "  Gateway URL: $(json_get_value "$apim_info" "gatewayUrl")"
        echo "  VNet Type: $(json_get_value "$apim_info" "virtualNetworkType")"
        echo "  Provisioning State: $(json_get_value "$apim_info" "provisioningState")"
        
        # Get API and subscription counts
        local api_count=$(az apim api list \
            --service-name "$APIM_SERVICE_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --subscription "$AZURE_SUBSCRIPTION_ID" \
            --query "length(@)" --output tsv 2>/dev/null || echo "0")
        
        local sub_count=$(az apim subscription list \
            --service-name "$APIM_SERVICE_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --subscription "$AZURE_SUBSCRIPTION_ID" \
            --query "length(@)" --output tsv 2>/dev/null || echo "0")
        
        echo "  APIs: $api_count"
        echo "  Subscriptions: $sub_count"
    else
        echo "  Status: Not found or inaccessible"
    fi
}

# Main execution
main() {
    local exit_code=$EXIT_SUCCESS
    
    # Run APIM tests
    test_apim_service_exists || exit_code=$?
    test_apim_connectivity || exit_code=$?
    test_apim_apis || exit_code=$?
    test_apim_subscriptions || exit_code=$?
    test_apim_network_config || exit_code=$?
    
    # Display summary
    echo
    display_apim_summary
    
    return $exit_code
}

# Run main function and cleanup
if main; then
    cleanup_script "APIM Service Test" $EXIT_SUCCESS
    exit $EXIT_SUCCESS
else
    cleanup_script "APIM Service Test" $EXIT_GENERAL_ERROR
    exit $EXIT_GENERAL_ERROR
fi