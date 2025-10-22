#!/bin/bash
################################################################################
# Fueki Wallet Swarm Recovery System
#
# Comprehensive crash recovery and state persistence for Claude Flow swarms
#
# Usage:
#   ./swarm-recovery.sh save [session-id]    # Save current swarm state
#   ./swarm-recovery.sh restore [session-id] # Restore from crash
#   ./swarm-recovery.sh status               # Check recovery status
#   ./swarm-recovery.sh list                 # List available checkpoints
#   ./swarm-recovery.sh cleanup [days]       # Clean old checkpoints (default: 7)
#   ./swarm-recovery.sh auto-save [interval] # Start auto-save (default: 300s)
#
# Environment Variables:
#   RECOVERY_DIR     - Directory for recovery data (default: ./scripts/recovery-data)
#   LOG_DIR          - Directory for logs (default: ./scripts/logs)
#   SWARM_DIR        - Swarm state directory (default: ./.swarm)
#   MAX_CHECKPOINTS  - Maximum checkpoints to keep (default: 20)
#   VERBOSE          - Enable verbose logging (0/1, default: 0)
#
################################################################################

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RECOVERY_DIR="${RECOVERY_DIR:-$SCRIPT_DIR/recovery-data}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
SWARM_DIR="${SWARM_DIR:-$PROJECT_ROOT/.swarm}"
MAX_CHECKPOINTS="${MAX_CHECKPOINTS:-20}"
VERBOSE="${VERBOSE:-0}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/recovery_${TIMESTAMP}.log"
AUTO_SAVE_PID_FILE="$RECOVERY_DIR/auto-save.pid"

# ============================================================================
# Utility Functions
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_verbose() {
    if [[ "$VERBOSE" == "1" ]]; then
        log "VERBOSE" "$@"
    fi
}

error() {
    log "ERROR" "$@"
    echo "❌ Error: $*" >&2
}

success() {
    log "INFO" "$@"
    echo "✅ $*"
}

warning() {
    log "WARN" "$@"
    echo "⚠️  Warning: $*"
}

info() {
    log "INFO" "$@"
    echo "ℹ️  $*"
}

die() {
    error "$@"
    exit 1
}

# ============================================================================
# Setup and Validation
# ============================================================================

setup_directories() {
    log_verbose "Setting up directories..."
    mkdir -p "$RECOVERY_DIR" "$LOG_DIR" "$SWARM_DIR"

    # Create subdirectories for organization
    mkdir -p "$RECOVERY_DIR/checkpoints"
    mkdir -p "$RECOVERY_DIR/snapshots"
    mkdir -p "$RECOVERY_DIR/metadata"

    log_verbose "Directories created successfully"
}

validate_environment() {
    log_verbose "Validating environment..."

    # Check for required commands
    local required_commands=("jq" "sqlite3")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            die "Required command '$cmd' not found. Please install it first."
        fi
    done

    # Check for claude-flow
    if ! command -v npx &> /dev/null; then
        die "npx not found. Please install Node.js and npm."
    fi

    log_verbose "Environment validation complete"
}

# ============================================================================
# State Capture Functions
# ============================================================================

get_session_id() {
    local provided_id="$1"

    if [[ -n "$provided_id" ]]; then
        echo "$provided_id"
        return
    fi

    # Try to get active session from swarm memory
    if [[ -f "$SWARM_DIR/memory.db" ]]; then
        local session_id=$(sqlite3 "$SWARM_DIR/memory.db" \
            "SELECT value FROM memory WHERE key LIKE '%session-id%' ORDER BY timestamp DESC LIMIT 1" 2>/dev/null || echo "")

        if [[ -n "$session_id" ]]; then
            echo "$session_id"
            return
        fi
    fi

    # Generate new session ID
    echo "swarm-$(date +%s)-$$"
}

