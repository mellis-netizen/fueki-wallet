# CI/CD Pipeline Setup Guide

## 🎯 Quick Start

### 1. Configure App Identifiers

Edit `/Users/computer/Fueki-Mobile-Wallet/ios/fastlane/Appfile`:
```ruby
app_identifier("com.fueki.wallet")  # Your actual bundle ID
apple_id("your-email@example.com")   # Your Apple Developer email
itc_team_id("YOUR_TEAM_ID")          # App Store Connect Team ID
team_id("YOUR_TEAM_ID")              # Developer Portal Team ID
```

### 2. Setup Code Signing Repository

Edit `/Users/computer/Fueki-Mobile-Wallet/ios/fastlane/Matchfile`:
```ruby
git_url("https://github.com/your-org/certificates")  # Your certs repo
team_id("YOUR_TEAM_ID")
```

### 3. Configure GitHub Secrets

Add these secrets in GitHub Settings → Secrets:

**Required:**
- `MATCH_PASSWORD` - Encryption password for certificates
- `MATCH_GIT_BASIC_AUTHORIZATION` - Base64 encoded `username:token`
- `MATCH_GIT_URL` - HTTPS URL to certificates repository
- `FASTLANE_USER` - Apple Developer account email
- `FASTLANE_PASSWORD` - Apple ID password
- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` - App-specific password

**Optional:**
- `SLACK_WEBHOOK_URL` - For build notifications

### 4. Initialize Code Signing

```bash
# Setup development certificates
fastlane ios match_setup type:development

# Setup distribution certificates
fastlane ios match_setup type:appstore

# Sync all certificates
fastlane ios sync_certs
```

## 🚀 Available Commands

### Local Development
```bash
# Run full CI pipeline
fastlane ios ci

# Individual steps
fastlane ios lint          # SwiftLint
fastlane ios test          # Run tests
fastlane ios build         # Build app
```

### Using Scripts
```bash
# Linting
bash ios/scripts/lint.sh

# Testing
bash ios/scripts/test.sh

# Building
bash ios/scripts/build.sh

# Coverage
bash ios/scripts/code-coverage.sh
```

### Release
```bash
# TestFlight beta
fastlane ios beta

# App Store release
fastlane ios release

# Generate screenshots
fastlane ios screenshots
```

## 📁 Files Created

### Fastlane Configuration
- `/Users/computer/Fueki-Mobile-Wallet/ios/fastlane/Fastfile` - Lane definitions
- `/Users/computer/Fueki-Mobile-Wallet/ios/fastlane/Appfile` - App configuration
- `/Users/computer/Fueki-Mobile-Wallet/ios/fastlane/Matchfile` - Code signing
- `/Users/computer/Fueki-Mobile-Wallet/ios/fastlane/Gymfile` - Build settings
- `/Users/computer/Fueki-Mobile-Wallet/ios/fastlane/Scanfile` - Test settings

### GitHub Actions
- `/Users/computer/Fueki-Mobile-Wallet/.github/workflows/ios-ci.yml` - CI workflow
- `/Users/computer/Fueki-Mobile-Wallet/.github/workflows/ios-release.yml` - Release workflow
- `/Users/computer/Fueki-Mobile-Wallet/.github/workflows/ios-tests.yml` - Test automation

### Scripts
- `/Users/computer/Fueki-Mobile-Wallet/ios/scripts/build.sh` - Build automation
- `/Users/computer/Fueki-Mobile-Wallet/ios/scripts/test.sh` - Test execution
- `/Users/computer/Fueki-Mobile-Wallet/ios/scripts/lint.sh` - Linting
- `/Users/computer/Fueki-Mobile-Wallet/ios/scripts/code-coverage.sh` - Coverage reporting

## 🔒 Quality Gates

All PRs must pass:
- ✅ Zero SwiftLint errors
- ✅ All unit tests passing
- ✅ Minimum 80% code coverage
- ✅ Successful build

## 📊 CI/CD Workflows

### On Pull Request
1. SwiftLint code quality check
2. Unit tests (iPhone 15 Pro, iPhone SE)
3. Build verification
4. Quality gate validation

### On Release Tag
1. Run full test suite
2. Build for App Store
3. Upload to TestFlight/App Store
4. Generate screenshots (if needed)
5. Create GitHub release
6. Notify team via Slack

## 🔧 Customization

### Adjust Coverage Threshold
Edit `MINIMUM_COVERAGE` in scripts:
```bash
MINIMUM_COVERAGE=85  # Default is 80
```

### Add More Devices
Edit `.github/workflows/ios-ci.yml`:
```yaml
matrix:
  device:
    - "iPhone 15 Pro Max"
    - "iPhone 15 Pro"
    - "iPad Pro"
```

### Modify SwiftLint Rules
SwiftLint config will be auto-generated at `.swiftlint.yml` on first run.

## 📚 Next Steps

1. ✅ Update team IDs and bundle identifiers
2. ✅ Configure GitHub secrets
3. ✅ Initialize code signing with match
4. ✅ Create certificates repository
5. ✅ Run local CI to verify setup
6. ✅ Push to trigger first CI build
7. ✅ Monitor GitHub Actions for results

## 🆘 Support

See `/Users/computer/Fueki-Mobile-Wallet/hive/infrastructure/cicd/README.md` for:
- Detailed documentation
- Troubleshooting guides
- Best practices
- Maintenance procedures

---

**Pipeline Status**: ✅ Ready for Configuration
**Hive Mind Task**: Completed
**Next Agent**: Configuration Specialist
