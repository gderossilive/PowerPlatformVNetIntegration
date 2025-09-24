#!/bin/bash
# =============================================================================
# RunMe.sh - One-click Orchestrator for Fresh Power Platform + Azure Environment
# =============================================================================
# This script orchestrates the end-to-end creation of a NEW environment for the
# Power Platform VNet Integration solution, wrapping existing component scripts
# and clearly surfacing REQUIRED MANUAL STEPS you must perform in the portals.
#
# AUTOMATED (via scripts):
#   1. Create Power Platform environment with Dataverse & Managed Environment (PAC CLI)
#   2. Deploy Azure infrastructure (RG, VNets, APIM, Private Endpoint, Enterprise Policy)
#   3. Link Enterprise Policy (Subnet Injection) to the Power Platform environment
#   4. Create Power Platform custom connector via PAC CLI (if authenticated)
#
# MANUAL ACTIONS REQUIRED (portal / UI):
#   A. Disable APIM public access (retry manually if script warnings appear)
#   B. (Optional) Validate connector functionality and configure Copilot Studio
#
# ENHANCED AUTOMATION (PAC CLI Mode - Default):
#   ✅ Dataverse database automatically provisioned
#   ✅ Managed Environment features automatically enabled
#   ✅ No manual Power Platform Admin Center steps required
#   ✅ Better reliability and error handling
#
# USAGE:
#   ./RunMe.sh -n "Fabrikam-Test" -r westeurope -p europe
#
# ARGUMENTS:
#   -n | --name          Display name of the Power Platform environment (required)
#   -r | --azure-region  Azure region (for infra) e.g. westeurope (required)
#   -p | --pp-location   Power Platform location code e.g. europe (required)
#   -f | --force         Skip confirmations
#   --skip-environment   Skip Power Platform environment creation (use existing)
#   --skip-infra         Skip Azure infra deployment (reuse existing)
#   --skip-link          Skip subnet injection linking
#   --skip-connector     Skip custom connector creation
#   --use-rest-api       Use REST API instead of PAC CLI for environment creation (legacy mode)
#   --disable-managed-env Disable managed environment features (not recommended)
#   --env-file PATH      Custom .env path (default: ./.env)
#
# OUTPUT:
#   Updated .env file containing all identifiers (Environment ID, RG, VNets, APIM, etc.)
#
# PREREQUISITES:
#   - Azure CLI (logged in) + appropriate permissions
#   - Power Platform Admin permissions
#   - Power Platform CLI (pac) authenticated: pac auth create --deviceCode (recommended)
#   - azd installed
#   - jq, curl present
#   - Existing repo scripts (under scripts/):
#       scripts/0-CreatePowerPlatformEnvironment.sh
#       scripts/1-InfraSetup.sh
#       scripts/2-SubnetInjectionSetup.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
ENV_FILE="${ROOT_DIR}/.env"
FORCE=false
SKIP_ENVIRONMENT=false
SKIP_INFRA=false
SKIP_LINK=false
SKIP_CONNECTOR=false
USE_REST_API=false
DISABLE_MANAGED_ENV=false
PP_ENV_NAME=""
AZURE_REGION=""
PP_LOCATION=""

color() { local c="$1"; shift; printf "\033[%sm%s\033[0m" "$c" "$*"; }
info(){ echo -e "$(color 34 [INFO]) $*"; }
success(){ echo -e "$(color 32 [SUCCESS]) $*"; }
warn(){ echo -e "$(color 33 [WARNING]) $*"; }
err(){ echo -e "$(color 31 [ERROR]) $*"; }

print_header(){ echo; echo "============================================"; echo "$1"; echo "============================================"; }

usage(){ sed -n '1,120p' "$0"; exit 1; }

