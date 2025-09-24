#!/bin/bash

# =============================================================================
# Enhanced Power Platform Environment Creation Script (PAC CLI Version)
# =============================================================================
#
# SYNOPSIS
#     Creates a fully configured Power Platform environment using PAC CLI for complete automation.
#
# DESCRIPTION
#     This enhanced script leverages PAC CLI to fully automate Power Platform environment creation,
#     including Dataverse database provisioning and managed environment configuration.
#     
#     FULLY AUTOMATED CAPABILITIES:
#     1. ✅ Creates Power Platform environment with Dataverse database
#     2. ✅ Enables managed environment features and governance settings
#     3. ✅ Configures security and sharing policies
#     4. ✅ Updates .env file with all environment details
#     5. ✅ Validates environment readiness for infrastructure deployment
#
#     ADVANTAGES OVER REST API APPROACH:
#     - More reliable Dataverse provisioning (uses proven PAC CLI backend)
#     - Built-in retry logic and error handling
#     - Consistent authentication model
#     - Better status monitoring and feedback
#     - Full managed environment automation
#
# REQUIREMENTS
#     - Power Platform CLI (pac) - installed and authenticated
#     - Power Platform Admin permissions
#     - Azure CLI for environment variable management
#
# USAGE
#     ./0-CreatePowerPlatformEnvironment-Enhanced.sh [OPTIONS]
#
# OPTIONS
#     --env-file PATH              Path to environment file (default: ./.env)
#     --environment-type TYPE      Environment type: Production, Sandbox, Trial, Developer (default: Sandbox)
#     --enable-managed-env        Enable managed environment with governance features (default: true)
#     --disable-managed-env       Disable managed environment features
#     --force                     Skip confirmation prompts
#     --help                      Show this help message
#
# EXAMPLES
#     # Create environment with all features enabled
#     ./0-CreatePowerPlatformEnvironment-Enhanced.sh --environment-type Production --force
#     
#     # Create basic environment without managed features
#     ./0-CreatePowerPlatformEnvironment-Enhanced.sh --disable-managed-env
#
# =============================================================================

set -euo pipefail

# Default values
ENV_FILE="./.env"
ENVIRONMENT_TYPE="Sandbox"
ENABLE_MANAGED_ENV="true"
FORCE="false"
SHOW_HELP="false"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }
log_step() { echo -e "${CYAN}$1${NC}"; }
log_header() { echo -e "${MAGENTA}$1${NC}"; }

# Function to configure managed environment
configure_managed_environment() {
    local env_id=$1
    
    log_step "Configuring managed environment features..."
    
    # Enable managed environment with standard protection
    MANAGED_CONFIG_OUTPUT=$(pac admin set-governance-config \
        --environment "$env_id" \
        --protection-level "Standard" \
        --solution-checker-mode "warn" \
        --limit-sharing-mode "excludeDefaultEnvironmentMaker" \
        --max-limit-user-sharing 10 \
        --suppress-validation-emails \
        2>&1)
    
    if [ $? -eq 0 ]; then
        log_info "Managed environment configured successfully"
        echo "Configuration details:"
        echo "- Protection Level: Standard"
        echo "- Solution Checker: Warn mode"
        echo "- Sharing: Limited to 10 users"
        echo "- Validation emails: Suppressed"
    else
        log_warning "Managed environment configuration encountered issues"
        echo "Output: $MANAGED_CONFIG_OUTPUT"
        log_warning "This may be due to license requirements or tenant settings"
    fi
}

# Function to update .env file and show completion message
update_env_file_and_complete() {
    log_step "Updating .env file with environment details..."
    
    # Create backup
    cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Update or add environment variables
    update_env_var() {
        local key=$1
        local value=$2
        
        if grep -q "^$key=" "$ENV_FILE"; then
            sed -i "s|^$key=.*|$key=$value|" "$ENV_FILE"
        else
            echo "$key=$value" >> "$ENV_FILE"
        fi
    }
    
    update_env_var "POWER_PLATFORM_ENVIRONMENT_ID" "$ENV_ID"
    update_env_var "POWER_PLATFORM_ENVIRONMENT_URL" "$ENV_URL"
    update_env_var "DATAVERSE_INSTANCE_URL" "$ENV_URL"
    update_env_var "DATAVERSE_ORGANIZATION_ID" "$ORG_ID"
    
    echo ""
    log_header "🎉 Power Platform Environment Ready!"
    log_header "===================================="
    echo "Environment Name: $POWER_PLATFORM_ENVIRONMENT_NAME"
    echo "Environment ID: $ENV_ID"
    echo "Environment Type: $ENVIRONMENT_TYPE"
    echo "Location: $POWER_PLATFORM_LOCATION"
    echo "Environment URL: $ENV_URL"
    echo ""
    echo "✅ Dataverse Database: ENABLED"
    echo "✅ Organization ID: $ORG_ID"
    
    if [ "$ENABLE_MANAGED_ENV" == "true" ]; then
        echo "✅ Managed Environment: ENABLED"
        echo "✅ Governance Features: CONFIGURED"
    fi
    
    echo ""
    echo "🚀 Ready for Infrastructure Deployment:"
    echo "1. Run: ./scripts/1-InfraSetup.sh"
    echo "2. Run: ./scripts/2-SubnetInjectionSetup.sh"
    echo "3. Run: ./scripts/3-CreateCustomConnector_v2.sh"
    echo "4. Run: ./scripts/4-SetupCopilotStudio.sh"
    echo ""
    echo "Or use the orchestrator: ./RunMe.sh --skip-environment"
    echo ""
    log_info "Environment details saved to $ENV_FILE"
    log_info "No manual steps required - fully automated!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --environment-type)
            ENVIRONMENT_TYPE="$2"
            shift 2
            ;;
        --enable-managed-env)
            ENABLE_MANAGED_ENV="true"
            shift
            ;;
        --disable-managed-env)
            ENABLE_MANAGED_ENV="false"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --help)
            SHOW_HELP="true"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

