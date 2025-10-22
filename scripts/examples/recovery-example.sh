#!/bin/bash
################################################################################
# Fueki Wallet Swarm Recovery - Usage Examples
#
# This script demonstrates various recovery system usage patterns
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECOVERY_SCRIPT="$SCRIPT_DIR/../swarm-recovery.sh"

echo "=============================================="
echo "  Fueki Swarm Recovery - Usage Examples"
echo "=============================================="
echo ""

# ============================================================================
# Example 1: Basic Save and Restore
# ============================================================================
example_basic() {
    echo "📋 Example 1: Basic Save and Restore"
    echo "--------------------------------------------"
    echo ""

    # Generate session ID
    SESSION_ID="example-basic-$(date +%s)"

    echo "1. Saving swarm state..."
    "$RECOVERY_SCRIPT" save "$SESSION_ID"

    echo ""
    echo "2. Simulating some work..."
    sleep 2

    echo ""
    echo "3. Restoring swarm state..."
    "$RECOVERY_SCRIPT" restore "$SESSION_ID"

    echo ""
    echo "✅ Basic save/restore complete!"
    echo ""
}

# ============================================================================
# Example 2: Auto-Save During Long Operation
# ============================================================================
example_auto_save() {
    echo "📋 Example 2: Auto-Save During Long Operation"
    echo "--------------------------------------------"
    echo ""

    SESSION_ID="example-autosave-$(date +%s)"

    echo "1. Starting auto-save (every 10 seconds for demo)..."
    "$RECOVERY_SCRIPT" auto-save start 10 "$SESSION_ID" &
    AUTO_SAVE_PID=$!

    echo ""
    echo "2. Simulating long-running swarm operation..."
    for i in {1..5}; do
        echo "   Processing step $i/5..."
        sleep 3
    done

    echo ""
    echo "3. Stopping auto-save..."
    "$RECOVERY_SCRIPT" auto-save stop

    echo ""
    echo "4. Listing all checkpoints created..."
    "$RECOVERY_SCRIPT" list | grep "$SESSION_ID" || echo "   (Checkpoints may take a moment to appear)"

    echo ""
    echo "✅ Auto-save example complete!"
    echo ""
}

# ============================================================================
# Example 3: Recovery After Simulated Crash
# ============================================================================
example_crash_recovery() {
    echo "📋 Example 3: Recovery After Simulated Crash"
    echo "--------------------------------------------"
    echo ""

    SESSION_ID="example-crash-$(date +%s)"

    echo "1. Starting work with periodic saves..."
    "$RECOVERY_SCRIPT" save "$SESSION_ID"

    echo ""
    echo "2. Simulating crash during operation..."
    echo "   (In real scenario, this would be a system failure)"
    sleep 2

    echo ""
    echo "3. System restarted - recovering state..."
    "$RECOVERY_SCRIPT" restore "$SESSION_ID"

    echo ""
    echo "4. Work can now continue from checkpoint!"

    echo ""
    echo "✅ Crash recovery example complete!"
    echo ""
}

# ============================================================================
# Example 4: Multi-Day Project Continuity
# ============================================================================
example_multi_day() {
    echo "📋 Example 4: Multi-Day Project Continuity"
    echo "--------------------------------------------"
    echo ""

    PROJECT_ID="wallet-v2-dev"

    echo "Day 1: Starting new project..."
    SESSION_ID="${PROJECT_ID}-day1"
    "$RECOVERY_SCRIPT" save "$SESSION_ID"

    echo ""
    echo "Day 2: Restoring and continuing work..."
    SESSION_ID="${PROJECT_ID}-day2"
    "$RECOVERY_SCRIPT" restore "${PROJECT_ID}-day1"
    "$RECOVERY_SCRIPT" save "$SESSION_ID"

    echo ""
    echo "Day 3: Restoring from yesterday..."
    SESSION_ID="${PROJECT_ID}-day3"
    "$RECOVERY_SCRIPT" restore "${PROJECT_ID}-day2"
    "$RECOVERY_SCRIPT" save "$SESSION_ID"

    echo ""
    echo "📊 Project checkpoint history:"
    "$RECOVERY_SCRIPT" list | grep "$PROJECT_ID" || echo "   (No checkpoints yet)"

    echo ""
    echo "✅ Multi-day continuity example complete!"
    echo ""
}