capture_swarm_state() {
    local session_id="$1"
    local output_file="$2"

    log_verbose "Capturing swarm state for session: $session_id"

    local state_data="{}"

    # Add metadata
    state_data=$(echo "$state_data" | jq \
        --arg session_id "$session_id" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg hostname "$(hostname)" \
        --arg project_root "$PROJECT_ROOT" \
        '. + {
            metadata: {
                session_id: $session_id,
                timestamp: $timestamp,
                hostname: $hostname,
                project_root: $project_root,
                version: "1.0.0"
            }
        }')

    # Capture swarm status via hooks
    info "Querying swarm status..."
    local swarm_status=""
    if swarm_status=$(npx claude-flow@alpha hooks session-export --session-id "$session_id" 2>/dev/null); then
        # Validate JSON before using it
        if echo "$swarm_status" | jq empty 2>/dev/null; then
            state_data=$(echo "$state_data" | jq --argjson status "$swarm_status" '. + {swarm_status: $status}')
            log_verbose "Swarm status captured"
        else
            warning "Invalid JSON from hooks, skipping swarm status"
        fi
    else
        warning "Could not capture swarm status via hooks"
    fi

    # Capture memory database
    if [[ -f "$SWARM_DIR/memory.db" ]]; then
        info "Exporting memory database..."
        local memory_dump=$(sqlite3 "$SWARM_DIR/memory.db" "SELECT key, value, namespace, ttl, timestamp FROM memory" -json 2>/dev/null || echo "[]")
        state_data=$(echo "$state_data" | jq --argjson memory "$memory_dump" '. + {memory: $memory}')
        log_verbose "Memory database exported: $(echo "$memory_dump" | jq 'length') entries"
    fi

    # Capture agent configurations
    if [[ -f "$SWARM_DIR/agents.json" ]]; then
        info "Capturing agent configurations..."
        local agents=$(cat "$SWARM_DIR/agents.json")
        state_data=$(echo "$state_data" | jq --argjson agents "$agents" '. + {agents: $agents}')
        log_verbose "Agent configurations captured"
    fi

    # Capture task states
    if [[ -f "$SWARM_DIR/tasks.json" ]]; then
        info "Capturing task states..."
        local tasks=$(cat "$SWARM_DIR/tasks.json")
        state_data=$(echo "$state_data" | jq --argjson tasks "$tasks" '. + {tasks: $tasks}')
        log_verbose "Task states captured"
    fi

    # Capture file system snapshot (git tracked files)
    if [[ -d "$PROJECT_ROOT/.git" ]]; then
        info "Creating file system snapshot..."
        local git_status=$(git -C "$PROJECT_ROOT" status --porcelain --untracked-files=all 2>/dev/null || echo "")
        local git_diff=$(git -C "$PROJECT_ROOT" diff HEAD 2>/dev/null || echo "")

        state_data=$(echo "$state_data" | jq \
            --arg git_status "$git_status" \
            --arg git_diff "$git_diff" \
            '. + {
                filesystem: {
                    git_status: $git_status,
                    git_diff: $git_diff,
                    timestamp: now | todate
                }
            }')
        log_verbose "File system snapshot created"
    fi

    # Capture environment variables (sanitized)
    local env_vars=$(env | grep -E '^(NODE_|NPM_|ANTHROPIC_|SWARM_|RECOVERY_)' | sed 's/=.*/=***/' || echo "")
    state_data=$(echo "$state_data" | jq --arg env "$env_vars" '. + {environment: $env}')

    # Capture active processes
    local swarm_processes=$(ps aux | grep -E '(claude-flow|npx)' | grep -v grep || echo "")
    state_data=$(echo "$state_data" | jq --arg processes "$swarm_processes" '. + {processes: $processes}')

    # Write state to file
    echo "$state_data" | jq '.' > "$output_file"

    success "State captured successfully: $output_file ($(du -h "$output_file" | cut -f1))"

    # Create metadata index
    create_checkpoint_metadata "$session_id" "$output_file"
}

