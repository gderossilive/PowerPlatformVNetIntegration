#!/bin/bash

set -euo pipefail

# =============================================================================
# Enhanced Power Platform Custom Connector Creation Script (PAC CLI)
# =============================================================================
#
# This script prepares and deploys a Power Platform custom connector backed by
# an Azure API Management (APIM) instance. It focuses on the PAC CLI workflow
# while guiding the user through manual connection creation, including
# retrieving the appropriate APIM subscription key when possible.
#
# Key capabilities:
#   • Validates required tooling (pac, az, jq) and environment configuration
#   • Sets up a PAC connector project using an existing Swagger definition
#   • Deploys the connector to the target Power Platform environment
#   • Attempts to resolve an APIM subscription and expose its primary key
#   • Outputs clear manual steps to create the connection in Power Apps/Automate
# =============================================================================

# Script metadata
SCRIPT_NAME="3-CreateCustomConnector_v2.sh"
SCRIPT_VERSION="2.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Default configuration
DEFAULT_ENV_FILE="$ROOT_DIR/.env"
DEFAULT_CONNECTOR_NAME="Petstore API Connector"
DEFAULT_APIM_SUBSCRIPTION_HINT="petstore"
CONNECTOR_PROJECT_DIR="$ROOT_DIR/custom-connector/petstore-connector"
API_DEFINITION_SOURCE="$ROOT_DIR/exports/petstore-api-definition-fixed.json"

# Colour definitions for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Output helpers
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
debug() { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${CYAN}[DEBUG]${NC} $*"; }

print_header() {
    echo -e "\n${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE} $1${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}\n"
}

usage() {
    cat <<EOF
${BOLD}Power Platform Custom Connector Creation Script${NC}

${BOLD}USAGE:${NC}
    ${SCRIPT_NAME} [OPTIONS]

${BOLD}OPTIONS:${NC}
    -e, --environment ENV_URL    Power Platform environment URL
    -a, --apim-name NAME         APIM service name
    -c, --connector-name NAME    Custom connector display name
    -f, --force                  Force recreation of connector project files
    -v, --verbose                Enable verbose diagnostic output
    -h, --help                   Show this help message and exit
    --skip-auth-check            Skip PAC CLI authentication verification
    --subscription-name NAME     Preferred APIM subscription display name/id
    --env-file PATH              Override path to .env file (default: $DEFAULT_ENV_FILE)

${BOLD}EXAMPLES:${NC}
    ${SCRIPT_NAME}
    ${SCRIPT_NAME} --environment "https://org123.crm.dynamics.com/" --verbose
    ${SCRIPT_NAME} --subscription-name "petstore-subscription-demo"
EOF
    exit 0
}

# Runtime variables
ENVIRONMENT_URL=""
APIM_NAME=""
CONNECTOR_NAME="$DEFAULT_CONNECTOR_NAME"
APIM_SUBSCRIPTION_NAME=""
APIM_SUBSCRIPTION_NAME_RESOLVED=""
APIM_SUBSCRIPTION_INTERNAL_ID=""
APIM_SUBSCRIPTION_KEY=""
APIM_RESOURCE_ID=""
AZURE_SUBSCRIPTION_ID=""
AZURE_RESOURCE_GROUP=""
FORCE=false
VERBOSE=false
SKIP_AUTH_CHECK=false
ENV_FILE="$DEFAULT_ENV_FILE"

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT_URL="$2"
            shift 2
            ;;
        -a|--apim-name)
            APIM_NAME="$2"
            shift 2
            ;;
        -c|--connector-name)
            CONNECTOR_NAME="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --skip-auth-check)
            SKIP_AUTH_CHECK=true
            shift
            ;;
        --subscription-name)
            APIM_SUBSCRIPTION_NAME="$2"
            shift 2
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            usage
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Validation helpers
# -----------------------------------------------------------------------------
validate_prerequisites() {
    debug "Validating prerequisites..."

    if ! command -v pac >/dev/null 2>&1; then
        error "Power Platform CLI (pac) not found."
        error "Install with: dotnet tool install --global Microsoft.PowerPlatform.CLI"
        exit 1
    fi
    debug "PAC CLI found: $(pac --version 2>/dev/null || echo 'unknown version')"

    if ! command -v az >/dev/null 2>&1; then
        error "Azure CLI (az) not found."
        error "Install instructions: https://learn.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    debug "Azure CLI found: $(az version 2>/dev/null | head -n 1 || echo 'unknown version')"

    if ! command -v jq >/dev/null 2>&1; then
        error "jq is required for JSON processing. Install with your package manager (e.g. sudo apt-get install jq)."
        exit 1
    fi
    debug "jq found: $(jq --version 2>/dev/null || echo 'unknown version')"

    if [[ ! -f "$ENV_FILE" ]]; then
        error "Environment file not found: $ENV_FILE"
        error "Ensure infrastructure setup completed or provide --env-file."
        exit 1
    fi
    debug "Environment file located: $ENV_FILE"

    if [[ ! -f "$API_DEFINITION_SOURCE" ]]; then
        error "API definition source missing: $API_DEFINITION_SOURCE"
        error "Run infrastructure provisioning to generate the export or adjust the path."
        exit 1
    fi
    debug "API definition source located: $API_DEFINITION_SOURCE"
}

