#!/bin/bash
# Code Signing Setup Script
# Configures certificates and provisioning profiles for CI/CD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Code Signing Setup${NC}"
echo "=================================="

# Check for required environment variables
if [ -z "$MATCH_PASSWORD" ]; then
    echo -e "${YELLOW}⚠️  MATCH_PASSWORD not set. Using empty password.${NC}"
    export MATCH_PASSWORD=""
fi

if [ -z "$MATCH_GIT_URL" ]; then
    echo -e "${RED}❌ Error: MATCH_GIT_URL environment variable not set${NC}"
    exit 1
fi

# Create keychain for CI
if [ -n "$CI" ]; then
    echo "Setting up CI keychain..."

    KEYCHAIN_PATH="$HOME/Library/Keychains/fastlane.keychain-db"
    KEYCHAIN_PASSWORD="${MATCH_KEYCHAIN_PASSWORD:-fastlane}"

    # Create keychain
    security create-keychain -p "$KEYCHAIN_PASSWORD" fastlane.keychain

    # Set keychain settings
    security set-keychain-settings -lut 21600 fastlane.keychain

    # Unlock keychain
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" fastlane.keychain

    # Add to search list
    security list-keychains -d user -s fastlane.keychain login.keychain

    # Set default keychain
    security default-keychain -s fastlane.keychain

    echo -e "${GREEN}✅ CI keychain created${NC}"
fi

# Install certificates and profiles
echo "Installing certificates and provisioning profiles..."

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Install development certificates
if [ "$MATCH_TYPE" = "development" ] || [ -z "$MATCH_TYPE" ]; then
    echo "Installing development certificates..."
    bundle exec fastlane match development --readonly
    echo -e "${GREEN}✅ Development certificates installed${NC}"
fi

# Install app store certificates
if [ "$MATCH_TYPE" = "appstore" ] || [ -z "$MATCH_TYPE" ]; then
    echo "Installing app store certificates..."
    bundle exec fastlane match appstore --readonly
    echo -e "${GREEN}✅ App Store certificates installed${NC}"
fi

# Install ad-hoc certificates (optional)
if [ "$MATCH_TYPE" = "adhoc" ]; then
    echo "Installing ad-hoc certificates..."
    bundle exec fastlane match adhoc --readonly
    echo -e "${GREEN}✅ Ad-hoc certificates installed${NC}"
fi

# Verify installation
echo "Verifying certificate installation..."
security find-identity -v -p codesigning

echo "=================================="
echo -e "${GREEN}✅ Code signing setup complete!${NC}"
