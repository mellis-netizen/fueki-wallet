# Fueki Wallet Swarm Recovery System

## Overview

The Swarm Recovery System provides comprehensive crash recovery and state persistence for Claude Flow swarms executing on the Fueki Mobile Wallet project. It enables automatic checkpointing, state restoration, and continuous operation even after system failures.

## Features

### 1. State Persistence
- **Complete Swarm State**: Captures all agent configurations, task states, and execution context
- **Memory Database**: Exports and restores the entire ReasoningBank/memory database
- **File System Snapshots**: Tracks git status and changes for rollback capability
- **Environment Capture**: Saves relevant environment variables (sanitized)
- **Process Information**: Records active swarm processes

### 2. Recovery Logic
- **Crash Detection**: Identifies incomplete or crashed swarm executions
- **State Restoration**: Fully restores swarm topology, agents, and context
- **Task Resumption**: Continues execution from last checkpoint
- **Memory Recovery**: Restores all coordination memory and context
- **Automatic Rollback**: Can revert to any previous checkpoint

### 3. Checkpoint System
- **Auto-Save**: Periodic checkpoints during execution (configurable interval)
- **Versioned Snapshots**: Maintains multiple checkpoint versions
- **Metadata Tracking**: Stores checkpoint information and recovery statistics
- **Automatic Cleanup**: Removes old checkpoints based on age or count
- **Storage Management**: Prevents disk space issues with intelligent rotation

### 4. Integration
- **Claude Flow Hooks**: Seamless integration with pre/post-task hooks
- **MCP Memory System**: Direct access to swarm coordination memory
- **Session Management**: Tracks and restores session context
- **Event Logging**: Comprehensive logging for debugging and auditing

## Installation

### Prerequisites

```bash
# Required tools
brew install jq sqlite3  # macOS
apt-get install jq sqlite3  # Linux

# Node.js and npm (for npx)
node --version  # Should be v18+
npm --version
```

### Setup

The recovery system is ready to use out of the box:

```bash
# Make script executable (already done)
chmod +x scripts/swarm-recovery.sh

# Verify installation
./scripts/swarm-recovery.sh status
```

## Usage

### Basic Commands

```bash
# Save current swarm state
./scripts/swarm-recovery.sh save

# Save with specific session ID
./scripts/swarm-recovery.sh save swarm-12345

# Restore from crash
./scripts/swarm-recovery.sh restore swarm-12345

# Check recovery status
./scripts/swarm-recovery.sh status

# List all checkpoints
./scripts/swarm-recovery.sh list

# Clean old checkpoints (older than 7 days)
./scripts/swarm-recovery.sh cleanup 7
```

### Auto-Save Mode

Start automatic checkpointing during long-running swarm operations:

```bash
# Start auto-save every 5 minutes (300 seconds)
./scripts/swarm-recovery.sh auto-save start 300

# Start with custom interval and session ID
./scripts/swarm-recovery.sh auto-save start 180 swarm-custom-id

# Check auto-save status
./scripts/swarm-recovery.sh auto-save status

# Stop auto-save
./scripts/swarm-recovery.sh auto-save stop
```

### Verbose Mode

Enable detailed logging for debugging:

```bash
VERBOSE=1 ./scripts/swarm-recovery.sh save
VERBOSE=1 ./scripts/swarm-recovery.sh restore swarm-12345
```

## Configuration

### Environment Variables

```bash
# Recovery data directory (default: ./scripts/recovery-data)
export RECOVERY_DIR=/path/to/recovery

# Log directory (default: ./scripts/logs)
export LOG_DIR=/path/to/logs

# Swarm state directory (default: ./.swarm)
export SWARM_DIR=/path/to/.swarm

# Maximum checkpoints to keep (default: 20)
export MAX_CHECKPOINTS=50

# Enable verbose logging (default: 0)
export VERBOSE=1
```

### Customize in Scripts

Add to your workflow scripts:

```bash
#!/bin/bash

# Configure recovery system
export RECOVERY_DIR="/data/fueki-recovery"
export MAX_CHECKPOINTS=30
export VERBOSE=1

# Start auto-save before swarm execution
./scripts/swarm-recovery.sh auto-save start 300 swarm-deploy-$(date +%s)

# Your swarm execution here
npx claude-flow@alpha swarm init hierarchical
npx claude-flow@alpha agent spawn researcher
# ... more swarm commands ...

# Save final state
./scripts/swarm-recovery.sh save swarm-deploy-$(date +%s)

# Stop auto-save
./scripts/swarm-recovery.sh auto-save stop
```

## Workflow Integration

### 1. Development Workflow

```bash
# Before starting development swarm
SESSION_ID="dev-$(date +%Y%m%d)"
./scripts/swarm-recovery.sh auto-save start 300 "$SESSION_ID"

# Execute swarm
npx claude-flow@alpha swarm init mesh --max-agents 5
npx claude-flow@alpha task orchestrate "Implement wallet features"

# If crash occurs, restore
./scripts/swarm-recovery.sh restore "$SESSION_ID"

# When done, save and cleanup
./scripts/swarm-recovery.sh save "$SESSION_ID"
./scripts/swarm-recovery.sh auto-save stop
```

