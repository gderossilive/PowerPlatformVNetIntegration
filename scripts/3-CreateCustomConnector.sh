#!/bin/bash#!/bin/bashEOF



echo "test"    exit 0


# =============================================================================EOF

# Enhanced Power Platform Custom Connector Creation Script (PAC CLI)    exit 0

# =============================================================================SCRIPT_VERSION="2.2"

#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# SYNOPSISROOT_DIR="$(dirname "$SCRIPT_DIR")"

#     Creates custom connectors in Power Platform using the Power Platform CLI (PAC).

#usage() {

# DESCRIPTION    cat << EOF

#     This script automates the creation of custom connectors in Power Platform by:${BOLD}Power Platform Custom Connector Creation Script${NC}

#     1. Authenticating with Power Platform CLI (PAC)

#     2. Discovering environment details from deployment artifacts${BOLD}USAGE:${NC}

#     3. Setting up connector project structure    $0 [OPTIONS]

#     4. Configuring API definitions in Swagger 2.0 format

#     5. Creating APIM-compatible authentication settings${BOLD}OPTIONS:${NC}

#     6. Deploying the custom connector to Power Platform    -e, --environment ENV_URL    Power Platform environment URL

#    -a, --apim-name NAME         APIM service name

#     The script supports Azure API Management integration with subscription key    -c, --connector-name NAME    Custom connector display name

#     authentication and VNet integration for secure connectivity.    -f, --force                  Force recreate connector if exists

#    -v, --verbose                Enable verbose output

# USAGE    -h, --help                   Show this help message

#     ./3-CreateCustomConnector.sh [OPTIONS]    --skip-auth-check           Skip PAC CLI authentication verification

#    --subscription-name NAME    APIM subscription name to use for key retrieval

# OPTIONS    --env-file PATH             Custom .env file path

#     -e, --environment ENV_URL    Power Platform environment URL (auto-detected if not provided)

#     -a, --apim-name NAME         APIM service name (auto-detected if not provided)${BOLD}EXAMPLES:${NC}

#     -c, --connector-name NAME    Custom connector display name (default: "Petstore API Connector")    # Auto-detect environment and create connector

#     -f, --force                  Force recreate connector if exists    $0

#     -v, --verbose                Enable verbose output

#     -h, --help                   Show this help message    # Specify environment explicitly

#     --skip-auth-check           Skip PAC CLI authentication verification    $0 -e "https://org123.crm.dynamics.com/"

#     --env-file PATH             Custom .env file path (default: ../.env)

#    # Custom connector name with verbose output

# EXAMPLES    $0 -c "My Petstore API" -v

#     # Auto-detect environment and create connector

#     ./3-CreateCustomConnector.sh${BOLD}PREREQUISITES:${NC}

#    - Power Platform CLI (pac) installed

#     # Specify environment explicitly    - Azure infrastructure deployed

#     ./3-CreateCustomConnector.sh -e "https://org123.crm.dynamics.com/"    - .env file with environment configuration

#

#     # Custom connector name with verbose outputEOF

#     ./3-CreateCustomConnector.sh -c "My Petstore API" -v    exit 0

#

# PREREQUISITES

#     - Power Platform CLI (pac) installed and authenticated     if [[ -n "$APIM_SUBSCRIPTION_KEY" ]]; then

#     - Azure infrastructure deployed via RunMe.sh or equivalent          cat << EOF

#     - .env file with POWER_PLATFORM_ENVIRONMENT_ID and APIM_SERVICE_NAME${BOLD}Primary Key (copy securely):${NC}

#     - Pre-configured Swagger 2.0 API definition in ../exports/$APIM_SUBSCRIPTION_KEY

#

# OUTPUTEOF

#     - Creates custom-connector/petstore-connector/ directory structure     else

#     - Deploys custom connector to Power Platform environment          cat << EOF

#     - Updates .env file with CUSTOM_CONNECTOR_ID${BOLD}Need the APIM primary key?${NC}

#    • Azure portal: API Management > ${APIM_NAME} > Subscriptions > (select subscription) > Keys

# =============================================================================EOF

          if [[ -n "$list_secrets_command" ]]; then

set -euo pipefail                cat << EOF

    • CLI: $list_secrets_command

# Script metadata

SCRIPT_NAME="3-CreateCustomConnector.sh"EOF

