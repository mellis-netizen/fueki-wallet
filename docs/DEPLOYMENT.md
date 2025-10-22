# Fueki Mobile Wallet - Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Build Process](#build-process)
4. [Environment Configuration](#environment-configuration)
5. [Deployment Strategies](#deployment-strategies)
6. [Monitoring and Maintenance](#monitoring-and-maintenance)
7. [Rollback Procedures](#rollback-procedures)
8. [Post-Deployment Verification](#post-deployment-verification)

---

## Overview

This guide covers the deployment process for Fueki Mobile Wallet, including build procedures, environment configuration, and deployment strategies for various platforms.

### Deployment Targets

- **iOS**: App Store (production), TestFlight (beta)
- **Android**: Google Play Store (production), Firebase App Distribution (beta)
- **Development**: Local testing, internal distribution

---

## Pre-Deployment Checklist

### Code Quality

- [ ] All tests passing (`npm test`)
- [ ] Test coverage > 80% (`npm run test:coverage`)
- [ ] No TypeScript errors (`npx tsc --noEmit`)
- [ ] No ESLint warnings (`npm run lint`)
- [ ] Security audit passed (`npm audit`)
- [ ] Dependencies updated
- [ ] Code review completed
- [ ] Documentation updated

### Security

- [ ] No hardcoded secrets or API keys
- [ ] Environment variables configured
- [ ] SSL/TLS certificates valid
- [ ] Security tests passed
- [ ] Penetration testing completed
- [ ] Third-party security audit (if applicable)
- [ ] Key management system tested
- [ ] Biometric authentication tested

### Functionality

- [ ] All features tested on target devices
- [ ] Network connectivity tested (mainnet/testnet)
- [ ] Transaction signing verified
- [ ] Backup/recovery tested
- [ ] Performance benchmarks met
- [ ] Memory leaks checked
- [ ] Battery usage acceptable
- [ ] Offline mode tested

### Compliance

- [ ] App Store guidelines reviewed
- [ ] Play Store policies reviewed
- [ ] Privacy policy updated
- [ ] Terms of service updated
- [ ] GDPR compliance verified (if applicable)
- [ ] Legal review completed

---

## Build Process

### Production Build

#### 1. Prepare Environment

```bash
# Clean previous builds
npm run clean
rm -rf node_modules package-lock.json

# Install dependencies
npm ci

# Verify installation
npm list --depth=0
```

#### 2. Run Quality Checks

```bash
# Run all tests
npm test

# Generate coverage report
npm run test:coverage

# Type checking
npx tsc --noEmit

# Linting
npm run lint

# Security audit
npm audit
```

#### 3. Build Application

```bash
# Set production environment
export NODE_ENV=production

# Build TypeScript
npm run build

# Verify build
ls -la dist/
```

#### 4. Generate Build Artifacts

```bash
# Create distribution package
npm pack

# Verify package contents
tar -tzf fueki-mobile-wallet-1.0.0.tgz
```

### Version Management

#### Semantic Versioning

Follow semantic versioning (MAJOR.MINOR.PATCH):

```bash
# Patch release (bug fixes)
npm version patch

# Minor release (new features, backward compatible)
npm version minor

# Major release (breaking changes)
npm version major
```

#### Version Tagging

```bash
# Tag release
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push tags
git push origin v1.0.0
```

### Build Configurations

#### Development Build

```bash
# .env.development
NODE_ENV=development
BITCOIN_NETWORK=testnet
ETHEREUM_NETWORK=sepolia
LOG_LEVEL=debug
ENABLE_DEV_TOOLS=true
```

#### Staging Build

```bash
# .env.staging
NODE_ENV=staging
BITCOIN_NETWORK=testnet
ETHEREUM_NETWORK=sepolia
LOG_LEVEL=info
ENABLE_DEV_TOOLS=false
```

#### Production Build

```bash
# .env.production
NODE_ENV=production
BITCOIN_NETWORK=mainnet
ETHEREUM_NETWORK=mainnet
LOG_LEVEL=error
ENABLE_DEV_TOOLS=false
```

---

## Environment Configuration

### Network Endpoints

#### Bitcoin Endpoints

**Mainnet**:
```typescript
const BITCOIN_MAINNET_ENDPOINTS = [
  'electrum.blockstream.info:50002',
  'bitcoin.aranguren.org:50002',
  'electrum3.bluewallet.io:50002',
  'electrum.emzy.de:50002'
];
```

**Testnet**:
```typescript
const BITCOIN_TESTNET_ENDPOINTS = [
  'testnet.aranguren.org:51002',
  'electrum.blockstream.info:60002',
  'testnet.qtornado.com:51002'
];
```

#### Ethereum Endpoints

**Mainnet**:
```typescript
const ETHEREUM_MAINNET_ENDPOINTS = [
  'https://eth.llamarpc.com',
  'https://rpc.ankr.com/eth',
  'https://ethereum.publicnode.com',
  'https://cloudflare-eth.com'
];
```

**Sepolia (Testnet)**:
```typescript
const ETHEREUM_SEPOLIA_ENDPOINTS = [
  'https://rpc.sepolia.org',
  'https://eth-sepolia.public.blastapi.io',
  'https://ethereum-sepolia.publicnode.com'
];
```

### Environment Variables

Create environment-specific configuration files:

```typescript
// config/environment.ts
export const config = {
  environment: process.env.NODE_ENV,
  bitcoin: {
    network: process.env.BITCOIN_NETWORK || 'testnet',
    endpoints: process.env.CUSTOM_BITCOIN_ENDPOINTS?.split(',') || []
  },
  ethereum: {
    network: process.env.ETHEREUM_NETWORK || 'sepolia',
    endpoints: process.env.CUSTOM_ETHEREUM_ENDPOINTS?.split(',') || [],
    chainId: process.env.ETHEREUM_CHAIN_ID ? parseInt(process.env.ETHEREUM_CHAIN_ID) : 11155111
  },
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    enableConsole: process.env.LOG_CONSOLE === 'true',
    enableFile: process.env.LOG_FILE === 'true'
  },
  features: {
    enableDevTools: process.env.ENABLE_DEV_TOOLS === 'true',
    enableAnalytics: process.env.ENABLE_ANALYTICS === 'true',
    enableCrashReporting: process.env.ENABLE_CRASH_REPORTING === 'true'
  }
};
```

### Secrets Management

**Never commit secrets to version control!**

#### Using Environment Variables

```bash
# Load secrets from secure source
export ENCRYPTION_KEY=$(aws secretsmanager get-secret-value --secret-id prod/encryption-key --query SecretString --output text)
export API_KEY=$(aws secretsmanager get-secret-value --secret-id prod/api-key --query SecretString --output text)
```

#### Using Secret Management Services

**AWS Secrets Manager**:
```typescript
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

async function getSecret(secretName: string): Promise<string> {
  const client = new SecretsManagerClient({ region: "us-east-1" });
  const response = await client.send(
    new GetSecretValueCommand({ SecretId: secretName })
  );
  return response.SecretString!;
}
```

**HashiCorp Vault**:
```typescript
import Vault from "node-vault";

const vault = Vault({
  endpoint: process.env.VAULT_ADDR,
  token: process.env.VAULT_TOKEN
});

async function getSecret(path: string): Promise<any> {
  const result = await vault.read(path);
  return result.data;
}
```

---

## Deployment Strategies

### Continuous Deployment (CD)

#### GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Build
        run: npm run build

      - name: Deploy to Production
        run: ./scripts/deploy.sh production
        env:
          DEPLOY_KEY: ${{ secrets.DEPLOY_KEY }}
```

### Blue-Green Deployment

```bash
#!/bin/bash
# scripts/deploy-blue-green.sh

# Deploy to green environment
./deploy.sh green

# Run health checks
./healthcheck.sh green

# Switch traffic from blue to green
./switch-traffic.sh blue green

# Monitor for issues
./monitor.sh green 10m

# If successful, decommission blue
# If issues detected, rollback to blue
```

### Canary Deployment

```bash
#!/bin/bash
# scripts/deploy-canary.sh

# Deploy to canary (5% of traffic)
./deploy.sh canary

# Monitor metrics
./monitor.sh canary 30m

# Gradually increase traffic
./scale-traffic.sh canary 25
./monitor.sh canary 30m

./scale-traffic.sh canary 50
./monitor.sh canary 30m

# Full rollout
./scale-traffic.sh canary 100
```

### Mobile App Deployment

#### iOS Deployment

```bash
# Build for App Store
xcodebuild -workspace ios/FuekiWallet.xcworkspace \
  -scheme FuekiWallet \
  -configuration Release \
  -archivePath build/FuekiWallet.xcarchive \
  archive

# Export IPA
xcodebuild -exportArchive \
  -archivePath build/FuekiWallet.xcarchive \
  -exportPath build \
  -exportOptionsPlist ios/ExportOptions.plist

# Upload to App Store Connect
xcrun altool --upload-app \
  --type ios \
  --file build/FuekiWallet.ipa \
  --username "your@email.com" \
  --password "@keychain:AC_PASSWORD"
```

#### Android Deployment

```bash
# Build release APK
cd android
./gradlew assembleRelease

# Sign APK
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore release.keystore \
  app/build/outputs/apk/release/app-release-unsigned.apk \
  release-key

# Optimize with zipalign
zipalign -v 4 \
  app/build/outputs/apk/release/app-release-unsigned.apk \
  app/build/outputs/apk/release/app-release.apk

# Upload to Play Store
# Use Play Console or fastlane
```

---

## Monitoring and Maintenance

### Health Checks

```typescript
// src/monitoring/healthcheck.ts
export async function healthCheck(): Promise<HealthStatus> {
  const checks = await Promise.all([
    checkBitcoinConnection(),
    checkEthereumConnection(),
    checkDatabaseConnection(),
    checkStorageAccess(),
    checkMemoryUsage(),
    checkCPUUsage()
  ]);

  return {
    status: checks.every(c => c.healthy) ? 'healthy' : 'unhealthy',
    checks,
    timestamp: Date.now()
  };
}
```

### Metrics Collection

```typescript
// src/monitoring/metrics.ts
export interface Metrics {
  // Performance
  requestLatency: number[];
  transactionThroughput: number;
  errorRate: number;

  // Resource usage
  memoryUsage: number;
  cpuUsage: number;
  networkBandwidth: number;

  // Business metrics
  activeUsers: number;
  transactionsProcessed: number;
  failedTransactions: number;
}

export class MetricsCollector {
  collect(): Metrics {
    return {
      requestLatency: this.getRequestLatencies(),
      transactionThroughput: this.getTransactionThroughput(),
      errorRate: this.getErrorRate(),
      memoryUsage: process.memoryUsage().heapUsed,
      cpuUsage: process.cpuUsage().user,
      networkBandwidth: this.getNetworkBandwidth(),
      activeUsers: this.getActiveUserCount(),
      transactionsProcessed: this.getTransactionCount(),
      failedTransactions: this.getFailedTransactionCount()
    };
  }
}
```

### Logging

```typescript
// src/monitoring/logger.ts
import winston from 'winston';

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});
```

### Alerting

```typescript
// src/monitoring/alerts.ts
export interface Alert {
  severity: 'low' | 'medium' | 'high' | 'critical';
  message: string;
  metric: string;
  threshold: number;
  currentValue: number;
  timestamp: number;
}

export class AlertManager {
  async sendAlert(alert: Alert): Promise<void> {
    // Send to monitoring service (PagerDuty, Slack, etc.)
    if (alert.severity === 'critical') {
      await this.sendPagerDutyAlert(alert);
      await this.sendSlackAlert(alert);
    } else {
      await this.sendSlackAlert(alert);
    }
  }
}
```

---

## Rollback Procedures

### Quick Rollback

```bash
#!/bin/bash
# scripts/rollback.sh

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: ./rollback.sh <version>"
  exit 1
fi

echo "Rolling back to version $VERSION..."

# Revert to previous version
git checkout tags/v$VERSION

# Rebuild
npm ci
npm run build

# Deploy
./scripts/deploy.sh production

echo "Rollback complete"
```

### Database Rollback

```bash
#!/bin/bash
# scripts/rollback-database.sh

MIGRATION=$1

echo "Rolling back database to $MIGRATION..."

# Revert database migration
npm run migrate:down $MIGRATION

echo "Database rollback complete"
```

### Emergency Procedures

1. **Identify Issue**
   ```bash
   # Check application logs
   tail -f /var/log/fueki-wallet/error.log

   # Check system metrics
   ./scripts/monitor.sh production
   ```

2. **Stop New Deployments**
   ```bash
   # Disable CI/CD pipeline
   gh workflow disable deploy.yml
   ```

3. **Rollback**
   ```bash
   # Rollback to last known good version
   ./scripts/rollback.sh 1.0.0
   ```

4. **Verify**
   ```bash
   # Run health checks
   ./scripts/healthcheck.sh production

   # Monitor for 15 minutes
   ./scripts/monitor.sh production 15m
   ```

5. **Communicate**
   - Notify team of rollback
   - Update status page
   - Document incident

---

## Post-Deployment Verification

### Automated Tests

```bash
#!/bin/bash
# scripts/post-deploy-tests.sh

echo "Running post-deployment tests..."

# Health check
./scripts/healthcheck.sh production

# Smoke tests
npm run test:smoke

# Integration tests
npm run test:integration

# Load tests
npm run test:load

echo "Post-deployment tests complete"
```

### Manual Verification

#### Checklist

- [ ] Application accessible
- [ ] User authentication working
- [ ] Wallet creation successful
- [ ] Balance retrieval working
- [ ] Transaction signing functional
- [ ] Transaction broadcasting successful
- [ ] Network switching working
- [ ] Backup/recovery functional
- [ ] Biometric authentication working
- [ ] All critical features operational

#### Test Scenarios

```typescript
// Test wallet creation
const wallet = await createWallet();
assert(wallet.address);
assert(wallet.privateKey);

// Test balance retrieval
const balance = await getBalance(wallet.address);
assert(balance.confirmed >= 0);

// Test transaction signing
const tx = await createTransaction({
  from: wallet.address,
  to: recipientAddress,
  amount: 0.001
});
const signed = await signTransaction(tx, wallet.privateKey);
assert(signed.signature);

// Test transaction broadcast
const txHash = await broadcastTransaction(signed);
assert(txHash);
```

### Performance Verification

```bash
# Monitor response times
curl -w "@curl-format.txt" -o /dev/null -s https://api.fueki.io/health

# Check resource usage
top -p $(pgrep -f fueki-wallet)

# Monitor error rates
grep "ERROR" /var/log/fueki-wallet/error.log | wc -l
```

### Security Verification

```bash
# SSL certificate check
openssl s_client -connect api.fueki.io:443

# Security headers check
curl -I https://api.fueki.io | grep -i security

# Vulnerability scan
npm audit

# Penetration testing
npm run test:security
```

---

## Maintenance Windows

### Scheduled Maintenance

```bash
# Schedule maintenance window
# 1. Notify users (24-48 hours advance)
# 2. Enable maintenance mode
./scripts/maintenance.sh enable

# 3. Perform updates
./scripts/update.sh

# 4. Run tests
npm test

# 5. Disable maintenance mode
./scripts/maintenance.sh disable

# 6. Monitor for issues
./scripts/monitor.sh production 1h
```

### Zero-Downtime Deployment

```bash
# Use blue-green or canary deployment
./scripts/deploy-blue-green.sh

# No maintenance window needed
# Users experience no downtime
```

---

## Disaster Recovery

### Backup Strategy

```bash
#!/bin/bash
# scripts/backup.sh

BACKUP_DIR="/backups/$(date +%Y%m%d_%H%M%S)"

# Backup database
pg_dump -U postgres fueki_wallet > $BACKUP_DIR/database.sql

# Backup configuration
cp -r /etc/fueki-wallet $BACKUP_DIR/config

# Backup user data (encrypted)
tar -czf $BACKUP_DIR/user-data.tar.gz /var/lib/fueki-wallet/data

# Upload to S3
aws s3 cp $BACKUP_DIR s3://fueki-backups/ --recursive
```

### Recovery Procedures

```bash
#!/bin/bash
# scripts/recover.sh

BACKUP_DIR=$1

# Stop application
./scripts/stop.sh

# Restore database
psql -U postgres fueki_wallet < $BACKUP_DIR/database.sql

# Restore configuration
cp -r $BACKUP_DIR/config/* /etc/fueki-wallet/

# Restore user data
tar -xzf $BACKUP_DIR/user-data.tar.gz -C /

# Start application
./scripts/start.sh

# Verify
./scripts/healthcheck.sh
```

---

## Deployment Best Practices

1. **Always test in staging first**
2. **Use automated deployment pipelines**
3. **Implement gradual rollouts**
4. **Monitor metrics continuously**
5. **Have rollback plan ready**
6. **Document every deployment**
7. **Communicate with stakeholders**
8. **Maintain deployment logs**
9. **Regular security audits**
10. **Keep dependencies updated**

---

## Support and Escalation

### Support Levels

**Level 1**: User-reported issues
- Response time: 24 hours
- Resolution time: 48 hours

**Level 2**: Critical bugs
- Response time: 4 hours
- Resolution time: 24 hours

**Level 3**: Production outage
- Response time: 15 minutes
- Resolution time: 2 hours

### Escalation Contacts

- **On-Call Engineer**: oncall@fueki.io
- **Engineering Manager**: manager@fueki.io
- **CTO**: cto@fueki.io

---

**Last Updated**: 2025-10-22
**Version**: 1.0.0