create_checkpoint_metadata() {
    local session_id="$1"
    local checkpoint_file="$2"

    local metadata_file="$RECOVERY_DIR/metadata/${session_id}.meta.json"

    jq -n \
        --arg session_id "$session_id" \
        --arg checkpoint_file "$checkpoint_file" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg size "$(stat -f%z "$checkpoint_file" 2>/dev/null || stat -c%s "$checkpoint_file" 2>/dev/null || echo 0)" \
        '{
            session_id: $session_id,
            checkpoint_file: $checkpoint_file,
            created_at: $timestamp,
            size_bytes: ($size | tonumber),
            recovery_count: 0,
            last_recovered: null,
            status: "active"
        }' > "$metadata_file"

    log_verbose "Metadata created: $metadata_file"
}

# ============================================================================
# Recovery Functions
# ============================================================================

restore_swarm_state() {
    local session_id="$1"

    log_verbose "Restoring swarm state for session: $session_id"

    # Find checkpoint file
    local checkpoint_file=$(find_latest_checkpoint "$session_id")

    if [[ -z "$checkpoint_file" ]] || [[ ! -f "$checkpoint_file" ]]; then
        die "No checkpoint found for session: $session_id"
    fi

    info "Found checkpoint: $checkpoint_file"

    # Load state data
    local state_data=$(cat "$checkpoint_file")

    # Validate checkpoint
    if ! echo "$state_data" | jq -e '.metadata.session_id' >/dev/null 2>&1; then
        die "Invalid checkpoint file: missing metadata"
    fi

    # Restore memory database
    info "Restoring memory database..."
    if echo "$state_data" | jq -e '.memory' >/dev/null 2>&1; then
        restore_memory_database "$state_data"
    fi

    # Restore agent configurations
    info "Restoring agent configurations..."
    if echo "$state_data" | jq -e '.agents' >/dev/null 2>&1; then
        echo "$state_data" | jq '.agents' > "$SWARM_DIR/agents.json"
        log_verbose "Agent configurations restored"
    fi

    # Restore task states
    info "Restoring task states..."
    if echo "$state_data" | jq -e '.tasks' >/dev/null 2>&1; then
        echo "$state_data" | jq '.tasks' > "$SWARM_DIR/tasks.json"
        log_verbose "Task states restored"
    fi

    # Restore session via hooks
    info "Restoring session context..."
    if npx claude-flow@alpha hooks session-restore --session-id "$session_id" 2>/dev/null; then
        log_verbose "Session context restored via hooks"
    else
        warning "Could not restore session via hooks"
    fi

    # Update metadata
    update_recovery_metadata "$session_id"

    success "Swarm state restored successfully from: $checkpoint_file"

    # Display recovery summary
    display_recovery_summary "$state_data"
}

restore_memory_database() {
    local state_data="$1"

    # Backup existing database
    if [[ -f "$SWARM_DIR/memory.db" ]]; then
        cp "$SWARM_DIR/memory.db" "$SWARM_DIR/memory.db.backup.$(date +%s)"
        log_verbose "Existing database backed up"
    fi

    # Initialize database
    sqlite3 "$SWARM_DIR/memory.db" "CREATE TABLE IF NOT EXISTS memory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
        value TEXT,
        namespace TEXT DEFAULT 'default',
        ttl INTEGER DEFAULT 0,
        timestamp INTEGER DEFAULT (strftime('%s', 'now'))
    );"

    # Restore memory entries
    echo "$state_data" | jq -c '.memory[]' | while IFS= read -r entry; do
        local key=$(echo "$entry" | jq -r '.key')
        local value=$(echo "$entry" | jq -r '.value')
        local namespace=$(echo "$entry" | jq -r '.namespace // "default"')
        local ttl=$(echo "$entry" | jq -r '.ttl // 0')
        local timestamp=$(echo "$entry" | jq -r '.timestamp')

        sqlite3 "$SWARM_DIR/memory.db" \
            "INSERT INTO memory (key, value, namespace, ttl, timestamp) VALUES (
                '$key',
                '$value',
                '$namespace',
                $ttl,
                $timestamp
            );" 2>/dev/null || warning "Failed to restore memory entry: $key"
    done

    local count=$(sqlite3 "$SWARM_DIR/memory.db" "SELECT COUNT(*) FROM memory;")
    log_verbose "Restored $count memory entries"
}

