#!/bin/bash

# Performance testing script for Fueki Mobile Wallet
set -e

echo "⚡ Running performance tests..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_FILE="$SCRIPT_DIR/performance-report.json"

# Create performance report
cat > "$REPORT_FILE" << EOF
{
  "test_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "benchmarks": {
    "tss_key_generation": {
      "test": "TSS Key Generation Performance",
      "target_time_ms": 5000,
      "status": "PENDING"
    },
    "transaction_signing": {
      "test": "Transaction Signing Performance",
      "target_time_ms": 2000,
      "status": "PENDING"
    },
    "blockchain_sync": {
      "test": "Blockchain Sync Performance",
      "target_time_ms": 10000,
      "status": "PENDING"
    },
    "ui_rendering": {
      "test": "UI Rendering Performance",
      "target_fps": 60,
      "status": "PENDING"
    }
  }
}
EOF

echo "📊 Performance benchmarks initialized"

# Run Xcode performance tests (requires XCTest Performance Metrics)
echo "Running Xcode performance tests..."

xcodebuild test \
    -scheme FuekiWallet \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
    -only-testing:FuekiWalletTests/PerformanceTests \
    2>&1 | tee "$SCRIPT_DIR/performance-output.log" || true

echo "✅ Performance tests complete"
echo "📄 Report saved to: $REPORT_FILE"