# ------------------------------- Parse Args ----------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name) PP_ENV_NAME="$2"; shift 2;;
    -r|--azure-region) AZURE_REGION="$2"; shift 2;;
    -p|--pp-location) PP_LOCATION="$2"; shift 2;;
    -f|--force) FORCE=true; shift;;
    --skip-environment) SKIP_ENVIRONMENT=true; shift;;
    --skip-infra) SKIP_INFRA=true; shift;;
    --skip-link) SKIP_LINK=true; shift;;
    --skip-connector) SKIP_CONNECTOR=true; shift;;
    --use-rest-api) USE_REST_API=true; shift;;
    --disable-managed-env) DISABLE_MANAGED_ENV=true; shift;;
    --env-file) ENV_FILE="$2"; shift 2;;
    -h|--help) usage;;
    *) err "Unknown argument: $1"; usage;;
  esac
done

if [[ -z "$PP_ENV_NAME" || -z "$AZURE_REGION" || -z "$PP_LOCATION" ]]; then
  err "Missing required arguments."; usage
fi

print_header "Power Platform VNet Integration Orchestrator"
info "Environment Name       : $PP_ENV_NAME"
info "Azure Region           : $AZURE_REGION"
info "Power Platform Location: $PP_LOCATION"
info "Env File               : $ENV_FILE"

if ! $FORCE; then
  read -r -p "Proceed with creation? (y/N) " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { warn "Aborted by user."; exit 0; }
fi

# ------------------------ Initialize Base .env -------------------------------
print_header "Step 0: Initialize Base .env"
TENANT_ID_LINE=$(grep '^TENANT_ID=' "$ENV_FILE" 2>/dev/null || echo "TENANT_ID=")
if [[ -z "${TENANT_ID_LINE#TENANT_ID=}" ]]; then
  warn "TENANT_ID not set in $ENV_FILE. Please edit the file and set TENANT_ID, AZURE_SUBSCRIPTION_ID first if empty."
fi
# Preserve existing tenant/sub; append or update rest
TENANT_ID=$(echo "$TENANT_ID_LINE" | cut -d= -f2-)
AZ_SUB_LINE=$(grep '^AZURE_SUBSCRIPTION_ID=' "$ENV_FILE" 2>/dev/null || echo "AZURE_SUBSCRIPTION_ID=")
AZ_SUB=$(echo "$AZ_SUB_LINE" | cut -d= -f2-)

cat > "$ENV_FILE" <<EOF
TENANT_ID=${TENANT_ID}
AZURE_SUBSCRIPTION_ID=${AZ_SUB}
AZURE_LOCATION=${AZURE_REGION}
POWER_PLATFORM_ENVIRONMENT_NAME=${PP_ENV_NAME}
POWER_PLATFORM_LOCATION=${PP_LOCATION}
EOF
success "Base .env initialized/updated."

# --------------------- Step 1: Create PP Environment -------------------------
if ! $SKIP_ENVIRONMENT; then
  print_header "Step 1: Create Power Platform Environment (PAC CLI Mode)"
  
  if $USE_REST_API; then
    info "Using REST API mode (legacy) for environment creation..."
    if ! bash "${SCRIPTS_DIR}/0-CreatePowerPlatformEnvironment.sh" --force --env-file "$ENV_FILE"; then
      err "Power Platform environment creation failed."; exit 1
    fi
  else
    info "Using PAC CLI mode for enhanced automation..."
    ENV_CREATION_CMD=(bash "${SCRIPTS_DIR}/0-CreatePowerPlatformEnvironment-Enhanced.sh" --force --env-file "$ENV_FILE")
    
    if ! $DISABLE_MANAGED_ENV; then
      ENV_CREATION_CMD+=(--enable-managed-env)
      info "✅ Managed environment features will be enabled automatically"
    fi
    
    if ! "${ENV_CREATION_CMD[@]}"; then
      err "Power Platform environment creation failed."; exit 1
    fi
  fi
  
  PP_ENV_ID=$(grep '^POWER_PLATFORM_ENVIRONMENT_ID=' "$ENV_FILE" | cut -d= -f2- || true)
  if [[ -z "$PP_ENV_ID" ]]; then
    err "Environment ID missing after creation."; exit 1
  fi
  success "Power Platform Environment ID: $PP_ENV_ID"
  
  if ! $USE_REST_API; then
    success "✅ Dataverse database automatically provisioned"
    if ! $DISABLE_MANAGED_ENV; then
      success "✅ Managed environment features automatically enabled"
    fi
    success "✅ No manual Power Platform steps required!"
  else
    # Show manual steps for REST API mode
    print_header "MANUAL STEP A: Enable Dataverse Database (REST API Mode)"
    cat <<'MANUAL_A'