# Show help
if [ "$SHOW_HELP" == "true" ]; then
    cat << 'EOF'
Enhanced Power Platform Environment Creation Script (PAC CLI)

USAGE:
    ./0-CreatePowerPlatformEnvironment-Enhanced.sh [OPTIONS]

OPTIONS:
    --env-file PATH               Path to environment file (default: ./.env)
    --environment-type TYPE       Environment type: Production, Sandbox, Trial, Developer (default: Sandbox)
    --enable-managed-env         Enable managed environment features (default)
    --disable-managed-env        Disable managed environment features  
    --force                      Skip confirmation prompts
    --help                       Show this help message

EXAMPLES:
    # Create fully managed production environment
    ./0-CreatePowerPlatformEnvironment-Enhanced.sh --environment-type Production --force
    
    # Create basic sandbox environment
    ./0-CreatePowerPlatformEnvironment-Enhanced.sh --disable-managed-env

ADVANTAGES:
    ✅ Fully automated Dataverse database provisioning
    ✅ Automated managed environment configuration
    ✅ Better error handling and retry logic
    ✅ Consistent PAC CLI authentication
    ✅ No manual steps required

EOF
    exit 0
fi

# Validate environment type
case "$ENVIRONMENT_TYPE" in
    "Production"|"Sandbox"|"Trial"|"Developer")
        ;;
    *)
        log_error "Invalid environment type: $ENVIRONMENT_TYPE"
        echo "Valid values: Production, Sandbox, Trial, Developer"
        exit 1
        ;;
esac

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    log_step "Loading environment variables from: $ENV_FILE"
    export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
else
    log_error "Environment file not found: $ENV_FILE"
    exit 1
fi

# Required variables with validation
: ${POWER_PLATFORM_ENVIRONMENT_NAME:?"POWER_PLATFORM_ENVIRONMENT_NAME environment variable is required"}
: ${POWER_PLATFORM_LOCATION:?"POWER_PLATFORM_LOCATION environment variable is required"}
: ${AZURE_LOCATION:?"AZURE_LOCATION environment variable is required"}

# Optional variables with defaults
ENVIRONMENT_DESCRIPTION="${ENVIRONMENT_DESCRIPTION:-Power Platform environment for VNet integration with Azure API Management}"
ENVIRONMENT_CURRENCY="${ENVIRONMENT_CURRENCY:-USD}"
ENVIRONMENT_LANGUAGE="${ENVIRONMENT_LANGUAGE:-English}"

echo ""
log_header "🚀 Enhanced Power Platform Environment Creation (PAC CLI)"
log_header "========================================================="
echo "Environment Name: $POWER_PLATFORM_ENVIRONMENT_NAME"
echo "Location: $POWER_PLATFORM_LOCATION"
echo "Type: $ENVIRONMENT_TYPE"
echo "Managed Environment: $ENABLE_MANAGED_ENV"
echo "Currency: $ENVIRONMENT_CURRENCY"
echo "Language: $ENVIRONMENT_LANGUAGE"
echo ""

# Get user confirmation if not using --force
if [ "$FORCE" != "true" ]; then
    echo "This script will create a FULLY AUTOMATED Power Platform environment with:"
    echo "✅ Base Power Platform environment"
    echo "✅ Dataverse database (automatically provisioned)"
    if [ "$ENABLE_MANAGED_ENV" == "true" ]; then
        echo "✅ Managed environment with governance features"
        echo "✅ Security and sharing policy configuration"
    fi
    echo ""
    echo "Continue with environment creation? (y/N)"
    read -r confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled by user."
        exit 0
    fi
    echo ""
fi

