#!/bin/bash

# Fueki Wallet - iOS Code Coverage Script
# Generate comprehensive coverage reports

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DERIVED_DATA="${DERIVED_DATA:-./ios/DerivedData}"
TEST_OUTPUT="${TEST_OUTPUT:-./ios/fastlane/test_output}"
RESULT_BUNDLE="${RESULT_BUNDLE:-$TEST_OUTPUT/TestResults.xcresult}"
COVERAGE_DIR="$TEST_OUTPUT/coverage"
MINIMUM_COVERAGE="${MINIMUM_COVERAGE:-80}"

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

    # Check xcov
    if ! command -v xcov &> /dev/null; then
        log_warning "xcov not found, installing..."
        gem install xcov
    fi

    # Check slather (alternative coverage tool)
    if ! command -v slather &> /dev/null; then
        log_warning "slather not found, installing..."
        gem install slather
    fi

    log_success "Requirements check passed"
}

setup_coverage_environment() {
    log_info "Setting up coverage environment..."

    # Create coverage directory
    mkdir -p "$COVERAGE_DIR"

    log_success "Coverage environment ready"
}

find_result_bundle() {
    log_info "Locating test result bundle..."

    if [ -d "$RESULT_BUNDLE" ]; then
        log_success "Found result bundle: $RESULT_BUNDLE"
        return 0
    fi

    # Try to find in DerivedData
    LATEST_RESULT=$(find "$DERIVED_DATA" -name "*.xcresult" -type d -print0 | xargs -0 ls -t | head -1)

    if [ ! -z "$LATEST_RESULT" ]; then
        RESULT_BUNDLE="$LATEST_RESULT"
        log_success "Found result bundle: $RESULT_BUNDLE"
        return 0
    fi

    log_error "Could not find test result bundle"
    return 1
}

extract_coverage_data() {
    log_info "Extracting coverage data..."

    # Export coverage data as JSON
    xcrun xccov view --report --json "$RESULT_BUNDLE" > "$COVERAGE_DIR/coverage.json"

    # Export coverage data as text
    xcrun xccov view --report "$RESULT_BUNDLE" > "$COVERAGE_DIR/coverage.txt"

    log_success "Coverage data extracted"
}

generate_html_report() {
    log_info "Generating HTML coverage report..."

    # Use xcov for beautiful HTML reports
    if command -v xcov &> /dev/null; then
        xcov \
            --scheme Fueki \
            --workspace ./ios/Fueki.xcworkspace \
            --output_directory "$COVERAGE_DIR" \
            --html_report \
            --minimum_coverage_percentage $MINIMUM_COVERAGE \
            --skip_slack \
            --json_report || true

        log_success "HTML report generated: $COVERAGE_DIR/index.html"
    else
        log_warning "xcov not available, skipping HTML report"
    fi
}

generate_xml_report() {
    log_info "Generating XML coverage report (Cobertura format)..."

    # Use slather for Cobertura XML (compatible with CI/CD tools)
    if command -v slather &> /dev/null; then
        cd ios

        slather coverage \
            --scheme Fueki \
            --workspace Fueki.xcworkspace \
            --output-directory "../$COVERAGE_DIR" \
            --cobertura-xml \
            --ignore "../ios/Pods/*" \
            --ignore "Pods/*" \
            Fueki.xcodeproj || true

        cd ..

        # Rename to standard name
        if [ -f "$COVERAGE_DIR/cobertura.xml" ]; then
            mv "$COVERAGE_DIR/cobertura.xml" "$COVERAGE_DIR/coverage.xml"
            log_success "XML report generated: $COVERAGE_DIR/coverage.xml"
        fi
    else
        log_warning "slather not available, skipping XML report"
    fi
}