SCRIPT_VERSION="2.1"          else

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"                echo

ROOT_DIR="$(dirname "$SCRIPT_DIR")"          fi

     fi

# Default configuration

DEFAULT_ENV_FILE="$ROOT_DIR/.env"     cat << EOF

DEFAULT_CONNECTOR_NAME="Petstore API Connector"3. 🚀 Use the connector:

DEFAULT_APIM_SUBSCRIPTION_HINT="petstore"    • Build apps or flows and pick the new connection

CONNECTOR_PROJECT_DIR="$ROOT_DIR/custom-connector/petstore-connector"    • Store the key in Azure Key Vault or another secrets manager

API_DEFINITION_SOURCE="$ROOT_DIR/exports/petstore-api-definition-fixed.json"

4. 🧪 Validate VNet integration:

# Color definitions for output    • Trigger the connector and confirm successful calls

declare -r RED='\033[0;31m'    • Monitor APIM diagnostics for private endpoint usage

declare -r GREEN='\033[0;32m'# Initialize variables

declare -r YELLOW='\033[1;33m'ENVIRONMENT_URL=""

declare -r BLUE='\033[0;34m'APIM_NAME=""

declare -r CYAN='\033[0;36m'CONNECTOR_NAME="$DEFAULT_CONNECTOR_NAME"

declare -r BOLD='\033[1m'APIM_SUBSCRIPTION_NAME=""

declare -r NC='\033[0m' # No ColorAPIM_SUBSCRIPTION_NAME_RESOLVED=""

APIM_SUBSCRIPTION_INTERNAL_ID=""

# Output functionsAPIM_SUBSCRIPTION_KEY=""

info() { echo -e "${BLUE}[INFO]${NC} $*"; }APIM_RESOURCE_ID=""

success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }AZURE_SUBSCRIPTION_ID=""

warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }AZURE_RESOURCE_GROUP=""

error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }FORCE=false

debug() { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${CYAN}[DEBUG]${NC} $*"; }VERBOSE=false

SKIP_AUTH_CHECK=false

# Print formatted headerENV_FILE="$DEFAULT_ENV_FILE"

print_header() {

    echo -e "\n${BOLD}${BLUE}========================================${NC}"# Parse command line arguments

    echo -e "${BOLD}${BLUE} $1${NC}"while [[ $# -gt 0 ]]; do

    echo -e "${BOLD}${BLUE}========================================${NC}\n"    case $1 in

}        -e|--environment)

            ENVIRONMENT_URL="$2"

# Usage information            shift 2

usage() {            ;;

    cat << EOF        -a|--apim-name)

${BOLD}Power Platform Custom Connector Creation Script${NC}            APIM_NAME="$2"

            shift 2

${BOLD}USAGE:${NC}            ;;

    $0 [OPTIONS]        -c|--connector-name)

            CONNECTOR_NAME="$2"

${BOLD}OPTIONS:${NC}            shift 2

    -e, --environment ENV_URL    Power Platform environment URL            ;;

    -a, --apim-name NAME         APIM service name        -f|--force)

    -c, --connector-name NAME    Custom connector display name            FORCE=true

    -f, --force                  Force recreate connector if exists            shift

    -v, --verbose                Enable verbose output            ;;

    -h, --help                   Show this help message        -v|--verbose)

    --skip-auth-check           Skip PAC CLI authentication verification            VERBOSE=true

    --subscription-name NAME    APIM subscription name to use for key retrieval            shift

    --env-file PATH             Custom .env file path            ;;

        --skip-auth-check)

${BOLD}EXAMPLES:${NC}            SKIP_AUTH_CHECK=true

    # Auto-detect environment and create connector            shift

    $0            ;;

        --subscription-name)

    # Specify environment explicitly            APIM_SUBSCRIPTION_NAME="$2"

    $0 -e "https://org123.crm.dynamics.com/"            shift 2

            ;;

    # Custom connector name with verbose output        --env-file)

    $0 -c "My Petstore API" -v            ENV_FILE="$2"

            shift 2

${BOLD}PREREQUISITES:${NC}            ;;

    - Power Platform CLI (pac) installed        -h|--help)

    - Azure infrastructure deployed            usage

    - .env file with environment configuration            ;;

        *)

