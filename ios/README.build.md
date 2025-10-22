# Fueki Mobile Wallet - iOS Build System

## Overview

This directory contains the complete production build configuration for the Fueki Mobile Wallet iOS app, including:

- **Fastlane** automation for building, testing, and deployment
- **Code signing** with Match for certificate management
- **CI/CD pipelines** with GitHub Actions
- **Build scripts** for version and build number management
- **App Store metadata** for app listing

## Directory Structure

```
ios/
├── fastlane/
│   ├── Fastfile              # Main Fastlane configuration
│   ├── Appfile               # App Store Connect credentials
│   ├── Matchfile             # Code signing configuration
│   ├── Gymfile               # Build settings
│   ├── Pluginfile            # Fastlane plugins
│   └── metadata/             # App Store metadata
├── scripts/
│   ├── increment_build.sh    # Build number automation
│   ├── release_notes.sh      # Release notes generation
│   └── setup_signing.sh      # Code signing setup
├── ExportOptions.plist       # Archive export configuration
└── README.build.md           # This file
```

## Prerequisites

### Local Development

1. **Xcode** 15.0 or later
2. **Ruby** 3.2 or later
3. **Bundler** for Ruby dependency management
4. **CocoaPods** for iOS dependencies
5. **Fastlane** installed via Bundler

```bash
# Install Ruby dependencies
cd ios
bundle install

# Install CocoaPods dependencies
pod install
```

### CI/CD Setup

Required GitHub Secrets:

- `APPLE_ID` - Apple Developer account email
- `TEAM_ID` - Apple Developer Team ID
- `ITC_TEAM_ID` - App Store Connect Team ID
- `MATCH_PASSWORD` - Password for Match certificate encryption
- `MATCH_GIT_URL` - Git repository URL for Match certificates
- `MATCH_GIT_BASIC_AUTHORIZATION` - Base64 encoded credentials for Match repo
- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` - App-specific password for App Store Connect
- `SLACK_WEBHOOK_URL` - (Optional) Slack webhook for notifications

## Fastlane Lanes

### Build Lanes

```bash
# Build for development
fastlane build_dev

# Build for staging/TestFlight
fastlane build_staging

# Build for production/App Store
fastlane build_production
```

### Testing Lanes

```bash
# Run unit tests
fastlane test

# Run UI tests
fastlane test_ui

# Run tests with coverage
fastlane test_coverage
```

### Deployment Lanes

```bash
# Deploy to TestFlight
fastlane deploy_testflight

# Deploy to App Store (manual review)
fastlane deploy_appstore

# Deploy to App Store and submit for review
fastlane deploy_appstore submit:true
```

### Code Signing Lanes

```bash
# Setup certificates for development
fastlane setup_certificates type:development

# Setup certificates for App Store
fastlane setup_certificates type:appstore

# Sync all certificates
fastlane sync_certificates

# Reset certificates (use with caution)
fastlane reset_certificates type:development
```

### Version Management Lanes

```bash
# Bump patch version (1.0.0 -> 1.0.1)
fastlane bump_patch

# Bump minor version (1.0.0 -> 1.1.0)
fastlane bump_minor

# Bump major version (1.0.0 -> 2.0.0)
fastlane bump_major

# Set specific version
fastlane set_version version:1.2.0
```

### Metadata & Screenshots

```bash
# Generate screenshots
fastlane screenshots

# Upload metadata to App Store
fastlane upload_metadata
```

### Utility Lanes

```bash
# Clean build artifacts
fastlane clean

