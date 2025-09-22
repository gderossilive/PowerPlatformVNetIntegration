#!/bin/bash

# =============================================================================
# Power Platform Custom Connector Creation Script (Bash Version)
# =============================================================================
#
# SYNOPSIS
#     Creates custom connectors in Power Platform from Azure API Management APIs.
#
# DESCRIPTION
#     This script automates the creation of custom connectors in Power Platform by:
#     1. Automatically importing Petstore API to APIM (if needed)
#     2. Exporting API definitions from Azure API Management (APIM)
#     3. Creating APIM subscription keys for connector authentication
#     4. Using Power Platform APIs to create custom connectors
#     5. Configuring security settings and connection parameters
#
#     The script supports both the Petstore sample API (with automatic import) and custom APIs 
#     deployed in APIM. It uses the Power Platform Dataverse API and Power Apps API for 
#     programmatic connector creation, eliminating the need for manual portal configuration.

set -euo pipefail  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script parameters with defaults
API_ID="${1:-petstore-api}"
CONNECTOR_NAME="${2:-}"
SUBSCRIPTION_NAME="${3:-}"
FORCE="${4:-false}"

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

echo "🔌 Power Platform Custom Connector Creation"
echo "==========================================="

# Function to load and validate environment variables
load_environment_variables() {
    local env_file="./.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        exit 1
    fi
    
    log_info "Loading environment variables from: $env_file"
    
    # Export variables from .env file, handling potential Windows line endings
    set -a  # Automatically export all variables
    source <(sed 's/\r$//' "$env_file")
    set +a  # Stop automatically exporting
    
    # Validate required environment variables
    local required_vars=("TENANT_ID" "AZURE_SUBSCRIPTION_ID" "POWER_PLATFORM_ENVIRONMENT_NAME" 
                         "POWER_PLATFORM_ENVIRONMENT_ID" "RESOURCE_GROUP" "APIM_NAME")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please run infrastructure deployment first."
        exit 1
    fi
    
    log_success "Environment variables loaded and validated."
}

# Function to test Azure authentication
test_azure_authentication() {
    log_info "Validating Azure CLI authentication..."
    
    # Check if logged in to correct tenant
    local current_account
    current_account=$(az account show --query "tenantId" -o tsv 2>/dev/null || echo "")
    
    if [[ "$current_account" != "$TENANT_ID" ]]; then
        log_error "Not logged into the correct Azure tenant. Expected: $TENANT_ID, Current: $current_account"
        log_error "Please run: az login --tenant $TENANT_ID"
        exit 1
    fi
    
    # Set the active subscription
    log_info "Setting Azure subscription: $AZURE_SUBSCRIPTION_ID"
    if ! az account set --subscription "$AZURE_SUBSCRIPTION_ID"; then
        log_error "Failed to set Azure subscription."
        exit 1
    fi
    
    log_success "Azure CLI configured successfully."
}

# Function to get Power Platform access token
get_power_platform_token() {
    log_info "Obtaining Power Platform access token..."
    
    local token
    token=$(az account get-access-token --resource "https://service.powerapps.com/" --query accessToken --output tsv)
    
    if [[ -z "$token" ]]; then
        log_error "Failed to obtain Power Platform access token"
        exit 1
    fi
    
    echo "$token"
}

# Function to import Petstore API to APIM if it doesn't exist
import_petstore_api() {
    local api_id="$1"
    
    if [[ "$api_id" != "petstore-api" ]]; then
        log_error "Automatic import is only supported for 'petstore-api'. For custom APIs, please import them manually to APIM first."
        exit 1
    fi
    
    log_info "Importing Petstore API to APIM..."
    
    # Check if API already exists
    if az apim api show --resource-group "$RESOURCE_GROUP" --service-name "$APIM_NAME" --api-id "$api_id" >/dev/null 2>&1; then
        log_info "Petstore API already exists in APIM, skipping import."
        return 0
    fi
    
    # Import the API
    log_info "Importing Petstore API from OpenAPI specification..."
    
    if ! az apim api import \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$api_id" \
        --specification-format OpenApi \
        --specification-url "https://petstore3.swagger.io/api/v3/openapi.json" \
        --path "/petstore" \
        --display-name "Petstore API" \
        --service-url "https://petstore3.swagger.io/" \
        --output json >/dev/null 2>&1; then
        log_error "Failed to import Petstore API"
        exit 1
    fi
    
    log_success "Petstore API imported successfully to APIM"
    
    # Verify the API was imported
    if ! az apim api show --resource-group "$RESOURCE_GROUP" --service-name "$APIM_NAME" --api-id "$api_id" --query "id" -o tsv >/dev/null 2>&1; then
        log_error "Failed to verify imported API"
        exit 1
    fi
    
    log_success "API import verified successfully"
}

