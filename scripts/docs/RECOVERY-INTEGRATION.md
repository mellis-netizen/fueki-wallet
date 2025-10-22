# Recovery System Integration Guide

## Quick Start

### Installation Check

```bash
# Verify recovery system is ready
./scripts/swarm-recovery.sh status

# Should show:
# ✓ Recovery directory exists
# ✓ Required tools installed (jq, sqlite3)
# ✓ No errors
```

### First Use

```bash
# 1. Save current swarm state
./scripts/swarm-recovery.sh save my-session

# 2. List checkpoints
./scripts/swarm-recovery.sh list

# 3. Restore if needed
./scripts/swarm-recovery.sh restore my-session
```

## Integration Patterns

### Pattern 1: Wrap Swarm Execution

Create a wrapper script that automatically handles recovery:

```bash
#!/bin/bash
# run-with-recovery.sh

set -euo pipefail

SESSION_ID="${1:-swarm-$(date +%s)}"
shift

# Start auto-save
./scripts/swarm-recovery.sh auto-save start 300 "$SESSION_ID"

# Trap to ensure cleanup
trap './scripts/swarm-recovery.sh auto-save stop' EXIT

# Execute swarm command
echo "Running: $@"
"$@"

# Save final state
./scripts/swarm-recovery.sh save "$SESSION_ID"
```

**Usage:**
```bash
./run-with-recovery.sh deploy-session npx claude-flow@alpha swarm init hierarchical
```

### Pattern 2: Task-Based Checkpoints

Save state at logical task boundaries:

```bash
#!/bin/bash
# task-workflow-with-recovery.sh

SESSION_ID="workflow-$(date +%Y%m%d)"

# Phase 1: Research
echo "Phase 1: Research"
npx claude-flow@alpha task orchestrate "Research requirements"
./scripts/swarm-recovery.sh save "${SESSION_ID}-phase1"

# Phase 2: Design
echo "Phase 2: Design"
npx claude-flow@alpha task orchestrate "Design architecture"
./scripts/swarm-recovery.sh save "${SESSION_ID}-phase2"

# Phase 3: Implementation
echo "Phase 3: Implementation"
npx claude-flow@alpha task orchestrate "Implement features"
./scripts/swarm-recovery.sh save "${SESSION_ID}-phase3"

# Phase 4: Testing
echo "Phase 4: Testing"
npx claude-flow@alpha task orchestrate "Run tests"
./scripts/swarm-recovery.sh save "${SESSION_ID}-phase4"
```

### Pattern 3: CI/CD Integration

#### GitHub Actions

```yaml
# .github/workflows/swarm-deploy.yml
name: Swarm Deployment with Recovery

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq sqlite3

      - name: Setup recovery system
        run: |
          export SESSION_ID="ci-${GITHUB_RUN_ID}"
          ./scripts/swarm-recovery.sh auto-save start 180 "$SESSION_ID"

      - name: Deploy with swarm
        id: deploy
        run: |
          export SESSION_ID="ci-${GITHUB_RUN_ID}"
          npx claude-flow@alpha swarm init hierarchical
          npx claude-flow@alpha task orchestrate "Deploy application"

      - name: Save state on success
        if: success()
        run: |
          export SESSION_ID="ci-${GITHUB_RUN_ID}"
          ./scripts/swarm-recovery.sh save "$SESSION_ID"

      - name: Save state on failure
        if: failure()
        run: |
          export SESSION_ID="ci-${GITHUB_RUN_ID}"
          ./scripts/swarm-recovery.sh save "${SESSION_ID}-failed"

      - name: Upload recovery data
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: recovery-checkpoint
          path: scripts/recovery-data/

      - name: Cleanup
        if: always()
        run: |
          ./scripts/swarm-recovery.sh auto-save stop
          ./scripts/swarm-recovery.sh cleanup 3
```

#### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - deploy

swarm-deploy:
  stage: deploy
  script:
    - apt-get update && apt-get install -y jq sqlite3
    - export SESSION_ID="ci-${CI_PIPELINE_ID}"
    - ./scripts/swarm-recovery.sh auto-save start 180 "$SESSION_ID"
    - npx claude-flow@alpha swarm init hierarchical
    - npx claude-flow@alpha task orchestrate "Deploy application"
    - ./scripts/swarm-recovery.sh save "$SESSION_ID"
  after_script:
    - ./scripts/swarm-recovery.sh auto-save stop
    - ./scripts/swarm-recovery.sh cleanup 3
  artifacts:
    when: always
    paths:
      - scripts/recovery-data/
    expire_in: 7 days