# Verify setup
fastlane verify
```

## Build Scripts

### Increment Build Number

Automatically increments build number based on:
- CI build number (GitHub Actions, Jenkins, etc.)
- Git commit count
- Current build number + 1

```bash
cd ios/scripts
chmod +x increment_build.sh
./increment_build.sh
```

### Generate Release Notes

Generates release notes from git commits:

```bash
cd ios/scripts
chmod +x release_notes.sh
./release_notes.sh [output_file] [commits_limit] [tag_pattern]
```

Categorizes commits by type:
- `feat:` - New Features
- `fix:` - Bug Fixes
- `improve:`, `enhance:`, `refactor:` - Improvements
- `security:` - Security fixes
- `perf:` - Performance improvements
- `docs:` - Documentation

### Setup Code Signing

Configures certificates and provisioning profiles for CI/CD:

```bash
cd ios/scripts
chmod +x setup_signing.sh
./setup_signing.sh
```

## CI/CD Workflows

### Build and Deploy (`ios-build.yml`)

Triggered on:
- Push to `main`, `develop`, `release/**` branches
- Tags starting with `v*`
- Pull requests
- Manual workflow dispatch

Jobs:
1. **Lint** - Code quality checks with SwiftLint
2. **Test** - Run unit and UI tests with coverage
3. **Build** - Build app for all environments
4. **Deploy TestFlight** - Deploy staging builds
5. **Deploy App Store** - Deploy production builds

### Release Automation (`ios-release.yml`)

Manual workflow for creating releases:

Inputs:
- `version_bump` - Version bump type (patch, minor, major, custom)
- `custom_version` - Custom version number
- `deploy_testflight` - Deploy to TestFlight
- `deploy_appstore` - Deploy to App Store

Steps:
1. Bump version number
2. Generate release notes
3. Commit and tag release
4. Build production app
5. Deploy to TestFlight/App Store
6. Create GitHub release

## Environment Configuration

### Development

- Bundle ID: `com.fueki.wallet.dev`
- App Name: `Fueki Dev`
- Export Method: `development`
- Configuration: `Debug`

### Staging

- Bundle ID: `com.fueki.wallet.staging`
- App Name: `Fueki Staging`
- Export Method: `app-store`
- Configuration: `Release`

### Production

- Bundle ID: `com.fueki.wallet`
- App Name: `Fueki Wallet`
- Export Method: `app-store`
- Configuration: `Release`

## Code Signing with Match

Match stores certificates and provisioning profiles in a Git repository:

### Initial Setup

```bash
# Initialize Match
fastlane match init

# Generate certificates for all environments
fastlane match development
fastlane match appstore
```

### Using Match in CI/CD

```bash
# Set environment variables
export MATCH_PASSWORD="your_password"
export MATCH_GIT_URL="git@github.com:your-org/certificates.git"

# Install certificates (read-only)
fastlane match appstore --readonly
```

### Nuke and Recreate

If certificates are invalid or expired:

```bash
# Nuke certificates (CAUTION: Irreversible)
fastlane match nuke development
fastlane match nuke appstore

# Recreate certificates
fastlane setup_certificates type:development
fastlane setup_certificates type:appstore
```

## App Store Metadata

Metadata files for App Store listing:

```
ios/metadata/en-US/
├── name.txt              # App name
├── subtitle.txt          # Subtitle
├── description.txt       # Full description
├── keywords.txt          # Search keywords
├── promotional_text.txt  # Promotional text
├── marketing_url.txt     # Marketing website
├── privacy_url.txt       # Privacy policy URL
├── support_url.txt       # Support URL
└── review_information/   # App Review contact info
```

### Updating Metadata

1. Edit text files in `ios/metadata/en-US/`
2. Upload to App Store Connect:

```bash
fastlane upload_metadata
```

## Common Workflows

### Local Development Build

```bash
cd ios
bundle exec fastlane build_dev
```

### TestFlight Release

```bash
cd ios
bundle exec fastlane deploy_testflight
```

### Production Release

```bash
cd ios

# Bump version
bundle exec fastlane bump_minor

# Build and deploy
bundle exec fastlane deploy_appstore submit:false
```

### Emergency Hotfix

```bash
cd ios

# Bump patch version
bundle exec fastlane bump_patch

# Build and deploy immediately
bundle exec fastlane deploy_appstore submit:true auto_release:true
```

## Troubleshooting

### Build Failures

```bash
# Clean build artifacts
fastlane clean

# Verify setup
fastlane verify

# Rebuild
fastlane build_production
```

### Code Signing Issues

```bash
# Check certificates
security find-identity -v -p codesigning

# Reinstall certificates
fastlane setup_certificates type:appstore

# Check provisioning profiles
fastlane sigh list
```

### Match Issues

```bash
# Reset Match
fastlane match nuke appstore --force
fastlane setup_certificates type:appstore
```

### Test Failures

```bash
# Run tests with verbose output
fastlane test --verbose

# Check test results
open ios/test_output/report.html
```

## Performance Optimization

### Build Time

- Use incremental builds
- Enable parallel testing
- Cache CocoaPods dependencies
- Use ccache for compilation

### CI/CD Optimization

- Cache Ruby gems
- Cache CocoaPods
- Use matrix builds for parallel execution
- Skip unnecessary steps with conditionals

## Security Best Practices

1. **Never commit secrets** to version control
2. **Use environment variables** for sensitive data
3. **Enable automatic security updates** in GitHub
4. **Regularly rotate** App Store Connect passwords
5. **Use App-Specific Passwords** for CI/CD
6. **Enable 2FA** on Apple Developer account
7. **Restrict access** to Match certificates repository
8. **Audit dependencies** regularly

## Monitoring and Analytics

### Build Metrics

- Build duration
- Test coverage
- Build success rate
- Deployment frequency

### App Store Metrics

- Crash rate
- User reviews and ratings
- Download statistics
- Revenue tracking

## Support

For issues or questions:

- GitHub Issues: https://github.com/your-org/fueki-mobile-wallet/issues
- Documentation: https://docs.fueki.com
- Email: support@fueki.com

## License

Copyright © 2024 Fueki. All rights reserved.
