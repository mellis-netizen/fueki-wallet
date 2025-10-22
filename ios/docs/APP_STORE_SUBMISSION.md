# App Store Submission Guide - Fueki Wallet

**Version:** 1.0
**Last Updated:** October 21, 2025
**Status:** Pre-Submission Checklist

---

## Prerequisites

Before beginning the App Store submission process, ensure all items from the Production Readiness Report are addressed, particularly the **CRITICAL** blockers.

---

## Phase 1: Pre-Submission Preparation

### 1.1 Apple Developer Account Setup

**Required:**
- [ ] Active Apple Developer Program membership ($99/year)
- [ ] App Store Connect access
- [ ] Two-factor authentication enabled
- [ ] Payment information configured

**Team Configuration:**
- [ ] Team roles assigned (Admin, Developer, Marketing)
- [ ] App Manager permissions granted
- [ ] TestFlight access configured

### 1.2 App Store Connect Configuration

#### Create App Record
```
1. Log in to App Store Connect (appstoreconnect.apple.com)
2. Navigate to "My Apps"
3. Click "+" → "New App"
4. Fill in required information:
   - Platform: iOS
   - Name: Fueki Wallet
   - Primary Language: English (U.S.)
   - Bundle ID: com.fueki.wallet
   - SKU: FUEKI-WALLET-001
   - User Access: Full Access
```

#### App Information
```
Name: Fueki Wallet
Subtitle: Secure Multi-Chain Crypto Wallet
Category: Finance
    Secondary: Utilities

Privacy Policy URL: https://fueki.com/privacy
Terms of Service URL: https://fueki.com/terms
Support URL: https://support.fueki.com
Marketing URL: https://fueki.com
```

### 1.3 Create Privacy Policy & Terms

**Privacy Policy Must Include:**
- Data collection practices
- How wallet data is stored (local only, Keychain)
- Biometric data usage (Face ID/Touch ID)
- Third-party services (blockchain APIs, payment ramps)
- User rights (data access, deletion)
- Contact information

**Example Template:**
```markdown
# Privacy Policy - Fueki Wallet

Last Updated: [Date]

## 1. Information We Collect
- Wallet addresses (stored locally on device)
- Transaction history (stored locally on device)
- Biometric authentication data (stored in device Secure Enclave)

## 2. How We Use Information
- To provide wallet services
- To authenticate transactions
- To display transaction history

## 3. Data Storage
All sensitive data is stored locally on your device using iOS Keychain
and Secure Enclave. We do not have access to your private keys or
biometric data.

## 4. Third-Party Services
- Blockchain RPC providers (for balance queries)
- MoonPay/Ramp Network (for buy/sell crypto)

## 5. Contact
Email: privacy@fueki.com
```

### 1.4 App Store Assets Preparation

#### App Icon Requirements
Create icons for all required sizes:

**iPhone:**
- 180 x 180 px (60pt @3x)
- 120 x 120 px (60pt @2x)
- 87 x 87 px (29pt @3x)
- 58 x 58 px (29pt @2x)

**iPad:**
- 167 x 167 px (83.5pt @2x)
- 152 x 152 px (76pt @2x)
- 58 x 58 px (29pt @2x)

**App Store:**
- 1024 x 1024 px (required, no alpha channel)

**Design Guidelines:**
- No alpha channel/transparency
- Square shape (iOS rounds corners automatically)
- 72 DPI resolution
- RGB color space
- PNG or JPEG format

#### Screenshot Requirements

**iPhone 6.9" (iPhone 16 Pro Max) - REQUIRED**
- Size: 1320 x 2868 px
- Minimum: 1 screenshot
- Maximum: 10 screenshots

**iPhone 6.7" (iPhone 15 Pro Max) - REQUIRED**
- Size: 1290 x 2796 px
- Minimum: 1 screenshot
- Maximum: 10 screenshots

**iPhone 6.5" (iPhone 14 Plus, 11 Pro Max) - REQUIRED**
- Size: 1284 x 2778 px
- Minimum: 1 screenshot
- Maximum: 10 screenshots

**iPhone 5.5" (iPhone 8 Plus)**
- Size: 1242 x 2208 px

