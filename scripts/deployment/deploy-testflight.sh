#!/bin/bash

# Deploy to TestFlight Script
# Automated deployment script for iOS TestFlight

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEME="FuekiWallet"
WORKSPACE="$PROJECT_ROOT/ios/$SCHEME.xcworkspace"
ARCHIVE_PATH="$PROJECT_ROOT/build/$SCHEME.xcarchive"
EXPORT_PATH="$PROJECT_ROOT/build"

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "This script must be run on macOS"
        exit 1
    fi

    # Check for required tools
    command -v xcodebuild >/dev/null 2>&1 || { print_error "xcodebuild not found"; exit 1; }
    command -v fastlane >/dev/null 2>&1 || { print_error "fastlane not found. Install with: gem install fastlane"; exit 1; }

    # Check for workspace
    if [ ! -d "$WORKSPACE" ]; then
        print_error "Workspace not found at $WORKSPACE"
        exit 1
    fi

    print_info "Prerequisites check passed"
}

# Check environment variables
check_environment() {
    print_step "Checking environment variables..."

    local missing_vars=()

    [ -z "$APP_STORE_CONNECT_API_KEY_ID" ] && missing_vars+=("APP_STORE_CONNECT_API_KEY_ID")
    [ -z "$APP_STORE_CONNECT_ISSUER_ID" ] && missing_vars+=("APP_STORE_CONNECT_ISSUER_ID")
    [ -z "$APP_STORE_CONNECT_API_KEY_BASE64" ] && missing_vars+=("APP_STORE_CONNECT_API_KEY_BASE64")

    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi

    print_info "Environment variables OK"
}

# Setup API key
setup_api_key() {
    print_step "Setting up App Store Connect API key..."

    mkdir -p ~/.private_keys
    echo "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode > ~/.private_keys/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8
    chmod 600 ~/.private_keys/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8

    print_info "API key configured"
}

# Clean build directory
clean_build() {
    print_step "Cleaning build directory..."

    rm -rf "$PROJECT_ROOT/build"
    mkdir -p "$PROJECT_ROOT/build"

    print_info "Build directory cleaned"
}

# Run tests
run_tests() {
    local skip_tests="${1:-false}"

    if [ "$skip_tests" == "true" ]; then
        print_warn "Skipping tests (--skip-tests flag used)"
        return 0
    fi

    print_step "Running tests..."

    cd "$PROJECT_ROOT"
    fastlane test || {
        print_error "Tests failed"
        exit 1
    }

    print_info "Tests passed"
}

# Build and archive
build_archive() {
    print_step "Building and archiving..."

    cd "$PROJECT_ROOT/ios"

    xcodebuild archive \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=iOS' \
        -allowProvisioningUpdates \
        CODE_SIGN_STYLE=Automatic \
        | xcpretty || {
        print_error "Archive failed"
        exit 1
    }

    print_info "Archive created successfully"
}

# Export IPA
export_ipa() {
    print_step "Exporting IPA..."

    # Create export options plist
    cat > "$PROJECT_ROOT/build/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$PROJECT_ROOT/build/ExportOptions.plist" \
        | xcpretty || {
        print_error "Export failed"
        exit 1
    }

    print_info "IPA exported successfully"
}

# Upload to TestFlight
upload_testflight() {
    local changelog="${1:-Bug fixes and improvements}"

    print_step "Uploading to TestFlight..."

    cd "$PROJECT_ROOT"

    fastlane pilot upload \
        --api_key_path ~/.private_keys/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8 \
        --api_key_id "$APP_STORE_CONNECT_API_KEY_ID" \
        --issuer_id "$APP_STORE_CONNECT_ISSUER_ID" \
        --ipa "$EXPORT_PATH/$SCHEME.ipa" \
        --skip_waiting_for_build_processing \
        --changelog "$changelog" || {
        print_error "Upload to TestFlight failed"
        exit 1
    }

    print_info "Successfully uploaded to TestFlight"
}

# Cleanup
cleanup() {
    print_step "Cleaning up..."

    rm -f ~/.private_keys/AuthKey_*.p8
    rm -rf "$PROJECT_ROOT/build"

    print_info "Cleanup complete"
}

# Main function
main() {
    local skip_tests=false
    local skip_cleanup=false
    local changelog="Bug fixes and improvements"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --skip-cleanup)
                skip_cleanup=true
                shift
                ;;
            --changelog)
                changelog="$2"
                shift 2
                ;;
            -h|--help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --skip-tests      Skip running tests
  --skip-cleanup    Skip cleanup after deployment
  --changelog TEXT  Custom changelog text for TestFlight
  -h, --help        Show this help message

Example:
  $0 --changelog "Fixed authentication bug"
EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    echo ""
    print_info "Starting TestFlight deployment process..."
    echo ""

    check_prerequisites
    check_environment
    setup_api_key
    clean_build
    run_tests "$skip_tests"
    build_archive
    export_ipa
    upload_testflight "$changelog"

    if [ "$skip_cleanup" != "true" ]; then
        cleanup
    fi

    echo ""
    print_info "Deployment completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Check TestFlight processing status in App Store Connect"
    echo "  2. Add testing information and submit for beta review"
    echo "  3. Invite external testers once approved"
    echo ""
}

# Handle script interruption
trap 'print_error "Script interrupted"; cleanup; exit 1' INT TERM

# Run main function
main "$@"
