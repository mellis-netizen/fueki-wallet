#!/bin/bash

# Fueki Wallet - iOS Linting Script
# SwiftLint automation with reporting

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SWIFTLINT_CONFIG=".swiftlint.yml"
OUTPUT_DIR="./ios/fastlane"
HTML_REPORT="$OUTPUT_DIR/swiftlint-report.html"
JSON_REPORT="$OUTPUT_DIR/swiftlint-report.json"

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

check_swiftlint() {
    log_info "Checking SwiftLint installation..."

    if command -v swiftlint &> /dev/null; then
        SWIFTLINT_VERSION=$(swiftlint version)
        log_success "SwiftLint $SWIFTLINT_VERSION is installed"
        return 0
    fi

    # Check if SwiftLint is installed via CocoaPods
    if [ -f "./ios/Pods/SwiftLint/swiftlint" ]; then
        log_success "SwiftLint found in CocoaPods"
        SWIFTLINT_PATH="./ios/Pods/SwiftLint/swiftlint"
        return 0
    fi

    log_error "SwiftLint is not installed"
    log_info "Install with: brew install swiftlint"
    exit 1
}

create_swiftlint_config() {
    if [ ! -f "$SWIFTLINT_CONFIG" ]; then
        log_warning "SwiftLint config not found, creating default..."

        cat > "$SWIFTLINT_CONFIG" << 'EOF'
# SwiftLint Configuration for Fueki Wallet

# Paths to include/exclude
included:
  - ios/Fueki

excluded:
  - Pods
  - DerivedData
  - .build
  - fastlane
  - build

# Enabled rules
opt_in_rules:
  - anyobject_protocol
  - array_init
  - closure_end_indentation
  - closure_spacing
  - collection_alignment
  - contains_over_filter_count
  - contains_over_filter_is_empty
  - contains_over_first_not_nil
  - contains_over_range_nil_comparison
  - discouraged_object_literal
  - empty_collection_literal
  - empty_count
  - empty_string
  - enum_case_associated_values_count
  - explicit_init
  - extension_access_modifier
  - fallthrough
  - fatal_error_message
  - file_header
  - first_where
  - flatmap_over_map_reduce
  - identical_operands
  - joined_default_parameter
  - last_where
  - legacy_random
  - literal_expression_end_indentation
  - lower_acl_than_parent
  - modifier_order
  - multiline_arguments
  - multiline_function_chains
  - multiline_literal_brackets
  - multiline_parameters
  - operator_usage_whitespace
  - overridden_super_call
  - pattern_matching_keywords
  - prefer_self_type_over_type_of_self
  - private_action
  - private_outlet
  - prohibited_super_call
  - redundant_nil_coalescing
  - redundant_type_annotation
  - sorted_first_last
  - static_operator
  - toggle_bool
  - unavailable_function
  - unneeded_parentheses_in_closure_argument
  - vertical_parameter_alignment_on_call
  - yoda_condition

# Disabled rules
disabled_rules:
  - trailing_whitespace

# Rule configurations
line_length:
  warning: 120
  error: 200
  ignores_function_declarations: true
  ignores_comments: true
  ignores_urls: true

file_length:
  warning: 500
  error: 1000
  ignore_comment_only_lines: true

function_body_length:
  warning: 50
  error: 100

function_parameter_count:
  warning: 5
  error: 8

type_body_length:
  warning: 300
  error: 500

type_name:
  min_length: 3
  max_length: 40
  excluded:
    - ID

identifier_name:
  min_length: 3
  max_length: 40
  excluded:
    - id
    - url
    - key
    - row
    - col
    - x
    - y
    - z

cyclomatic_complexity:
  warning: 10
  error: 20
  ignores_case_statements: true

nesting:
  type_level:
    warning: 2
    error: 3
  statement_level:
    warning: 5
    error: 10

# Custom rules
custom_rules:
  no_print:
    name: "No Print Statements"
    regex: "print\\("
    message: "Use proper logging instead of print()"
    severity: warning

  no_force_unwrapping:
    name: "No Force Unwrapping"
    regex: "!\\s*(?!\\=)"
    message: "Avoid force unwrapping, use optional binding instead"
    severity: warning

  no_hardcoded_strings:
    name: "No Hardcoded Strings"
    regex: "NSLocalizedString\\(\"[^\"]+\", comment: \"\""
    message: "Provide meaningful comments for localized strings"
    severity: warning

# Reporter
reporter: "html"
EOF

        log_success "Created default SwiftLint configuration"
    fi
}

