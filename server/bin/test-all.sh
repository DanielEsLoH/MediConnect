#!/usr/bin/env bash
#===============================================================================
# MediConnect Microservices - Centralized Test Execution Script
#===============================================================================
#
# Description:
#   Production-grade test runner for all MediConnect microservices.
#   Executes RSpec tests via Docker Compose, aggregates SimpleCov coverage
#   reports, and provides comprehensive test result summaries.
#
# Usage:
#   ./bin/test-all.sh [OPTIONS]
#
# Options:
#   --parallel      Run all services in parallel (faster, but mixed output)
#   --service NAME  Run tests for a single service only
#   --ci            CI/CD mode (no colors, JUnit XML output)
#   --verbose       Show detailed output from each service
#   --no-coverage   Skip coverage threshold enforcement
#   --help          Show this help message
#
# Examples:
#   ./bin/test-all.sh                    # Run all tests sequentially
#   ./bin/test-all.sh --parallel         # Run all tests in parallel
#   ./bin/test-all.sh --service users-service  # Run single service
#   ./bin/test-all.sh --ci               # CI mode with JUnit output
#
# Exit Codes:
#   0 - All tests passed and coverage >= 90%
#   1 - One or more tests failed
#   2 - Coverage below 90% threshold
#   3 - Configuration or environment error
#
# Compatibility:
#   - Works with bash 3.2+ (macOS default) and bash 4+
#   - Supports both docker-compose (v1) and docker compose (v2)
#
# Author: MediConnect Team
# Version: 1.0.0
#===============================================================================

set -o pipefail

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

# Script directory (for relative paths)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Services to test (in dependency order)
SERVICES="api-gateway users-service doctors-service appointments-service notifications-service payments-service"

# Coverage threshold
COVERAGE_THRESHOLD=90

# Output directories
COVERAGE_AGGREGATE_DIR="$PROJECT_ROOT/coverage-aggregate"
JUNIT_OUTPUT_DIR="$PROJECT_ROOT/test-results"
RESULTS_DIR=""  # Will be set in setup_directories

# Timing
SCRIPT_START_TIME=$(date +%s)

# Docker compose command (will be detected)
DOCKER_COMPOSE_CMD=""

#-------------------------------------------------------------------------------
# Color Codes (disabled in CI mode)
#-------------------------------------------------------------------------------

# Default: colors enabled
COLOR_ENABLED=true

setup_colors() {
    if [ "$COLOR_ENABLED" = "true" ]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        MAGENTA='\033[0;35m'
        CYAN='\033[0;36m'
        WHITE='\033[1;37m'
        BOLD='\033[1m'
        DIM='\033[2m'
        NC='\033[0m' # No Color

        # Status symbols
        PASS_SYMBOL="[PASS]"
        FAIL_SYMBOL="[FAIL]"
        WARN_SYMBOL="[WARN]"
        INFO_SYMBOL="[INFO]"
        RUN_SYMBOL="[....]"
    else
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        MAGENTA=''
        CYAN=''
        WHITE=''
        BOLD=''
        DIM=''
        NC=''

        # Plain text symbols for CI
        PASS_SYMBOL="[PASS]"
        FAIL_SYMBOL="[FAIL]"
        WARN_SYMBOL="[WARN]"
        INFO_SYMBOL="[INFO]"
        RUN_SYMBOL="[....]"
    fi
}

#-------------------------------------------------------------------------------
# Command Line Options
#-------------------------------------------------------------------------------

PARALLEL_MODE=false
SINGLE_SERVICE=""
CI_MODE=false
VERBOSE_MODE=false
SKIP_COVERAGE=false

#-------------------------------------------------------------------------------
# Helper Functions for Service Data (bash 3.2 compatible)
#-------------------------------------------------------------------------------