update_recovery_metadata() {
    local session_id="$1"
    local metadata_file="$RECOVERY_DIR/metadata/${session_id}.meta.json"

    if [[ -f "$metadata_file" ]]; then
        local updated_meta=$(jq \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '.recovery_count += 1 | .last_recovered = $timestamp | .status = "recovered"' \
            "$metadata_file")

        echo "$updated_meta" > "$metadata_file"
        log_verbose "Recovery metadata updated"
    fi
}

display_recovery_summary() {
    local state_data="$1"

    echo ""
    echo "=================================================="
    echo "        RECOVERY SUMMARY"
    echo "=================================================="
    echo ""
    echo "Session ID:    $(echo "$state_data" | jq -r '.metadata.session_id')"
    echo "Timestamp:     $(echo "$state_data" | jq -r '.metadata.timestamp')"
    echo "Hostname:      $(echo "$state_data" | jq -r '.metadata.hostname')"
    echo ""
    echo "Agents:        $(echo "$state_data" | jq '.agents | length // 0')"
    echo "Tasks:         $(echo "$state_data" | jq '.tasks | length // 0')"
    echo "Memory Entries: $(echo "$state_data" | jq '.memory | length // 0')"
    echo ""
    echo "=================================================="
    echo ""
}

# ============================================================================
# Checkpoint Management
# ============================================================================

find_latest_checkpoint() {
    local session_id="$1"

    # Find all checkpoints for session
    local checkpoints=$(find "$RECOVERY_DIR/checkpoints" -name "${session_id}_*.json" 2>/dev/null | sort -r)

    if [[ -z "$checkpoints" ]]; then
        echo ""
        return
    fi

    # Return most recent
    echo "$checkpoints" | head -n 1
}

