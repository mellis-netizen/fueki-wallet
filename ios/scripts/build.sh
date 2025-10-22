#!/bin/bash

# Fueki Wallet - iOS Build Script
# Production-grade build automation

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
CONFIGURATION="${CONFIGURATION:-Release}"
WORKSPACE="./ios/Fueki.xcworkspace"
BUILD_DIR="./ios/build"
DERIVED_DATA="./ios/DerivedData"
OUTPUT_DIR="./ios/fastlane/build_output"

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

    # Check CocoaPods
    if ! command -v pod &> /dev/null; then
        log_warning "CocoaPods not found, installing..."
        gem install cocoapods
    fi

    # Check fastlane
    if ! command -v fastlane &> /dev/null; then
        log_warning "fastlane not found, installing..."
        gem install fastlane
    fi

    log_success "Requirements check passed"
}

clean_build() {
    log_info "Cleaning previous builds..."

    # Clean derived data
    if [ -d "$DERIVED_DATA" ]; then
        rm -rf "$DERIVED_DATA"
        log_success "Removed derived data"
    fi

    # Clean build directory
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        log_success "Removed build directory"
    fi

    # Clean output directory
    if [ -d "$OUTPUT_DIR" ]; then
        rm -rf "$OUTPUT_DIR"
        log_success "Removed output directory"
    fi

    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$BUILD_DIR"

    log_success "Clean completed"
}

install_dependencies() {
    log_info "Installing dependencies..."

    cd ios

    # Install CocoaPods
    log_info "Installing CocoaPods dependencies..."
    pod install --repo-update

    cd ..

    log_success "Dependencies installed"
}

build_app() {
    log_info "Building app..."
    log_info "Scheme: $SCHEME"
    log_info "Configuration: $CONFIGURATION"

    # Use fastlane for production builds
    if [ "$CONFIGURATION" == "Release" ]; then
        log_info "Using fastlane for Release build..."
        bundle exec fastlane ios build
    else
        # Direct xcodebuild for Debug builds
        log_info "Using xcodebuild for Debug build..."

        xcodebuild \
            -workspace "$WORKSPACE" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath "$DERIVED_DATA" \
            -destination "generic/platform=iOS" \
            clean build \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            | tee "$OUTPUT_DIR/build.log" \
            | xcpretty --color
    fi

    log_success "Build completed successfully"
}

archive_app() {
    if [ "$CONFIGURATION" != "Release" ]; then
        log_warning "Skipping archive for non-Release build"
        return
    fi

    log_info "Archiving app..."

    ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"

    xcodebuild \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=iOS" \
        archive \
        | tee "$OUTPUT_DIR/archive.log" \
        | xcpretty --color

    log_success "Archive created: $ARCHIVE_PATH"
}

generate_build_info() {
    log_info "Generating build info..."

    BUILD_INFO_FILE="$OUTPUT_DIR/build_info.json"

    cat > "$BUILD_INFO_FILE" << EOF
{
  "scheme": "$SCHEME",
  "configuration": "$CONFIGURATION",
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "git_branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')",
  "xcode_version": "$(xcodebuild -version | head -1)",
  "swift_version": "$(swift --version | head -1)"
}
EOF

    log_success "Build info saved to $BUILD_INFO_FILE"
}

run_static_analysis() {
    log_info "Running static analysis..."

    xcodebuild \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA" \
        analyze \
        | tee "$OUTPUT_DIR/analysis.log" \
        | xcpretty --color

    log_success "Static analysis completed"
}

# Main execution
main() {
    log_info "=== Fueki Wallet iOS Build ==="
    log_info "Starting build process..."

    check_requirements
    clean_build
    install_dependencies

    # Optional: Run static analysis for Release builds
    if [ "$CONFIGURATION" == "Release" ]; then
        run_static_analysis
    fi

    build_app
    archive_app
    generate_build_info

    log_success "=== Build Process Completed ==="
    log_info "Build artifacts: $OUTPUT_DIR"
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --scheme)
            SCHEME="$2"
            shift 2
            ;;
        --no-clean)
            NO_CLEAN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --configuration <Debug|Release>  Build configuration (default: Release)"
            echo "  --scheme <scheme>                 Xcode scheme (default: Fueki)"
            echo "  --no-clean                        Skip clean step"
            echo "  --help                            Show this help message"
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
