#!/bin/bash

# =============================================================================
# Master Troubleshooting Script - Run All Atomic Tests
# =============================================================================

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/functions.sh"

# Script configuration
SCRIPT_NAME="Master Troubleshooting Script"
TEST_RESULTS=()
FAILED_TESTS=()

# Function to run a test script and capture results
run_test_script() {
    local test_name="$1"
    local script_path="$2"
    local category="$3"
    
    log_info "Running test: $test_name"
    echo "----------------------------------------"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Test script not found: $script_path"
        TEST_RESULTS+=("$category/$test_name: MISSING")
        FAILED_TESTS+=("$category/$test_name")
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        log_error "Test script not executable: $script_path"
        TEST_RESULTS+=("$category/$test_name: NOT_EXECUTABLE")
        FAILED_TESTS+=("$category/$test_name")
        return 1
    fi
    
    # Run the test script
    local start_time=$(date +%s)
    if bash "$script_path"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "$test_name completed successfully (${duration}s)"
        TEST_RESULTS+=("$category/$test_name: PASSED (${duration}s)")
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "$test_name failed (${duration}s)"
        TEST_RESULTS+=("$category/$test_name: FAILED (${duration}s)")
        FAILED_TESTS+=("$category/$test_name")
        return 1
    fi
}

# Function to display test results summary
display_test_summary() {
    log_header "Test Results Summary"
    
    local total_tests=${#TEST_RESULTS[@]}
    local failed_count=${#FAILED_TESTS[@]}
    local passed_count=$((total_tests - failed_count))
    
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_count"
    echo "Failed: $failed_count"
    echo
    
    if [[ $failed_count -eq 0 ]]; then
        log_success "All tests passed!"
    else
        log_warning "$failed_count tests failed"
        echo
        log_info "Failed Tests:"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo "  ❌ $failed_test"
        done
    fi
    
    echo
    log_info "Detailed Results:"
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == *"PASSED"* ]]; then
            echo "  ✅ $result"
        elif [[ "$result" == *"FAILED"* ]]; then
            echo "  ❌ $result"
        else
            echo "  ⚠️  $result"
        fi
    done
}

# Function to check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    local prereq_ok=true
    
    # Check if .env file exists
    if [[ ! -f "$SCRIPT_DIR/../.env" ]]; then
        log_warning ".env file not found in project root"
        log_info "Some tests may fail without proper environment configuration"
    else
        log_success ".env file found"
    fi
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not found"
        prereq_ok=false
    else
        log_success "Azure CLI available"
    fi
    
    # Check Power Platform CLI
    if ! command -v pac &> /dev/null; then
        log_warning "Power Platform CLI not found"
        log_info "Power Platform tests may be skipped"
    else
        log_success "Power Platform CLI available"
    fi
    
    # Check required tools
    for tool in curl jq; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            prereq_ok=false
        else
            log_success "$tool available"
        fi
    done
    
    if [[ "$prereq_ok" != true ]]; then
        log_error "Prerequisites check failed"
        return 1
    fi
    
    log_success "All prerequisites available"
    return 0
}

# Main execution function
main() {
    # Parse command line arguments
    local run_all=true
    local specific_category=""
    local continue_on_failure=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --category)
                specific_category="$2"
                run_all=false
                shift 2
                ;;
            --continue-on-failure)
                continue_on_failure=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --category CATEGORY    Run tests for specific category only"
                echo "  --continue-on-failure  Continue running tests even if some fail"
                echo "  --help                Show this help message"
                echo
                echo "Available categories: auth, powerplatform, enterprise-policy, apim, azure-infra"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_header "$SCRIPT_NAME"
    log_info "Starting comprehensive troubleshooting at $(date)"
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit $EXIT_CONFIG_ERROR
    fi
    
    echo
    
    # Define test categories and scripts
    declare -A test_categories=(
        ["auth"]="Authentication Tests"
        ["powerplatform"]="Power Platform Tests"
        ["enterprise-policy"]="Enterprise Policy Tests"
        ["apim"]="API Management Tests"
        ["azure-infra"]="Azure Infrastructure Tests"
    )
    
    declare -A test_scripts=(
        ["auth/test-auth"]="$SCRIPT_DIR/auth/test-auth.sh"
        ["powerplatform/test-environment"]="$SCRIPT_DIR/powerplatform/test-environment.sh"
        ["enterprise-policy/test-enterprise-policy"]="$SCRIPT_DIR/enterprise-policy/test-enterprise-policy.sh"
        ["apim/test-apim-service"]="$SCRIPT_DIR/apim/test-apim-service.sh"
    )
    
    # Run tests
    local overall_exit_code=$EXIT_SUCCESS
    
    for test_key in "${!test_scripts[@]}"; do
        local category=$(echo "$test_key" | cut -d'/' -f1)
        local test_name=$(echo "$test_key" | cut -d'/' -f2)
        local script_path="${test_scripts[$test_key]}"
        
        # Skip if specific category requested and this isn't it
        if [[ "$run_all" == false ]] && [[ "$category" != "$specific_category" ]]; then
            continue
        fi
        
        echo
        log_header "${test_categories[$category]} - $test_name"
        
        if ! run_test_script "$test_name" "$script_path" "$category"; then
            overall_exit_code=$EXIT_GENERAL_ERROR
            
            if [[ "$continue_on_failure" != true ]]; then
                log_error "Test failed and --continue-on-failure not specified"
                break
            fi
        fi
        
        echo
    done
    
    # Display final summary
    echo
    display_test_summary
    
    return $overall_exit_code
}

# Initialize script
set -euo pipefail
trap 'handle_error $? "$BASH_COMMAND" $LINENO' ERR

# Run main function
if main "$@"; then
    cleanup_script "$SCRIPT_NAME" $EXIT_SUCCESS
    exit $EXIT_SUCCESS
else
    cleanup_script "$SCRIPT_NAME" $EXIT_GENERAL_ERROR
    exit $EXIT_GENERAL_ERROR
fi