list_checkpoints() {
    echo ""
    echo "=================================================="
    echo "        AVAILABLE CHECKPOINTS"
    echo "=================================================="
    echo ""

    if [[ ! -d "$RECOVERY_DIR/metadata" ]] || [[ -z "$(ls -A "$RECOVERY_DIR/metadata" 2>/dev/null)" ]]; then
        info "No checkpoints found"
        return
    fi

    printf "%-25s %-20s %-10s %-10s %s\n" "SESSION ID" "CREATED" "SIZE" "RECOVERIES" "STATUS"
    echo "--------------------------------------------------"

    for meta_file in "$RECOVERY_DIR/metadata"/*.meta.json; do
        if [[ -f "$meta_file" ]]; then
            local session_id=$(jq -r '.session_id' "$meta_file")
            local created=$(jq -r '.created_at' "$meta_file")
            local size=$(jq -r '.size_bytes' "$meta_file")
            local recoveries=$(jq -r '.recovery_count' "$meta_file")
            local status=$(jq -r '.status' "$meta_file")

            # Format size
            local size_human=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size}B")

            # Truncate session ID for display
            local session_display="${session_id:0:22}..."

            printf "%-25s %-20s %-10s %-10s %s\n" \
                "$session_display" \
                "${created:0:19}" \
                "$size_human" \
                "$recoveries" \
                "$status"
        fi
    done

    echo ""
}

cleanup_old_checkpoints() {
    local days="${1:-7}"

    info "Cleaning up checkpoints older than $days days..."

    local deleted_count=0
    local kept_count=0

    # Find old checkpoint files
    while IFS= read -r checkpoint_file; do
        if [[ -n "$checkpoint_file" ]] && [[ -f "$checkpoint_file" ]]; then
            rm -f "$checkpoint_file"
            ((deleted_count++))
            log_verbose "Deleted: $checkpoint_file"
        fi
    done < <(find "$RECOVERY_DIR/checkpoints" -name "*.json" -mtime "+${days}" 2>/dev/null)

    # Clean up orphaned metadata
    for meta_file in "$RECOVERY_DIR/metadata"/*.meta.json; do
        if [[ -f "$meta_file" ]]; then
            local checkpoint_file=$(jq -r '.checkpoint_file' "$meta_file")
            if [[ ! -f "$checkpoint_file" ]]; then
                rm -f "$meta_file"
                log_verbose "Deleted orphaned metadata: $meta_file"
            else
                ((kept_count++))
            fi
        fi
    done

    success "Cleanup complete: $deleted_count deleted, $kept_count kept"
}

# ============================================================================
# Auto-Save Functions
# ============================================================================

start_auto_save() {
    local interval="${1:-300}"
    local session_id="${2:-$(get_session_id "")}"

    # Check if auto-save is already running
    if [[ -f "$AUTO_SAVE_PID_FILE" ]]; then
        local pid=$(cat "$AUTO_SAVE_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            warning "Auto-save already running with PID: $pid"
            return
        fi
    fi

    info "Starting auto-save (interval: ${interval}s, session: $session_id)"

    # Start background process
    (
        while true; do
            sleep "$interval"

            log_verbose "Auto-save triggered for session: $session_id"

            local checkpoint_file="$RECOVERY_DIR/checkpoints/${session_id}_$(date +%Y%m%d_%H%M%S).json"

            if capture_swarm_state "$session_id" "$checkpoint_file"; then
                log_verbose "Auto-save completed: $checkpoint_file"
            else
                warning "Auto-save failed"
            fi

            # Cleanup old checkpoints to prevent disk space issues
            cleanup_old_checkpoints 7
        done
    ) &

    local pid=$!
    echo "$pid" > "$AUTO_SAVE_PID_FILE"

    success "Auto-save started with PID: $pid"
}

stop_auto_save() {
    if [[ ! -f "$AUTO_SAVE_PID_FILE" ]]; then
        warning "Auto-save is not running"
        return
    fi

    local pid=$(cat "$AUTO_SAVE_PID_FILE")

    if ps -p "$pid" > /dev/null 2>&1; then
        kill "$pid"
        rm -f "$AUTO_SAVE_PID_FILE"
        success "Auto-save stopped (PID: $pid)"
    else
        warning "Auto-save process not found (PID: $pid)"
        rm -f "$AUTO_SAVE_PID_FILE"
    fi
}

check_auto_save_status() {
    if [[ ! -f "$AUTO_SAVE_PID_FILE" ]]; then
        info "Auto-save: Not running"
        return 1
    fi

    local pid=$(cat "$AUTO_SAVE_PID_FILE")

    if ps -p "$pid" > /dev/null 2>&1; then
        success "Auto-save: Running (PID: $pid)"
        return 0
    else
        warning "Auto-save: Stale PID file found"
        rm -f "$AUTO_SAVE_PID_FILE"
        return 1
    fi
}

# ============================================================================
# Status and Reporting
# ============================================================================

show_status() {
    echo ""
    echo "=================================================="
    echo "        SWARM RECOVERY STATUS"
    echo "=================================================="
    echo ""

    # Recovery directory info
    echo "Recovery Directory: $RECOVERY_DIR"
    echo "Log Directory:      $LOG_DIR"
    echo "Swarm Directory:    $SWARM_DIR"
    echo ""

    # Storage usage
    local recovery_size=$(du -sh "$RECOVERY_DIR" 2>/dev/null | cut -f1 || echo "0")
    echo "Storage Used:       $recovery_size"
    echo ""

    # Checkpoint count
    local checkpoint_count=$(find "$RECOVERY_DIR/checkpoints" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    echo "Total Checkpoints:  $checkpoint_count"
    echo "Max Checkpoints:    $MAX_CHECKPOINTS"
    echo ""

    # Auto-save status
    check_auto_save_status
    echo ""

    # Recent checkpoints
    echo "Recent Checkpoints:"
    echo "--------------------------------------------------"
    if [[ -d "$RECOVERY_DIR/metadata" ]]; then
        local recent=$(find "$RECOVERY_DIR/metadata" -name "*.meta.json" -type f 2>/dev/null | sort -r | head -n 5)

        if [[ -n "$recent" ]]; then
            for meta_file in $recent; do
                local session_id=$(jq -r '.session_id' "$meta_file" 2>/dev/null || echo "unknown")
                local created=$(jq -r '.created_at' "$meta_file" 2>/dev/null || echo "unknown")
                echo "  - $session_id (${created:0:19})"
            done
        else
            echo "  No checkpoints found"
        fi
    else
        echo "  No checkpoints found"
    fi

    echo ""
    echo "=================================================="
    echo ""
}

# ============================================================================
# Main Command Handler
# ============================================================================

show_usage() {
    cat << EOF

Fueki Wallet Swarm Recovery System

Usage:
  $0 save [session-id]         Save current swarm state
  $0 restore [session-id]      Restore from crash
  $0 status                    Check recovery status
  $0 list                      List available checkpoints
  $0 cleanup [days]            Clean old checkpoints (default: 7 days)
  $0 auto-save start [interval] [session-id]
                               Start auto-save (default: 300s)
  $0 auto-save stop            Stop auto-save
  $0 auto-save status          Check auto-save status
  $0 help                      Show this help message

Environment Variables:
  RECOVERY_DIR     Directory for recovery data
  LOG_DIR          Directory for logs
  SWARM_DIR        Swarm state directory
  MAX_CHECKPOINTS  Maximum checkpoints to keep
  VERBOSE          Enable verbose logging (0/1)

Examples:
  # Save current state
  $0 save

  # Save with specific session ID
  $0 save swarm-12345

  # Restore from crash
  $0 restore swarm-12345

  # Enable verbose logging
  VERBOSE=1 $0 save

  # Start auto-save every 5 minutes
  $0 auto-save start 300

EOF
}

main() {
    # Setup
    setup_directories
    validate_environment

    # Parse command
    local command="${1:-help}"

    case "$command" in
        save)
            local session_id=$(get_session_id "${2:-}")
            local checkpoint_file="$RECOVERY_DIR/checkpoints/${session_id}_${TIMESTAMP}.json"

            info "Saving swarm state..."
            capture_swarm_state "$session_id" "$checkpoint_file"

            # Post-edit hook
            npx claude-flow@alpha hooks post-edit \
                --file "scripts/swarm-recovery.sh" \
                --memory-key "fueki-wallet/devops/recovery-checkpoint" \
                2>/dev/null || true
            ;;

        restore)
            local session_id="${2:-}"

            if [[ -z "$session_id" ]]; then
                die "Session ID required for restore. Use 'list' to see available sessions."
            fi

            info "Restoring swarm state..."
            restore_swarm_state "$session_id"
            ;;

        status)
            show_status
            ;;

        list)
            list_checkpoints
            ;;

        cleanup)
            local days="${2:-7}"
            cleanup_old_checkpoints "$days"
            ;;

        auto-save)
            local subcommand="${2:-status}"

            case "$subcommand" in
                start)
                    local interval="${3:-300}"
                    local session_id="${4:-$(get_session_id "")}"
                    start_auto_save "$interval" "$session_id"
                    ;;
                stop)
                    stop_auto_save
                    ;;
                status)
                    check_auto_save_status
                    ;;
                *)
                    die "Unknown auto-save command: $subcommand"
                    ;;
            esac
            ;;

        help|--help|-h)
            show_usage
            exit 0
            ;;

        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# ============================================================================
# Script Entry Point
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
