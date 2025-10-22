# CI/CD and Deployment Guide

## Overview

This document outlines the complete CI/CD pipeline setup for the Fueki Mobile Wallet, including automated testing, building, and deployment processes for both iOS and Android platforms.

## Table of Contents

1. [CI/CD Architecture](#cicd-architecture)
2. [GitHub Actions Workflows](#github-actions-workflows)
3. [Environment Configuration](#environment-configuration)
4. [iOS Deployment](#ios-deployment)
5. [Android Deployment](#android-deployment)
6. [Version Management](#version-management)
7. [Security Best Practices](#security-best-practices)
8. [Troubleshooting](#troubleshooting)

---

## CI/CD Architecture

### Pipeline Overview

```
┌─────────────┐
│   PR Event  │
└──────┬──────┘
       │
       ├───► Code Quality (ESLint, TypeScript, SwiftLint)
       ├───► Security Scanning (SAST, Dependency Check, Secrets)
       ├───► Unit Tests (Node.js, iOS, Android)
       ├───► Integration Tests
       └───► Build Validation
              │
              └───► Merge to Main
                    │
                    ├───► Automated Builds
                    ├───► TestFlight (iOS)
                    ├───► Play Store (Android)
                    └───► GitHub Release
```

### Key Features

- **Parallel Execution**: Multiple jobs run concurrently for faster feedback
- **Matrix Testing**: Tests across multiple Node.js versions and device configurations
- **Caching**: Aggressive caching of dependencies and build artifacts
- **Security**: Automated vulnerability scanning and secrets detection
- **Automated Deployment**: Push-button deployments to TestFlight and Play Store

---

## GitHub Actions Workflows

### 1. Pull Request CI (`pull-request.yml`)

**Triggers**: Pull requests to `main` or `develop`

**Jobs**:
- Code quality checks (SwiftLint, ESLint, Prettier)
- Security scanning (Semgrep, TruffleHog, npm audit)
- Unit tests with coverage reporting
- Integration and UI tests
- Build validation

**Key Features**:
- Automatic PR comments with test results and coverage
- SARIF upload for security findings
- Parallel test execution

### 2. Main CI (`ci.yml`)

**Triggers**: Push to `main` or `develop`, manual dispatch

**Jobs**:
- SwiftLint code quality
- Unit tests (iOS with multiple simulators)
- Integration tests with mock services
- UI tests across iPhone and iPad
- Build validation and artifact upload
- Coverage report generation

### 3. Android CI (`android-ci.yml`)

**Triggers**: Push/PR to `main` or `develop`

**Jobs**:
- Lint and TypeScript checks
- Unit tests with Node.js matrix (16, 18, 20)
- Android build (debug and release)
- Instrumentation tests on emulators (API 28, 30, 33)
- Security scanning

### 4. Node.js CI (`nodejs-ci.yml`)

**Triggers**: Push/PR to `main` or `develop`

**Jobs**:
- Code quality (ESLint, Prettier, TypeScript)
- Unit tests across Node.js versions
- Cryptographic test vectors validation
- Dependency security audit
- Build validation

### 5. Security Scanning (`security.yml`)

**Triggers**: Push, PR, daily schedule (2 AM UTC), manual

**Jobs**:
- CodeQL SAST analysis
- SwiftLint security rules
- OWASP dependency vulnerability check
- CocoaPods security audit
- Gitleaks secrets detection
- Binary security analysis (PIE, stack canaries, ARC)

### 6. TestFlight Deployment (`testflight.yml`)

**Triggers**: Push to `main`, tags (`v*.*.*-beta*`), manual

**Jobs**:
- Pre-flight validation (version, secrets)
- Build and archive with code signing
- Export IPA with proper provisioning
- Upload to TestFlight via Fastlane
- Create GitHub release

### 7. Play Store Deployment (`play-store.yml`)

**Triggers**: Push to `main`, tags, manual

**Jobs**:
- Pre-flight validation
- Build signed AAB and APK
- ProGuard mapping generation
- Upload to Play Store (internal/alpha/beta/production)
- GitHub release creation

### 8. Version Bump (`version-bump.yml`)

**Triggers**: Manual workflow dispatch

**Features**:
- Semantic version bumping (major/minor/patch)
- Prerelease support (beta, rc)
- Synchronized version across package.json, iOS, Android
- Automatic changelog generation
- Git tagging and GitHub release draft

---

## Environment Configuration

### Environment Files

Three environment configurations are provided:

1. **Development** (`config/environments/development.env.example`)
   - Testnet networks
   - Debug mode enabled
   - Local/dev API endpoints
   - Development tools enabled

2. **Staging** (`config/environments/staging.env.example`)
   - Testnet networks
   - Staging API endpoints
   - Analytics enabled
   - Production-like settings

3. **Production** (`config/environments/production.env.example`)
   - Mainnet networks
   - Production API endpoints
   - Maximum security settings
   - Error tracking enabled

### Setup Instructions

```bash
# Copy example files
cp config/environments/development.env.example .env.development
cp config/environments/staging.env.example .env.staging
cp config/environments/production.env.example .env.production

# Fill in your actual values
# NEVER commit these files to version control!
```

### Key Configuration Variables

#### API Configuration
- `API_BASE_URL`: Backend API endpoint
- `API_TIMEOUT`: Request timeout in milliseconds
- `API_RETRY_ATTEMPTS`: Number of retry attempts

#### Blockchain Networks
- `BITCOIN_NETWORK`: mainnet/testnet
- `ETHEREUM_NETWORK`: mainnet/goerli/sepolia
- `ETHEREUM_RPC_URL`: Ethereum node endpoint

#### Security
- `SESSION_TIMEOUT`: Session timeout in milliseconds
- `MAX_LOGIN_ATTEMPTS`: Maximum failed login attempts
- `ENCRYPTION_ALGORITHM`: Encryption algorithm (aes-256-gcm)

---

## iOS Deployment

### Prerequisites

1. **Apple Developer Account**
   - Paid developer membership
   - App created in App Store Connect
   - Bundle ID registered

2. **Certificates and Profiles**
   - Distribution certificate
   - App Store provisioning profile
   - Managed via Fastlane Match

3. **App Store Connect API Key**
   - Create API key in App Store Connect
   - Download `.p8` file
   - Save Key ID, Issuer ID, and base64-encoded key

### Required Secrets

Set these in GitHub repository settings:

```
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_API_KEY_BASE64
CERTIFICATES_P12_BASE64
CERTIFICATES_PASSWORD
PROVISIONING_PROFILE_BASE64
PROVISIONING_PROFILE_NAME
DEVELOPMENT_TEAM_ID
BUNDLE_IDENTIFIER
```

### Manual Deployment

Using Fastlane:

```bash
# Run tests
fastlane test

# Deploy to TestFlight
fastlane beta

# Deploy to App Store
fastlane release
```

Using deployment script:

```bash
# Deploy with all checks
./scripts/deployment/deploy-testflight.sh

# Skip tests (not recommended)
./scripts/deployment/deploy-testflight.sh --skip-tests

# Custom changelog
./scripts/deployment/deploy-testflight.sh --changelog "Fixed critical bug"
```

### Automated Deployment

Trigger via GitHub Actions:

1. **Automatic on Tag**:
   ```bash
   git tag -a v1.0.0-beta1 -m "Beta release 1"
   git push origin v1.0.0-beta1
   ```

2. **Manual Dispatch**:
   - Go to Actions → TestFlight Distribution
   - Click "Run workflow"
   - Enter version and release notes
   - Click "Run workflow"

### TestFlight Testing

1. **Internal Testing**:
   - Automatically available to team
   - No review required
   - Up to 100 internal testers

2. **External Testing**:
   - Submit for beta review
   - Add testing information
   - Invite up to 10,000 testers

---

## Android Deployment

### Prerequisites

1. **Google Play Developer Account**
   - One-time $25 registration fee
   - App created in Play Console
   - Package name registered

2. **Signing Key**
   - App signing key generated
   - Upload key (if using Play App Signing)
   - Keystore and key passwords

3. **Service Account**
   - Create in Google Cloud Console
   - Grant Play Console access
   - Download JSON key file

### Required Secrets

```
ANDROID_KEYSTORE_BASE64
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
ANDROID_STORE_PASSWORD
PLAY_STORE_SERVICE_ACCOUNT_JSON
```

### Manual Deployment

Using Gradle:

```bash
# Build release AAB
cd android
./gradlew bundleRelease

# Build release APK
./gradlew assembleRelease
```

Using deployment script:

```bash
# Deploy to internal track
./scripts/deployment/deploy-playstore.sh --track internal

# Deploy to beta
./scripts/deployment/deploy-playstore.sh --track beta

# Deploy to production
./scripts/deployment/deploy-playstore.sh --track production --changelog "Major update"
```

### Automated Deployment

1. **Automatic on Tag**:
   ```bash
   git tag -a v1.0.0 -m "Production release"
   git push origin v1.0.0
   ```

2. **Manual Dispatch**:
   - Go to Actions → Play Store Deployment
   - Select track (internal/alpha/beta/production)
   - Enter version information
   - Click "Run workflow"

### Release Tracks

1. **Internal Testing**:
   - Up to 100 testers
   - Immediate rollout
   - No review required

2. **Alpha/Beta**:
   - Open or closed testing
   - Can require opt-in
   - Staged rollout available

3. **Production**:
   - Public release
   - Review required
   - Staged rollout recommended

---

## Version Management

### Version Manager Script

Automated version bumping across all platforms:

```bash
# Bump patch version (1.0.0 → 1.0.1)
./scripts/ci/version-manager.sh patch

# Bump minor version (1.0.0 → 1.1.0)
./scripts/ci/version-manager.sh minor

# Bump major version (1.0.0 → 2.0.0)
./scripts/ci/version-manager.sh major

# Specify build number
./scripts/ci/version-manager.sh patch 42
```

### What Gets Updated

- `package.json` version
- `ios/FuekiWallet/Info.plist` (CFBundleShortVersionString, CFBundleVersion)
- `android/app/build.gradle` (versionName, versionCode)
- `version.txt` (simple text file)
- `CHANGELOG.md` (new entry added)

### GitHub Actions Version Bump

Use the workflow for automated version management:

1. Go to Actions → Version Bump
2. Select bump type (patch/minor/major)
3. Optional: Add prerelease identifier (beta, rc)
4. Click "Run workflow"

The workflow will:
- Bump version in all files
- Generate changelog entry
- Commit changes
- Create and push git tag
- Create draft release

---

## Security Best Practices

### Secrets Management

1. **Never Commit Secrets**
   - Use `.gitignore` for sensitive files
   - Use environment variables
   - Use GitHub Secrets for CI/CD

2. **Rotate Regularly**
   - API keys every 90 days
   - Certificates before expiration
   - Access tokens quarterly

3. **Principle of Least Privilege**
   - Service accounts with minimal permissions
   - Read-only access where possible
   - Separate dev/prod credentials

### Code Signing

1. **iOS**:
   - Use Fastlane Match for certificate management
   - Store in private git repository
   - Encrypt with strong passphrase

2. **Android**:
   - Use Play App Signing
   - Keep upload key secure
   - Base64 encode for GitHub Secrets

### Dependency Security

1. **Automated Scanning**:
   - npm audit (Node.js)
   - OWASP Dependency-Check
   - Snyk integration
   - GitHub Dependabot

2. **Best Practices**:
   - Pin dependency versions
   - Review updates before merging
   - Use lock files
   - Regular security updates

---

## Troubleshooting

### Common iOS Issues

#### Code Signing Failed

```
Error: Code signing failed
```

**Solution**:
- Verify certificates are valid and not expired
- Check provisioning profile matches bundle ID
- Ensure certificate is properly imported to keychain
- Verify team ID is correct

#### Archive Upload Failed

```
Error: Upload to App Store Connect failed
```

**Solution**:
- Check API key is valid and has proper permissions
- Verify network connectivity
- Check App Store Connect service status
- Try re-generating API key

### Common Android Issues

#### Build Failed

```
Error: Task assembleRelease failed
```

**Solution**:
- Check keystore file is properly decoded
- Verify key alias and passwords are correct
- Clean build: `./gradlew clean`
- Check Gradle version compatibility

#### Upload Failed

```
Error: Upload to Play Store failed
```

**Solution**:
- Verify service account has proper permissions
- Check package name matches Play Console
- Ensure version code is incremented
- Review Play Console for error details

### Common CI/CD Issues

#### Workflow Not Triggering

**Solution**:
- Check workflow file syntax (YAML)
- Verify branch names match triggers
- Check repository permissions
- Review GitHub Actions logs

#### Test Failures

**Solution**:
- Run tests locally first
- Check test environment configuration
- Verify mock data and fixtures
- Review test logs in Actions

#### Secrets Not Available

**Solution**:
- Verify secrets are set in repository settings
- Check secret names match exactly
- Use `${{ secrets.SECRET_NAME }}` syntax
- Secrets are not available in forks

---

## Additional Resources

### Documentation
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Google Play Console API](https://developers.google.com/android-publisher)

### Tools
- [Fastlane](https://fastlane.tools/)
- [CocoaPods](https://cocoapods.org/)
- [Gradle](https://gradle.org/)
- [xcpretty](https://github.com/xcpretty/xcpretty)

### Support
- Open an issue on GitHub
- Review workflow logs
- Check community forums
- Contact team leads

---

## Summary

This CI/CD pipeline provides:
- ✅ Automated testing on every PR
- ✅ Security scanning and vulnerability detection
- ✅ Code quality enforcement
- ✅ Automated builds for iOS and Android
- ✅ Push-button deployments to TestFlight and Play Store
- ✅ Version management and changelog generation
- ✅ GitHub release automation

For questions or issues, please refer to the troubleshooting section or contact the development team.
