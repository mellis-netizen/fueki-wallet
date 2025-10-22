#!/bin/bash
# Dependency Check Script for Fueki Mobile Wallet iOS
# Verifies all dependencies are installed and up-to-date

set -e

echo "🔍 Checking iOS Dependencies for Fueki Mobile Wallet..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running from correct directory
if [ ! -f "Podfile" ]; then
    echo -e "${RED}❌ Error: Podfile not found. Please run this script from the ios/ directory.${NC}"
    exit 1
fi

# Check CocoaPods installation
echo ""
echo "📦 Checking CocoaPods..."
if ! command -v pod &> /dev/null; then
    echo -e "${RED}❌ CocoaPods not installed${NC}"
    echo "Install with: sudo gem install cocoapods"
    exit 1
else
    POD_VERSION=$(pod --version)
    echo -e "${GREEN}✅ CocoaPods installed (version $POD_VERSION)${NC}"
fi

# Check if Pods directory exists
echo ""
echo "📂 Checking Pods directory..."
if [ ! -d "Pods" ]; then
    echo -e "${YELLOW}⚠️  Pods directory not found${NC}"
    echo "Run: pod install"
    exit 1
else
    echo -e "${GREEN}✅ Pods directory exists${NC}"
fi

# Check if Podfile.lock exists
echo ""
echo "🔒 Checking Podfile.lock..."
if [ ! -f "Podfile.lock" ]; then
    echo -e "${YELLOW}⚠️  Podfile.lock not found${NC}"
    echo "Run: pod install"
    exit 1
else
    echo -e "${GREEN}✅ Podfile.lock exists${NC}"
fi

# Verify critical dependencies
echo ""
echo "🔐 Verifying Critical Dependencies..."

CRITICAL_DEPS=(
    "CryptoSwift"
    "BigInt"
    "web3swift"
    "KeychainAccess"
    "Alamofire"
    "SwiftLint"
)

MISSING_DEPS=()

for dep in "${CRITICAL_DEPS[@]}"; do
    if grep -q "$dep" Podfile.lock; then
        VERSION=$(grep -A 1 "  - $dep" Podfile.lock | tail -1 | sed 's/.*(\(.*\))/\1/')
        echo -e "${GREEN}✅ $dep $VERSION${NC}"
    else
        echo -e "${RED}❌ $dep - NOT FOUND${NC}"
        MISSING_DEPS+=("$dep")
    fi
done

# Check for outdated pods
echo ""
echo "🔄 Checking for outdated dependencies..."
pod outdated | head -20 || echo -e "${GREEN}All dependencies are up-to-date${NC}"

# Check Swift version
echo ""
echo "🔧 Checking Swift version..."
if command -v swift &> /dev/null; then
    SWIFT_VERSION=$(swift --version | head -1)
    echo -e "${GREEN}✅ $SWIFT_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Swift not found in PATH${NC}"
fi

# Check Xcode version
echo ""
echo "🔧 Checking Xcode version..."
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -1)
    echo -e "${GREEN}✅ $XCODE_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Xcode not found${NC}"
fi

# Check workspace
echo ""
echo "🏗️  Checking workspace..."
if [ -f "FuekiWallet.xcworkspace/contents.xcworkspacedata" ]; then
    echo -e "${GREEN}✅ Workspace exists${NC}"
else
    echo -e "${RED}❌ Workspace not found${NC}"
    echo "Run: pod install"
    exit 1
fi

# Summary
echo ""
echo "=================================================="
if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All critical dependencies are installed${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open FuekiWallet.xcworkspace (not .xcodeproj)"
    echo "2. Build project (Cmd+B)"
    echo "3. Run tests (Cmd+U)"
else
    echo -e "${RED}❌ Missing dependencies: ${MISSING_DEPS[*]}${NC}"
    echo ""
    echo "Run: pod install"
    exit 1
fi

echo ""
echo "🎉 Dependency check complete!"