# Function to export API definition from APIM
export_api_definition() {
    local api_id="$1"
    local output_file="$2"
    
    log_info "Exporting API definition for: $api_id"
    
    # Check if API exists in APIM
    if ! az apim api show --resource-group "$RESOURCE_GROUP" --service-name "$APIM_NAME" --api-id "$api_id" >/dev/null 2>&1; then
        # Try to import the API if it's the Petstore API
        if [[ "$api_id" == "petstore-api" ]]; then
            import_petstore_api "$api_id"
        else
            log_error "API '$api_id' not found in APIM. Please import it manually first."
            exit 1
        fi
    fi
    
    # Create temporary directory for export
    local temp_dir="./temp-export"
    mkdir -p "$temp_dir"
    
    # Export the API definition
    log_info "Exporting OpenAPI definition..."
    
    if ! az apim api export \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --api-id "$api_id" \
        --export-format "OpenApiJsonFile" \
        --file-path "$temp_dir" >/dev/null 2>&1; then
        log_error "Failed to export API definition"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Find the exported file (Azure CLI creates a file with a specific naming pattern)
    local exported_file
    exported_file=$(find "$temp_dir" -name "*openapi*.json" | head -1)
    
    if [[ -z "$exported_file" || ! -f "$exported_file" ]]; then
        log_error "Exported API definition file not found"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Copy to final location
    cp "$exported_file" "$output_file"
    rm -rf "$temp_dir"
    
    log_success "API definition exported to: $output_file"
}

# Function to create APIM subscription
create_apim_subscription() {
    local subscription_id="$1"
    local display_name="$2"
    local api_id="$3"
    
    log_info "Creating APIM subscription: $display_name"
    
    # REST API URL for APIM subscription
    local subscription_url="https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ApiManagement/service/$APIM_NAME/subscriptions/$subscription_id"
    
    # Check if subscription already exists
    local existing_subscription
    existing_subscription=$(az rest --method GET --url "${subscription_url}?api-version=2021-08-01" --output json 2>/dev/null || echo "")
    
    if [[ -n "$existing_subscription" && "$existing_subscription" != "null" ]]; then
        log_info "Subscription already exists, retrieving existing key..."
    else
        # Create the subscription
        log_info "Creating new subscription..."
        
        # Determine scope - scope to specific API if provided
        local scope="/apis/$api_id"
        log_info "Setting subscription scope to API: $api_id"
        
        # Create subscription payload
        local subscription_payload
        subscription_payload=$(cat <<EOF
{
    "properties": {
        "displayName": "$display_name",
        "scope": "$scope",
        "state": "active"
    }
}
EOF
        )
        
        if ! az rest --method PUT --url "${subscription_url}?api-version=2021-08-01" --body "$subscription_payload" --headers "Content-Type=application/json" --output json >/dev/null 2>&1; then
            log_error "Failed to create APIM subscription"
            exit 1
        fi
        
        log_success "APIM subscription created successfully"
        
        # Brief pause for Azure to propagate the subscription
        sleep 2
    fi
    
    # Get the subscription key
    local key_url="${subscription_url}/listSecrets"
    local key_data
    key_data=$(az rest --method POST --url "${key_url}?api-version=2021-08-01" --output json 2>/dev/null)
    
    if [[ -z "$key_data" ]]; then
        log_error "Failed to retrieve subscription key"
        exit 1
    fi
    
    local subscription_key
    subscription_key=$(echo "$key_data" | jq -r '.primaryKey // empty')
    
    if [[ -z "$subscription_key" ]]; then
        log_error "Failed to extract subscription key from response"
        exit 1
    fi
    
    log_success "Subscription key retrieved successfully"
    
    # Save key to environment file
    save_subscription_key_to_env "$subscription_key" "$subscription_id"
    
    echo "$subscription_key"
}

