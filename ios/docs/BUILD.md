# Fueki Wallet - Build & Deployment Guide

## Development Environment Setup

### Prerequisites

1. **macOS Requirements**
   - macOS 13.0 (Ventura) or later
   - At least 50GB free disk space
   - 8GB RAM minimum (16GB recommended)

2. **Install Xcode**
   ```bash
   # Download from App Store or
   xcode-select --install

   # Verify installation
   xcode-select -p
   # Output: /Applications/Xcode.app/Contents/Developer
   ```

3. **Install Homebrew**
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

4. **Install Dependencies**
   ```bash
   # Install CocoaPods
   sudo gem install cocoapods

   # Install SwiftLint
   brew install swiftlint

   # Install xcbeautify (optional, for better build output)
   brew install xcbeautify
   ```

### Project Setup

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd Fueki-Mobile-Wallet/ios
   ```

2. **Install Dependencies**
   ```bash
   # Using CocoaPods
   pod install

   # Or using Swift Package Manager (SPM)
   # Dependencies are managed in Xcode project
   ```

3. **Environment Configuration**
   ```bash
   # Copy example environment file
   cp .env.example .env

   # Edit with your settings
   nano .env
   ```

4. **Open Project**
   ```bash
   # If using CocoaPods
   open FuekiWallet.xcworkspace

   # If using SPM only
   open FuekiWallet.xcodeproj
   ```

## Build Configurations

### 1. Debug Build

**Purpose**: Development and testing

```bash
# Command line build
xcodebuild \
  -workspace FuekiWallet.xcworkspace \
  -scheme FuekiWallet \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# Or in Xcode: Product > Build (⌘B)
```

**Configuration Settings**:
- Optimization Level: None
- Swift Compilation Mode: Incremental
- Debug Information: Yes
- Assertions: Enabled
- API Environment: Staging

### 2. Release Build

**Purpose**: Production deployment

```bash
# Command line build
xcodebuild \
  -workspace FuekiWallet.xcworkspace \
  -scheme FuekiWallet \
  -configuration Release \
  -destination generic/platform=iOS \
  -archivePath ./build/FuekiWallet.xcarchive \
  archive

# Or in Xcode: Product > Archive
```

**Configuration Settings**:
- Optimization Level: -O (Fast)
- Swift Compilation Mode: Whole Module
- Debug Information: Strip
- Assertions: Disabled
- API Environment: Production

### 3. Staging Build

**Purpose**: Pre-production testing

**Configuration Settings**:
- Similar to Release
- API Environment: Staging
- Additional logging enabled

## Build Schemes

### Available Schemes

1. **FuekiWallet** - Main app target
2. **FuekiWallet-Staging** - Staging environment
3. **FuekiWallet-Tests** - Test target

### Scheme Configuration

```
Edit Scheme > Run > Info
- Build Configuration: Debug/Release
- Executable: FuekiWallet.app

Edit Scheme > Run > Arguments
- Environment Variables:
  - API_BASE_URL: $(API_BASE_URL)
  - ENVIRONMENT: $(ENVIRONMENT)
```

## Code Signing

### 1. Development Signing

```bash
# Automatic signing (recommended for development)
# Xcode > Project Settings > Signing & Capabilities
# ✓ Automatically manage signing
# Team: [Your Team]
```

### 2. Distribution Signing

**Manual Signing for App Store**:

1. **Create Certificates**
   ```bash
   # Via Xcode or Apple Developer Portal
   # - Development Certificate
   # - Distribution Certificate
   ```

2. **Create Provisioning Profiles**
   - App Store Profile
   - Ad Hoc Profile (for testing)
   - Development Profile

3. **Configure in Xcode**
   ```
   Signing & Capabilities
   ├── Debug
   │   ├── Certificate: iPhone Developer
   │   └── Profile: Development
   └── Release
       ├── Certificate: iPhone Distribution
       └── Profile: App Store
   ```

### 3. Fastlane Setup (Recommended)

```bash
# Install Fastlane
sudo gem install fastlane

# Initialize
cd ios
fastlane init

# Configure match for code signing
fastlane match init
```

**Matchfile**:
```ruby
git_url("git@github.com:your-org/certificates.git")
storage_mode("git")
type("appstore")
app_identifier(["com.fueki.wallet"])
username("your-apple-id@email.com")
```

## Building with Fastlane

### 1. Install Fastlane

```bash
# Install via Homebrew
brew install fastlane

# Or via RubyGems
sudo gem install fastlane -NV
```

### 2. Create Fastfile

```ruby
# ios/fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Run tests"
  lane :test do
    run_tests(
      scheme: "FuekiWallet",
      devices: ["iPhone 15"]
    )
  end

  desc "Build for development"
  lane :dev do
    match(type: "development")
    gym(
      scheme: "FuekiWallet",
      configuration: "Debug",
      export_method: "development"
    )
  end

  desc "Build and deploy to TestFlight"
  lane :beta do
    increment_build_number
    match(type: "appstore")
    gym(
      scheme: "FuekiWallet",
      configuration: "Release",
      export_method: "app-store"
    )
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end

  desc "Deploy to App Store"
  lane :release do
    increment_build_number
    match(type: "appstore")
    gym(
      scheme: "FuekiWallet",
      configuration: "Release",
      export_method: "app-store"
    )
    upload_to_app_store(
      submit_for_review: false,
      automatic_release: false
    )
  end
end
```

### 3. Run Lanes

```bash
# Run tests
fastlane test