EOF            error "Unknown option: $1"

    exit 0            usage

}            ;;

    esac

# Initialize variablesdone

ENVIRONMENT_URL=""

APIM_NAME=""# Validation functions

CONNECTOR_NAME="$DEFAULT_CONNECTOR_NAME"validate_prerequisites() {

APIM_SUBSCRIPTION_NAME=""    debug "Validating prerequisites..."

APIM_SUBSCRIPTION_NAME_RESOLVED=""    

APIM_SUBSCRIPTION_KEY=""    # Check for PAC CLI

FORCE=false    if ! command -v pac >&/dev/null; then

VERBOSE=false        error "Power Platform CLI (pac) not found."

SKIP_AUTH_CHECK=false        error "Install it with: dotnet tool install --global Microsoft.PowerPlatform.CLI"

ENV_FILE="$DEFAULT_ENV_FILE"        exit 1

    fi
    
    debug "PAC CLI found: $(pac --version 2>/dev/null || echo 'Unknown version')"

    # Check for Azure CLI
    if ! command -v az >&/dev/null; then
        error "Azure CLI (az) not found."
        error "Install it from https://learn.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi

    debug "Azure CLI found: $(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo 'Unknown version')"

    # Check for jq
    if ! command -v jq >&/dev/null; then
        error "jq is required for JSON parsing."
        error "Install it with: sudo apt-get install jq"
        exit 1
    fi

    debug "jq found: $(jq --version 2>/dev/null || echo 'Unknown version')"
    
    # Check for .env file
    if [[ ! -f "$ENV_FILE" ]]; then
        error "Environment file not found: $ENV_FILE"
        error "Please run the infrastructure setup first or specify correct --env-file path"
        exit 1
    fi
    
    debug "Environment file found: $ENV_FILE"
    
    # Check for API definition source
    if [[ ! -f "$API_DEFINITION_SOURCE" ]]; then
        error "API definition source not found: $API_DEFINITION_SOURCE"
        error "Please ensure the infrastructure setup has been completed"
        exit 1
    fi
    
    debug "API definition source found: $API_DEFINITION_SOURCE"
}

# Authentication verification
verify_pac_authentication() {
    if [[ "$SKIP_AUTH_CHECK" == "true" ]]; then
        debug "Skipping PAC CLI authentication check"
        return 0
    fi
    
    debug "Verifying PAC CLI authentication..."
    
    if ! pac auth list 2>/dev/null | grep -q "@"; then
        error "PAC CLI authentication required."
        echo
        info "To authenticate, run one of the following:"
        info "  pac auth create --deviceCode --tenant <YOUR_TENANT_ID>"
        info "  pac auth create --tenant <YOUR_TENANT_ID>"
        echo
        info "Then re-run this script."
        exit 1
    fi
    
    local auth_info
    auth_info=$(pac auth list 2>/dev/null | head -5)
    debug "PAC CLI authentication status:"
    debug "$auth_info"
    success "PAC CLI authentication verified"
}

