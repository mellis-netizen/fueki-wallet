#!/bin/bash
# Build Number Increment Script
# Automatically increments build number based on git commits or CI build number

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project paths
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="${PROJECT_DIR}/FuekiWallet/Info.plist"

echo -e "${GREEN}🔢 Build Number Increment Script${NC}"
echo "=================================="

# Check if Info.plist exists
if [ ! -f "$INFO_PLIST" ]; then
    echo -e "${RED}❌ Error: Info.plist not found at ${INFO_PLIST}${NC}"
    exit 1
fi

# Get current version and build number
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST")

echo "Current Version: $CURRENT_VERSION"
echo "Current Build: $CURRENT_BUILD"

# Determine new build number
if [ -n "$CI_BUILD_NUMBER" ]; then
    # Use CI build number if available (GitHub Actions, Jenkins, etc.)
    NEW_BUILD="$CI_BUILD_NUMBER"
    echo -e "${YELLOW}Using CI build number: $NEW_BUILD${NC}"
elif [ -n "$GITHUB_RUN_NUMBER" ]; then
    # GitHub Actions run number
    NEW_BUILD="$GITHUB_RUN_NUMBER"
    echo -e "${YELLOW}Using GitHub Actions run number: $NEW_BUILD${NC}"
elif git rev-parse --git-dir > /dev/null 2>&1; then
    # Use git commit count
    GIT_COMMIT_COUNT=$(git rev-list --count HEAD)
    NEW_BUILD="$GIT_COMMIT_COUNT"
    echo -e "${YELLOW}Using git commit count: $NEW_BUILD${NC}"
else
    # Increment current build number
    NEW_BUILD=$((CURRENT_BUILD + 1))
    echo -e "${YELLOW}Incrementing build number: $NEW_BUILD${NC}"
fi

# Update build number in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$INFO_PLIST"

echo -e "${GREEN}✅ Build number updated to: $NEW_BUILD${NC}"
echo "Version: $CURRENT_VERSION ($NEW_BUILD)"

# Optional: Update build number in project.pbxproj for all targets
if command -v agvtool &> /dev/null; then
    cd "$PROJECT_DIR"
    agvtool new-version -all "$NEW_BUILD"
    echo -e "${GREEN}✅ Updated all targets with agvtool${NC}"
fi

echo "=================================="
echo -e "${GREEN}✅ Build number increment complete!${NC}"
