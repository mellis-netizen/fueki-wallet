#!/bin/bash

# Version Manager Script for Fueki Mobile Wallet
# Manages version numbers across package.json, iOS, and Android

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get current version from package.json
get_current_version() {
    if [ -f "$PROJECT_ROOT/package.json" ]; then
        node -p "require('$PROJECT_ROOT/package.json').version" 2>/dev/null || echo "0.0.0"
    else
        echo "0.0.0"
    fi
}

# Function to increment version
increment_version() {
    local version=$1
    local bump_type=$2

    IFS='.' read -r -a version_parts <<< "$version"
    local major="${version_parts[0]}"
    local minor="${version_parts[1]}"
    local patch="${version_parts[2]}"

    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            print_error "Invalid bump type: $bump_type"
            exit 1
            ;;
    esac

    echo "$major.$minor.$patch"
}

# Function to update package.json
update_package_json() {
    local new_version=$1

    if [ -f "$PROJECT_ROOT/package.json" ]; then
        print_info "Updating package.json to version $new_version"
        cd "$PROJECT_ROOT"
        npm version "$new_version" --no-git-tag-version --allow-same-version
    fi
}

# Function to update iOS version
update_ios_version() {
    local new_version=$1
    local build_number=$2

    local info_plist="$PROJECT_ROOT/ios/FuekiWallet/Info.plist"

    if [ -f "$info_plist" ]; then
        print_info "Updating iOS version to $new_version ($build_number)"
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $new_version" "$info_plist" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$info_plist" 2>/dev/null || true
    else
        print_warn "iOS Info.plist not found at $info_plist"
    fi
}

# Function to update Android version
update_android_version() {
    local new_version=$1
    local version_code=$2

    local build_gradle="$PROJECT_ROOT/android/app/build.gradle"

    if [ -f "$build_gradle" ]; then
        print_info "Updating Android version to $new_version ($version_code)"
        sed -i.bak "s/versionCode .*/versionCode $version_code/" "$build_gradle"
        sed -i.bak "s/versionName .*/versionName \"$new_version\"/" "$build_gradle"
        rm -f "$build_gradle.bak"
    else
        print_warn "Android build.gradle not found at $build_gradle"
    fi
}

# Function to update version.txt
update_version_file() {
    local new_version=$1
    echo "$new_version" > "$PROJECT_ROOT/version.txt"
    print_info "Updated version.txt to $new_version"
}

# Function to generate changelog entry
generate_changelog_entry() {
    local new_version=$1
    local changelog="$PROJECT_ROOT/CHANGELOG.md"
    local date=$(date +%Y-%m-%d)

    if [ ! -f "$changelog" ]; then
        print_info "Creating CHANGELOG.md"
        cat > "$changelog" << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
    fi

    # Add new version entry
    local temp_file=$(mktemp)
    {
        head -n 6 "$changelog"
        cat << EOF

## [$new_version] - $date

### Added
- New features and improvements

### Changed
- Updates and modifications

### Fixed
- Bug fixes

EOF
        tail -n +7 "$changelog"
    } > "$temp_file"

    mv "$temp_file" "$changelog"
    print_info "Added changelog entry for version $new_version"
}

# Main function
main() {
    local bump_type="${1:-patch}"
    local build_number="${2:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

    # Validate bump type
    if [[ ! "$bump_type" =~ ^(major|minor|patch)$ ]]; then
        print_error "Invalid bump type. Use: major, minor, or patch"
        exit 1
    fi

    # Get current version
    local current_version=$(get_current_version)
    print_info "Current version: $current_version"

    # Calculate new version
    local new_version=$(increment_version "$current_version" "$bump_type")
    print_info "New version: $new_version"

    # Update all version files
    update_package_json "$new_version"
    update_ios_version "$new_version" "$build_number"
    update_android_version "$new_version" "$build_number"
    update_version_file "$new_version"
    generate_changelog_entry "$new_version"

    print_info "Version bump complete!"
    print_info "Version: $new_version"
    print_info "Build Number: $build_number"

    # Git operations (if in a git repo)
    if git rev-parse --git-dir > /dev/null 2>&1; then
        print_info "Git repository detected"
        echo ""
        echo "To commit and tag this version, run:"
        echo "  git add ."
        echo "  git commit -m \"chore: bump version to $new_version\""
        echo "  git tag -a \"v$new_version\" -m \"Release $new_version\""
        echo "  git push && git push --tags"
    fi
}

# Show usage if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << EOF
Usage: $0 [bump_type] [build_number]

Arguments:
  bump_type    : major, minor, or patch (default: patch)
  build_number : Build/version code number (default: git commit count)

Examples:
  $0 patch              # Increment patch version (1.0.0 -> 1.0.1)
  $0 minor              # Increment minor version (1.0.0 -> 1.1.0)
  $0 major              # Increment major version (1.0.0 -> 2.0.0)
  $0 patch 42           # Set specific build number
EOF
    exit 0
fi

# Run main function
main "$@"
