#!/bin/bash

# Deploy to Google Play Store Script
# Automated deployment script for Android Play Store

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
ANDROID_DIR="$PROJECT_ROOT/android"
BUILD_DIR="$ANDROID_DIR/app/build/outputs"

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check for required tools
    command -v node >/dev/null 2>&1 || { print_error "Node.js not found"; exit 1; }
    command -v npm >/dev/null 2>&1 || { print_error "npm not found"; exit 1; }

    # Check for Android directory
    if [ ! -d "$ANDROID_DIR" ]; then
        print_error "Android directory not found at $ANDROID_DIR"
        exit 1
    fi

    # Check for Gradle wrapper
    if [ ! -f "$ANDROID_DIR/gradlew" ]; then
        print_error "Gradle wrapper not found"
        exit 1
    fi

    print_info "Prerequisites check passed"
}

# Check environment variables
check_environment() {
    print_step "Checking environment variables..."

    local missing_vars=()

    [ -z "$ANDROID_KEYSTORE_BASE64" ] && missing_vars+=("ANDROID_KEYSTORE_BASE64")
    [ -z "$ANDROID_KEY_ALIAS" ] && missing_vars+=("ANDROID_KEY_ALIAS")
    [ -z "$ANDROID_KEY_PASSWORD" ] && missing_vars+=("ANDROID_KEY_PASSWORD")
    [ -z "$ANDROID_STORE_PASSWORD" ] && missing_vars+=("ANDROID_STORE_PASSWORD")
    [ -z "$PLAY_STORE_SERVICE_ACCOUNT_JSON" ] && missing_vars+=("PLAY_STORE_SERVICE_ACCOUNT_JSON")

    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi

    print_info "Environment variables OK"
}

# Setup keystore
setup_keystore() {
    print_step "Setting up Android keystore..."

    echo "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$ANDROID_DIR/app/release.keystore"

    cat > "$ANDROID_DIR/keystore.properties" << EOF
storePassword=$ANDROID_STORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
storeFile=app/release.keystore
EOF

    chmod 600 "$ANDROID_DIR/keystore.properties"
    chmod 600 "$ANDROID_DIR/app/release.keystore"

    print_info "Keystore configured"
}

# Setup service account
setup_service_account() {
    print_step "Setting up Play Store service account..."

    echo "$PLAY_STORE_SERVICE_ACCOUNT_JSON" > "$PROJECT_ROOT/service-account.json"
    chmod 600 "$PROJECT_ROOT/service-account.json"

    print_info "Service account configured"
}

# Install dependencies
install_dependencies() {
    print_step "Installing dependencies..."

    cd "$PROJECT_ROOT"
    npm ci

    print_info "Dependencies installed"
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
    npm test || {
        print_error "Tests failed"
        exit 1
    }

    print_info "Tests passed"
}

# Clean build
clean_build() {
    print_step "Cleaning build directory..."

    cd "$ANDROID_DIR"
    ./gradlew clean

    print_info "Build directory cleaned"
}

# Build AAB (Android App Bundle)
build_bundle() {
    print_step "Building Android App Bundle..."

    cd "$ANDROID_DIR"
    ./gradlew bundleRelease --no-daemon --stacktrace || {
        print_error "Bundle build failed"
        exit 1
    }

    local aab_file=$(find "$BUILD_DIR/bundle/release" -name "*.aab" | head -n 1)
    if [ -z "$aab_file" ]; then
        print_error "AAB file not found after build"
        exit 1
    fi

    print_info "Bundle built successfully: $aab_file"
}

# Build APK
build_apk() {
    print_step "Building signed APK..."

    cd "$ANDROID_DIR"
    ./gradlew assembleRelease --no-daemon --stacktrace || {
        print_error "APK build failed"
        exit 1
    }

    local apk_file=$(find "$BUILD_DIR/apk/release" -name "*-release.apk" | head -n 1)
    if [ -z "$apk_file" ]; then
        print_error "APK file not found after build"
        exit 1
    fi

    print_info "APK built successfully: $apk_file"
}

# Upload to Play Store
upload_playstore() {
    local track="${1:-internal}"
    local changelog="${2:-Bug fixes and improvements}"

    print_step "Uploading to Play Store ($track track)..."

    # Install fastlane if not available
    if ! command -v fastlane >/dev/null 2>&1; then
        print_info "Installing fastlane..."
        gem install fastlane -NV
    fi

    cd "$PROJECT_ROOT"

    # Create Fastfile for Android if it doesn't exist
    mkdir -p "$PROJECT_ROOT/fastlane"
    cat > "$PROJECT_ROOT/fastlane/Fastfile" << EOF
default_platform(:android)

platform :android do
  lane :deploy do
    upload_to_play_store(
      package_name: "com.fueki.wallet",
      json_key: "service-account.json",
      track: "$track",
      aab: "$BUILD_DIR/bundle/release/app-release.aab",
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
end
EOF

    fastlane deploy || {
        print_error "Upload to Play Store failed"
        exit 1
    }

    print_info "Successfully uploaded to Play Store ($track track)"
}

# Generate release notes
generate_release_notes() {
    local version="${1:-1.0.0}"
    local notes_dir="$PROJECT_ROOT/fastlane/metadata/android/en-US/changelogs"

    mkdir -p "$notes_dir"

    local version_code=$(grep "versionCode" "$ANDROID_DIR/app/build.gradle" | awk '{print $2}')
    echo "Bug fixes and improvements" > "$notes_dir/${version_code}.txt"

    print_info "Generated release notes for version code $version_code"
}

# Cleanup
cleanup() {
    print_step "Cleaning up..."

    rm -f "$ANDROID_DIR/app/release.keystore"
    rm -f "$ANDROID_DIR/keystore.properties"
    rm -f "$PROJECT_ROOT/service-account.json"

    print_info "Cleanup complete"
}

# Main function
main() {
    local skip_tests=false
    local skip_cleanup=false
    local track="internal"
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
            --track)
                track="$2"
                shift 2
                ;;
            --changelog)
                changelog="$2"
                shift 2
                ;;
            -h|--help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --skip-tests       Skip running tests
  --skip-cleanup     Skip cleanup after deployment
  --track TRACK      Release track (internal, alpha, beta, production)
  --changelog TEXT   Custom changelog text
  -h, --help         Show this help message

Example:
  $0 --track beta --changelog "Fixed authentication bug"
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
    print_info "Starting Play Store deployment process..."
    print_info "Track: $track"
    echo ""

    check_prerequisites
    check_environment
    setup_keystore
    setup_service_account
    install_dependencies
    run_tests "$skip_tests"
    clean_build
    build_bundle
    build_apk
    generate_release_notes
    upload_playstore "$track" "$changelog"

    if [ "$skip_cleanup" != "true" ]; then
        cleanup
    fi

    echo ""
    print_info "Deployment completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Check Play Console for processing status"
    echo "  2. Review the release in the Play Console"
    echo "  3. Promote to higher tracks when ready"
    echo ""
}

# Handle script interruption
trap 'print_error "Script interrupted"; cleanup; exit 1' INT TERM

# Run main function
main "$@"
