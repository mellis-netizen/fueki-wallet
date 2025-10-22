# Xcode Project File Issue - Resolution Guide

## Problem
The Xcode project file (`FuekiWallet.xcodeproj/project.pbxproj`) has become corrupted, causing CocoaPods to fail with:
```
[Xcodeproj] Type checking error: got `XCBuildConfiguration` for attribute: Attribute `children`
```

## Root Cause
The project.pbxproj file has internal structure corruption where build configuration objects are being referenced incorrectly in the project tree.

## Solutions (in order of preference)

### Solution 1: Fix with Xcode (RECOMMENDED)
1. Open Xcode
2. File → Open → Select `FuekiWallet.xcodeproj`
3. Let Xcode auto-fix any project issues
4. Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)
5. Close Xcode
6. Run `pod install` again

### Solution 2: Recreate Project from Scratch
If Xcode cannot fix the project:

1. Backup current files:
```bash
cd ios
cp -r FuekiWallet FuekiWallet.backup
cp Podfile Podfile.backup
```

2. Create new Xcode project:
   - Open Xcode
   - File → New → Project
   - iOS → App
   - Product Name: FuekiWallet
   - Interface: SwiftUI or UIKit (match original)
   - Save in `ios/` directory

3. Restore source files and configurations:
   - Copy files from `FuekiWallet.backup/` to new project
   - Add files to Xcode project
   - Configure build settings from xcconfig files
   - Run `pod install`

### Solution 3: Manual pbxproj Edit (ADVANCED)
Only attempt if familiar with Xcode project file format:

1. Open `FuekiWallet.xcodeproj/project.pbxproj` in text editor
2. Search for UUID `13B07F961A680F5B00A75B9A`
3. Verify it's correctly referenced only in appropriate sections
4. Remove any duplicate or misplaced references
5. Save and try `pod install`

## Temporary Workaround - Use SPM Only

Since CocoaPods is failing, use Swift Package Manager exclusively:

1. Open `FuekiWallet.xcodeproj` in Xcode
2. File → Add Packages
3. Add each dependency from `Package.swift`:
   - https://github.com/krzyzanowskim/CryptoSwift.git
   - https://github.com/attaswift/BigInt.git
   - https://github.com/kishikawakatsumi/KeychainAccess.git
   - https://github.com/web3swift-team/web3swift.git
   - https://github.com/Alamofire/Alamofire.git

## Prevention
- Always commit working project files to version control
- Use Xcode's project format validation regularly
- Avoid manual edits to `.pbxproj` files
- Keep Xcode and CocoaPods up to date

## Verification
After fixing, verify with:
```bash
cd ios
pod install
xcodebuild -workspace FuekiWallet.xcworkspace -scheme FuekiWallet -configuration Debug clean
```

## Next Steps
1. Try Solution 1 first (let Xcode fix it)
2. If that fails, use Solution 2 (recreate project)
3. Once fixed, immediately commit to version control
4. Document any custom Xcode settings for future reference