**iPad Pro 12.9" (6th Gen)**
- Size: 2048 x 2732 px

**Screenshot Content Guidelines:**
- Show actual app UI (not concept/marketing renders)
- Include status bar
- Can add text overlays explaining features
- First 3 screenshots are most important
- Landscape and portrait orientations

**Recommended Screenshots:**
1. Wallet dashboard (showing balance)
2. Send crypto screen
3. Receive crypto with QR code
4. Transaction history
5. Buy crypto screen
6. Security settings (biometric)

#### App Preview Video (Optional but Recommended)

**Specifications:**
- Format: .MOV or .MP4
- Codec: H.264 or HEVC
- Duration: 15-30 seconds
- Resolution: Match screenshot sizes
- Orientation: Portrait or landscape
- File size: Max 500 MB

**Content Ideas:**
- Opening wallet
- Checking balance
- Sending crypto
- Scanning QR code
- Biometric authentication

---

## Phase 2: Code Preparation

### 2.1 Privacy Manifest (CRITICAL)

Create `/ios/FuekiWallet/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>

    <key>NSPrivacyTrackingDomains</key>
    <array/>

    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeFinancialInfo</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeSensitiveInfo</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>

    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>35F9.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

**Add to Xcode Project:**
1. Drag `PrivacyInfo.xcprivacy` into Xcode project
2. Ensure it's added to FuekiWallet target
3. Verify in Build Phases → Copy Bundle Resources

### 2.2 Remove Debug Code

**Find and remove all print() statements:**
```bash
# Search for debug statements
grep -r "print(" --include="*.swift" src/ > debug_statements.txt

# Replace with OSLog (recommended)
import OSLog
let logger = Logger(subsystem: "com.fueki.wallet", category: "general")
logger.info("User authenticated")
```

**Conditional Compilation for Debug:**
```swift
#if DEBUG
logger.debug("Debug info: \(variable)")
#endif
```

### 2.3 Version Configuration

**In Xcode:**
1. Select project in navigator
2. Select FuekiWallet target
3. Go to "General" tab
4. Set:
   - Version: 1.0.0 (MARKETING_VERSION)
   - Build: 1 (CURRENT_PROJECT_VERSION)

**Or in project.pbxproj:**
```
MARKETING_VERSION = 1.0.0;
CURRENT_PROJECT_VERSION = 1;
```

### 2.4 Code Signing Configuration

**Automatic Signing (Recommended):**
1. Select FuekiWallet target
2. Go to "Signing & Capabilities"
3. Check "Automatically manage signing"
4. Select your team
5. Xcode will create provisioning profiles

**Manual Signing:**
1. Create App ID in Apple Developer portal
2. Create Distribution Certificate
3. Create App Store provisioning profile
4. Download and install profiles
5. Select profiles in Xcode

**Update Entitlements for Production:**
```xml
<!-- FuekiWallet.entitlements -->
<key>aps-environment</key>
<string>production</string> <!-- Change from development -->
```

### 2.5 Build Configuration

**Release Build Settings:**
```
SWIFT_OPTIMIZATION_LEVEL = -O (Optimize for Speed)
SWIFT_COMPILATION_MODE = wholemodule
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
ENABLE_BITCODE = NO (deprecated)
VALIDATE_PRODUCT = YES
```

**Preprocessor Macros:**
```
DEBUG = 0 (for Release configuration)
```

---

## Phase 3: Testing & Validation

### 3.1 Pre-Submission Testing

**Device Testing Checklist:**
- [ ] Test on physical iPhone (not just simulator)
- [ ] Test Face ID on device with Face ID
- [ ] Test Touch ID on device with Touch ID
- [ ] Test on iPad (if iPad support included)
- [ ] Test on different iOS versions (16.0 minimum)
- [ ] Test with poor network connection
- [ ] Test with airplane mode
- [ ] Test background app refresh
- [ ] Test push notifications

**Functional Testing:**
- [ ] Create new wallet
- [ ] Import existing wallet
- [ ] Send transaction
- [ ] Receive transaction
- [ ] Buy crypto (testnet)
- [ ] Sell crypto (testnet)
- [ ] Scan QR code
- [ ] Biometric authentication
- [ ] App launch authentication
- [ ] Transaction signing with biometrics

**Performance Testing:**
- [ ] Launch time < 2 seconds
- [ ] UI maintains 60 FPS
- [ ] Memory usage < 100 MB
- [ ] No memory leaks (Instruments)
- [ ] Battery usage acceptable
- [ ] Network requests optimized

### 3.2 TestFlight Beta Testing

**Setup TestFlight:**
1. In App Store Connect, go to "TestFlight"
2. Create internal testing group
3. Add internal testers (up to 100)
4. Upload build (see Phase 4)
5. Add external testing group (optional)
6. Submit for Beta App Review

**Beta Testing Checklist:**
- [ ] 10+ internal testers
- [ ] Test for 1-2 weeks
- [ ] Collect feedback
- [ ] Monitor crash reports
- [ ] Fix critical bugs
- [ ] Re-upload if needed

### 3.3 Compliance Checks

**Export Compliance:**
```
Does your app use encryption?
YES