# Function to save subscription key to environment file
save_subscription_key_to_env() {
    local subscription_key="$1"
    local subscription_name="$2"
    
    local env_file="./.env"
    local key_var_name="APIM_SUBSCRIPTION_KEY_${subscription_name^^}"
    key_var_name=$(echo "$key_var_name" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
    
    # Remove existing key if present
    if grep -q "^${key_var_name}=" "$env_file" 2>/dev/null; then
        # Use sed to replace the existing line
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS sed
            sed -i '' "/^${key_var_name}=/d" "$env_file"
        else
            # Linux sed
            sed -i "/^${key_var_name}=/d" "$env_file"
        fi
    fi
    
    # Add the new key
    echo "${key_var_name}=${subscription_key}" >> "$env_file"
    
    log_success "Subscription key saved to .env file as: $key_var_name"
}

# Function to create custom connector in Power Platform
create_custom_connector() {
    local access_token="$1"
    local environment_id="$2"
    local connector_name="$3"
    local api_definition_path="$4"
    local apim_host="$5"
    local api_path="$6"
    
    log_info "Creating custom connector: $connector_name"
    
    # Load and modify the API definition
    local temp_definition="/tmp/modified-api-definition.json"
    
    # Update the API definition for Power Platform
    jq --arg title "$connector_name" \
       --arg host "$apim_host" \
       --arg basePath "$api_path" \
       '.info.title = $title | .host = $host | .basePath = $basePath' \
       "$api_definition_path" > "$temp_definition"
    
    # Add security definition for API key
    jq '.securityDefinitions.apiKeyHeader = {
        "type": "apiKey",
        "name": "Ocp-Apim-Subscription-Key",
        "in": "header"
    } | .security = [{"apiKeyHeader": []}]' "$temp_definition" > "${temp_definition}.tmp" && mv "${temp_definition}.tmp" "$temp_definition"
    
    log_info "API definition prepared for Power Platform"
    
    # Prepare connector payload
    local connector_payload
    connector_payload=$(cat <<EOF
{
    "properties": {
        "displayName": "$connector_name",
        "description": "Custom connector for $connector_name via Azure API Management",
        "iconBrandColor": "#007fff",
        "capabilities": [],
        "connectionParameters": {
            "api_key": {
                "type": "securestring",
                "uiDefinition": {
                    "displayName": "API Key",
                    "description": "API subscription key for Azure API Management",
                    "tooltip": "Enter your Azure API Management subscription key",
                    "constraints": {
                        "required": "true"
                    }
                }
            }
        },
        "swagger": $(cat "$temp_definition")
    }
}
EOF
    )
    
    # Create the connector via Power Platform API
    log_info "Submitting connector creation request..."
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        -d "$connector_payload" \
        "https://api.powerapps.com/providers/Microsoft.PowerApps/environments/$environment_id/apis?api-version=2016-11-01")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | head -n -1)
    
    # Clean up temporary file
    rm -f "$temp_definition"
    
    if [[ "$http_code" == "201" || "$http_code" == "200" ]]; then
        log_success "Custom connector created successfully (HTTP $http_code)"
        
        # Extract connector information
        local connector_id
        connector_id=$(echo "$response_body" | jq -r '.name // "unknown"')
        
        echo "$response_body" | jq '.'
        return 0
    else
        log_error "Failed to create custom connector (HTTP $http_code)"
        log_error "Response: $response_body"
        return 1
    fi
}

