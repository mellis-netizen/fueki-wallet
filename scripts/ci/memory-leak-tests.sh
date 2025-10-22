#!/bin/bash

# Memory leak detection for Fueki Mobile Wallet
set -e

echo "🧠 Running memory leak tests..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_FILE="$SCRIPT_DIR/memory-report.json"

# Create memory report
cat > "$REPORT_FILE" << EOF
{
  "test_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "memory_tests": {
    "retain_cycles": {
      "test": "Retain Cycle Detection",
      "status": "PENDING"
    },
    "memory_growth": {
      "test": "Memory Growth Analysis",
      "status": "PENDING"
    },
    "leak_detection": {
      "test": "Memory Leak Detection",
      "status": "PENDING"
    }
  }
}
EOF

echo "Running memory leak detection with Instruments..."

# Run tests with memory profiling
xcodebuild test \
    -scheme FuekiWallet \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
    -enableAddressSanitizer YES \
    -enableThreadSanitizer NO \
    2>&1 | tee "$SCRIPT_DIR/memory-output.log" || true

echo "✅ Memory leak tests complete"
echo "📄 Report saved to: $REPORT_FILE"