```

### Pattern 4: Production Monitoring

Create a monitoring daemon that watches for crashes:

```bash
#!/bin/bash
# swarm-monitor.sh

set -euo pipefail

SESSION_ID="${1:-prod-$(date +%Y%m%d)}"
CHECK_INTERVAL="${2:-30}"
MAX_RETRIES="${3:-3}"

echo "Starting swarm monitor for session: $SESSION_ID"
echo "Check interval: ${CHECK_INTERVAL}s"
echo "Max retries: $MAX_RETRIES"

retries=0

# Start auto-save
./scripts/swarm-recovery.sh auto-save start 60 "$SESSION_ID"

while true; do
    # Check if swarm is running
    if ! pgrep -f "claude-flow" > /dev/null; then
        echo "⚠️  Swarm not detected!"

        if [[ $retries -lt $MAX_RETRIES ]]; then
            retries=$((retries + 1))
            echo "Attempt $retries/$MAX_RETRIES: Recovering swarm..."

            # Restore last checkpoint
            if ./scripts/swarm-recovery.sh restore "$SESSION_ID"; then
                echo "✅ Recovery successful, restarting swarm..."

                # Restart swarm (customize for your use case)
                npx claude-flow@alpha hooks session-restore --session-id "$SESSION_ID"

                # Reset retry counter on success
                retries=0
            else
                echo "❌ Recovery failed"
            fi
        else
            echo "❌ Max retries reached. Manual intervention required."
            ./scripts/swarm-recovery.sh save "${SESSION_ID}-failed-$(date +%s)"
            exit 1
        fi
    else
        echo "✅ Swarm running normally ($(date))"
        retries=0
    fi

    sleep "$CHECK_INTERVAL"
done
```

### Pattern 5: Development Workflow

Integrate with your development scripts:

```bash
#!/bin/bash
# dev-workflow.sh

set -euo pipefail

# Configuration
SESSION_ID="dev-$(whoami)-$(date +%Y%m%d)"
FEATURE="${1:-default}"

echo "=================================================="
echo "  Fueki Wallet Development with Recovery"
echo "=================================================="
echo ""
echo "Session ID: $SESSION_ID"
echo "Feature:    $FEATURE"
echo ""

# Check for existing checkpoint
if ./scripts/swarm-recovery.sh list | grep -q "$SESSION_ID"; then
    read -p "Found existing session. Restore? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo "Restoring session..."
        ./scripts/swarm-recovery.sh restore "$SESSION_ID"
    fi
fi

# Start auto-save for development
echo "Starting auto-save (5 minute intervals)..."
./scripts/swarm-recovery.sh auto-save start 300 "$SESSION_ID"

# Trap to ensure cleanup on exit
trap 'cleanup' EXIT

cleanup() {
    echo ""
    echo "Cleaning up..."
    ./scripts/swarm-recovery.sh save "$SESSION_ID"
    ./scripts/swarm-recovery.sh auto-save stop
    echo "Session saved: $SESSION_ID"
}

# Run development swarm
echo ""
echo "Starting development swarm..."
npx claude-flow@alpha swarm init mesh --max-agents 5

# Execute feature development
echo ""
echo "Working on feature: $FEATURE"
npx claude-flow@alpha task orchestrate "Develop feature: $FEATURE"

echo ""
echo "✅ Development complete!"
```

## Hook Integration

### Pre-Task Hook Integration

Add to your task scripts:

```bash
#!/bin/bash
# task-with-hooks.sh

TASK_ID="task-$(date +%s)"
SESSION_ID="swarm-$(date +%Y%m%d)"

# Pre-task: Initialize recovery
npx claude-flow@alpha hooks pre-task --description "Execute task with recovery"

# Save initial state
./scripts/swarm-recovery.sh save "$SESSION_ID"

# Execute task
npx claude-flow@alpha task orchestrate "Your task here"

# Post-task: Save completion state
npx claude-flow@alpha hooks post-task --task-id "$TASK_ID"
./scripts/swarm-recovery.sh save "${SESSION_ID}-completed"
```

### Post-Edit Hook Integration

Track file changes with recovery:

```bash
#!/bin/bash
# edit-with-recovery.sh