# Environment discovery
discover_environment_details() {
    debug "Discovering environment details from $ENV_FILE..."
    
    # Extract environment ID if not provided
    if [[ -z "$ENVIRONMENT_URL" ]]; then
        local env_id
        env_id=$(grep '^POWER_PLATFORM_ENVIRONMENT_ID=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
        
        if [[ -n "$env_id" ]]; then
            debug "Found environment ID: $env_id"
            
            # Try to get environment URL from troubleshooting script
            local troubleshoot_script="$ROOT_DIR/troubleshooting/powerplatform/test-environment.sh"
            if [[ -f "$troubleshoot_script" ]]; then
                debug "Running troubleshooting script to get environment URL..."
                local env_output
                env_output=$(bash "$troubleshoot_script" 2>/dev/null || echo "")
                ENVIRONMENT_URL=$(echo "$env_output" | grep -o 'https://org[a-z0-9]*\.crm[0-9]*\.dynamics\.com/' | head -1 || echo "")
                
                if [[ -n "$ENVIRONMENT_URL" ]]; then
                    debug "Discovered environment URL: $ENVIRONMENT_URL"
                else
                    warn "Could not extract environment URL from troubleshooting script"
                fi
            fi
        fi
        
        # Fallback: try to extract from env file directly
        if [[ -z "$ENVIRONMENT_URL" ]]; then
            ENVIRONMENT_URL=$(grep '^POWER_PLATFORM_ENVIRONMENT_URL=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
            debug "Environment URL from .env: $ENVIRONMENT_URL"
        fi
    fi
    
    # Extract Azure subscription and resource group
    if [[ -z "$AZURE_SUBSCRIPTION_ID" ]]; then
        AZURE_SUBSCRIPTION_ID=$(grep '^AZURE_SUBSCRIPTION_ID=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
        debug "Azure subscription ID from .env: ${AZURE_SUBSCRIPTION_ID:-"(not found)"}"
    fi

    if [[ -z "$AZURE_RESOURCE_GROUP" ]]; then
        AZURE_RESOURCE_GROUP=$(grep '^RESOURCE_GROUP=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
        debug "Resource group from .env: ${AZURE_RESOURCE_GROUP:-"(not found)"}"
    fi

    # Extract APIM name if not provided
    if [[ -z "$APIM_NAME" ]]; then
        APIM_NAME=$(grep '^APIM_SERVICE_NAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
        if [[ -z "$APIM_NAME" ]]; then
            APIM_NAME=$(grep '^APIM_NAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
            debug "APIM name fallback from .env: $APIM_NAME"
        else
            debug "APIM service name from .env: $APIM_NAME"
        fi
    else
        debug "APIM service name provided via arguments: $APIM_NAME"
    fi

    # Determine APIM resource ID
    if [[ -z "$APIM_RESOURCE_ID" ]]; then
        APIM_RESOURCE_ID=$(grep '^APIM_ID=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")

        if [[ -z "$APIM_RESOURCE_ID" ]] && [[ -n "$AZURE_SUBSCRIPTION_ID" ]] && [[ -n "$AZURE_RESOURCE_GROUP" ]] && [[ -n "$APIM_NAME" ]]; then
            APIM_RESOURCE_ID="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.ApiManagement/service/$APIM_NAME"
            debug "Constructed APIM resource ID: $APIM_RESOURCE_ID"
        elif [[ -n "$APIM_RESOURCE_ID" ]]; then
            debug "APIM resource ID from .env: $APIM_RESOURCE_ID"
        else
            warn "Unable to determine APIM resource ID from environment configuration"
        fi
    fi

    # Extract APIM subscription name hint if not provided
    if [[ -z "$APIM_SUBSCRIPTION_NAME" ]]; then
        APIM_SUBSCRIPTION_NAME=$(grep '^APIM_SUBSCRIPTION_NAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
        if [[ -n "$APIM_SUBSCRIPTION_NAME" ]]; then
            debug "APIM subscription name from .env: $APIM_SUBSCRIPTION_NAME"
        fi
    else
        debug "APIM subscription name provided via arguments: $APIM_SUBSCRIPTION_NAME"
    fi
    
    # Validate discovered values
    if [[ -z "$ENVIRONMENT_URL" ]]; then
        error "Could not determine Power Platform environment URL."
        error "Please provide it with --environment option or ensure it's in $ENV_FILE"
        exit 1
    fi
    
    if [[ -z "$APIM_NAME" ]]; then
        error "Could not determine APIM service name."
        error "Please provide it with --apim-name option or ensure APIM_SERVICE_NAME is in $ENV_FILE"
        exit 1
    fi
    
    info "Environment URL: $ENVIRONMENT_URL"
    info "APIM Service: $APIM_NAME"
    info "Connector Name: $CONNECTOR_NAME"
}

# Resolve APIM subscription details and retrieve key
resolve_apim_subscription_details() {
    debug "Resolving APIM subscription details..."

    if [[ -z "$APIM_RESOURCE_ID" ]]; then
        warn "Skipping APIM subscription resolution because APIM resource ID is not available"
        return 0
    fi

    if ! az account show >/dev/null 2>&1; then
        warn "Azure CLI is not logged in. Run 'az login' to enable APIM subscription key discovery."
        return 0
    fi

    local subscription_hint
    subscription_hint=${APIM_SUBSCRIPTION_NAME:-$DEFAULT_APIM_SUBSCRIPTION_HINT}

    local list_uri
    list_uri="https://management.azure.com${APIM_RESOURCE_ID}/subscriptions?api-version=2023-05-01-preview"
    debug "Querying APIM subscriptions: $list_uri"

    local subscriptions_json
    if ! subscriptions_json=$(az rest --method get --uri "$list_uri" 2>/dev/null); then
        warn "Unable to list APIM subscriptions (insufficient permissions or Azure CLI context)."
        return 0
    fi

    if [[ -z "$subscriptions_json" ]] || [[ $(echo "$subscriptions_json" | jq '.value | length') -eq 0 ]]; then
        warn "No APIM subscriptions returned. Create a subscription in Azure portal if needed."
        return 0
    fi

    local subscription_object
    if [[ -n "$APIM_SUBSCRIPTION_NAME" ]]; then
        subscription_object=$(echo "$subscriptions_json" | jq -c --arg search "$APIM_SUBSCRIPTION_NAME" '
            .value[] | select((.properties.displayName // "" | ascii_downcase) == ($search | ascii_downcase) or (.name | ascii_downcase) == ($search | ascii_downcase))' | head -n1)
    fi

    if [[ -z "$subscription_object" ]] && [[ -n "$subscription_hint" ]]; then
        subscription_object=$(echo "$subscriptions_json" | jq -c --arg hint "$subscription_hint" '
            .value[] | select((.properties.displayName // "" | ascii_downcase) | contains($hint | ascii_downcase) or (.name | ascii_downcase) | contains($hint | ascii_downcase))' | head -n1)
    fi

    if [[ -z "$subscription_object" ]]; then
        warn "Could not automatically match an APIM subscription. Use --subscription-name to specify it explicitly."
        return 0
    fi

    APIM_SUBSCRIPTION_INTERNAL_ID=$(echo "$subscription_object" | jq -r '.name // empty')
    APIM_SUBSCRIPTION_NAME_RESOLVED=$(echo "$subscription_object" | jq -r '.properties.displayName // empty')

    if [[ -z "$APIM_SUBSCRIPTION_NAME_RESOLVED" ]]; then
        APIM_SUBSCRIPTION_NAME_RESOLVED="$APIM_SUBSCRIPTION_INTERNAL_ID"
    fi

    success "Resolved APIM subscription: $APIM_SUBSCRIPTION_NAME_RESOLVED"
    debug "APIM subscription resource ID: $APIM_SUBSCRIPTION_INTERNAL_ID"

    local secrets_uri
    secrets_uri="https://management.azure.com${APIM_RESOURCE_ID}/subscriptions/${APIM_SUBSCRIPTION_INTERNAL_ID}/listSecrets?api-version=2023-05-01-preview"
    debug "Retrieving APIM subscription secrets: $secrets_uri"

    local secrets_json
    if secrets_json=$(az rest --method post --uri "$secrets_uri" --body '{}' 2>/dev/null); then
        APIM_SUBSCRIPTION_KEY=$(echo "$secrets_json" | jq -r '.primaryKey // empty')
        if [[ -n "$APIM_SUBSCRIPTION_KEY" ]]; then
            success "Retrieved APIM subscription primary key"
        else
            warn "APIM subscription key response did not include a primaryKey value"
        fi
    else
        warn "Unable to retrieve APIM subscription key automatically. You may need additional permissions."
    fi
}

# Project setup
setup_connector_project() {
    print_header "Setting up Connector Project"
    
    # Create project directory
    debug "Creating connector project directory: $CONNECTOR_PROJECT_DIR"
    mkdir -p "$CONNECTOR_PROJECT_DIR"
    
    # Initialize PAC connector project if needed
    if [[ ! -f "$CONNECTOR_PROJECT_DIR/apiProperties.json" ]] || [[ "$FORCE" == "true" ]]; then
        info "Initializing PAC connector project..."
        cd "$CONNECTOR_PROJECT_DIR"
        
        # Remove existing files if force mode
        if [[ "$FORCE" == "true" ]]; then
            debug "Force mode: removing existing connector files"
            rm -f apiProperties.json settings.json apiDefinition.swagger.json
        fi
        
        # Initialize project
        if pac connector init --connection-template ApiKey --generate-settings-file --outputDirectory . 2>/dev/null; then
            success "Connector project initialized"
        else
            warn "Connector project initialization may have failed (files might already exist)"
        fi
    else
        debug "Connector project already exists, skipping initialization"
    fi
}

# API definition setup
setup_api_definition() {
    print_header "Configuring API Definition"
    
    # Copy and configure Swagger 2.0 definition
    info "Setting up Swagger 2.0 API definition..."
    cp "$API_DEFINITION_SOURCE" "$CONNECTOR_PROJECT_DIR/apiDefinition.swagger.json"
    
    # Update APIM host in the definition
    debug "Updating APIM host to: ${APIM_NAME}.azure-api.net"
    if command -v sed >&/dev/null; then
        sed -i "s/\"host\": \"[^\"]*\"/\"host\": \"${APIM_NAME}.azure-api.net\"/" "$CONNECTOR_PROJECT_DIR/apiDefinition.swagger.json"
        success "API definition configured for APIM: ${APIM_NAME}.azure-api.net"
    else
        warn "sed not available, please manually update the host in apiDefinition.swagger.json"
    fi
    
    # Validate the API definition
    debug "Validating API definition format..."
    if grep -q '"swagger": "2.0"' "$CONNECTOR_PROJECT_DIR/apiDefinition.swagger.json"; then
        success "API definition validated (Swagger 2.0 format)"
    else
        error "API definition is not in Swagger 2.0 format"
        exit 1
    fi
}

# Configure connection properties
setup_connection_properties() {
    print_header "Configuring Connection Properties"
    
    info "Setting up APIM subscription key authentication..."
    
    cat > "$CONNECTOR_PROJECT_DIR/apiProperties.json" << EOF
{
  "properties": {
    "connectionParameters": {
      "api_key": {
        "type": "securestring",
        "uiDefinition": {
          "displayName": "APIM Subscription Key",
          "description": "Enter your Azure API Management subscription key for the ${APIM_NAME} service",
          "tooltip": "This key is required to authenticate with the APIM Petstore API. You can find this key in the Azure portal under API Management > Subscriptions.",
          "constraints": {
            "tabIndex": 2,
            "clearText": false,
            "required": "true"
          }
        }
      }
    },
    "iconBrandColor": "#007ee5",
    "capabilities": [],
    "scriptOperations": null,
    "publisher": "Microsoft Sample",
    "stackOwner": "Microsoft Sample",
    "privacy": {
      "PolicyUrl": "https://privacy.microsoft.com/privacystatement"
    }
  }
}
EOF
    
    success "Connection properties configured for APIM authentication"
}

# Deploy connector
deploy_custom_connector() {
    print_header "Deploying Custom Connector"
    
    cd "$CONNECTOR_PROJECT_DIR"
    
    info "Creating custom connector in Power Platform environment..."
    info "Environment: $ENVIRONMENT_URL"
    debug "Using files:"
    debug "  API Definition: $(basename "$CONNECTOR_PROJECT_DIR")/apiDefinition.swagger.json"
    debug "  API Properties: $(basename "$CONNECTOR_PROJECT_DIR")/apiProperties.json"
    
    # Deploy the connector
    local connector_result
    connector_result=$(pac connector create \
        --environment "$ENVIRONMENT_URL" \
        --api-definition-file ./apiDefinition.swagger.json \
        --api-properties-file ./apiProperties.json 2>&1 || echo "DEPLOYMENT_FAILED")
    
    debug "PAC connector create output:"
    debug "$connector_result"
    
    # Check deployment result
    if echo "$connector_result" | grep -q "Connector created with ID"; then
        local connector_id
        connector_id=$(echo "$connector_result" | grep -o "Connector created with ID [a-f0-9-]*" | cut -d' ' -f5)
        
        success "🎉 Custom connector deployed successfully!"
        success "Connector ID: $connector_id"
        success "Connector Name: $CONNECTOR_NAME"
        
        # Save connector ID to env file
        if ! grep -q "^CUSTOM_CONNECTOR_ID=" "$ENV_FILE"; then
            echo "CUSTOM_CONNECTOR_ID=$connector_id" >> "$ENV_FILE"
            debug "Saved connector ID to $ENV_FILE"
        else
            debug "CUSTOM_CONNECTOR_ID already exists in $ENV_FILE"
        fi
        
        return 0
    else
        error "❌ Custom connector deployment failed"
        echo
        error "Deployment output:"
        echo "$connector_result"
        echo
        error "Common troubleshooting steps:"
        error "1. Verify PAC CLI authentication: pac auth list"
        error "2. Check environment URL is correct: $ENVIRONMENT_URL"
        error "3. Ensure environment has proper permissions"
        error "4. Verify APIM service is accessible: $APIM_NAME"
        return 1
    fi
}

# Provide next steps
show_next_steps() {
    print_header "Next Steps"
    
    local connector_id
    connector_id=$(grep '^CUSTOM_CONNECTOR_ID=' "$ENV_FILE" | cut -d= -f2- || echo "")

     local list_secrets_command=""
     local primary_key_status="not retrieved automatically"

     if [[ -n "$APIM_RESOURCE_ID" && -n "$APIM_SUBSCRIPTION_INTERNAL_ID" ]]; then
          list_secrets_command="az rest --method post --uri 'https://management.azure.com${APIM_RESOURCE_ID}/subscriptions/${APIM_SUBSCRIPTION_INTERNAL_ID}/listSecrets?api-version=2023-05-01-preview' --body '{}'"
     fi

     if [[ -n "$APIM_SUBSCRIPTION_KEY" ]]; then
          primary_key_status="retrieved (shown below)"
     fi

     cat << EOF
${GREEN}✅ Custom Connector Setup Complete${NC}

${BOLD}What's been created:${NC}
📁 Project Directory: $(basename "$CONNECTOR_PROJECT_DIR")
🔗 Connector ID: ${connector_id:-"Check environment file"}
🌐 Environment: $ENVIRONMENT_URL
🔑 Authentication: APIM Subscription Key

${BOLD}Next Actions:${NC}
1. 🔌 Create a connection in Power Apps / Power Automate:
    • Power Apps portal: Data > Connections > New connection
    • Select Custom > "${CONNECTOR_NAME}" > Create
    • When prompted, paste the APIM subscription primary key

2. 🔑 Review APIM subscription details:
    • Subscription: ${APIM_SUBSCRIPTION_NAME_RESOLVED:-"(not automatically detected)"}
    • Subscription ID: ${APIM_SUBSCRIPTION_INTERNAL_ID:-"(n/a)"}
    • Primary Key: $primary_key_status
EOF

     if [[ -n "$APIM_SUBSCRIPTION_KEY" ]]; then
          cat << EOF

${BOLD}Primary Key (copy securely):${NC}
$APIM_SUBSCRIPTION_KEY

EOF
     else
          cat << EOF

${BOLD}Need the APIM primary key?${NC}
    • Azure portal: API Management > ${APIM_NAME} > Subscriptions > (select subscription) > Keys
EOF
          if [[ -n "$list_secrets_command" ]]; then
                cat << EOF
    • CLI: $list_secrets_command

EOF
          else
                echo
          fi
     fi

     cat << EOF
3. 🚀 Use the connector:
    • Build apps or flows and pick the new connection
    • Store the key in Azure Key Vault or another secrets manager

4. 🧪 Validate VNet integration:
    • Trigger the connector and confirm successful calls
    • Monitor APIM diagnostics for private endpoint usage

${BOLD}Documentation:${NC}
📚 See docs/CUSTOM_CONNECTOR_PAC_CLI_SETUP.md for detailed information

${BOLD}Troubleshooting:${NC}
🔧 Run troubleshooting scripts in ./troubleshooting/ directory
📞 For support, check the GitHub repository issues

EOF
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    error "Script failed at line $line_number with exit code $exit_code"
    error "Check the output above for specific error details"
    
    if [[ -f "$CONNECTOR_PROJECT_DIR/apiDefinition.swagger.json" ]]; then
        debug "Connector project files created, you may retry with --force to recreate"
    fi
    
    exit $exit_code
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# Main execution
main() {
    print_header "Power Platform Custom Connector Creation (PAC CLI v$SCRIPT_VERSION)"
    
    info "Starting custom connector creation process..."
    debug "Script directory: $SCRIPT_DIR"
    debug "Root directory: $ROOT_DIR"
    debug "Environment file: $ENV_FILE"
    
    # Execute setup steps
    validate_prerequisites
    verify_pac_authentication
    discover_environment_details
    resolve_apim_subscription_details
    setup_connector_project
    setup_api_definition
    setup_connection_properties
    deploy_custom_connector
    show_next_steps
    
    success "🎉 Custom connector creation completed successfully!"
}

# Run main function
main "$@"