verify_pac_authentication() {
    if [[ "$SKIP_AUTH_CHECK" == "true" ]]; then
        debug "Skipping PAC authentication check as requested."
        return
    fi

    debug "Verifying PAC CLI authentication context..."
    if ! pac auth list 2>/dev/null | grep -q '@'; then
        error "PAC CLI authentication required."
        echo
        info "Run one of the following commands to authenticate:"
        info "  pac auth create --deviceCode --tenant <YOUR_TENANT_ID>"
        info "  pac auth create --tenant <YOUR_TENANT_ID>"
        echo
        exit 1
    fi
    success "PAC CLI authentication verified."
}

# -----------------------------------------------------------------------------
# Environment discovery
# -----------------------------------------------------------------------------
discover_environment_details() {
    debug "Discovering environment configuration from $ENV_FILE..."

    AZURE_SUBSCRIPTION_ID=$(grep '^AZURE_SUBSCRIPTION_ID=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
    AZURE_RESOURCE_GROUP=$(grep '^RESOURCE_GROUP=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")

    if [[ -z "$ENVIRONMENT_URL" ]]; then
        ENVIRONMENT_URL=$(grep '^POWER_PLATFORM_ENVIRONMENT_URL=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
        if [[ -z "$ENVIRONMENT_URL" ]]; then
            warn "Environment URL not found in .env; consider supplying --environment."
        fi
    fi

    if [[ -z "$APIM_NAME" ]]; then
        APIM_NAME=$(grep '^APIM_SERVICE_NAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
        if [[ -z "$APIM_NAME" ]]; then
            APIM_NAME=$(grep '^APIM_NAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
        fi
    fi

    APIM_RESOURCE_ID=$(grep '^APIM_ID=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
    if [[ -z "$APIM_RESOURCE_ID" && -n "$AZURE_SUBSCRIPTION_ID" && -n "$AZURE_RESOURCE_GROUP" && -n "$APIM_NAME" ]]; then
        APIM_RESOURCE_ID="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}"
        debug "Constructed APIM resource ID: $APIM_RESOURCE_ID"
    fi

    if [[ -z "$APIM_SUBSCRIPTION_NAME" ]]; then
        APIM_SUBSCRIPTION_NAME=$(grep '^APIM_SUBSCRIPTION_NAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo "")
    fi

    if [[ -z "$ENVIRONMENT_URL" ]]; then
        error "Power Platform environment URL could not be determined. Provide --environment or populate POWER_PLATFORM_ENVIRONMENT_URL in $ENV_FILE."
        exit 1
    fi

    if [[ -z "$APIM_NAME" ]]; then
        error "APIM service name not available. Provide --apim-name or set APIM_SERVICE_NAME in $ENV_FILE."
        exit 1
    fi

    info "Environment URL: $ENVIRONMENT_URL"
    info "APIM Service: $APIM_NAME"
    info "Connector Name: $CONNECTOR_NAME"
    debug "Azure subscription: ${AZURE_SUBSCRIPTION_ID:-'(unset)'}"
    debug "Resource group: ${AZURE_RESOURCE_GROUP:-'(unset)'}"
}

# -----------------------------------------------------------------------------
# APIM subscription resolution
# -----------------------------------------------------------------------------
resolve_apim_subscription_details() {
    debug "Attempting to resolve APIM subscription details..."

    if [[ -z "$APIM_RESOURCE_ID" ]]; then
        warn "APIM resource ID unavailable; skipping subscription lookup."
        return
    fi

    if ! az account show >/dev/null 2>&1; then
        warn "Azure CLI is not logged in. Run 'az login' to enable automatic subscription discovery."
        return
    fi

    local subscription_hint="${APIM_SUBSCRIPTION_NAME:-$DEFAULT_APIM_SUBSCRIPTION_HINT}"
    local list_uri="https://management.azure.com${APIM_RESOURCE_ID}/subscriptions?api-version=2023-05-01-preview"
    debug "Listing APIM subscriptions via: $list_uri"

    local subscriptions_json
    if ! subscriptions_json=$(az rest --method get --uri "$list_uri" 2>/dev/null); then
        warn "Unable to enumerate APIM subscriptions (permissions or scope issue)."
        return
    fi

    if [[ -z "$subscriptions_json" ]] || [[ $(echo "$subscriptions_json" | jq '.value | length') -eq 0 ]]; then
        warn "No APIM subscriptions were returned. Create one in the Azure portal if necessary."
        return
    fi

    local subscription_object=""
    if [[ -n "$APIM_SUBSCRIPTION_NAME" ]]; then
        subscription_object=$(echo "$subscriptions_json" | jq -c --arg search "$APIM_SUBSCRIPTION_NAME" '
            .value
            | map(select((type == "object") and ((.properties.displayName // "" | ascii_downcase) == ($search | ascii_downcase)
                                                  or (.name // "" | ascii_downcase) == ($search | ascii_downcase))))
            | first // empty')
    fi

    if [[ -z "$subscription_object" && -n "$subscription_hint" ]]; then
        local hint_lower
        hint_lower=$(echo "$subscription_hint" | tr '[:upper:]' '[:lower:]')
        subscription_object=$(echo "$subscriptions_json" | jq -c --arg hint "$hint_lower" '
            .value
            | map(select((type == "object") and (((.properties.displayName // "" | ascii_downcase) | contains($hint))
                                                  or ((.name // "" | ascii_downcase) | contains($hint)))))
            | first // empty')
    fi

    if [[ -z "$subscription_object" ]]; then
        warn "Could not automatically match an APIM subscription. Use --subscription-name for an exact match."
        return
    fi

    APIM_SUBSCRIPTION_INTERNAL_ID=$(echo "$subscription_object" | jq -r '.name // empty')
    APIM_SUBSCRIPTION_NAME_RESOLVED=$(echo "$subscription_object" | jq -r '.properties.displayName // empty')
    if [[ -z "$APIM_SUBSCRIPTION_NAME_RESOLVED" ]]; then
        APIM_SUBSCRIPTION_NAME_RESOLVED="$APIM_SUBSCRIPTION_INTERNAL_ID"
    fi

    success "Resolved APIM subscription: $APIM_SUBSCRIPTION_NAME_RESOLVED"
    debug "Subscription resource name: $APIM_SUBSCRIPTION_INTERNAL_ID"

    local secrets_uri="https://management.azure.com${APIM_RESOURCE_ID}/subscriptions/${APIM_SUBSCRIPTION_INTERNAL_ID}/listSecrets?api-version=2023-05-01-preview"
    debug "Requesting subscription secrets via: $secrets_uri"

    local secrets_json
    if secrets_json=$(az rest --method post --uri "$secrets_uri" --body '{}' 2>/dev/null); then
        APIM_SUBSCRIPTION_KEY=$(echo "$secrets_json" | jq -r '.primaryKey // empty')
        if [[ -n "$APIM_SUBSCRIPTION_KEY" ]]; then
            success "Retrieved APIM subscription primary key."
        else
            warn "Subscription secrets response did not include a primary key."
        fi
    else
        warn "Unable to retrieve APIM subscription key automatically (insufficient permissions?)."
    fi
}

# -----------------------------------------------------------------------------
# Connector project preparation
# -----------------------------------------------------------------------------
setup_connector_project() {
    print_header "Setting up Connector Project"

    mkdir -p "$CONNECTOR_PROJECT_DIR"
    debug "Connector project directory: $CONNECTOR_PROJECT_DIR"

    if [[ "$FORCE" == "true" ]]; then
        debug "Force flag detected; cleaning existing connector files."
        rm -f "$CONNECTOR_PROJECT_DIR/apiDefinition.swagger.json" \
              "$CONNECTOR_PROJECT_DIR/apiProperties.json" \
              "$CONNECTOR_PROJECT_DIR/settings.json"
    fi

    if [[ ! -f "$CONNECTOR_PROJECT_DIR/apiProperties.json" ]]; then
        info "Initializing PAC connector project (ApiKey template)..."
        (
            cd "$CONNECTOR_PROJECT_DIR"
            if pac connector init --connection-template ApiKey --generate-settings-file --outputDirectory . 2>/dev/null; then
                success "Connector project initialized."
            else
                warn "PAC project initialization reported issues (files may already exist)."
            fi
        )
    else
        debug "PAC connector project already prepared; skipping init."
    fi
}

setup_api_definition() {
    print_header "Configuring API Definition"

    info "Copying API definition from exports directory..."
    cp "$API_DEFINITION_SOURCE" "$CONNECTOR_PROJECT_DIR/apiDefinition.swagger.json"

    local apim_host="${APIM_NAME}.azure-api.net"
    debug "Updating Swagger host to: $apim_host"
    sed -i "s/\"host\": \"[^\"]*\"/\"host\": \"${apim_host}\"/" "$CONNECTOR_PROJECT_DIR/apiDefinition.swagger.json"

    if grep -q '"swagger": "2.0"' "$CONNECTOR_PROJECT_DIR/apiDefinition.swagger.json"; then
        success "Swagger definition prepared for APIM host ${apim_host}."
    else
        error "API definition is not in Swagger 2.0 format; PAC connector requires Swagger 2.0."
        exit 1
    fi
}

setup_connection_properties() {
    print_header "Configuring Connection Properties"

    cat >"$CONNECTOR_PROJECT_DIR/apiProperties.json" <<EOF
{
  "properties": {
    "connectionParameters": {
      "api_key": {
        "type": "securestring",
        "uiDefinition": {
          "displayName": "APIM Subscription Key",
          "description": "Enter your Azure API Management subscription key for the ${APIM_NAME} service",
          "tooltip": "This key authenticates calls routed through your APIM instance.",
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

    success "Connection properties configured for APIM subscription key authentication."
}

# -----------------------------------------------------------------------------
# Connector deployment
# -----------------------------------------------------------------------------
deploy_custom_connector() {
    print_header "Deploying Custom Connector"

    pushd "$CONNECTOR_PROJECT_DIR" >/dev/null

    info "Deploying connector to Power Platform environment..."
    info "Environment: $ENVIRONMENT_URL"

    local connector_result
    if ! connector_result=$(pac connector create \
        --environment "$ENVIRONMENT_URL" \
        --api-definition-file ./apiDefinition.swagger.json \
        --api-properties-file ./apiProperties.json 2>&1); then
        connector_result="DEPLOYMENT_FAILED\n${connector_result}"
    fi

    debug "PAC CLI output:\n$connector_result"

    if echo "$connector_result" | grep -q "Connector created with ID"; then
        local connector_id
        connector_id=$(echo "$connector_result" | grep -o "Connector created with ID [a-f0-9-]*" | awk '{print $5}')
        success "Custom connector deployed successfully."
        success "Connector ID: $connector_id"

        if [[ -n "${connector_id}" ]]; then
            if ! grep -q '^CUSTOM_CONNECTOR_ID=' "$ENV_FILE" 2>/dev/null; then
                echo "CUSTOM_CONNECTOR_ID=${connector_id}" >>"$ENV_FILE"
                debug "Stored connector ID in $ENV_FILE."
            fi
        fi
        popd >/dev/null
        return 0
    fi

    popd >/dev/null
    error "Custom connector deployment failed."
    echo "$connector_result"
    return 1
}

# -----------------------------------------------------------------------------
# Manual guidance output
# -----------------------------------------------------------------------------
show_manual_connection_guidance() {
    print_header "Next Steps"

    local connector_id=""
    if [[ -f "$ENV_FILE" ]]; then
        connector_id=$(grep '^CUSTOM_CONNECTOR_ID=' "$ENV_FILE" | cut -d= -f2- || echo "")
    fi

    local list_secrets_command=""
    if [[ -n "$APIM_RESOURCE_ID" && -n "$APIM_SUBSCRIPTION_INTERNAL_ID" ]]; then
        list_secrets_command="az rest --method post --uri 'https://management.azure.com${APIM_RESOURCE_ID}/subscriptions/${APIM_SUBSCRIPTION_INTERNAL_ID}/listSecrets?api-version=2023-05-01-preview' --body '{}'"
    fi

    local primary_key_status="not retrieved automatically"
    if [[ -n "$APIM_SUBSCRIPTION_KEY" ]]; then
        primary_key_status="retrieved (shown below)"
    fi

    cat <<EOF
${GREEN}✅ Custom Connector setup complete${NC}

${BOLD}Connector summary:${NC}
• Project directory: $(basename "$CONNECTOR_PROJECT_DIR")
• Connector name: ${CONNECTOR_NAME}
• Connector ID: ${connector_id:-"(check environment)"}
• Environment URL: ${ENVIRONMENT_URL}

${BOLD}Next actions:${NC}
1. Create a connection in Power Apps / Power Automate:
   • Power Apps portal → Data → Connections → New connection
   • Select Custom → "${CONNECTOR_NAME}" → Create
   • When prompted, paste the APIM subscription primary key

2. Review APIM subscription details:
   • Subscription: ${APIM_SUBSCRIPTION_NAME_RESOLVED:-"(not auto-detected)"}
   • Subscription ID: ${APIM_SUBSCRIPTION_INTERNAL_ID:-"(n/a)"}
   • Primary Key: ${primary_key_status}
EOF

    if [[ -n "$APIM_SUBSCRIPTION_KEY" ]]; then
        cat <<EOF

${BOLD}Primary key (handle securely):${NC}
$APIM_SUBSCRIPTION_KEY
EOF
    else
        cat <<EOF

${BOLD}Need to retrieve the primary key?${NC}
   • Azure portal: API Management → ${APIM_NAME} → Subscriptions → (select subscription) → Keys
EOF
        if [[ -n "$list_secrets_command" ]]; then
            cat <<EOF
   • CLI: $list_secrets_command
EOF
        fi
        echo
    fi

    cat <<EOF
3. Use the connector:
   • Add it as a data source in Power Apps or a connector step in Power Automate
   • Store the subscription key in a secure location (Key Vault, Azure App Configuration, etc.)

4. Validate VNet integration:
   • Execute operations through the connector and ensure APIM logs show private endpoint traffic
   • Review Azure Monitor / Application Insights for diagnostics

${BOLD}Documentation:${NC}
   • docs/CUSTOM_CONNECTOR_PAC_CLI_SETUP.md for end-to-end details

${BOLD}Troubleshooting:${NC}
   • Run scripts in the troubleshooting/ directory
   • Re-run this script with --verbose for additional diagnostics
EOF
}

# -----------------------------------------------------------------------------
# Error handling
# -----------------------------------------------------------------------------
handle_error() {
    local exit_code=$?
    local line_number=$1
    error "Script failed at line $line_number with exit code $exit_code"
    error "Review the output above for troubleshooting guidance."
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# -----------------------------------------------------------------------------
# Main entry point
# -----------------------------------------------------------------------------
main() {
    print_header "Power Platform Custom Connector (PAC CLI v${SCRIPT_VERSION})"

    info "Starting custom connector creation pipeline..."
    debug "Root directory: $ROOT_DIR"
    debug "Environment file: $ENV_FILE"

    validate_prerequisites
    verify_pac_authentication
    discover_environment_details
    resolve_apim_subscription_details
    setup_connector_project
    setup_api_definition
    setup_connection_properties

    if deploy_custom_connector; then
        show_manual_connection_guidance
        success "🎉 Custom connector deployment workflow completed!"
    else
        error "Deployment step failed; review output and retry after resolving issues."
    fi
}

main "$@"