ACTION REQUIRED:
  1. Open https://admin.powerplatform.microsoft.com/
  2. Environments -> select: (your environment name)
  3. Settings -> Dynamics 365 apps -> "Create my database"
  4. Choose language/currency, disable sample data (recommended)
  5. Submit and WAIT until provisioning completes (can take 10-15 minutes)
  6. (Optional) Re-run this orchestrator with --force to continue or just proceed once ready.
MANUAL_A

    print_header "MANUAL STEP B: Convert to Managed Environment (Optional)"
    cat <<'MANUAL_B'
ACTION OPTIONAL:
  1. Same environment -> Settings -> Features
  2. Locate Managed Environment toggle -> Enable
  3. Configure governance options (DLP, IP firewall, etc.)
  4. Save changes
MANUAL_B
  fi
else
  warn "Skipping Power Platform environment creation (--skip-environment)."
  PP_ENV_ID=$(grep '^POWER_PLATFORM_ENVIRONMENT_ID=' "$ENV_FILE" | cut -d= -f2- || true)
  if [[ -z "$PP_ENV_ID" ]]; then
    err "Environment ID missing in $ENV_FILE. Please create environment first or check .env file."; exit 1
  fi
  success "Using existing Power Platform Environment ID: $PP_ENV_ID"
fi

# --------------------- Step 2: Azure Infrastructure --------------------------
if ! $SKIP_INFRA; then
  print_header "Step 2: Azure Infrastructure Deployment"
  if ! bash "${SCRIPTS_DIR}/1-InfraSetup.sh"; then
     err "Infrastructure deployment failed."; exit 1; fi
else
  warn "Skipping Azure infrastructure deployment (--skip-infra)."
fi

# Capture values again (infra script may have recreated .env)
PP_ENV_ID=$(grep '^POWER_PLATFORM_ENVIRONMENT_ID=' "$ENV_FILE" | cut -d= -f2- || true)
RG_NAME=$(grep '^RESOURCE_GROUP=' "$ENV_FILE" | cut -d= -f2- || true)
APIM_NAME=$(grep '^APIM_SERVICE_NAME=' "$ENV_FILE" | cut -d= -f2- || true)
if [[ -z "$APIM_NAME" ]]; then
  APIM_NAME=$(grep '^APIM_NAME=' "$ENV_FILE" | cut -d= -f2- || true)
fi

# ------------------ MANUAL STEP C: APIM Public Access ------------------------
print_header "MANUAL STEP C: Verify APIM Private Access"
cat <<'MANUAL_C'
ACTION REQUIRED IF WARNINGS WERE DISPLAYED:
  1. Azure Portal -> API Management -> (instance)
  2. Navigate: Networking -> Public network access -> Disable
  3. Ensure private endpoint connection status = Approved
  4. Validate DNS resolution inside injected environment (later via connector test)
MANUAL_C

# --------------------- Step 3: Subnet Injection Link -------------------------
if ! $SKIP_LINK; then
  print_header "Step 3: Link Enterprise Policy (Subnet Injection)"
  if ! bash "${SCRIPTS_DIR}/2-SubnetInjectionSetup.sh"; then
     err "Subnet injection linking failed."; exit 1; fi
else
  warn "Skipping subnet injection linking (--skip-link)."
fi

