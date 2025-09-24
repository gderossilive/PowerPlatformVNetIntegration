#!/bin/bash

# =============================================================================
# Common Utility Functions for Power Platform VNet Integration Troubleshooting
# =============================================================================

# Source other common modules
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMON_DIR/logging.sh"
source "$COMMON_DIR/config.sh"

# Exit codes
export EXIT_SUCCESS=0
export EXIT_GENERAL_ERROR=1
export EXIT_CONFIG_ERROR=2
export EXIT_AUTH_ERROR=3
export EXIT_PERMISSION_ERROR=4
export EXIT_NOT_FOUND=5
export EXIT_NETWORK_ERROR=6
export EXIT_API_ERROR=7
export EXIT_DRY_RUN=10

# Script initialization
init_script() {
    local script_name="$1"
    local required_vars=("${@:2}")
    
    # Set error handling
    set -euo pipefail
    
    # Trap for error handling
    trap 'handle_error $? "$BASH_COMMAND" $LINENO' ERR
    
    log_header "$script_name"
    log_info "Starting $script_name at $(date)"
    
    # Load environment configuration
    if ! load_env_config; then
        log_warning "Could not load .env file, using environment variables"
    fi
    
    # Validate required environment variables
    if [[ ${#required_vars[@]} -gt 0 ]]; then
        if ! validate_env_vars "${required_vars[@]}"; then
            log_error "Required environment variables missing"
            exit $EXIT_CONFIG_ERROR
        fi
    fi
    
    # Validate Azure authentication
    if ! validate_azure_auth; then
        log_error "Azure authentication failed"
        exit $EXIT_AUTH_ERROR
    fi
    
    log_success "Script initialization completed"
}

# Script cleanup
cleanup_script() {
    local script_name="$1"
    local exit_code="${2:-0}"
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$script_name completed successfully"
    else
        log_error "$script_name failed with exit code $exit_code"
    fi
    
    log_info "Finished $script_name at $(date)"
}

# Make HTTP request with proper error handling
make_http_request() {
    local method="$1"
    local url="$2"
    local headers="$3"
    local data="${4:-}"
    local expected_status="${5:-200}"
    
    local response_file=$(mktemp)
    local http_code
    
    if [[ -n "$data" ]]; then
        http_code=$(curl -s -w "%{http_code}" \
            -X "$method" \
            -H "$headers" \
            -d "$data" \
            "$url" \
            -o "$response_file")
    else
        http_code=$(curl -s -w "%{http_code}" \
            -X "$method" \
            -H "$headers" \
            "$url" \
            -o "$response_file")
    fi
    
    local response_content=$(cat "$response_file")
    rm -f "$response_file"
    
    if [[ "$http_code" == "$expected_status" ]]; then
        echo "$response_content"
        return 0
    else
        log_error "HTTP request failed: $method $url"
        log_error "Expected status: $expected_status, Got: $http_code"
        log_error "Response: $response_content"
        return 1
    fi
}

# Test connectivity to a URL
test_connectivity() {
    local url="$1"
    local timeout="${2:-10}"
    local expected_status="${3:-200}"
    
    log_debug "Testing connectivity to: $url"
    
    local http_code=$(curl -s -w "%{http_code}" \
        --max-time "$timeout" \
        --connect-timeout 5 \
        -o /dev/null \
        "$url" 2>/dev/null || echo "000")
    
    if [[ "$http_code" == "$expected_status" ]]; then
        log_success "Connectivity test passed: $url (HTTP $http_code)"
        return 0
    else
        log_error "Connectivity test failed: $url (HTTP $http_code)"
        return 1
    fi
}

# Test DNS resolution
test_dns_resolution() {
    local hostname="$1"
    local record_type="${2:-A}"
    
    log_debug "Testing DNS resolution for: $hostname ($record_type record)"
    
    if nslookup "$hostname" >/dev/null 2>&1; then
        local ip=$(nslookup "$hostname" | grep "Address:" | tail -1 | awk '{print $2}')
        log_success "DNS resolution successful: $hostname -> $ip"
        return 0
    else
        log_error "DNS resolution failed: $hostname"
        return 1
    fi
}

# Generate timestamp
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Create temporary directory
create_temp_dir() {
    local prefix="${1:-tmp}"
    local temp_dir=$(mktemp -d -t "${prefix}_$(get_timestamp)_XXXXX")
    echo "$temp_dir"
}

# JSON manipulation helpers
json_get_value() {
    local json="$1"
    local key="$2"
    
    echo "$json" | jq -r ".$key // empty" 2>/dev/null || echo ""
}

json_has_key() {
    local json="$1"
    local key="$2"
    
    echo "$json" | jq -e "has(\"$key\")" >/dev/null 2>&1
}

# Array helpers
array_contains() {
    local array=("${@:1:$#-1}")
    local element="${@: -1}"
    
    for item in "${array[@]}"; do
        if [[ "$item" == "$element" ]]; then
            return 0
        fi
    done
    return 1
}

# String helpers
trim_whitespace() {
    local string="$1"
    echo "$string" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

to_lowercase() {
    local string="$1"
    echo "$string" | tr '[:upper:]' '[:lower:]'
}

# File helpers
backup_file() {
    local file="$1"
    local backup_dir="${2:-./backups}"
    
    if [[ -f "$file" ]]; then
        mkdir -p "$backup_dir"
        local timestamp=$(get_timestamp)
        local backup_file="$backup_dir/$(basename "$file").backup.$timestamp"
        cp "$file" "$backup_file"
        log_info "File backed up: $file -> $backup_file"
        echo "$backup_file"
    fi
}

# Retry mechanism
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    local command="${@:3}"
    
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt/$max_attempts: $command"
        
        if eval "$command"; then
            log_success "Command succeeded on attempt $attempt"
            return 0
        else
            if [[ $attempt -lt $max_attempts ]]; then
                log_warning "Command failed on attempt $attempt, retrying in ${delay}s..."
                sleep "$delay"
            else
                log_error "Command failed after $max_attempts attempts"
                return 1
            fi
        fi
        
        ((attempt++))
    done
}

# Progress bar
show_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%*s" "$filled" | tr ' ' '='
    printf "%*s" "$empty" | tr ' ' '-'
    printf "] %d%% (%d/%d)" "$percentage" "$current" "$total"
}

# Export all functions
export -f init_script
export -f cleanup_script
export -f make_http_request
export -f test_connectivity
export -f test_dns_resolution
export -f get_timestamp
export -f create_temp_dir
export -f json_get_value
export -f json_has_key
export -f array_contains
export -f trim_whitespace
export -f to_lowercase
export -f backup_file
export -f retry_command
export -f show_progress_bar