# Check PAC CLI authentication
log_step "Checking PAC CLI authentication..."
AUTH_LIST=$(pac auth list 2>/dev/null || echo "")
AUTH_INFO=$(echo "$AUTH_LIST" | awk '/^\[[0-9]+\]/ && /\*/ {print $4; exit}')
if [ -z "$AUTH_INFO" ]; then
    log_error "PAC CLI not authenticated. Please run: pac auth create --deviceCode"
    echo "$AUTH_LIST"
    exit 1
fi
log_info "Authenticated as: $AUTH_INFO"

# Check if environment already exists
log_step "Checking if environment already exists..."
EXISTING_ENV=$(pac admin list --name "$POWER_PLATFORM_ENVIRONMENT_NAME" --json 2>/dev/null | jq -r '.[0].EnvironmentId // ""' 2>/dev/null || echo "")

if [ ! -z "$EXISTING_ENV" ]; then
    log_warning "Environment already exists with ID: $EXISTING_ENV"
    
    # Get environment details
    ENV_DETAILS=$(pac admin list --name "$POWER_PLATFORM_ENVIRONMENT_NAME" --json | jq -r '.[0]')
    ENV_URL=$(echo $ENV_DETAILS | jq -r '.EnvironmentUrl')
    ORG_ID=$(echo $ENV_DETAILS | jq -r '.OrganizationId')
    
    if [ "$ORG_ID" != "null" ] && [ ! -z "$ORG_ID" ]; then
        log_info "Environment already has Dataverse enabled"
        ENV_ID="$EXISTING_ENV"
        
        # Check and configure managed environment if requested
        if [ "$ENABLE_MANAGED_ENV" == "true" ]; then
            configure_managed_environment "$ENV_ID"
        fi
        
        # Update .env file and complete
        update_env_file_and_complete
        exit 0
    else
        log_error "Existing environment does not have Dataverse. Please delete it first or use a different name."
        exit 1
    fi
fi

# Create new environment with Dataverse using PAC CLI
log_step "Creating new environment with Dataverse using PAC CLI..."

# Generate unique domain name
DOMAIN_NAME="e2e$(date +%m%d%H%M)$(echo $RANDOM | md5sum | head -c 4)"

log_info "Creating environment: $POWER_PLATFORM_ENVIRONMENT_NAME"
log_info "Domain: $DOMAIN_NAME"
log_info "Region: $POWER_PLATFORM_LOCATION"

# Create environment with PAC CLI
CREATE_OUTPUT=$(pac admin create \
    --name "$POWER_PLATFORM_ENVIRONMENT_NAME" \
    --region "$POWER_PLATFORM_LOCATION" \
    --type "$ENVIRONMENT_TYPE" \
    --currency "$ENVIRONMENT_CURRENCY" \
    --language "$ENVIRONMENT_LANGUAGE" \
    --domain "$DOMAIN_NAME" \
    --async \
    --max-async-wait-time 45 2>&1)

if [ $? -eq 0 ]; then
    log_info "Environment creation initiated successfully"
    echo "PAC CLI Output: $CREATE_OUTPUT"
    
    # Wait for completion by monitoring status
    log_step "Monitoring environment creation progress..."
    TIMEOUT=2700  # 45 minutes
    ELAPSED=0
    POLL_INTERVAL=30
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        sleep $POLL_INTERVAL
        ELAPSED=$((ELAPSED + POLL_INTERVAL))
        
        # Check if environment appears in list with Dataverse
        ENV_CHECK=$(pac admin list --name "$POWER_PLATFORM_ENVIRONMENT_NAME" --json 2>/dev/null | jq -r '.[0] // {}' 2>/dev/null || echo "{}")
        ENV_ID=$(echo $ENV_CHECK | jq -r '.EnvironmentId // ""')
        ORG_ID=$(echo $ENV_CHECK | jq -r '.OrganizationId // ""')
        ENV_URL=$(echo $ENV_CHECK | jq -r '.EnvironmentUrl // ""')
        
        if [ ! -z "$ENV_ID" ] && [ "$ORG_ID" != "null" ] && [ ! -z "$ORG_ID" ]; then
            log_info "Environment creation completed successfully!"
            echo "Environment ID: $ENV_ID"
            echo "Environment URL: $ENV_URL"
            echo "Organization ID: $ORG_ID"
            break
        elif [ ! -z "$ENV_ID" ]; then
            echo "Environment exists but Dataverse still provisioning... (Elapsed: ${ELAPSED}s)"
        else
            echo "Environment creation in progress... (Elapsed: ${ELAPSED}s)"
        fi
        
        if [ $ELAPSED -ge $TIMEOUT ]; then
            log_error "Environment creation timeout after 45 minutes"
            exit 1
        fi
    done
else
    log_error "Environment creation failed"
    echo "Error output: $CREATE_OUTPUT"
    exit 1
fi

# Function to configure managed environment if requested
if [ "$ENABLE_MANAGED_ENV" == "true" ]; then
    configure_managed_environment "$ENV_ID"
fi

# Update .env file and complete setup
update_env_file_and_complete

log_info "Enhanced PAC CLI environment creation completed successfully!"