# Extract system ID if available and append to .env safely
SYSTEM_ID=$(grep '^ENTERPRISE_POLICY_SYSTEM_ID=' "$ENV_FILE" | cut -d= -f2- || true)
if [[ -z "$SYSTEM_ID" ]]; then
  # Try discover from enterprise policy resource
  if [[ -n "$RG_NAME" ]]; then
    EP_NAME=$(grep '^ENTERPRISE_POLICY_NAME=' "$ENV_FILE" | cut -d= -f2- || true)
    if [[ -n "$EP_NAME" ]]; then
      DETAIL=$(az resource show --name "$EP_NAME" --resource-group "$RG_NAME" --resource-type "Microsoft.PowerPlatform/enterprisePolicies" -o json 2>/dev/null || echo '')
      SYS=$(echo "$DETAIL" | jq -r '.properties.systemId // empty')
      if [[ -n "$SYS" ]]; then
        echo "ENTERPRISE_POLICY_SYSTEM_ID=$SYS" >> "$ENV_FILE"
        success "Captured ENTERPRISE_POLICY_SYSTEM_ID: $SYS"
      fi
    fi
  fi
fi

# ------------------ Custom Connector Setup (PAC CLI) ------------------------
# Run custom connector setup if not skipped
if [[ "${SKIP_CONNECTOR:-false}" != "true" ]]; then
  print_header "Setting up Custom Connector via PAC CLI"
  
  info "Running dedicated custom connector creation script..."
  if [[ -x "${SCRIPTS_DIR}/3-CreateCustomConnector_v2.sh" ]]; then
    cd "$ROOT_DIR"
    if "${SCRIPTS_DIR}/3-CreateCustomConnector_v2.sh" --env-file "$ENV_FILE"; then
      success "Custom connector creation completed successfully"
    else
      warn "Custom connector creation encountered issues. Check the output above."
      warn "You can retry manually: ${SCRIPTS_DIR}/3-CreateCustomConnector_v2.sh"
    fi
  else
    warn "Custom connector script not found or not executable: ${SCRIPTS_DIR}/3-CreateCustomConnector_v2.sh"
    warn "Please run it manually after infrastructure setup is complete"
  fi
else
  warn "Skipping custom connector setup (--skip-connector)."
fi

# ------------------ Summary & Next Steps -------------------------------------
print_header "Summary"
cat <<EOF
Environment Name : $PP_ENV_NAME
Environment ID   : $PP_ENV_ID
Resource Group   : $RG_NAME
APIM Name        : $APIM_NAME
Env File         : $ENV_FILE
EOF

cat <<'NEXT'
🎉 DEPLOYMENT COMPLETED WITH ENHANCED AUTOMATION:
  ✅ Power Platform environment with Dataverse automatically created (PAC CLI mode)
  ✅ Managed environment features automatically enabled (unless disabled)
  ✅ Azure infrastructure deployed with private networking
  ✅ Enterprise policy linked for VNet subnet injection
  ✅ Custom connector created and configured (if PAC CLI authenticated)

NEXT OPTIONAL ACTIONS:
  1. Test the custom connector with your APIM subscription key in Power Apps
  2. Run ./scripts/4-SetupCopilotStudio.sh to configure Copilot Studio assets
  3. Validate connector functionality (invoke operations from Power Apps/Power Automate)
  4. (Optional) Backup environment file: cp .env .env.$(date +%Y%m%d-%H%M%S).backup
  5. For teardown: ./Cleanup.sh (then manually delete PP environment)

TROUBLESHOOTING:
  - If custom connector creation failed, check PAC CLI authentication: pac auth list
  - Re-run with --skip-connector to skip automatic connector creation
  - Run ./scripts/3-CreateCustomConnector_v2.sh --help for detailed connector setup options
  - Use --use-rest-api for legacy REST API mode if PAC CLI issues occur
  - If APIM network settings failed, configure manually then re-run (--skip-infra --skip-link as needed)
  - If subnet injection status shows Unknown, wait a few minutes and re-run subnet linking script

AUTOMATION NOTES:
  - PAC CLI mode (default): Full automation, no manual steps required for Power Platform
  - REST API mode (--use-rest-api): Legacy mode, requires manual Dataverse setup
  - Managed Environment: Enabled by default (use --disable-managed-env to disable)
NEXT

if $USE_REST_API; then
  warn "RunMe.sh orchestration completed using REST API mode. Review manual steps above before proceeding."
else
  success "RunMe.sh orchestration completed with full automation! No manual Power Platform steps required."
fi