### 2. CI/CD Integration

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    steps:
      - name: Setup Recovery
        run: |
          export SESSION_ID="ci-${GITHUB_RUN_ID}"
          ./scripts/swarm-recovery.sh auto-save start 180 "$SESSION_ID"

      - name: Deploy with Swarm
        run: |
          npx claude-flow@alpha swarm init hierarchical
          npx claude-flow@alpha task orchestrate "Deploy application"

      - name: Save State on Failure
        if: failure()
        run: |
          export SESSION_ID="ci-${GITHUB_RUN_ID}"
          ./scripts/swarm-recovery.sh save "$SESSION_ID"

      - name: Cleanup
        if: always()
        run: |
          ./scripts/swarm-recovery.sh auto-save stop
          ./scripts/swarm-recovery.sh cleanup 3
```

### 3. Production Monitoring

```bash
#!/bin/bash
# production-monitor.sh

SESSION_ID="prod-$(date +%Y%m%d-%H%M%S)"

# Start with aggressive auto-save for production
./scripts/swarm-recovery.sh auto-save start 60 "$SESSION_ID"

# Health check loop
while true; do
  if ! pgrep -f "claude-flow" > /dev/null; then
    echo "Swarm crashed! Initiating recovery..."
    ./scripts/swarm-recovery.sh restore "$SESSION_ID"

    # Restart swarm
    npx claude-flow@alpha hooks session-restore --session-id "$SESSION_ID"
  fi

  sleep 30
done
```

## Recovery Scenarios

### Scenario 1: System Crash During Development

```bash
# System crashed while swarm was running
# Check available checkpoints
./scripts/swarm-recovery.sh list

# Restore most recent checkpoint
./scripts/swarm-recovery.sh restore swarm-20251021-143022

# Verify restoration
npx claude-flow@alpha swarm status

# Continue work
npx claude-flow@alpha task status
```

### Scenario 2: Task Failure Recovery

```bash
# Task failed partway through
SESSION_ID="task-recovery-$(date +%s)"

# Restore last known good state
./scripts/swarm-recovery.sh restore "$SESSION_ID"

# Review what was completed
npx claude-flow@alpha memory search "completed"

# Resume from checkpoint
npx claude-flow@alpha task orchestrate "Continue from checkpoint"
```

### Scenario 3: Multi-Day Project Continuity

```bash
# Day 1: Start project with auto-save
SESSION_ID="project-wallet-v2"
./scripts/swarm-recovery.sh auto-save start 300 "$SESSION_ID"
# ... work ...
./scripts/swarm-recovery.sh save "$SESSION_ID"

# Day 2: Resume from yesterday
./scripts/swarm-recovery.sh restore "$SESSION_ID"
./scripts/swarm-recovery.sh auto-save start 300 "$SESSION_ID"
# ... continue work ...

# Day 3+: Same pattern
./scripts/swarm-recovery.sh restore "$SESSION_ID"
```

## Data Structure

### Checkpoint File Format

```json
{
  "metadata": {
    "session_id": "swarm-1729543200-12345",
    "timestamp": "2025-10-21T14:30:00Z",
    "hostname": "dev-machine",
    "project_root": "/Users/computer/Fueki-Mobile-Wallet",
    "version": "1.0.0"
  },
  "swarm_status": {
    "topology": "hierarchical",
    "agents": [...],
    "tasks": [...]
  },
  "memory": [
    {
      "key": "swarm/coordinator/status",
      "value": "{\"status\":\"active\"}",
      "namespace": "coordination",
      "ttl": 3600,
      "timestamp": 1729543200
    }
  ],
  "agents": {
    "coordinator": {...},
    "researcher": {...},
    "coder": {...}
  },
  "tasks": {
    "task-001": {
      "status": "completed",
      "result": "..."
    }
  },
  "filesystem": {
    "git_status": "...",
    "git_diff": "..."
  },
  "environment": "NODE_ENV=***\nANTHROPIC_API_KEY=***",
  "processes": "..."
}
```

### Metadata File Format

```json
{
  "session_id": "swarm-1729543200-12345",
  "checkpoint_file": "/path/to/checkpoint.json",
  "created_at": "2025-10-21T14:30:00Z",
  "size_bytes": 245678,
  "recovery_count": 2,
  "last_recovered": "2025-10-21T15:45:00Z",
  "status": "recovered"
}
```

## Directory Structure

```
scripts/
├── swarm-recovery.sh          # Main recovery script
├── recovery-data/             # Recovery data directory
│   ├── checkpoints/          # State snapshots
│   │   ├── swarm-xxx_20251021_143022.json
│   │   └── swarm-xxx_20251021_144530.json
│   ├── snapshots/            # File system snapshots
│   └── metadata/             # Checkpoint metadata
│       ├── swarm-xxx.meta.json
│       └── swarm-yyy.meta.json
└── logs/                      # Recovery logs
    ├── recovery_20251021_143022.log
    └── recovery_20251021_144530.log