Is your app exempt from encryption export regulations?
NO (uses standard encryption)

Does your app qualify for Encryption Registration exemption?
YES (only uses encryption in iOS SDK)

ITSAppUsesNonExemptEncryption: NO (in Info.plist)
```

**Content Rights:**
- [ ] All content is original or properly licensed
- [ ] No copyright infringement
- [ ] No trademark violations
- [ ] All third-party libraries properly attributed

**Age Rating:**
```
Recommended: 4+ (No Objectionable Content)

Content Descriptors:
- None

Age Rating: 4+
```

---

## Phase 4: Build & Archive

### 4.1 Create Archive

**Via Xcode:**
1. Select "Any iOS Device (arm64)" as destination
2. Product → Archive
3. Wait for archive to complete
4. Organizer window opens automatically

**Via Command Line:**
```bash
# Clean build folder
xcodebuild clean -project FuekiWallet.xcodeproj -scheme FuekiWallet

# Create archive
xcodebuild archive \
  -project FuekiWallet.xcodeproj \
  -scheme FuekiWallet \
  -configuration Release \
  -archivePath ./build/FuekiWallet.xcarchive \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  PROVISIONING_PROFILE_SPECIFIER="FuekiWallet AppStore"
```

### 4.2 Validate Archive

**Before uploading:**
1. In Organizer, select archive
2. Click "Validate App"
3. Select distribution method: "App Store Connect"
4. Select team
5. Choose automatic or manual signing
6. Click "Validate"
7. Fix any errors that appear

**Common Validation Errors:**
- Missing icons
- Invalid provisioning profile
- Missing entitlements
- Privacy manifest issues
- Invalid bundle identifier

### 4.3 Upload to App Store Connect

**Via Xcode Organizer:**
1. Select validated archive
2. Click "Distribute App"
3. Select "App Store Connect"
4. Select "Upload"
5. Choose signing options
6. Review IPA contents
7. Click "Upload"
8. Wait for processing

**Via Command Line (Fastlane recommended):**
```bash
# Export IPA
xcodebuild -exportArchive \
  -archivePath ./build/FuekiWallet.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist

# Upload with altool
xcrun altool --upload-app \
  --type ios \
  --file ./build/FuekiWallet.ipa \
  --username "your@email.com" \
  --password "@keychain:APP_STORE_PASSWORD"
```

**ExportOptions.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

---

## Phase 5: App Store Connect Configuration

### 5.1 Version Information

**App Information:**
```
Name: Fueki Wallet
Subtitle: Secure Multi-Chain Crypto Wallet
```

**Description:**
```
Fueki Wallet is a secure, non-custodial cryptocurrency wallet that gives
you complete control over your digital assets.

KEY FEATURES:
• Multi-Chain Support - Bitcoin, Ethereum, and more
• Biometric Security - Face ID and Touch ID protection
• Non-Custodial - You control your private keys
• Buy & Sell Crypto - Integrated payment ramps
• QR Code Scanner - Easy address scanning
• Transaction History - Track all your transactions
• Secure Storage - iOS Keychain and Secure Enclave

SECURITY:
• Your keys, your crypto - we never have access
• Hardware-backed encryption via Secure Enclave
• Biometric authentication for transactions
• Open-source and audited code