# Get human-readable service name
get_service_name() {
    local service="$1"
    case "$service" in
        api-gateway) echo "API Gateway" ;;
        users-service) echo "Users Service" ;;
        doctors-service) echo "Doctors Service" ;;
        appointments-service) echo "Appointments Service" ;;
        notifications-service) echo "Notifications Service" ;;
        payments-service) echo "Payments Service" ;;
        *) echo "$service" ;;
    esac
}

# Store result for a service
store_result() {
    local service="$1"
    local result="$2"
    local coverage="$3"
    local duration="$4"
    local tests_run="$5"
    local tests_failed="$6"

    echo "RESULT=$result" > "$RESULTS_DIR/${service}.result"
    echo "COVERAGE=$coverage" >> "$RESULTS_DIR/${service}.result"
    echo "DURATION=$duration" >> "$RESULTS_DIR/${service}.result"
    echo "TESTS_RUN=$tests_run" >> "$RESULTS_DIR/${service}.result"
    echo "TESTS_FAILED=$tests_failed" >> "$RESULTS_DIR/${service}.result"
}

# Get result for a service
get_result() {
    local service="$1"
    local field="$2"

    if [ -f "$RESULTS_DIR/${service}.result" ]; then
        grep "^${field}=" "$RESULTS_DIR/${service}.result" | cut -d= -f2
    else
        case "$field" in
            RESULT) echo "fail" ;;
            COVERAGE) echo "0.0" ;;
            DURATION) echo "0" ;;
            TESTS_RUN) echo "0" ;;
            TESTS_FAILED) echo "0" ;;
        esac
    fi
}

# Track failed services
add_failed_service() {
    local service="$1"
    echo "$service" >> "$RESULTS_DIR/failed_services.txt"
}

get_failed_services() {
    if [ -f "$RESULTS_DIR/failed_services.txt" ]; then
        cat "$RESULTS_DIR/failed_services.txt"
    fi
}

count_failed_services() {
    if [ -f "$RESULTS_DIR/failed_services.txt" ]; then
        wc -l < "$RESULTS_DIR/failed_services.txt" | tr -d ' '
    else
        echo "0"
    fi
}

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}${INFO_SYMBOL}${NC} $1"
}

log_success() {
    echo -e "${GREEN}${PASS_SYMBOL}${NC} $1"
}

log_error() {
    echo -e "${RED}${FAIL_SYMBOL}${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}${WARN_SYMBOL}${NC} $1"
}

log_header() {
    echo ""
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}======================================================================${NC}"
}

log_subheader() {
    echo ""
    echo -e "${BOLD}$1${NC}"
    echo -e "${DIM}--------------------------------------------------${NC}"
}

log_progress() {
    local service="$1"
    local status="$2"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    local name
    name=$(get_service_name "$service")

    if [ "$status" = "start" ]; then
        echo -e "${DIM}[$timestamp]${NC} ${RUN_SYMBOL} ${BOLD}${name}${NC} - Running tests..."
    elif [ "$status" = "complete" ]; then
        local duration
        duration=$(get_result "$service" "DURATION")
        local result
        result=$(get_result "$service" "RESULT")
        if [ "$result" = "pass" ]; then
            echo -e "${DIM}[$timestamp]${NC} ${GREEN}${PASS_SYMBOL}${NC} ${BOLD}${name}${NC} - Completed in ${duration}s"
        else
            echo -e "${DIM}[$timestamp]${NC} ${RED}${FAIL_SYMBOL}${NC} ${BOLD}${name}${NC} - Failed after ${duration}s"
        fi
    fi
}

#-------------------------------------------------------------------------------
# Help Message
#-------------------------------------------------------------------------------