```

## Best Practices

### 1. Regular Checkpointing
- Use auto-save for long-running operations
- Save manually at logical breakpoints
- Keep 5-10 recent checkpoints for quick access

### 2. Session Naming
- Use descriptive session IDs: `deploy-staging-20251021`
- Include date/time for tracking: `dev-$(date +%Y%m%d-%H%M%S)`
- Tag by purpose: `bugfix-auth`, `feature-wallet`

### 3. Storage Management
- Clean old checkpoints regularly (weekly)
- Monitor disk usage with `status` command
- Archive important checkpoints externally

### 4. Recovery Testing
- Test recovery process regularly
- Verify restored state completeness
- Document recovery procedures for team

### 5. Production Use
- Use aggressive auto-save intervals (60s)
- Monitor recovery logs for issues
- Set up alerts for checkpoint failures
- Keep multiple checkpoint generations

## Troubleshooting

### Issue: "Command not found: jq"

```bash
# Install jq
brew install jq  # macOS
apt-get install jq  # Linux
```

### Issue: "No checkpoint found"

```bash
# List available checkpoints
./scripts/swarm-recovery.sh list

# Check if session ID is correct
# Session IDs are case-sensitive
```

### Issue: "Memory database restore failed"

```bash
# Check if .swarm directory exists
ls -la .swarm/

# Verify database file permissions
chmod 644 .swarm/memory.db

# Try manual restore
sqlite3 .swarm/memory.db ".schema"
```

### Issue: "Auto-save not working"

```bash
# Check if already running
./scripts/swarm-recovery.sh auto-save status

# Stop stale process
./scripts/swarm-recovery.sh auto-save stop

# Restart with verbose logging
VERBOSE=1 ./scripts/swarm-recovery.sh auto-save start 300
```

### Issue: "Checkpoint file corrupted"

```bash
# Validate JSON
jq '.' scripts/recovery-data/checkpoints/swarm-xxx.json

# Try previous checkpoint
./scripts/swarm-recovery.sh list
./scripts/swarm-recovery.sh restore swarm-xxx-previous
```

## Performance Considerations

### Checkpoint Size
- Typical checkpoint: 100KB - 5MB
- Large projects: 10MB - 50MB
- Includes: state + memory + metadata

### Auto-Save Overhead
- CPU: < 5% during save
- I/O: Brief spike during write
- Recommended interval: 300s (5 min)
- Aggressive interval: 60s (1 min)

### Storage Requirements
- 20 checkpoints: ~100MB - 1GB
- 1 month of data: ~5GB - 20GB
- Regular cleanup: Keeps under 1GB

## Security Considerations

### Sensitive Data
- API keys are sanitized in environment capture
- Git diffs may contain sensitive code
- Store recovery data in secure location
- Encrypt backups if storing remotely

### Access Control
```bash
# Restrict access to recovery directory
chmod 700 scripts/recovery-data/
chmod 600 scripts/recovery-data/checkpoints/*
```

### Backup Strategy
```bash
# Regular backup of recovery data
tar -czf recovery-backup-$(date +%Y%m%d).tar.gz scripts/recovery-data/

# Store encrypted backup
gpg -c recovery-backup-$(date +%Y%m%d).tar.gz
```

## Advanced Usage

### Custom Checkpoint Hooks

Create `scripts/custom-checkpoint.sh`:

```bash
#!/bin/bash
# Custom checkpoint with additional data

SESSION_ID="$1"

# Save base checkpoint
./scripts/swarm-recovery.sh save "$SESSION_ID"

# Add custom data
CHECKPOINT_FILE=$(find scripts/recovery-data/checkpoints -name "${SESSION_ID}_*.json" | tail -n 1)

# Enhance with custom data
jq '. + {
  custom: {
    deployment_version: "'$(git describe --tags)'",
    environment: "'${ENVIRONMENT}'",
    metrics: {...}
  }
}' "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp"

mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"
```

### Integration with Monitoring

```bash
#!/bin/bash
# Send checkpoint metrics to monitoring system

CHECKPOINT_SIZE=$(stat -f%z "$CHECKPOINT_FILE")
AGENT_COUNT=$(jq '.agents | length' "$CHECKPOINT_FILE")

# Send to monitoring (example: StatsD)
echo "swarm.checkpoint.size:${CHECKPOINT_SIZE}|g" | nc -u -w1 localhost 8125
echo "swarm.checkpoint.agents:${AGENT_COUNT}|g" | nc -u -w1 localhost 8125
```

## Support

- **Documentation**: `/scripts/README-RECOVERY.md`
- **Logs**: `scripts/logs/recovery_*.log`
- **Issues**: Check logs for error details
- **Community**: Share recovery patterns with team

## License

Part of Fueki Mobile Wallet project. See main project LICENSE.

---

**Version**: 1.0.0
**Last Updated**: 2025-10-21
**Maintained By**: Fueki DevOps Team