run_swiftlint() {
    log_info "Running SwiftLint..."

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Determine SwiftLint path
    SWIFTLINT_CMD="swiftlint"
    if [ ! -z "$SWIFTLINT_PATH" ]; then
        SWIFTLINT_CMD="$SWIFTLINT_PATH"
    fi

    # Run SwiftLint with HTML reporter
    log_info "Generating HTML report..."
    $SWIFTLINT_CMD lint \
        --config "$SWIFTLINT_CONFIG" \
        --reporter html > "$HTML_REPORT" || true

    # Run SwiftLint with JSON reporter for parsing
    log_info "Generating JSON report..."
    $SWIFTLINT_CMD lint \
        --config "$SWIFTLINT_CONFIG" \
        --reporter json > "$JSON_REPORT" || true

    # Run SwiftLint with console output
    log_info "Console output:"
    $SWIFTLINT_CMD lint \
        --config "$SWIFTLINT_CONFIG" \
        --reporter emoji || LINT_EXIT_CODE=$?

    return ${LINT_EXIT_CODE:-0}
}

analyze_results() {
    log_info "Analyzing lint results..."

    if [ -f "$JSON_REPORT" ]; then
        # Count violations
        TOTAL_VIOLATIONS=$(cat "$JSON_REPORT" | grep -c '"severity"' || echo "0")
        ERROR_COUNT=$(cat "$JSON_REPORT" | grep -c '"severity" *: *"error"' || echo "0")
        WARNING_COUNT=$(cat "$JSON_REPORT" | grep -c '"severity" *: *"warning"' || echo "0")

        echo ""
        log_info "=== Lint Results ==="
        echo "Total violations: $TOTAL_VIOLATIONS"
        echo "Errors: $ERROR_COUNT"
        echo "Warnings: $WARNING_COUNT"
        echo ""

        # Create summary file
        cat > "$OUTPUT_DIR/lint-summary.txt" << EOF
SwiftLint Summary
=================
Date: $(date)
Total Violations: $TOTAL_VIOLATIONS
Errors: $ERROR_COUNT
Warnings: $WARNING_COUNT

Reports:
- HTML: $HTML_REPORT
- JSON: $JSON_REPORT
EOF

        # Check if there are errors
        if [ "$ERROR_COUNT" -gt 0 ]; then
            log_error "Found $ERROR_COUNT SwiftLint errors!"
            return 1
        elif [ "$WARNING_COUNT" -gt 0 ]; then
            log_warning "Found $WARNING_COUNT SwiftLint warnings"
            return 0
        else
            log_success "No lint violations found!"
            return 0
        fi
    else
        log_error "Could not find JSON report"
        return 1
    fi
}

fix_violations() {
    log_info "Attempting to auto-fix violations..."

    SWIFTLINT_CMD="swiftlint"
    if [ ! -z "$SWIFTLINT_PATH" ]; then
        SWIFTLINT_CMD="$SWIFTLINT_PATH"
    fi

    $SWIFTLINT_CMD autocorrect \
        --config "$SWIFTLINT_CONFIG" \
        --format

    log_success "Auto-fix completed"
}

# Main execution
main() {
    log_info "=== Fueki Wallet iOS Linting ==="

    check_swiftlint
    create_swiftlint_config

    if run_swiftlint; then
        LINT_PASSED=true
    else
        LINT_PASSED=false
    fi

    analyze_results
    ANALYZE_RESULT=$?

    # Print report locations
    echo ""
    log_info "Reports generated:"
    log_info "  - HTML: $HTML_REPORT"
    log_info "  - JSON: $JSON_REPORT"
    log_info "  - Summary: $OUTPUT_DIR/lint-summary.txt"

    if [ $ANALYZE_RESULT -eq 0 ]; then
        log_success "=== Linting Completed Successfully ==="
        exit 0
    else
        log_error "=== Linting Failed ==="
        exit 1
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            fix_violations
            exit 0
            ;;
        --strict)
            STRICT_MODE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --fix      Auto-fix violations"
            echo "  --strict   Treat warnings as errors"
            echo "  --help     Show this help message"
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
