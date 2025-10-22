# CI/CD Pipeline Setup Guide

## Overview

Fueki Mobile Wallet uses GitHub Actions for comprehensive CI/CD automation, including testing, security scanning, and deployment to TestFlight and the App Store.

## Workflows

### 1. Pull Request CI (`pull-request.yml`)

**Triggers:** Pull requests to `main` or `develop` branches

**Jobs:**
- **Code Quality**: SwiftLint analysis with strict mode
- **Security Scan**: SAST with Semgrep, dependency checks, secrets detection
- **Unit Tests**: Comprehensive test suite with code coverage
- **Integration Tests**: API and blockchain integration tests
- **UI Tests**: Automated UI testing on iOS Simulator
- **Build Validation**: Debug and release build verification

**Requirements:**
- All tests must pass
- Code coverage maintained (target: 80%)
- No security vulnerabilities
- SwiftLint checks pass

### 2. Main Branch CI/CD (`main-ci.yml`)

**Triggers:** Pushes to `main` branch, manual workflow dispatch

**Jobs:**
- Complete test suite execution
- Code coverage reporting to Codecov
- TestFlight deployment (manual trigger)
- Slack notifications

### 3. App Store Release (`release.yml`)

**Triggers:** Git tags (`v*.*.*`), manual workflow dispatch

**Jobs:**
- Version validation
- Complete test suite with coverage threshold (80% minimum)
- Security audit and penetration testing
- Production build
- App Store upload
- GitHub release creation
- Notifications

### 4. Nightly Tests (`nightly-tests.yml`)

**Triggers:** Daily at 2 AM UTC, manual trigger

**Jobs:**
- Multi-device testing (iPhone 15, Pro Max, iPad Pro)
- Performance benchmarks
- Memory leak detection
- Nightly summary notifications

### 5. Dependency Updates (`dependency-update.yml`)

**Triggers:** Weekly on Monday, manual trigger

**Jobs:**
- Swift package dependency updates
- Automated testing with new dependencies
- Pull request creation for review

### 6. CodeQL Analysis (`codeql-analysis.yml`)

**Triggers:** Pushes to main/develop, PRs, weekly schedule

**Jobs:**
- Static code analysis for security vulnerabilities
- SARIF report generation
- GitHub Security tab integration

### 7. Automated Code Review (`code-review.yml`)

**Triggers:** Pull requests

**Jobs:**
- File complexity analysis
- TODO/FIXME detection
- Automated PR comments with metrics

## Setup Instructions

### Prerequisites

1. **Xcode 15.0** or later
2. **macOS 13** (Ventura) for GitHub Actions runners
3. **Apple Developer Account** with App Store Connect access
4. **Fastlane** installed (`brew install fastlane`)

### GitHub Secrets Configuration

Configure the following secrets in your GitHub repository settings:

#### Code Signing

```
CERTIFICATE_BASE64          # Base64-encoded .p12 certificate
P12_PASSWORD                # Password for .p12 certificate
KEYCHAIN_PASSWORD           # Password for temporary keychain
MATCH_PASSWORD              # Password for match certificates repo
```

#### App Store Connect

```
APP_STORE_CONNECT_API_KEY_ID        # API Key ID
APP_STORE_CONNECT_API_ISSUER_ID     # Issuer ID
APP_STORE_CONNECT_API_KEY_BASE64    # Base64-encoded API key (.p8)
FASTLANE_APP_PASSWORD               # App-specific password
```

#### Third-Party Services

```
CODECOV_TOKEN              # Codecov upload token
SLACK_WEBHOOK_URL          # Slack notification webhook
```

### Generating Required Secrets

#### 1. Code Signing Certificate

```bash
# Export certificate from Keychain
security find-identity -v -p codesigning

# Create .p12 file
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities \
  -f pkcs12 \
  -o certificate.p12 \
  -P YOUR_PASSWORD

# Convert to Base64
base64 -i certificate.p12 -o certificate.base64
```

#### 2. App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to Users and Access → Keys
3. Create new API key with "Admin" role
4. Download the .p8 file
5. Convert to Base64:

```bash
base64 -i AuthKey_KEYID.p8 -o authkey.base64
```

