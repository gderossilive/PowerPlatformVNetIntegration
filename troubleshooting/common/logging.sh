#!/bin/bash

# =============================================================================
# Common Logging Functions for Power Platform VNet Integration Troubleshooting
# =============================================================================

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# Icons for better visual output
export CHECK_MARK="✓"
export WARNING="⚠️"
export ERROR="❌"
export INFO="ℹ️"
export ROCKET="🚀"
export GEAR="⚙️"
export MAGNIFYING_GLASS="🔍"

# Debug mode
export DEBUG=${DEBUG:-false}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ${CHECK_MARK} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ${WARNING} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} ${ERROR} $1"
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} ${MAGNIFYING_GLASS} $1"
    fi
}

log_header() {
    echo -e "\n${BOLD}${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..${#1}})${NC}"
}

log_step() {
    echo -e "\n${GEAR} ${BOLD}$1${NC}"
}

log_result() {
    local status=$1
    local message=$2
    
    if [[ "$status" == "success" ]]; then
        log_success "$message"
    elif [[ "$status" == "warning" ]]; then
        log_warning "$message"
    elif [[ "$status" == "error" ]]; then
        log_error "$message"
    else
        log_info "$message"
    fi
}

# Progress indicator
show_progress() {
    local message=$1
    local delay=${2:-0.1}
    
    echo -n "$message"
    for i in {1..3}; do
        echo -n "."
        sleep $delay
    done
    echo ""
}

# Error handling
handle_error() {
    local exit_code=$1
    local error_message=$2
    local line_number=${3:-"unknown"}
    
    log_error "Script failed at line $line_number: $error_message"
    log_error "Exit code: $exit_code"
    
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "Call stack:"
        local frame=0
        while caller $frame; do
            ((frame++))
        done
    fi
    
    exit $exit_code
}

# Success message
show_success_banner() {
    local message=$1
    echo -e "\n${GREEN}${BOLD}"
    echo "████████████████████████████████████████"
    echo "█          SUCCESS - $message          █"
    echo "████████████████████████████████████████"
    echo -e "${NC}"
}

# Failure message
show_failure_banner() {
    local message=$1
    echo -e "\n${RED}${BOLD}"
    echo "████████████████████████████████████████"
    echo "█          FAILED - $message           █"
    echo "████████████████████████████████████████"
    echo -e "${NC}"
}

# Confirmation prompt
confirm_action() {
    local message=$1
    local default=${2:-"n"}
    
    if [[ "$default" == "y" ]]; then
        read -p "$message [Y/n]: " response
        response=${response:-y}
    else
        read -p "$message [y/N]: " response
        response=${response:-n}
    fi
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}