# ============================================================================
# Example 5: Cleanup Old Checkpoints
# ============================================================================
example_cleanup() {
    echo "📋 Example 5: Cleanup Old Checkpoints"
    echo "--------------------------------------------"
    echo ""

    echo "1. Current storage status:"
    "$RECOVERY_SCRIPT" status | grep -A 2 "Storage Used"

    echo ""
    echo "2. All checkpoints:"
    "$RECOVERY_SCRIPT" list

    echo ""
    echo "3. Cleaning up checkpoints older than 7 days..."
    "$RECOVERY_SCRIPT" cleanup 7

    echo ""
    echo "4. Updated storage status:"
    "$RECOVERY_SCRIPT" status | grep -A 2 "Storage Used"

    echo ""
    echo "✅ Cleanup example complete!"
    echo ""
}

# ============================================================================
# Example 6: Production Deployment with Recovery
# ============================================================================
example_production() {
    echo "📋 Example 6: Production Deployment Pattern"
    echo "--------------------------------------------"
    echo ""

    DEPLOY_ID="prod-deploy-$(date +%Y%m%d-%H%M%S)"

    echo "1. Pre-deployment: Save current state..."
    "$RECOVERY_SCRIPT" save "pre-${DEPLOY_ID}"

    echo ""
    echo "2. Start auto-save for deployment (aggressive: 5s for demo)..."
    "$RECOVERY_SCRIPT" auto-save start 5 "$DEPLOY_ID" &

    echo ""
    echo "3. Simulating deployment steps..."
    for step in "backup" "test" "deploy" "verify"; do
        echo "   Executing: $step"
        sleep 2
    done

    echo ""
    echo "4. Deployment complete - final checkpoint..."
    "$RECOVERY_SCRIPT" save "post-${DEPLOY_ID}"

    echo ""
    echo "5. Stopping auto-save..."
    "$RECOVERY_SCRIPT" auto-save stop

    echo ""
    echo "6. Deployment checkpoints:"
    "$RECOVERY_SCRIPT" list | grep "$DEPLOY_ID" || echo "   (Checkpoints may take a moment)"

    echo ""
    echo "✅ Production deployment example complete!"
    echo ""
}

# ============================================================================
# Main Menu
# ============================================================================
show_menu() {
    echo ""
    echo "Select an example to run:"
    echo ""
    echo "  1) Basic Save and Restore"
    echo "  2) Auto-Save During Long Operation"
    echo "  3) Recovery After Simulated Crash"
    echo "  4) Multi-Day Project Continuity"
    echo "  5) Cleanup Old Checkpoints"
    echo "  6) Production Deployment Pattern"
    echo "  7) Run All Examples"
    echo "  8) Exit"
    echo ""
}

run_example() {
    case "$1" in
        1) example_basic ;;
        2) example_auto_save ;;
        3) example_crash_recovery ;;
        4) example_multi_day ;;
        5) example_cleanup ;;
        6) example_production ;;
        7)
            example_basic
            example_auto_save
            example_crash_recovery
            example_multi_day
            example_cleanup
            example_production
            ;;
        8) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
}

main() {
    if [[ $# -gt 0 ]]; then
        # Run specific example from command line
        run_example "$1"
    else
        # Interactive mode
        while true; do
            show_menu
            read -p "Enter choice [1-8]: " choice
            echo ""
            run_example "$choice"

            read -p "Press Enter to continue..."
        done
    fi
}

main "$@"
