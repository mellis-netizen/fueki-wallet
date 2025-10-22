# Fueki Wallet - CI/CD Infrastructure

Production-grade CI/CD pipeline for iOS development using Fastlane and GitHub Actions.

## 📁 Directory Structure

```
ios/
├── fastlane/
│   ├── Fastfile          # Lane definitions
│   ├── Appfile           # App identifier configuration
│   ├── Matchfile         # Code signing configuration
│   ├── Gymfile           # Build configuration
│   └── Scanfile          # Test configuration
│
├── scripts/
│   ├── build.sh          # Build automation
│   ├── test.sh           # Test execution
│   ├── lint.sh           # SwiftLint automation
│   └── code-coverage.sh  # Coverage reporting
│
.github/
└── workflows/
    ├── ios-ci.yml        # Continuous integration
    ├── ios-release.yml   # Release automation
    └── ios-tests.yml     # Test automation
```

## 🚀 Fastlane Lanes

### Development Lanes
- `fastlane ios lint` - Run SwiftLint
- `fastlane ios test` - Run all tests with coverage
- `fastlane ios build` - Build app for testing
- `fastlane ios ci` - Full CI pipeline (lint + test + build)

### Release Lanes
- `fastlane ios beta` - Deploy to TestFlight
- `fastlane ios release` - Deploy to App Store
- `fastlane ios screenshots` - Generate App Store screenshots

### Utility Lanes
- `fastlane ios match_setup type:<type>` - Setup code signing
- `fastlane ios sync_certs` - Sync all certificates
- `fastlane ios register_device name:<name> udid:<udid>` - Register new device

## 🔧 GitHub Actions Workflows

### iOS CI (`ios-ci.yml`)
Triggered on: Push to `main`/`develop`, Pull Requests

**Jobs:**
1. **Lint** - SwiftLint code quality checks
2. **Test** - Unit & UI tests with coverage (matrix: iPhone 15 Pro, iPhone SE)
3. **Build** - Build app with code signing
4. **Quality Gates** - Verify all quality requirements

**Quality Gates:**
- ✅ Zero SwiftLint errors
- ✅ All tests passing
- ✅ Minimum 80% code coverage
- ✅ Successful build

### iOS Release (`ios-release.yml`)
Triggered on: Tags (`v*`), Manual workflow dispatch

**Jobs:**
1. **Release** - Build and deploy to TestFlight/App Store
2. **Screenshots** - Generate App Store screenshots (release only)

**Deployment Options:**
- `beta` - TestFlight deployment
- `release` - App Store deployment

### iOS Tests (`ios-tests.yml`)
Triggered on: Push, Pull Requests, Daily schedule (2 AM UTC)

**Jobs:**
1. **Unit Tests** - Matrix across 4 device types
2. **UI Tests** - iPhone & iPad testing
3. **Code Coverage** - Generate and upload coverage reports
4. **Performance Tests** - Performance benchmarking

## 🔐 Required Secrets

Configure these in GitHub Settings → Secrets and variables → Actions:

### Code Signing
- `MATCH_PASSWORD` - Password for match repository
- `MATCH_GIT_BASIC_AUTHORIZATION` - Git credentials for certificates repo
- `MATCH_GIT_URL` - Git repository URL for certificates

### App Store Connect
- `FASTLANE_USER` - Apple Developer account email
- `FASTLANE_PASSWORD` - Apple ID password
- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` - App-specific password
- `FASTLANE_SESSION` - App Store Connect session (optional)

### Notifications
- `SLACK_WEBHOOK_URL` - Slack webhook for notifications

## 📝 Configuration Files

### Appfile
Update team IDs and app identifier:
```ruby
app_identifier("com.fueki.wallet")
apple_id("developer@fueki.io")
itc_team_id("TEAM_ID")
team_id("TEAM_ID")
```

### Matchfile
Configure certificate storage:
```ruby
git_url("https://github.com/fueki/certificates")
app_identifier(["com.fueki.wallet"])
team_id("TEAM_ID")
```

## 🛠️ Local Development

### Prerequisites
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install CocoaPods
gem install cocoapods

# Install fastlane
gem install fastlane

# Install SwiftLint
brew install swiftlint
```

### Run CI Pipeline Locally
```bash
# Run linting
bash ios/scripts/lint.sh

# Run tests
bash ios/scripts/test.sh

# Build app
bash ios/scripts/build.sh

# Generate coverage
bash ios/scripts/code-coverage.sh

# Full CI pipeline
fastlane ios ci
```

## 📊 Code Coverage

Minimum required coverage: **80%**

Coverage reports are generated in multiple formats:
- HTML: `ios/fastlane/test_output/coverage/index.html`
- XML (Cobertura): `ios/fastlane/test_output/coverage/coverage.xml`
- JSON: `ios/fastlane/test_output/coverage/coverage.json`

View coverage locally:
```bash
open ios/fastlane/test_output/coverage/index.html
```

## 🔄 CI/CD Pipeline Flow

### Pull Request Flow
```
Push/PR → Lint → Unit Tests → Build → Quality Gates → Merge
```

### Release Flow (Beta)
```
Tag/Manual → Tests → Build → Code Sign → TestFlight → Notify
```

### Release Flow (Production)
```
Manual → Tests → Build → Code Sign → Screenshots → App Store → Tag → Notify
```

## 📱 Device Matrix

### CI Tests
- iPhone 15 Pro
- iPhone SE (3rd generation)

### Full Test Suite
- iPhone 15 Pro Max
- iPhone 15 Pro
- iPhone 14
- iPhone SE (3rd generation)
- iPad Pro (12.9-inch)

## 🎯 Best Practices

1. **Always run tests locally** before pushing
2. **Keep code coverage above 80%**
3. **Fix all SwiftLint warnings** before merging
4. **Use feature branches** for development
5. **Test on multiple devices** before release
6. **Review test results** in GitHub Actions artifacts
7. **Monitor TestFlight feedback** before App Store release

## 🐛 Troubleshooting

### Build Failures
```bash
# Clean derived data
rm -rf ios/DerivedData

# Clean build folder
rm -rf ios/build

# Reinstall dependencies
cd ios && pod install --repo-update
```

### Code Signing Issues
```bash
# Re-sync certificates
fastlane ios sync_certs

# Reset match
fastlane match nuke development
fastlane match nuke distribution
fastlane ios match_setup type:development
fastlane ios match_setup type:appstore
```

### Test Failures
```bash
# Reset simulator
xcrun simctl shutdown all
xcrun simctl erase all

# Rebuild and test
bash ios/scripts/test.sh
```

## 📚 Documentation

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [Xcode Build Settings](https://developer.apple.com/documentation/xcode/build-settings-reference)

## 🔄 Maintenance

### Weekly Tasks
- Review test coverage trends
- Update dependencies
- Check for SwiftLint updates

### Monthly Tasks
- Rotate code signing certificates (if needed)
- Review and update CI/CD configurations
- Audit test suite performance

### Quarterly Tasks
- Update Xcode version in workflows
- Review and optimize build times
- Update fastlane and plugins

---

**Maintained by**: Fueki Wallet DevOps Team
**Last Updated**: 2025-10-21