#### 3. Match Setup

```bash
# Initialize match
fastlane match init

# Generate certificates
fastlane match development
fastlane match appstore
```

## CI Scripts

### Security Scan (`scripts/ci/security-scan.sh`)

Performs comprehensive security analysis:
- Hardcoded secrets detection
- Weak cryptographic algorithms
- Insecure network connections
- Info.plist security settings
- SQL injection vulnerabilities
- Insecure data storage

**Usage:**
```bash
bash scripts/ci/security-scan.sh
```

### Coverage Report (`scripts/ci/generate-coverage-report.sh`)

Generates HTML and JSON coverage reports from Xcode test results.

**Usage:**
```bash
bash scripts/ci/generate-coverage-report.sh
```

### Certificate Import (`scripts/ci/import-certificates.sh`)

Imports signing certificates in CI environment.

**Environment Variables:**
- `CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `KEYCHAIN_PASSWORD`

### Performance Tests (`scripts/ci/performance-tests.sh`)

Runs performance benchmarks:
- TSS key generation
- Transaction signing
- Blockchain sync
- UI rendering

### Memory Leak Tests (`scripts/ci/memory-leak-tests.sh`)

Detects memory issues:
- Retain cycles
- Memory growth
- Leak detection with Address Sanitizer

### Penetration Tests (`scripts/ci/pentest.sh`)

Security penetration testing:
- Authentication security
- Data encryption at rest
- Network security
- Input validation
- Secure communication

## SwiftLint Configuration

Configuration file: `.swiftlint.yml`

**Custom Rules:**
- No print statements in production code
- No force casting
- Secure random for cryptography
- No hardcoded secrets

**Thresholds:**
- Line length: 120 (warning), 200 (error)
- File length: 500 (warning), 1000 (error)
- Function body: 50 (warning), 100 (error)

## Pre-commit Hooks

Install pre-commit hooks:

```bash
pip install pre-commit
pre-commit install
```

**Hooks:**
- Trailing whitespace removal
- SwiftLint validation
- Security scan
- Swift format
- No print statements check

## Fastlane Lanes

### Development

```bash
# Run all tests
fastlane test

# Run SwiftLint
fastlane lint

# Security scan
fastlane security_scan
```

### Deployment

```bash
# Deploy to TestFlight
fastlane beta

# Release to App Store
fastlane release

# Sync certificates
fastlane sync_certificates
```

## Monitoring and Notifications

### Slack Integration

Configure Slack webhook for notifications:
- TestFlight deployment status
- Release completion
- Nightly test results
- Build failures

### Codecov Integration

Automatic code coverage reporting:
- PR coverage comments
- Coverage trends
- File-level coverage

## Troubleshooting

### Common Issues

**1. Certificate Import Fails**
- Verify Base64 encoding
- Check password correctness
- Ensure keychain permissions

**2. Tests Timeout**
- Increase timeout in workflow
- Check simulator availability
- Verify network connectivity

**3. SwiftLint Failures**
- Run `swiftlint autocorrect`
- Review `.swiftlint.yml` rules
- Fix custom rule violations

**4. Build Failures**
- Clear derived data
- Update Swift package cache
- Check Xcode version

## Best Practices

1. **Branch Protection**: Enable required status checks for `main` branch
2. **Code Review**: Require at least one approval for PRs
3. **Security**: Never commit secrets to repository
4. **Testing**: Maintain 80%+ code coverage
5. **Versioning**: Use semantic versioning (MAJOR.MINOR.PATCH)
6. **Documentation**: Update release notes for each version

## Release Process

1. Create feature branch from `develop`
2. Implement changes with tests
3. Open PR to `develop`
4. Pass all CI checks
5. Code review and approval
6. Merge to `develop`
7. Create release PR from `develop` to `main`
8. Tag release: `git tag v1.0.0`
9. Push tag to trigger release workflow
10. Monitor App Store Connect for build processing

## Support

For issues or questions:
- GitHub Issues: [Fueki-Mobile-Wallet/issues](https://github.com/fueki/Fueki-Mobile-Wallet/issues)
- Documentation: `/docs`
- CI/CD Logs: GitHub Actions tab