SESSION_ID="edit-$(date +%s)"
FILE="$1"

# Pre-edit checkpoint
./scripts/swarm-recovery.sh save "pre-edit-${SESSION_ID}"

# Edit file (your editor here)
$EDITOR "$FILE"

# Post-edit hooks
npx claude-flow@alpha hooks post-edit \
    --file "$FILE" \
    --memory-key "edits/${SESSION_ID}"

# Save post-edit state
./scripts/swarm-recovery.sh save "post-edit-${SESSION_ID}"
```

## API Usage

### Programmatic Integration

Use the recovery system from Node.js:

```javascript
// recovery-api.js
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

class RecoverySystem {
  constructor(scriptPath = './scripts/swarm-recovery.sh') {
    this.scriptPath = scriptPath;
  }

  async save(sessionId) {
    const { stdout, stderr } = await execPromise(
      `${this.scriptPath} save ${sessionId}`
    );
    return { success: !stderr.includes('Error'), output: stdout };
  }

  async restore(sessionId) {
    const { stdout, stderr } = await execPromise(
      `${this.scriptPath} restore ${sessionId}`
    );
    return { success: !stderr.includes('Error'), output: stdout };
  }

  async status() {
    const { stdout } = await execPromise(`${this.scriptPath} status`);
    return stdout;
  }

  async list() {
    const { stdout } = await execPromise(`${this.scriptPath} list`);
    return stdout;
  }

  async startAutoSave(interval = 300, sessionId = null) {
    const cmd = sessionId
      ? `${this.scriptPath} auto-save start ${interval} ${sessionId}`
      : `${this.scriptPath} auto-save start ${interval}`;

    await execPromise(cmd);
  }

  async stopAutoSave() {
    await execPromise(`${this.scriptPath} auto-save stop`);
  }
}

// Usage
async function main() {
  const recovery = new RecoverySystem();

  const sessionId = `node-app-${Date.now()}`;

  // Start auto-save
  await recovery.startAutoSave(300, sessionId);

  try {
    // Your swarm operations here
    console.log('Running swarm operations...');

    // Save final state
    await recovery.save(sessionId);
  } catch (error) {
    console.error('Error:', error);

    // Attempt recovery
    await recovery.restore(sessionId);
  } finally {
    await recovery.stopAutoSave();
  }
}

module.exports = RecoverySystem;
```

### Python Integration

```python
#!/usr/bin/env python3
# recovery_api.py

import subprocess
import json
from typing import Optional, Dict

class RecoverySystem:
    def __init__(self, script_path: str = './scripts/swarm-recovery.sh'):
        self.script_path = script_path

    def _run_command(self, *args) -> Dict[str, any]:
        """Run recovery script command."""
        cmd = [self.script_path] + list(args)
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True
        )

        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr
        }

    def save(self, session_id: str) -> Dict[str, any]:
        """Save swarm state."""
        return self._run_command('save', session_id)

    def restore(self, session_id: str) -> Dict[str, any]:
        """Restore swarm state."""
        return self._run_command('restore', session_id)

    def status(self) -> str:
        """Get recovery system status."""
        result = self._run_command('status')
        return result['stdout']

    def list_checkpoints(self) -> str:
        """List available checkpoints."""
        result = self._run_command('list')
        return result['stdout']

    def start_auto_save(self, interval: int = 300, session_id: Optional[str] = None):
        """Start auto-save."""
        if session_id:
            return self._run_command('auto-save', 'start', str(interval), session_id)
        return self._run_command('auto-save', 'start', str(interval))

    def stop_auto_save(self):
        """Stop auto-save."""
        return self._run_command('auto-save', 'stop')

# Usage
if __name__ == '__main__':
    recovery = RecoverySystem()

    session_id = f'python-app-{int(time.time())}'

    # Start auto-save
    recovery.start_auto_save(300, session_id)

    try:
        # Your swarm operations here
        print('Running swarm operations...')

        # Save final state
        recovery.save(session_id)
    except Exception as e:
        print(f'Error: {e}')

        # Attempt recovery
        recovery.restore(session_id)
    finally:
        recovery.stop_auto_save()
```

## Best Practices

### 1. Session Naming Convention

```bash
# Use descriptive, hierarchical session IDs
SESSION_ID="project-phase-date-user"