show_help() {
    cat << 'EOF'
MediConnect Microservices - Centralized Test Execution Script
==============================================================

USAGE:
    ./bin/test-all.sh [OPTIONS]

OPTIONS:
    --parallel          Run all services in parallel for faster execution
                        Note: Output may be interleaved

    --service NAME      Run tests for a single service only
                        Valid services:
                          - api-gateway
                          - users-service
                          - doctors-service
                          - appointments-service
                          - notifications-service
                          - payments-service

    --ci                CI/CD mode:
                          - Disables colored output
                          - Generates JUnit XML reports
                          - Optimized for automated pipelines

    --verbose           Show detailed output from each service test run

    --no-coverage       Skip coverage threshold enforcement
                        (tests still run, but low coverage won't fail build)

    --help              Show this help message and exit

EXAMPLES:
    # Run all tests sequentially (default)
    ./bin/test-all.sh

    # Run all tests in parallel (faster)
    ./bin/test-all.sh --parallel

    # Run only users-service tests
    ./bin/test-all.sh --service users-service

    # CI/CD pipeline execution
    ./bin/test-all.sh --ci --parallel

    # Verbose output for debugging
    ./bin/test-all.sh --service api-gateway --verbose

EXIT CODES:
    0   All tests passed and coverage >= 90%
    1   One or more tests failed
    2   Coverage below 90% threshold
    3   Configuration or environment error

REQUIREMENTS:
    - Docker and Docker Compose installed and running
    - All service containers must be buildable
    - SimpleCov configured in each service (90% threshold)

COVERAGE REPORTS:
    - Individual reports: ./<service>/coverage/index.html
    - Aggregate summary: ./coverage-aggregate/summary.txt
    - JUnit XML (CI mode): ./test-results/<service>.xml

EOF
}

#-------------------------------------------------------------------------------
# Environment Validation
#-------------------------------------------------------------------------------

validate_environment() {
    log_header "Environment Validation"

    local errors=0

    # Check Docker
    if ! command -v docker > /dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        errors=$((errors + 1))
    else
        log_success "Docker is available: $(docker --version | head -1)"
    fi

    # Check Docker Compose (both v1 and v2 syntax)
    if command -v docker-compose > /dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
        log_success "Docker Compose (v1) is available: $(docker-compose --version | head -1)"
    elif docker compose version > /dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
        log_success "Docker Compose (v2) is available: $(docker compose version | head -1)"
    else
        log_error "Docker Compose is not installed"
        errors=$((errors + 1))
    fi

    # Check if Docker daemon is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker daemon is not running"
        errors=$((errors + 1))
    else
        log_success "Docker daemon is running"
    fi

    # Check project root
    if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        log_error "docker-compose.yml not found in $PROJECT_ROOT"
        errors=$((errors + 1))
    else
        log_success "docker-compose.yml found"
    fi

    # Validate single service if specified
    if [ -n "$SINGLE_SERVICE" ]; then
        local valid=false
        for svc in $SERVICES; do
            if [ "$svc" = "$SINGLE_SERVICE" ]; then
                valid=true
                break
            fi
        done

        if [ "$valid" = "false" ]; then
            log_error "Invalid service: $SINGLE_SERVICE"
            log_info "Valid services: $SERVICES"
            errors=$((errors + 1))
        else
            log_success "Service validated: $SINGLE_SERVICE"
        fi
    fi

    # Check service directories exist
    local services_to_check="$SERVICES"
    if [ -n "$SINGLE_SERVICE" ]; then
        services_to_check="$SINGLE_SERVICE"
    fi

    for service in $services_to_check; do
        if [ ! -d "$PROJECT_ROOT/$service" ]; then
            log_error "Service directory not found: $PROJECT_ROOT/$service"
            errors=$((errors + 1))
        fi
    done

    if [ $errors -gt 0 ]; then
        log_error "Environment validation failed with $errors error(s)"
        exit 3
    fi

    log_success "Environment validation passed"
}

#-------------------------------------------------------------------------------
# Setup Directories
#-------------------------------------------------------------------------------

setup_directories() {
    log_info "Setting up output directories..."

    # Create results directory for tracking
    RESULTS_DIR=$(mktemp -d)

    # Create coverage aggregate directory
    mkdir -p "$COVERAGE_AGGREGATE_DIR"

    # Create JUnit output directory (for CI mode)
    if [ "$CI_MODE" = "true" ]; then
        mkdir -p "$JUNIT_OUTPUT_DIR"
    fi

    # Clean previous results
    rm -f "$COVERAGE_AGGREGATE_DIR"/*.txt
    rm -f "$COVERAGE_AGGREGATE_DIR"/*.log

    log_success "Output directories ready"
}

#-------------------------------------------------------------------------------
# Cleanup Function
#-------------------------------------------------------------------------------

cleanup() {
    if [ -n "$RESULTS_DIR" ] && [ -d "$RESULTS_DIR" ]; then
        rm -rf "$RESULTS_DIR"
    fi
}

trap cleanup EXIT

#-------------------------------------------------------------------------------
# Run Tests for Single Service
#-------------------------------------------------------------------------------

run_service_tests() {
    local service="$1"
    local output_file
    local start_time
    local end_time
    local duration
    local exit_code

    output_file=$(mktemp)
    start_time=$(date +%s)

    log_progress "$service" "start"

    # Build the Docker Compose command
    local compose_cmd="$DOCKER_COMPOSE_CMD -f $PROJECT_ROOT/docker-compose.yml"
    local rspec_cmd="bundle exec rspec"

    # Add JUnit formatter for CI mode
    if [ "$CI_MODE" = "true" ]; then
        rspec_cmd="$rspec_cmd --format RspecJunitFormatter --out /rails/tmp/rspec_results.xml --format progress"
    fi

    # Execute tests
    if [ "$VERBOSE_MODE" = "true" ]; then
        # Verbose: show output in real-time
        (
            cd "$PROJECT_ROOT" && \
            $compose_cmd run --rm \
                -e RAILS_ENV=test \
                -e COVERAGE=true \
                "$service" $rspec_cmd 2>&1
        ) | tee "$output_file"
        exit_code=${PIPESTATUS[0]}
    else
        # Quiet: capture output
        (
            cd "$PROJECT_ROOT" && \
            $compose_cmd run --rm \
                -e RAILS_ENV=test \
                -e COVERAGE=true \
                "$service" $rspec_cmd 2>&1
        ) > "$output_file" 2>&1
        exit_code=$?
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Parse results from output
    parse_test_results "$service" "$output_file" "$exit_code" "$duration"

    # Copy JUnit results if in CI mode
    if [ "$CI_MODE" = "true" ]; then
        local junit_src="$PROJECT_ROOT/$service/tmp/rspec_results.xml"
        if [ -f "$junit_src" ]; then
            cp "$junit_src" "$JUNIT_OUTPUT_DIR/${service}.xml"
        fi
    fi

    log_progress "$service" "complete"

    # Save output for debugging if failed
    local result
    result=$(get_result "$service" "RESULT")
    if [ "$result" = "fail" ]; then
        cp "$output_file" "$COVERAGE_AGGREGATE_DIR/${service}-output.log"
    fi

    # Cleanup
    rm -f "$output_file"

    return $exit_code
}

#-------------------------------------------------------------------------------
# Parse Test Results from Output
#-------------------------------------------------------------------------------

parse_test_results() {
    local service="$1"
    local output_file="$2"
    local exit_code="$3"
    local duration="$4"

    # Default values
    local result="fail"
    local coverage="0.0"
    local tests_run=0
    local tests_failed=0

    if [ -f "$output_file" ]; then
        local content
        content=$(cat "$output_file")

        # Parse RSpec summary line (e.g., "50 examples, 2 failures")
        local rspec_summary
        rspec_summary=$(echo "$content" | grep -E "^[0-9]+ examples?, [0-9]+ failures?" | tail -1)

        if [ -n "$rspec_summary" ]; then
            # Extract examples count
            tests_run=$(echo "$rspec_summary" | grep -oE "^[0-9]+" | head -1)
            tests_run=${tests_run:-0}

            # Extract failures count
            tests_failed=$(echo "$rspec_summary" | sed -E 's/.*([0-9]+) failures?.*/\1/' | grep -oE "^[0-9]+$")
            tests_failed=${tests_failed:-0}
        fi

        # Parse SimpleCov coverage percentage
        # SimpleCov-console outputs lines like "COVERAGE: 91.23% -- 500/548 lines in 25 files"
        # or table format with "All Files ( 91.23% covered at 10.5 hits/line )"
        local coverage_line
        coverage_line=$(echo "$content" | grep -iE "(COVERAGE:|covered)" | grep -oE "[0-9]+\.[0-9]+%" | head -1)

        if [ -n "$coverage_line" ]; then
            # Remove the % sign
            coverage="${coverage_line%\%}"
        else
            # Try alternate pattern: "Coverage report generated ... covered (XX.XX%)"
            coverage_line=$(echo "$content" | grep -oE "[0-9]+\.[0-9]+%" | tail -1)
            if [ -n "$coverage_line" ]; then
                coverage="${coverage_line%\%}"
            fi
        fi
    fi

    # Determine pass/fail status
    if [ "$exit_code" -eq 0 ] && [ "${tests_failed:-0}" -eq 0 ]; then
        result="pass"
    else
        result="fail"
        add_failed_service "$service"
    fi

    # Store the results
    store_result "$service" "$result" "$coverage" "$duration" "$tests_run" "$tests_failed"
}

#-------------------------------------------------------------------------------
# Run Tests Sequentially
#-------------------------------------------------------------------------------

run_tests_sequential() {
    local services_to_run="$SERVICES"

    if [ -n "$SINGLE_SERVICE" ]; then
        services_to_run="$SINGLE_SERVICE"
    fi

    local service_count
    service_count=$(echo "$services_to_run" | wc -w | tr -d ' ')

    log_header "Running Tests (Sequential Mode)"
    log_info "Services to test: $service_count"
    echo ""

    for service in $services_to_run; do
        run_service_tests "$service"
    done
}

#-------------------------------------------------------------------------------
# Run Tests in Parallel
#-------------------------------------------------------------------------------

run_tests_parallel() {
    local services_to_run="$SERVICES"

    if [ -n "$SINGLE_SERVICE" ]; then
        services_to_run="$SINGLE_SERVICE"
    fi

    local service_count
    service_count=$(echo "$services_to_run" | wc -w | tr -d ' ')

    log_header "Running Tests (Parallel Mode)"
    log_info "Services to test: $service_count"
    log_warning "Output may be interleaved. Check individual logs for details."
    echo ""

    # File to track PIDs
    local pids_file="$RESULTS_DIR/pids.txt"
    > "$pids_file"

    # Start all services in background
    for service in $services_to_run; do
        (
            run_service_tests_parallel "$service"
        ) &
        local pid=$!
        echo "$service:$pid" >> "$pids_file"
        log_info "Started $(get_service_name "$service") (PID: $pid)"
    done

    # Wait for all processes
    log_info "Waiting for all services to complete..."
    echo ""

    while IFS=: read -r service pid; do
        wait "$pid" 2>/dev/null || true
        log_progress "$service" "complete"
    done < "$pids_file"
}

run_service_tests_parallel() {
    local service="$1"
    local output_file
    local start_time
    local end_time
    local duration
    local exit_code

    output_file=$(mktemp)
    start_time=$(date +%s)

    # Build the Docker Compose command
    local compose_cmd="$DOCKER_COMPOSE_CMD -f $PROJECT_ROOT/docker-compose.yml"
    local rspec_cmd="bundle exec rspec"

    # Add JUnit formatter for CI mode
    if [ "$CI_MODE" = "true" ]; then
        rspec_cmd="$rspec_cmd --format RspecJunitFormatter --out /rails/tmp/rspec_results.xml --format progress"
    fi

    # Execute tests
    (
        cd "$PROJECT_ROOT" && \
        $compose_cmd run --rm \
            -e RAILS_ENV=test \
            -e COVERAGE=true \
            "$service" $rspec_cmd 2>&1
    ) > "$output_file" 2>&1
    exit_code=$?

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Parse results from output
    parse_test_results "$service" "$output_file" "$exit_code" "$duration"

    # Copy JUnit results if in CI mode
    if [ "$CI_MODE" = "true" ]; then
        local junit_src="$PROJECT_ROOT/$service/tmp/rspec_results.xml"
        if [ -f "$junit_src" ]; then
            cp "$junit_src" "$JUNIT_OUTPUT_DIR/${service}.xml"
        fi
    fi

    # Save output for debugging if failed
    local result
    result=$(get_result "$service" "RESULT")
    if [ "$result" = "fail" ]; then
        cp "$output_file" "$COVERAGE_AGGREGATE_DIR/${service}-output.log"
    fi

    rm -f "$output_file"
}

#-------------------------------------------------------------------------------
# Display Coverage Summary Table
#-------------------------------------------------------------------------------

display_coverage_summary() {
    local services_to_show="$SERVICES"

    if [ -n "$SINGLE_SERVICE" ]; then
        services_to_show="$SINGLE_SERVICE"
    fi

    log_header "Coverage Summary"

    # Table header
    printf "\n"
    printf "${BOLD}%-25s %12s %12s %10s${NC}\n" "Service" "Coverage" "Tests" "Status"
    printf "%-25s %12s %12s %10s\n" "=========================" "============" "============" "=========="

    local total_tests=0
    local total_failed=0
    local coverage_sum=0
    local coverage_count=0
    local all_passed=true
    local coverage_failed=false

    for service in $services_to_show; do
        local name
        name=$(get_service_name "$service")
        local coverage
        coverage=$(get_result "$service" "COVERAGE")
        local tests
        tests=$(get_result "$service" "TESTS_RUN")
        local failed
        failed=$(get_result "$service" "TESTS_FAILED")
        local result
        result=$(get_result "$service" "RESULT")

        # Calculate totals
        total_tests=$((total_tests + tests))
        total_failed=$((total_failed + failed))

        # Add to coverage calculation if we have valid coverage
        if [ "$coverage" != "0.0" ] && [ -n "$coverage" ]; then
            # Use awk for floating point addition
            coverage_sum=$(echo "$coverage_sum $coverage" | awk '{print $1 + $2}')
            coverage_count=$((coverage_count + 1))
        fi

        # Format test count
        local test_display="$tests"
        if [ "$failed" -gt 0 ]; then
            test_display="$tests (${failed} failed)"
        fi

        # Determine status display
        local status_display
        local status_color

        if [ "$result" = "pass" ]; then
            # Check coverage threshold using awk for comparison
            local cov_check
            cov_check=$(echo "$coverage $COVERAGE_THRESHOLD" | awk '{print ($1 >= $2) ? 1 : 0}')

            if [ "$cov_check" -eq 1 ] || [ "$SKIP_COVERAGE" = "true" ]; then
                status_display="PASS"
                status_color="${GREEN}"
            else
                status_display="LOW COV"
                status_color="${YELLOW}"
                coverage_failed=true
            fi
        else
            status_display="FAIL"
            status_color="${RED}"
            all_passed=false
        fi

        # Print row
        printf "%-25s %11s%% %12s ${status_color}%10s${NC}\n" \
            "$name" "$coverage" "$test_display" "$status_display"
    done

    # Separator
    printf "%-25s %12s %12s %10s\n" "=========================" "============" "============" "=========="

    # Calculate overall coverage (weighted average)
    local overall_coverage="0.0"
    if [ $coverage_count -gt 0 ]; then
        overall_coverage=$(echo "$coverage_sum $coverage_count" | awk '{printf "%.2f", $1 / $2}')
    fi

    # Overall status
    local overall_status
    local overall_color

    if [ "$all_passed" = "true" ]; then
        local cov_check
        cov_check=$(echo "$overall_coverage $COVERAGE_THRESHOLD" | awk '{print ($1 >= $2) ? 1 : 0}')

        if [ "$cov_check" -eq 1 ] || [ "$SKIP_COVERAGE" = "true" ]; then
            overall_status="PASS"
            overall_color="${GREEN}"
        else
            overall_status="LOW COV"
            overall_color="${YELLOW}"
        fi
    else
        overall_status="FAIL"
        overall_color="${RED}"
    fi

    # Print overall row
    printf "${BOLD}%-25s %11s%% %12s ${overall_color}%10s${NC}\n" \
        "OVERALL" "$overall_coverage" "$total_tests" "$overall_status"

    printf "\n"

    # Store for exit code determination
    OVERALL_COVERAGE="$overall_coverage"
    ALL_TESTS_PASSED="$all_passed"
    COVERAGE_THRESHOLD_MET=$(echo "$overall_coverage $COVERAGE_THRESHOLD" | awk '{print ($1 >= $2) ? 1 : 0}')
}

#-------------------------------------------------------------------------------
# Display Execution Summary
#-------------------------------------------------------------------------------

display_execution_summary() {
    local script_end_time
    script_end_time=$(date +%s)
    local total_duration=$((script_end_time - SCRIPT_START_TIME))

    log_header "Execution Summary"

    # Timing
    log_info "Total execution time: ${total_duration}s"

    # Per-service timing
    local services_to_show="$SERVICES"
    if [ -n "$SINGLE_SERVICE" ]; then
        services_to_show="$SINGLE_SERVICE"
    fi

    log_subheader "Per-Service Timing"
    for service in $services_to_show; do
        local duration
        duration=$(get_result "$service" "DURATION")
        local name
        name=$(get_service_name "$service")
        printf "  %-25s %5ss\n" "$name" "$duration"
    done

    # Failed services detail
    local failed_count
    failed_count=$(count_failed_services)

    if [ "$failed_count" -gt 0 ]; then
        log_subheader "Failed Services"
        for service in $(get_failed_services); do
            local name
            name=$(get_service_name "$service")
            log_error "$name"
            if [ -f "$COVERAGE_AGGREGATE_DIR/${service}-output.log" ]; then
                log_info "  Log: $COVERAGE_AGGREGATE_DIR/${service}-output.log"
            fi
        done

        # Suggest common fixes
        log_subheader "Troubleshooting Tips"
        echo "  1. Check if database migrations are up to date:"
        echo "     docker-compose run --rm <service> bundle exec rails db:migrate RAILS_ENV=test"
        echo ""
        echo "  2. Check if dependencies are installed:"
        echo "     docker-compose run --rm <service> bundle install"
        echo ""
        echo "  3. View detailed test output:"
        echo "     cat $COVERAGE_AGGREGATE_DIR/<service>-output.log"
        echo ""
        echo "  4. Run specific service tests with verbose output:"
        echo "     ./bin/test-all.sh --service <service> --verbose"
    fi

    # CI mode info
    if [ "$CI_MODE" = "true" ]; then
        log_subheader "CI Artifacts"
        log_info "JUnit XML reports: $JUNIT_OUTPUT_DIR/"
        log_info "Coverage aggregate: $COVERAGE_AGGREGATE_DIR/"
    fi
}

#-------------------------------------------------------------------------------
# Generate Aggregate Report
#-------------------------------------------------------------------------------

generate_aggregate_report() {
    local report_file="$COVERAGE_AGGREGATE_DIR/summary.txt"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat > "$report_file" << EOF
================================================================================
MediConnect Test Coverage Report
Generated: $timestamp
================================================================================

CONFIGURATION
-------------
Coverage Threshold: ${COVERAGE_THRESHOLD}%
Parallel Mode: ${PARALLEL_MODE}
CI Mode: ${CI_MODE}

RESULTS BY SERVICE
------------------
EOF

    local services_to_show="$SERVICES"
    if [ -n "$SINGLE_SERVICE" ]; then
        services_to_show="$SINGLE_SERVICE"
    fi

    for service in $services_to_show; do
        local name
        name=$(get_service_name "$service")
        local coverage
        coverage=$(get_result "$service" "COVERAGE")
        local tests
        tests=$(get_result "$service" "TESTS_RUN")
        local failed
        failed=$(get_result "$service" "TESTS_FAILED")
        local result
        result=$(get_result "$service" "RESULT")
        local duration
        duration=$(get_result "$service" "DURATION")

        cat >> "$report_file" << EOF

$name
------------------------------
  Coverage:     ${coverage}%
  Tests Run:    $tests
  Tests Failed: $failed
  Duration:     ${duration}s
  Status:       $(echo "$result" | tr '[:lower:]' '[:upper:]')
EOF
    done

    # Determine threshold met
    local threshold_met="NO"
    if [ "${COVERAGE_THRESHOLD_MET:-0}" -eq 1 ]; then
        threshold_met="YES"
    fi

    # Determine all passed
    local all_passed_display="NO"
    if [ "${ALL_TESTS_PASSED}" = "true" ]; then
        all_passed_display="YES"
    fi

    cat >> "$report_file" << EOF

================================================================================
OVERALL SUMMARY
================================================================================
Overall Coverage: ${OVERALL_COVERAGE}%
Threshold Met:    $threshold_met
All Tests Passed: $all_passed_display
================================================================================
EOF

    log_info "Aggregate report saved: $report_file"
}

#-------------------------------------------------------------------------------
# Determine Exit Code
#-------------------------------------------------------------------------------

determine_exit_code() {
    # Priority 1: Test failures
    if [ "$ALL_TESTS_PASSED" != "true" ]; then
        log_error "RESULT: Tests failed in one or more services"
        return 1
    fi

    # Priority 2: Coverage threshold (unless skipped)
    if [ "$SKIP_COVERAGE" != "true" ] && [ "${COVERAGE_THRESHOLD_MET:-0}" -ne 1 ]; then
        log_warning "RESULT: Coverage below ${COVERAGE_THRESHOLD}% threshold (${OVERALL_COVERAGE}%)"
        return 2
    fi

    log_success "RESULT: All tests passed with adequate coverage"
    return 0
}

#-------------------------------------------------------------------------------
# Parse Command Line Arguments
#-------------------------------------------------------------------------------

parse_arguments() {
    while [ $# -gt 0 ]; do
        case $1 in
            --parallel)
                PARALLEL_MODE=true
                shift
                ;;
            --service)
                if [ -n "$2" ] && [ "${2#--}" = "$2" ]; then
                    SINGLE_SERVICE="$2"
                    shift 2
                else
                    log_error "--service requires a service name"
                    exit 3
                fi
                ;;
            --ci)
                CI_MODE=true
                COLOR_ENABLED=false
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --no-coverage)
                SKIP_COVERAGE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 3
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------

main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Setup colors based on mode
    setup_colors

    # Display banner
    echo ""
    echo -e "${BOLD}${MAGENTA}================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}     MediConnect Microservices - Test Suite Runner${NC}"
    echo -e "${BOLD}${MAGENTA}================================================================${NC}"
    echo -e "${DIM}Started: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""

    # Validate environment
    validate_environment

    # Setup directories
    setup_directories

    # Run tests
    if [ "$PARALLEL_MODE" = "true" ]; then
        run_tests_parallel
    else
        run_tests_sequential
    fi

    # Display coverage summary
    display_coverage_summary

    # Generate aggregate report
    generate_aggregate_report

    # Display execution summary
    display_execution_summary

    # Final banner
    echo ""
    echo -e "${BOLD}${MAGENTA}================================================================${NC}"

    # Determine and return exit code
    determine_exit_code
    local exit_code=$?

    echo -e "${DIM}Completed: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BOLD}${MAGENTA}================================================================${NC}"
    echo ""

    exit $exit_code
}

# Execute main function with all arguments
main "$@"