# Main execution
main() {
    # Step 1: Load environment variables
    load_environment_variables
    
    # Step 2: Test Azure authentication
    test_azure_authentication
    
    # Step 3: Get Power Platform access token
    local access_token
    access_token=$(get_power_platform_token)
    
    # Step 4: Set default values
    if [[ -z "$CONNECTOR_NAME" ]]; then
        CONNECTOR_NAME="${API_ID^} Connector"
    fi
    
    if [[ -z "$SUBSCRIPTION_NAME" ]]; then
        SUBSCRIPTION_NAME="${CONNECTOR_NAME,,}-subscription"
        SUBSCRIPTION_NAME=$(echo "$SUBSCRIPTION_NAME" | tr ' ' '-')
    fi
    
    log_info "Configuration:"
    log_info "- API ID: $API_ID"
    log_info "- Connector Name: $CONNECTOR_NAME"
    log_info "- Subscription Name: $SUBSCRIPTION_NAME"
    log_info "- Environment: $POWER_PLATFORM_ENVIRONMENT_NAME"
    echo
    
    # Step 5: Export API definition
    local api_definition_file="./api-definition-${API_ID}.json"
    export_api_definition "$API_ID" "$api_definition_file"
    
    # Step 6: Create APIM subscription
    log_info "Creating APIM subscription for the connector..."
    local subscription_key
    subscription_key=$(create_apim_subscription "$SUBSCRIPTION_NAME" "$CONNECTOR_NAME Subscription" "$API_ID")
    
    # Step 7: Determine APIM host and API path
    local apim_host="${APIM_NAME}.azure-api.net"
    local api_path="/$API_ID"
    
    log_info "APIM connection details:"
    log_info "- Host: $apim_host"
    log_info "- API Path: $api_path"
    log_info "- Subscription Key: $subscription_key"
    echo
    
    # Step 8: Create custom connector
    local connector_created=false
    
    if [[ -n "$POWER_PLATFORM_ENVIRONMENT_ID" && "$POWER_PLATFORM_ENVIRONMENT_ID" != "null" ]]; then
        log_info "Creating custom connector in Power Platform environment..."
        
        if create_custom_connector "$access_token" "$POWER_PLATFORM_ENVIRONMENT_ID" "$CONNECTOR_NAME" "$api_definition_file" "$apim_host" "$api_path"; then
            connector_created=true
        else
            log_warning "Custom connector creation via API failed. API definition is available for manual creation."
        fi
    else
        log_warning "Power Platform environment ID not available. API definition exported for manual creation."
    fi
    
    # Step 9: Output results
    echo
    log_success "🎉 Custom Connector Setup Completed!"
    echo "====================================="
    
    if [[ "$connector_created" == true ]]; then
        echo "Status: Connector created via API"
    else
        echo "Status: API Definition exported for manual creation"
    fi
    
    echo "Display Name: $CONNECTOR_NAME"
    echo "Environment: $POWER_PLATFORM_ENVIRONMENT_NAME"
    echo ""
    echo "Connection Information:"
    echo "- APIM Host: $apim_host"
    echo "- API Path: $api_path"
    echo "- Subscription Key: $subscription_key"
    echo ""
    echo "Files Created:"
    echo "- API Definition: $api_definition_file"
    echo ""
    echo "Next Steps:"
    echo "1. Go to https://make.powerapps.com"
    echo "2. Select environment: $POWER_PLATFORM_ENVIRONMENT_NAME"
    echo "3. Navigate to Data > Custom connectors"
    
    if [[ "$connector_created" == true ]]; then
        echo "4. Find your connector: $CONNECTOR_NAME"
        echo "5. Test the connector using the subscription key above"
    else
        echo "4. Create a new custom connector"
        echo "5. Import the API definition from: $api_definition_file"
        echo "6. Configure authentication with the subscription key above"
    fi
    
    echo ""
    echo "For Copilot Studio integration, run: ./4-SetupCopilotStudio.sh"
    
    # Clean up API definition file
    if [[ -f "$api_definition_file" ]]; then
        rm -f "$api_definition_file"
        log_info "Temporary API definition file cleaned up"
    fi
}

# Handle script arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [API_ID] [CONNECTOR_NAME] [SUBSCRIPTION_NAME] [FORCE]"
        echo ""
        echo "Parameters:"
        echo "  API_ID           APIM API identifier (default: petstore-api)"
        echo "  CONNECTOR_NAME   Display name for connector (default: {API_ID} Connector)"
        echo "  SUBSCRIPTION_NAME APIM subscription name (default: {connector-name}-subscription)"
        echo "  FORCE            Skip confirmations (default: false)"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Create connector for petstore-api"
        echo "  $0 my-api \"My Business API Connector\" # Create connector for custom API"
        exit 0
        ;;
    *)
        # Run main function
        main
        ;;
esac