# Examples:
wallet-dev-20251021-john
wallet-prod-deploy-20251021-143000
wallet-bugfix-auth-20251021
wallet-feature-payments-20251021
```

### 2. Checkpoint Frequency

```bash
# Development: 5-10 minutes
./scripts/swarm-recovery.sh auto-save start 300

# Staging: 2-3 minutes
./scripts/swarm-recovery.sh auto-save start 180

# Production: 1 minute
./scripts/swarm-recovery.sh auto-save start 60

# CI/CD: 3 minutes
./scripts/swarm-recovery.sh auto-save start 180
```

### 3. Storage Management

```bash
# Weekly cleanup job
0 2 * * 0 /path/to/scripts/swarm-recovery.sh cleanup 7

# Monthly archive
0 3 1 * * tar -czf recovery-archive-$(date +%Y%m).tar.gz scripts/recovery-data/
```

### 4. Monitoring Integration

```bash
# Send metrics to monitoring system
CHECKPOINT_SIZE=$(stat -f%z "$CHECKPOINT_FILE" 2>/dev/null || stat -c%s "$CHECKPOINT_FILE")
echo "swarm.checkpoint.size:${CHECKPOINT_SIZE}|g" | nc -u -w1 statsd-host 8125

# Alert on recovery failures
if ! ./scripts/swarm-recovery.sh restore "$SESSION_ID" 2>&1 | grep -q "successfully"; then
    curl -X POST https://alerts.company.com/webhook \
        -d '{"alert":"Recovery failed","session":"'$SESSION_ID'"}'
fi
```

## Troubleshooting Integration Issues

### Issue: Recovery script not found in CI

**Solution:**
```yaml
# Ensure script is executable in CI
- name: Setup recovery
  run: |
    chmod +x scripts/swarm-recovery.sh
    ./scripts/swarm-recovery.sh status
```

### Issue: Missing dependencies in container

**Solution:**
```dockerfile
# Add to Dockerfile
RUN apt-get update && apt-get install -y \
    jq \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*
```

### Issue: Permission denied on checkpoint files

**Solution:**
```bash
# Fix permissions
chmod -R 755 scripts/recovery-data/
chmod 644 scripts/recovery-data/checkpoints/*
```

### Issue: Session restore doesn't resume work

**Solution:**
```bash
# After restore, reinitialize swarm with restored memory
./scripts/swarm-recovery.sh restore "$SESSION_ID"
npx claude-flow@alpha hooks session-restore --session-id "$SESSION_ID"
```

## Advanced Integration

### Custom Checkpoint Data

Extend checkpoints with custom data:

```bash
#!/bin/bash
# custom-checkpoint.sh

SESSION_ID="$1"
CUSTOM_DATA="$2"

# Save base checkpoint
./scripts/swarm-recovery.sh save "$SESSION_ID"

# Find the checkpoint file
CHECKPOINT_FILE=$(find scripts/recovery-data/checkpoints \
    -name "${SESSION_ID}_*.json" | tail -n 1)

# Add custom data
jq --arg data "$CUSTOM_DATA" \
    '. + {custom: $data}' \
    "$CHECKPOINT_FILE" > "${CHECKPOINT_FILE}.tmp"

mv "${CHECKPOINT_FILE}.tmp" "$CHECKPOINT_FILE"
```

### Health Check Integration

```bash
#!/bin/bash
# health-check.sh

# Check recovery system health
HEALTH_STATUS="healthy"

# Check disk space
DISK_USAGE=$(df -h scripts/recovery-data/ | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 80 ]]; then
    HEALTH_STATUS="degraded"
    echo "⚠️  High disk usage: ${DISK_USAGE}%"
fi

# Check auto-save status
if ./scripts/swarm-recovery.sh auto-save status | grep -q "Not running"; then
    HEALTH_STATUS="degraded"
    echo "⚠️  Auto-save not running"
fi

# Return health status
echo "$HEALTH_STATUS"
exit 0
```

## Resources

- Main Documentation: `/scripts/README-RECOVERY.md`
- Example Scripts: `/scripts/examples/recovery-example.sh`
- Recovery Script: `/scripts/swarm-recovery.sh`
- Logs Directory: `/scripts/logs/`

---

**Version**: 1.0.0
**Last Updated**: 2025-10-21