calculate_coverage_percentage() {
    log_info "Calculating coverage percentage..."

    if [ -f "$COVERAGE_DIR/coverage.json" ]; then
        # Extract line coverage percentage using Python
        COVERAGE_PERCENT=$(python3 -c "
import json
import sys

try:
    with open('$COVERAGE_DIR/coverage.json', 'r') as f:
        data = json.load(f)

    if 'lineCoverage' in data:
        coverage = data['lineCoverage'] * 100
        print(f'{coverage:.2f}')
    else:
        targets = data.get('targets', [])
        if targets:
            coverage = targets[0].get('lineCoverage', 0) * 100
            print(f'{coverage:.2f}')
        else:
            print('0.00')
except Exception as e:
    print('0.00', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || echo "0.00")

        echo "$COVERAGE_PERCENT" > "$COVERAGE_DIR/coverage_percentage.txt"

        log_info "Line Coverage: ${COVERAGE_PERCENT}%"

        return 0
    else
        log_error "Coverage JSON not found"
        return 1
    fi
}

generate_coverage_summary() {
    log_info "Generating coverage summary..."

    COVERAGE_PERCENT=$(cat "$COVERAGE_DIR/coverage_percentage.txt" 2>/dev/null || echo "0.00")

    cat > "$COVERAGE_DIR/summary.txt" << EOF
Code Coverage Summary
====================
Date: $(date)
Line Coverage: ${COVERAGE_PERCENT}%
Minimum Required: ${MINIMUM_COVERAGE}%

Reports:
- HTML: $COVERAGE_DIR/index.html
- XML: $COVERAGE_DIR/coverage.xml
- JSON: $COVERAGE_DIR/coverage.json
- Text: $COVERAGE_DIR/coverage.txt

Status: $([ $(echo "$COVERAGE_PERCENT >= $MINIMUM_COVERAGE" | bc -l) -eq 1 ] && echo "PASSED ✅" || echo "FAILED ❌")
EOF

    cat "$COVERAGE_DIR/summary.txt"

    log_success "Coverage summary generated"
}

check_coverage_threshold() {
    log_info "Checking coverage threshold..."

    COVERAGE_PERCENT=$(cat "$COVERAGE_DIR/coverage_percentage.txt" 2>/dev/null || echo "0.00")

    if (( $(echo "$COVERAGE_PERCENT >= $MINIMUM_COVERAGE" | bc -l) )); then
        log_success "Coverage ${COVERAGE_PERCENT}% meets minimum threshold ${MINIMUM_COVERAGE}%"
        return 0
    else
        log_error "Coverage ${COVERAGE_PERCENT}% is below minimum threshold ${MINIMUM_COVERAGE}%"
        return 1
    fi
}

generate_coverage_badge() {
    log_info "Generating coverage badge..."

    COVERAGE_PERCENT=$(cat "$COVERAGE_DIR/coverage_percentage.txt" 2>/dev/null || echo "0")
    COVERAGE_INT=${COVERAGE_PERCENT%.*}

    # Determine badge color
    if [ "$COVERAGE_INT" -ge 80 ]; then
        COLOR="brightgreen"
    elif [ "$COVERAGE_INT" -ge 60 ]; then
        COLOR="yellow"
    else
        COLOR="red"
    fi

    # Generate badge URL
    BADGE_URL="https://img.shields.io/badge/coverage-${COVERAGE_PERCENT}%25-${COLOR}"

    echo "$BADGE_URL" > "$COVERAGE_DIR/badge_url.txt"

    log_success "Badge URL: $BADGE_URL"
}

open_coverage_report() {
    if [ -f "$COVERAGE_DIR/index.html" ]; then
        log_info "Opening coverage report in browser..."
        open "$COVERAGE_DIR/index.html" 2>/dev/null || true
    fi
}

# Main execution
main() {
    log_info "=== Fueki Wallet Code Coverage Analysis ==="

    check_requirements
    setup_coverage_environment

    if ! find_result_bundle; then
        log_error "Cannot proceed without test results"
        exit 1
    fi

    extract_coverage_data
    generate_html_report
    generate_xml_report
    calculate_coverage_percentage
    generate_coverage_summary
    generate_coverage_badge

    echo ""
    log_info "Coverage reports location: $COVERAGE_DIR"

    # Check threshold
    if check_coverage_threshold; then
        log_success "=== Coverage Analysis Completed Successfully ==="

        # Optionally open report in browser
        # open_coverage_report

        exit 0
    else
        log_error "=== Coverage Analysis Failed ==="
        exit 1
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --minimum)
            MINIMUM_COVERAGE="$2"
            shift 2
            ;;
        --open)
            OPEN_REPORT=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --minimum <percent>  Minimum coverage threshold (default: 80)"
            echo "  --open               Open HTML report in browser"
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
