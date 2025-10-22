#!/bin/bash
# Automated Release Notes Generator
# Generates release notes from git commits and pull requests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_FILE="${1:-./fastlane/metadata/en-US/release_notes.txt}"
COMMITS_LIMIT="${2:-50}"
TAG_PATTERN="${3:-v*}"

echo -e "${GREEN}📝 Release Notes Generator${NC}"
echo "=================================="

# Ensure we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Not a git repository${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Get the latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 --match="$TAG_PATTERN" 2>/dev/null || echo "")

if [ -z "$LATEST_TAG" ]; then
    echo -e "${YELLOW}⚠️  No previous tags found. Generating notes from all commits.${NC}"
    COMMIT_RANGE="HEAD"
else
    echo "Latest tag: $LATEST_TAG"
    COMMIT_RANGE="$LATEST_TAG..HEAD"
fi

# Get version information
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
BUILD_DATE=$(date +"%Y-%m-%d")

# Start generating release notes
cat > "$OUTPUT_FILE" << EOF
# Fueki Mobile Wallet - Release Notes
Version: $VERSION
Build Date: $BUILD_DATE

## What's New

EOF

# Parse commits and categorize
echo -e "${BLUE}Analyzing commits...${NC}"

# Features (commits starting with feat:)
FEATURES=$(git log $COMMIT_RANGE --pretty=format:"%s" --grep="^feat:" --no-merges -i | head -n "$COMMITS_LIMIT")
if [ -n "$FEATURES" ]; then
    echo "### ✨ New Features" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    while IFS= read -r commit; do
        # Remove feat: prefix and capitalize
        MESSAGE=$(echo "$commit" | sed 's/^feat://i' | sed 's/^ *//' | sed 's/^./\U&/')
        echo "- $MESSAGE" >> "$OUTPUT_FILE"
    done <<< "$FEATURES"
    echo "" >> "$OUTPUT_FILE"
fi

# Improvements (commits starting with improve:, enhance:, or refactor:)
IMPROVEMENTS=$(git log $COMMIT_RANGE --pretty=format:"%s" --grep="^improve:\|^enhance:\|^refactor:" --no-merges -i | head -n "$COMMITS_LIMIT")
if [ -n "$IMPROVEMENTS" ]; then
    echo "### 🚀 Improvements" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    while IFS= read -r commit; do
        MESSAGE=$(echo "$commit" | sed 's/^improve://i' | sed 's/^enhance://i' | sed 's/^refactor://i' | sed 's/^ *//' | sed 's/^./\U&/')
        echo "- $MESSAGE" >> "$OUTPUT_FILE"
    done <<< "$IMPROVEMENTS"
    echo "" >> "$OUTPUT_FILE"
fi

# Bug Fixes (commits starting with fix:)
FIXES=$(git log $COMMIT_RANGE --pretty=format:"%s" --grep="^fix:" --no-merges -i | head -n "$COMMITS_LIMIT")
if [ -n "$FIXES" ]; then
    echo "### 🐛 Bug Fixes" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    while IFS= read -r commit; do
        MESSAGE=$(echo "$commit" | sed 's/^fix://i' | sed 's/^ *//' | sed 's/^./\U&/')
        echo "- $MESSAGE" >> "$OUTPUT_FILE"
    done <<< "$FIXES"
    echo "" >> "$OUTPUT_FILE"
fi

# Security fixes (commits starting with security:)
SECURITY=$(git log $COMMIT_RANGE --pretty=format:"%s" --grep="^security:" --no-merges -i | head -n "$COMMITS_LIMIT")
if [ -n "$SECURITY" ]; then
    echo "### 🔒 Security" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    while IFS= read -r commit; do
        MESSAGE=$(echo "$commit" | sed 's/^security://i' | sed 's/^ *//' | sed 's/^./\U&/')
        echo "- $MESSAGE" >> "$OUTPUT_FILE"
    done <<< "$SECURITY"
    echo "" >> "$OUTPUT_FILE"
fi

# Performance improvements (commits starting with perf:)
PERFORMANCE=$(git log $COMMIT_RANGE --pretty=format:"%s" --grep="^perf:" --no-merges -i | head -n "$COMMITS_LIMIT")
if [ -n "$PERFORMANCE" ]; then
    echo "### ⚡ Performance" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    while IFS= read -r commit; do
        MESSAGE=$(echo "$commit" | sed 's/^perf://i' | sed 's/^ *//' | sed 's/^./\U&/')
        echo "- $MESSAGE" >> "$OUTPUT_FILE"
    done <<< "$PERFORMANCE"
    echo "" >> "$OUTPUT_FILE"
fi

# Documentation (commits starting with docs:)
DOCS=$(git log $COMMIT_RANGE --pretty=format:"%s" --grep="^docs:" --no-merges -i | head -n "$COMMITS_LIMIT")
if [ -n "$DOCS" ]; then
    echo "### 📚 Documentation" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    while IFS= read -r commit; do
        MESSAGE=$(echo "$commit" | sed 's/^docs://i' | sed 's/^ *//' | sed 's/^./\U&/')
        echo "- $MESSAGE" >> "$OUTPUT_FILE"
    done <<< "$DOCS"
    echo "" >> "$OUTPUT_FILE"
fi

# Add footer
cat >> "$OUTPUT_FILE" << EOF

---

Thank you for using Fueki Mobile Wallet! 🙏

For more information, visit our website or contact support.
EOF

# Display summary
echo "=================================="
echo -e "${GREEN}✅ Release notes generated successfully!${NC}"
echo "Output file: $OUTPUT_FILE"
echo ""
echo "Preview:"
echo "=================================="
head -n 20 "$OUTPUT_FILE"
echo "=================================="

# Optional: Generate a shorter version for TestFlight (max 4000 chars)
TESTFLIGHT_NOTES="${OUTPUT_FILE%.txt}_testflight.txt"
head -c 3900 "$OUTPUT_FILE" > "$TESTFLIGHT_NOTES"
echo "" >> "$TESTFLIGHT_NOTES"
echo "..." >> "$TESTFLIGHT_NOTES"

echo -e "${GREEN}✅ TestFlight notes: $TESTFLIGHT_NOTES${NC}"