PRIVACY:
• No account required
• No personal information collected
• All data stored locally on your device

Perfect for both beginners and experienced crypto users. Download Fueki
Wallet today and take control of your digital assets!

Need help? Visit support.fueki.com
```

**Keywords:**
```
crypto,wallet,bitcoin,ethereum,blockchain,cryptocurrency,secure,biometric,
non-custodial,web3,defi,nft
```
(Max 100 characters total, comma-separated)

**Promotional Text:**
```
Take control of your crypto with military-grade security and biometric
protection. Your keys, your crypto.
```
(Max 170 characters)

**Support URL:** https://support.fueki.com
**Marketing URL:** https://fueki.com

### 5.2 Pricing & Availability

```
Price: Free
Availability: All territories
```

**Pre-Order:**
- Not recommended for initial release

### 5.3 App Privacy

**Data Collection:**
Answer questionnaire in App Store Connect:

**Financial Information:**
- [x] Collect
- [ ] Used for tracking
- [ ] Linked to user
- [x] Used for app functionality

**Sensitive Information:**
- [x] Collect (biometric data)
- [ ] Used for tracking
- [ ] Linked to user
- [x] Used for app functionality
- [x] Used for fraud prevention

**Third-Party Advertising:**
- [ ] No

**Third-Party Analytics:**
- [ ] No (unless implemented)

### 5.4 App Review Information

**Contact Information:**
```
First Name: [Your Name]
Last Name: [Your Last Name]
Phone: [Your Phone]
Email: [Your Email]
```

**Demo Account:**
Not required (no login system)

**Notes:**
```
Fueki Wallet is a non-custodial cryptocurrency wallet. To fully test:

1. Create a new wallet (generates seed phrase)
2. Send test transaction (use Ethereum Sepolia testnet)
3. Receive crypto via QR code scanner
4. Test biometric authentication (Face ID/Touch ID)

IMPORTANT: This app connects to real blockchain networks. For testing,
please use testnet addresses only.

Test addresses available at: https://fueki.com/test-addresses

All crypto operations require biometric authentication.
```

**Attachment:**
Include screenshots of:
- Wallet dashboard
- Transaction signing with Face ID
- Test transaction on Sepolia testnet

---

## Phase 6: Submit for Review

### 6.1 Pre-Submission Checklist

**Required:**
- [x] App icon uploaded (1024x1024)
- [x] Screenshots uploaded (all required sizes)
- [x] App description written
- [x] Keywords optimized
- [x] Support URL active
- [x] Privacy policy URL active
- [x] Build uploaded and processed
- [x] Privacy questionnaire completed
- [x] App Review information filled
- [x] Export compliance answered
- [x] Age rating set

**Optional:**
- [ ] App preview video uploaded
- [ ] Promotional text written
- [ ] Marketing URL added
- [ ] Localizations added

### 6.2 Submit for Review

1. In App Store Connect, go to "App Store" tab
2. Select your app version (1.0)
3. Click "Add for Review"
4. Review all information
5. Accept export compliance
6. Click "Submit for Review"

**Expected Timeline:**
- Waiting for Review: 1-3 days
- In Review: 1-2 days
- Total: 2-5 days average

---

## Phase 7: During App Review

### 7.1 Monitoring

**Check Daily:**
- App Store Connect dashboard
- Resolution Center (for any questions from reviewers)
- Email for App Review messages

**Respond Quickly:**
- If reviewer requests info: respond within 24 hours
- If demo account needed: provide immediately
- If clarification needed: be thorough and polite

### 7.2 Possible Review Outcomes

**Approved (Best Case):**
- App goes "Pending Developer Release"
- You can release immediately or schedule

**Rejected (Common First Time):**
- Review rejection reasons provided
- Fix issues and resubmit
- No penalty for resubmission

**Metadata Rejected:**
- Screenshots or description need changes
- Fix and resubmit (no new build needed)

**In Review - Developer Action Needed:**
- Reviewer has questions
- Respond promptly in Resolution Center

### 7.3 Common Rejection Reasons

**For Finance Apps:**
1. Unclear about fees/charges
2. Missing risk disclaimers
3. Privacy policy too vague
4. Security concerns
5. Incomplete functionality

**How to Avoid:**
- Clearly state "no fees" if applicable
- Include crypto investment risk disclaimer
- Detailed privacy policy
- Demonstrate security features
- Test all functionality before submitting

---

## Phase 8: Post-Approval

### 8.1 Release

**Options:**
1. **Release Immediately:** App goes live automatically
2. **Manual Release:** You click "Release" when ready
3. **Scheduled Release:** Set specific date/time

**Recommendation:** Manual release for first version

### 8.2 Monitor Launch

**First 24 Hours:**
- Monitor crash reports in App Store Connect
- Check reviews and ratings
- Monitor support email
- Watch analytics dashboard

**First Week:**
- Track downloads
- Respond to all reviews
- Fix critical bugs quickly
- Prepare bug-fix update if needed

### 8.3 Updates

**Bug Fix Updates (1.0.1, 1.0.2):**
- Increment build number only
- Fast-track review if critical bug
- No marketing changes

**Feature Updates (1.1.0, 1.2.0):**
- Update version number
- Update screenshots if UI changed
- Update description
- Full review process

**Major Updates (2.0.0):**
- Significant changes
- May require new screenshots
- Update all marketing materials

---

## Phase 9: Marketing & Growth

### 9.1 App Store Optimization (ASO)

**Monitor & Improve:**
- Download conversion rate
- Keyword rankings
- Screenshot performance
- Description updates

**A/B Testing (via App Store Connect):**
- Test different app icons
- Test different screenshots
- Test description variations

### 9.2 User Acquisition

**Organic:**
- Social media marketing
- Content marketing (blog posts)
- Community engagement (Reddit, Discord)
- PR and press releases

**Paid:**
- Apple Search Ads
- Google Ads
- Social media ads
- Influencer partnerships

### 9.3 User Retention

**Best Practices:**
- Respond to all reviews
- Regular updates (monthly)
- Feature requests from users
- Push notifications (if applicable)
- Email marketing (if collecting emails)

---

## Troubleshooting Guide

### Build Issues

**Problem:** "No signing certificate"
**Solution:**
```bash
# Ensure certificate is installed
security find-identity -v -p codesigning

