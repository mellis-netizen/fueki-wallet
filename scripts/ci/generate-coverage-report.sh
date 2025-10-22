#!/bin/bash

# Generate code coverage report from Xcode test results
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COVERAGE_FILE="$SCRIPT_DIR/coverage.json"

echo "📊 Generating code coverage report..."

# Check if coverage.json exists
if [ ! -f "$COVERAGE_FILE" ]; then
    echo "❌ Coverage file not found: $COVERAGE_FILE"
    exit 1
fi

# Extract coverage data using Python
python3 - << EOF
import json
import sys

try:
    with open('$COVERAGE_FILE', 'r') as f:
        data = json.load(f)

    # Extract coverage metrics
    targets = data.get('targets', [])

    total_lines = 0
    covered_lines = 0
    total_files = 0

    print("\n" + "="*60)
    print("           CODE COVERAGE REPORT")
    print("="*60)

    for target in targets:
        target_name = target.get('name', 'Unknown')
        files = target.get('files', [])

        if files:
            print(f"\nTarget: {target_name}")
            print("-" * 60)

            for file_data in files:
                file_path = file_data.get('path', 'Unknown')
                file_name = file_path.split('/')[-1]
                line_coverage = file_data.get('lineCoverage', 0) * 100

                total_files += 1

                # Color coding
                if line_coverage >= 80:
                    status = "✅"
                elif line_coverage >= 60:
                    status = "⚠️ "
                else:
                    status = "❌"

                print(f"{status} {file_name:40} {line_coverage:6.2f}%")

    # Calculate overall coverage
    overall_coverage = data.get('lineCoverage', 0) * 100

    print("\n" + "="*60)
    print(f"Overall Line Coverage: {overall_coverage:.2f}%")
    print(f"Total Files Analyzed: {total_files}")
    print("="*60)

    # Coverage thresholds
    if overall_coverage >= 80:
        print("\n✅ Coverage meets the 80% threshold")
        sys.exit(0)
    elif overall_coverage >= 60:
        print("\n⚠️  Coverage is below 80% threshold")
        sys.exit(0)  # Warning but don't fail
    else:
        print("\n❌ Coverage is critically low (below 60%)")
        sys.exit(1)

except Exception as e:
    print(f"Error processing coverage data: {e}")
    sys.exit(1)
EOF

PYTHON_EXIT_CODE=$?

# Generate HTML report (simplified)
cat > "$SCRIPT_DIR/coverage-summary.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Fueki Wallet - Code Coverage</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; padding: 20px; }
        .header { background: #007AFF; color: white; padding: 20px; border-radius: 8px; }
        .metric { display: inline-block; margin: 10px 20px; }
        .high { color: #34C759; }
        .medium { color: #FF9500; }
        .low { color: #FF3B30; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f5f5f5; font-weight: 600; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Fueki Wallet - Code Coverage Report</h1>
        <p>Generated: $(date)</p>
    </div>
    <div style="margin-top: 20px;">
        <p>See <code>coverage.json</code> for detailed coverage data.</p>
    </div>
</body>
</html>
EOF

echo -e "\n📄 HTML report generated: $SCRIPT_DIR/coverage-summary.html"

exit $PYTHON_EXIT_CODE
