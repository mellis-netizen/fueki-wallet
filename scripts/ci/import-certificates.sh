#!/bin/bash

# Import iOS signing certificates for CI/CD
set -e

echo "🔐 Importing iOS certificates..."

# Check required environment variables
if [ -z "$CERTIFICATE_BASE64" ]; then
    echo "❌ CERTIFICATE_BASE64 environment variable not set"
    exit 1
fi

if [ -z "$P12_PASSWORD" ]; then
    echo "❌ P12_PASSWORD environment variable not set"
    exit 1
fi

if [ -z "$KEYCHAIN_PASSWORD" ]; then
    echo "❌ KEYCHAIN_PASSWORD environment variable not set"
    exit 1
fi

# Create variables
KEYCHAIN_PATH="$RUNNER_TEMP/app-signing.keychain-db"
CERTIFICATE_PATH="$RUNNER_TEMP/certificate.p12"

# Decode certificate
echo "$CERTIFICATE_BASE64" | base64 --decode > "$CERTIFICATE_PATH"

# Create temporary keychain
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

# Import certificate to keychain
security import "$CERTIFICATE_PATH" \
    -P "$P12_PASSWORD" \
    -A \
    -t cert \
    -f pkcs12 \
    -k "$KEYCHAIN_PATH"

security list-keychain -d user -s "$KEYCHAIN_PATH"
security default-keychain -s "$KEYCHAIN_PATH"

# Set key partition list (required for codesign)
security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "$KEYCHAIN_PASSWORD" \
    "$KEYCHAIN_PATH"

echo "✅ Certificates imported successfully"

# Verify
security find-identity -v -p codesigning "$KEYCHAIN_PATH"