# Development build
fastlane dev

# TestFlight upload
fastlane beta

# App Store upload
fastlane release
```

## Continuous Integration

### GitHub Actions

Create `.github/workflows/ios.yml`:

```yaml
name: iOS CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  build:
    runs-on: macos-13

    steps:
    - uses: actions/checkout@v3

    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.0'

    - name: Install Dependencies
      run: |
        cd ios
        pod install

    - name: Run Tests
      run: |
        xcodebuild test \
          -workspace ios/FuekiWallet.xcworkspace \
          -scheme FuekiWallet \
          -destination 'platform=iOS Simulator,name=iPhone 15' \
          | xcbeautify

    - name: Build
      run: |
        xcodebuild build \
          -workspace ios/FuekiWallet.xcworkspace \
          -scheme FuekiWallet \
          -configuration Release \
          -destination 'generic/platform=iOS' \
          | xcbeautify

    - name: Upload Build Artifacts
      uses: actions/upload-artifact@v3
      with:
        name: build
        path: |
          ios/build/
```

### Xcode Cloud

**Configure in Xcode**:
1. Product > Xcode Cloud > Create Workflow
2. Select repository
3. Configure build actions
4. Set environment variables
5. Enable TestFlight distribution

## Build Optimization

### 1. Build Time Optimization

**Xcode Build Settings**:
```
Build Settings
├── Compilation Mode
│   ├── Debug: Incremental
│   └── Release: Whole Module
├── Optimization Level
│   ├── Debug: None
│   └── Release: -O
├── Enable Index-While-Building
│   └── Yes
└── Build Active Architecture Only
    ├── Debug: Yes
    └── Release: No
```

**Tips**:
```bash
# Use new build system
File > Workspace Settings > Build System > New Build System

# Enable parallelization
defaults write com.apple.dt.Xcode BuildSystemScheduleInherentlyParallelCommandsExclusively -bool NO

# Increase concurrent build tasks
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks 8
```

### 2. Derived Data Management

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Or use Xcode
# Product > Clean Build Folder (⇧⌘K)
```

### 3. Modular Build

```swift
// Split into frameworks for faster incremental builds
// - FuekiCore.framework
// - FuekiUI.framework
// - FuekiNetwork.framework
```

## App Thinning

### 1. Enable Bitcode

```
Build Settings > Build Options > Enable Bitcode = YES
```

### 2. Asset Catalogs

- Use asset catalogs for images
- Enable automatic asset slicing
- Provide @1x, @2x, @3x variants

### 3. On-Demand Resources

```swift
// For large assets not needed at launch
let resourceRequest = NSBundleResourceRequest(tags: ["level2"])
resourceRequest.beginAccessingResources { error in
    // Use resources
}
```

## Versioning

### Semantic Versioning

Format: `MAJOR.MINOR.PATCH (BUILD)`

Example: `1.2.3 (45)`

### Automated Version Bumping

```bash
# Using agvtool
agvtool next-version -all  # Increment build number
agvtool new-marketing-version 1.2.3  # Set version

# Using Fastlane
fastlane increment_build_number
fastlane increment_version_number bump_type:patch
```

### Version Management Script

```bash
#!/bin/bash
# scripts/bump_version.sh

VERSION_TYPE=$1  # major, minor, patch

if [ "$VERSION_TYPE" == "major" ]; then
    fastlane increment_version_number bump_type:major
elif [ "$VERSION_TYPE" == "minor" ]; then
    fastlane increment_version_number bump_type:minor
else
    fastlane increment_version_number bump_type:patch
fi

fastlane increment_build_number

git add .
git commit -m "Bump version to $(fastlane get_version_number)"
```

## Distribution

### 1. TestFlight Distribution

```bash
# Via Fastlane
fastlane beta

# Or upload manually
# 1. Archive in Xcode (Product > Archive)
# 2. Window > Organizer
# 3. Select archive > Distribute App > App Store Connect
# 4. Upload
```

### 2. Ad Hoc Distribution

```bash
# Create IPA
fastlane gym \
  --export_method ad-hoc \
  --output_directory ./build

# Distribute via email or file sharing
```

### 3. Enterprise Distribution

```bash
# Build with enterprise certificate
fastlane gym \
  --export_method enterprise \
  --output_directory ./build
```

## Troubleshooting

### Common Build Issues

1. **Code Signing Issues**
   ```bash
   # Delete derived data
   rm -rf ~/Library/Developer/Xcode/DerivedData

   # Refresh provisioning profiles
   fastlane match nuke development
   fastlane match development
   ```

2. **Pod Installation Issues**
   ```bash
   pod deintegrate
   pod install --repo-update
   ```

3. **Build Failures**
   ```bash
   # Clean and rebuild
   xcodebuild clean
   xcodebuild build
   ```

## Build Scripts

### Pre-build Script

```bash
#!/bin/bash
# Pre-build: Generate build info

BUILD_NUMBER=$(xcodebuild -showBuildSettings | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
echo "Build: $BUILD_NUMBER" > BuildInfo.txt
```

### Post-build Script

```bash
#!/bin/bash
# Post-build: Upload dSYMs to crash reporting

find "$DWARF_DSYM_FOLDER_PATH" -name "*.dSYM" | xargs -I \{\} $PODS_ROOT/FirebaseCrashlytics/upload-symbols -gsp "$PROJECT_DIR/GoogleService-Info.plist" -p ios \{\}
```

---

For deployment to production, see [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md).
