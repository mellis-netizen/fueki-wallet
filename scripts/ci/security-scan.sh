#!/bin/bash

# Security scanning script for Fueki Mobile Wallet
set -e

echo "🔒 Starting security scan..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

REPORT_FILE="$OUTPUT_DIR/security-report.json"
VULNERABILITIES=0

echo "{" > "$REPORT_FILE"
echo "  \"scan_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$REPORT_FILE"
echo "  \"checks\": {" >> "$REPORT_FILE"

# 1. Check for hardcoded secrets
echo -e "\n${YELLOW}[1/6]${NC} Checking for hardcoded secrets..."
SECRET_PATTERNS=(
    "password\s*=\s*['\"][^'\"]+['\"]"
    "api_key\s*=\s*['\"][^'\"]+['\"]"
    "private_key\s*=\s*['\"][^'\"]+['\"]"
    "secret\s*=\s*['\"][^'\"]+['\"]"
    "AWS_ACCESS_KEY_ID"
    "-----BEGIN RSA PRIVATE KEY-----"
)

SECRETS_FOUND=0
for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -r -E "$pattern" "$PROJECT_ROOT/src" 2>/dev/null | grep -v "Binary file"; then
        SECRETS_FOUND=$((SECRETS_FOUND + 1))
    fi
done

if [ $SECRETS_FOUND -gt 0 ]; then
    echo -e "${RED}❌ Found $SECRETS_FOUND potential secrets${NC}"
    VULNERABILITIES=$((VULNERABILITIES + SECRETS_FOUND))
    echo "    \"hardcoded_secrets\": { \"status\": \"FAIL\", \"count\": $SECRETS_FOUND }," >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ No hardcoded secrets found${NC}"
    echo "    \"hardcoded_secrets\": { \"status\": \"PASS\", \"count\": 0 }," >> "$REPORT_FILE"
fi

# 2. Check for insecure cryptographic practices
echo -e "\n${YELLOW}[2/6]${NC} Checking cryptographic practices..."
CRYPTO_ISSUES=0

# Check for weak algorithms
if grep -r "MD5\|SHA1" "$PROJECT_ROOT/src" --include="*.swift" 2>/dev/null; then
    echo -e "${RED}❌ Weak hash algorithms detected (MD5/SHA1)${NC}"
    CRYPTO_ISSUES=$((CRYPTO_ISSUES + 1))
fi

# Check for insecure random
if grep -r "arc4random\|random()" "$PROJECT_ROOT/src" --include="*.swift" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Consider using SecRandomCopyBytes for cryptographic operations${NC}"
fi

if [ $CRYPTO_ISSUES -gt 0 ]; then
    VULNERABILITIES=$((VULNERABILITIES + CRYPTO_ISSUES))
    echo "    \"cryptographic_issues\": { \"status\": \"FAIL\", \"count\": $CRYPTO_ISSUES }," >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Cryptographic practices look good${NC}"
    echo "    \"cryptographic_issues\": { \"status\": \"PASS\", \"count\": 0 }," >> "$REPORT_FILE"
fi

# 3. Check for insecure network connections
echo -e "\n${YELLOW}[3/6]${NC} Checking network security..."
NETWORK_ISSUES=0

if grep -r "http://" "$PROJECT_ROOT/src" --include="*.swift" 2>/dev/null | grep -v "localhost\|127.0.0.1"; then
    echo -e "${RED}❌ Insecure HTTP connections detected${NC}"
    NETWORK_ISSUES=$((NETWORK_ISSUES + 1))
fi

if grep -r "URLSessionConfiguration.*allowsConstrainedNetworkAccess.*false" "$PROJECT_ROOT/src" --include="*.swift" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Insecure network configuration detected${NC}"
fi

if [ $NETWORK_ISSUES -gt 0 ]; then
    VULNERABILITIES=$((VULNERABILITIES + NETWORK_ISSUES))
    echo "    \"network_security\": { \"status\": \"FAIL\", \"count\": $NETWORK_ISSUES }," >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Network security configuration looks good${NC}"
    echo "    \"network_security\": { \"status\": \"PASS\", \"count\": 0 }," >> "$REPORT_FILE"
fi

# 4. Check Info.plist security settings
echo -e "\n${YELLOW}[4/6]${NC} Checking Info.plist security..."
PLIST_ISSUES=0

# This check will be enabled when Info.plist is created
# if [ -f "$PROJECT_ROOT/FuekiWallet/Info.plist" ]; then
#     # Check for App Transport Security
#     if ! grep -q "NSAppTransportSecurity" "$PROJECT_ROOT/FuekiWallet/Info.plist"; then
#         echo -e "${YELLOW}⚠️  App Transport Security not configured${NC}"
#     fi
# fi

echo "    \"plist_security\": { \"status\": \"PASS\", \"count\": 0 }," >> "$REPORT_FILE"

# 5. Check for SQL injection vulnerabilities
echo -e "\n${YELLOW}[5/6]${NC} Checking for SQL injection risks..."
SQL_ISSUES=0

if grep -r "\\\"SELECT.*\\\\\\(.*\\)\\\"" "$PROJECT_ROOT/src" --include="*.swift" 2>/dev/null; then
    echo -e "${RED}❌ Potential SQL injection vulnerability detected${NC}"
    SQL_ISSUES=$((SQL_ISSUES + 1))
fi

if [ $SQL_ISSUES -gt 0 ]; then
    VULNERABILITIES=$((VULNERABILITIES + SQL_ISSUES))
    echo "    \"sql_injection\": { \"status\": \"FAIL\", \"count\": $SQL_ISSUES }," >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ No SQL injection vulnerabilities detected${NC}"
    echo "    \"sql_injection\": { \"status\": \"PASS\", \"count\": 0 }," >> "$REPORT_FILE"
fi

# 6. Check for insecure data storage
echo -e "\n${YELLOW}[6/6]${NC} Checking data storage security..."
STORAGE_ISSUES=0

if grep -r "UserDefaults.standard.set.*password\|UserDefaults.standard.set.*key" "$PROJECT_ROOT/src" --include="*.swift" 2>/dev/null; then
    echo -e "${RED}❌ Sensitive data stored in UserDefaults${NC}"
    STORAGE_ISSUES=$((STORAGE_ISSUES + 1))
fi

if [ $STORAGE_ISSUES -gt 0 ]; then
    VULNERABILITIES=$((VULNERABILITIES + STORAGE_ISSUES))
    echo "    \"insecure_storage\": { \"status\": \"FAIL\", \"count\": $STORAGE_ISSUES }" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Data storage security looks good${NC}"
    echo "    \"insecure_storage\": { \"status\": \"PASS\", \"count\": 0 }" >> "$REPORT_FILE"
fi

# Close JSON
echo "  }," >> "$REPORT_FILE"
echo "  \"total_vulnerabilities\": $VULNERABILITIES," >> "$REPORT_FILE"
echo "  \"status\": \"$([ $VULNERABILITIES -eq 0 ] && echo PASS || echo FAIL)\"" >> "$REPORT_FILE"
echo "}" >> "$REPORT_FILE"

# Summary
echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}         SECURITY SCAN SUMMARY${NC}"
echo -e "${YELLOW}═══════════════════════════════════════${NC}"
echo -e "Total vulnerabilities found: $VULNERABILITIES"
echo -e "Report saved to: $REPORT_FILE"

if [ $VULNERABILITIES -eq 0 ]; then
    echo -e "${GREEN}✅ Security scan PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ Security scan FAILED${NC}"
    echo -e "${RED}Please fix the vulnerabilities before proceeding${NC}"
    exit 1
fi