# If missing, download from Apple Developer portal
```

**Problem:** "Provisioning profile doesn't match"
**Solution:** Use automatic signing or regenerate profiles

**Problem:** "Missing required icon"
**Solution:** Verify all icon sizes in Assets.xcassets

### Upload Issues

**Problem:** "Invalid binary"
**Solution:** Rebuild with correct architecture (arm64)

**Problem:** "Missing compliance"
**Solution:** Answer export compliance questions

**Problem:** "Invalid Info.plist"
**Solution:** Verify all required keys present

### Review Issues

**Problem:** Rejected for "Incomplete functionality"
**Solution:** Ensure all features work on testnet

**Problem:** Rejected for "Privacy issues"
**Solution:** Add/update privacy manifest and policy

**Problem:** Rejected for "Security concerns"
**Solution:** Document security measures in review notes

---

## Checklist Summary

### Critical (Must Complete)
- [ ] Privacy manifest created
- [ ] Debug logging removed
- [ ] Production signing configured
- [ ] All app icons generated
- [ ] Screenshots captured (all sizes)
- [ ] App description written
- [ ] Privacy policy published
- [ ] Support URL active
- [ ] Build validated and uploaded
- [ ] Privacy questionnaire completed

### Recommended
- [ ] TestFlight beta testing
- [ ] Performance profiling
- [ ] App preview video
- [ ] Marketing materials
- [ ] Press kit

### Optional
- [ ] Localization
- [ ] iPad optimization
- [ ] Apple Watch companion
- [ ] Widget support

---

## Resources

**Apple Documentation:**
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help: https://developer.apple.com/help/app-store-connect/
- Privacy Manifest: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files

**Tools:**
- App Store Connect: https://appstoreconnect.apple.com
- Apple Developer Portal: https://developer.apple.com
- TestFlight: Built into App Store Connect

**Support:**
- Apple Developer Forums: https://developer.apple.com/forums/
- App Store Review: https://developer.apple.com/contact/app-store/

---

**Document Version:** 1.0
**Last Updated:** October 21, 2025
**Maintainer:** Production Validation Team
