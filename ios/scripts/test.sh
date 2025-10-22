#!/bin/bash

# Fueki Wallet - iOS Test Script
# Comprehensive test execution with coverage reporting

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCHEME="${SCHEME:-Fueki}"
DEVICE="${DEVICE:-iPhone 15 Pro}"
WORKSPACE="./ios/Fueki.xcworkspace"
DERIVED_DATA="./ios/DerivedData"
TEST_OUTPUT="./ios/fastlane/test_output"
RESULT_BUNDLE="$TEST_OUTPUT/TestResults.xcresult"

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_requirements() {
    log_info "Checking requirements..."

    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode is not installed"
        exit 1
    fi

    # Check xcpretty
    if ! command -v xcpretty &> /dev/null; then
        log_warning "xcpretty not found, installing..."
        gem install xcpretty
    fi

    # Check fastlane
    if ! command -v fastlane &> /dev/null; then
        log_warning "fastlane not found, installing..."
        gem install fastlane
    fi

    log_success "Requirements check passed"
}

setup_test_environment() {
    log_info "Setting up test environment..."

    # Create output directories
    mkdir -p "$TEST_OUTPUT"
    mkdir -p "$DERIVED_DATA"

    # Clean previous test results
    if [ -d "$RESULT_BUNDLE" ]; then
        rm -rf "$RESULT_BUNDLE"
    fi

    log_success "Test environment ready"
}

list_available_simulators() {
    log_info "Available simulators:"
    xcrun simctl list devices available | grep -E "iPhone|iPad"
}

boot_simulator() {
    log_info "Booting simulator: $DEVICE"

    # Get simulator ID
    SIMULATOR_ID=$(xcrun simctl list devices available | grep "$DEVICE" | head -1 | grep -o '\([0-9A-F-]*\)' | head -1)

    if [ -z "$SIMULATOR_ID" ]; then
        log_error "Simulator '$DEVICE' not found"
        list_available_simulators
        exit 1
    fi

    # Boot simulator if not already booted
    SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -o '(.*)')

    if [[ "$SIMULATOR_STATE" != *"Booted"* ]]; then
        xcrun simctl boot "$SIMULATOR_ID"
        sleep 5
        log_success "Simulator booted: $DEVICE"
    else
        log_info "Simulator already booted"
    fi
}

run_unit_tests() {
    log_info "Running unit tests..."

    xcodebuild test \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULT_BUNDLE" \
        -enableCodeCoverage YES \
        -only-testing:"${SCHEME}Tests" \
        clean test \
        | tee "$TEST_OUTPUT/unit-tests.log" \
        | xcpretty --color --report html --output "$TEST_OUTPUT/unit-tests.html"

    log_success "Unit tests completed"
}

run_ui_tests() {
    log_info "Running UI tests..."

    UI_RESULT_BUNDLE="$TEST_OUTPUT/UITestResults.xcresult"

    xcodebuild test \
        -workspace "$WORKSPACE" \
        -scheme "${SCHEME}UITests" \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$UI_RESULT_BUNDLE" \
        -only-testing:"${SCHEME}UITests" \
        clean test \
        | tee "$TEST_OUTPUT/ui-tests.log" \
        | xcpretty --color --report html --output "$TEST_OUTPUT/ui-tests.html"

    log_success "UI tests completed"
}

run_all_tests_fastlane() {
    log_info "Running all tests via fastlane..."

    bundle exec fastlane ios test

    log_success "All tests completed via fastlane"
}

extract_test_results() {
    log_info "Extracting test results..."

    if [ -d "$RESULT_BUNDLE" ]; then
        # Extract test summary
        xcrun xcresulttool get --format json --path "$RESULT_BUNDLE" > "$TEST_OUTPUT/results.json"

        # Generate human-readable summary
        echo "Test Results Summary" > "$TEST_OUTPUT/summary.txt"
        echo "====================" >> "$TEST_OUTPUT/summary.txt"
        echo "" >> "$TEST_OUTPUT/summary.txt"

        # Extract pass/fail counts
        TOTAL_TESTS=$(xcrun xcresulttool get --path "$RESULT_BUNDLE" | grep -c "Test Case" || echo "0")
        echo "Total Tests: $TOTAL_TESTS" >> "$TEST_OUTPUT/summary.txt"

        log_success "Test results extracted"
    else
        log_warning "No test results bundle found"
    fi
}

generate_coverage_report() {
    log_info "Generating coverage report..."

    bash ./ios/scripts/code-coverage.sh

    log_success "Coverage report generated"
}

check_test_results() {
    log_info "Checking test results..."

    # Check if tests passed
    if [ -f "$TEST_OUTPUT/unit-tests.log" ]; then
        if grep -q "Test Suite.*failed" "$TEST_OUTPUT/unit-tests.log"; then
            log_error "Some tests failed!"
            return 1
        fi
    fi

    log_success "All tests passed!"
    return 0
}

print_summary() {
    log_info "=== Test Execution Summary ==="

    if [ -f "$TEST_OUTPUT/summary.txt" ]; then
        cat "$TEST_OUTPUT/summary.txt"
    fi

    echo ""
    log_info "Test reports:"
    log_info "  - Unit tests: $TEST_OUTPUT/unit-tests.html"
    log_info "  - Coverage: $TEST_OUTPUT/coverage.html"
    log_info "  - Results bundle: $RESULT_BUNDLE"
}

# Main execution
main() {
    log_info "=== Fueki Wallet iOS Tests ==="
    log_info "Device: $DEVICE"
    log_info "Scheme: $SCHEME"

    check_requirements
    setup_test_environment
    boot_simulator

    # Run tests
    if command -v fastlane &> /dev/null && [ -f "Gemfile" ]; then
        run_all_tests_fastlane
    else
        run_unit_tests
        # Uncomment to run UI tests
        # run_ui_tests
    fi

    extract_test_results
    generate_coverage_report

    # Check results
    if check_test_results; then
        print_summary
        log_success "=== Test Execution Completed Successfully ==="
        exit 0
    else
        log_error "=== Test Execution Failed ==="
        exit 1
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --scheme)
            SCHEME="$2"
            shift 2
            ;;
        --unit-only)
            UNIT_ONLY=true
            shift
            ;;
        --ui-only)
            UI_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --device <device>    Simulator device name (default: iPhone 15 Pro)"
            echo "  --scheme <scheme>    Xcode scheme (default: Fueki)"
            echo "  --unit-only          Run only unit tests"
            echo "  --ui-only            Run only UI tests"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
