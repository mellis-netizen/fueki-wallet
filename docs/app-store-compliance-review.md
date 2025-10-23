# Fueki Wallet - App Store Compliance Review
**Date**: October 22, 2025
**Reviewer**: App Store Compliance Specialist
**Project**: Fueki Wallet (Rebranded from Unstoppable Wallet)

---

## Executive Summary

**Overall Compliance Status**: ⚠️ **REQUIRES CRITICAL UPDATES**

This review identifies **7 critical blockers** and **12 major issues** that must be resolved before App Store submission. The Fueki Wallet rebranding requires a **NEW App Store listing** with updated bundle identifiers, assets, and metadata.

**Estimated Timeline to Submission**: 2-3 weeks (with all issues addressed)

---

## 1. REQUIRED ASSETS - Status: 🔴 INCOMPLETE

### 1.1 App Icon Requirements

**Current Status**:
- ✅ 1024x1024px icon exists: `unstop_1024.png`
- ❌ **BLOCKER**: Icon still shows "Unstoppable" branding
- ❌ **BLOCKER**: App icon must be replaced with Fueki branding

**Required Action**:
```
Create NEW app icons with Fueki branding:
- AppIcon.appiconset/fueki_1024.png (1024x1024, no alpha)
- All size variants (60@2x, 60@3x, 76, 83.5@2x, etc.)
- Widget icon (if applicable)
- Alternate icons (optional, for user customization)
```

**File Locations**:
- Main app: `./UnstoppableWallet/UnstoppableWallet/AppIcon.xcassets/AppIcon.appiconset/`
- Widget: `./UnstoppableWallet/Widget/Assets.xcassets/AppIcon.appiconset/`
- Dev builds: `./UnstoppableWallet/UnstoppableWallet/AppIconDev.xcassets/`

**Design Specifications**:
```
Fueki Logo Requirements:
- Modern, institutional-grade typography
- Color: Blue gradient (#2563EB to #3B82F6) or monochrome
- Style: Bold, geometric sans-serif
- Tagline integration: "Institutional-Grade Digital Securities" (optional for icon)
- No transparency/alpha channel for 1024x1024 version
- Should work at all sizes from 40x40 to 1024x1024
```

**Priority**: 🔴 **CRITICAL BLOCKER**

---

### 1.2 Launch Screen

**Current Status**:
- ✅ Launch screen exists: `LaunchScreen.xib`
- ⚠️ **NEEDS REVIEW**: Verify branding (likely shows "Unstoppable")
- ⚠️ **NEEDS UPDATE**: Must display "Fueki" branding

**Required Action**:
```
Update LaunchScreen.xib:
1. Replace logo image with Fueki logo
2. Update text labels (if any) to "Fueki Wallet"
3. Test on all device sizes (iPhone SE to iPhone 15 Pro Max)
4. Verify dark/light mode compatibility
```

**Priority**: 🔴 **CRITICAL**

---

### 1.3 App Store Screenshots

**Current Status**:
- ❌ **MISSING**: No screenshots found in project
- ❌ **BLOCKER**: App Store requires screenshots for submission

**Required Screenshots** (per Apple requirements):
```
iPhone 6.7" Display (iPhone 15 Pro Max):
- Minimum 3 screenshots, maximum 10
- Dimensions: 1290 x 2796 pixels

iPhone 6.5" Display (iPhone 14 Plus):
- Minimum 3 screenshots, maximum 10
- Dimensions: 1284 x 2778 pixels

iPhone 5.5" Display (iPhone 8 Plus - optional):
- For backward compatibility
- Dimensions: 1242 x 2208 pixels

iPad Pro (12.9-inch) - if supporting iPad:
- Minimum 3 screenshots
- Dimensions: 2048 x 2732 pixels
```

**Screenshot Content Recommendations**:
```
1. Main wallet dashboard (showing Fueki branding)
2. Token list with balances
3. Transaction history
4. Security features (Face ID, biometrics)
5. Token swap interface
6. Send/Receive screens
7. Settings/security options
```

**Priority**: 🔴 **CRITICAL BLOCKER**

---

### 1.4 App Preview Video (Optional but Recommended)

**Current Status**:
- ❌ Not created yet
- ✅ Recommended for "movie production" quality demo

**Specifications**:
```
- Format: .mov, .m4v, or .mp4
- Resolution: 1080p (1920x1080) or device-specific
- Duration: 15-30 seconds
- Content: Key features, security, ease of use
- Aspect ratio: 16:9 or device ratio
```

**Priority**: 🟡 **RECOMMENDED** (for high-quality presentation)

---

## 2. BUNDLE IDENTIFIER & METADATA - Status: 🔴 CRITICAL ISSUES

### 2.1 Bundle Identifier

**Current Status**:
```
Production: io.horizontalsystems.bank-wallet
Dev:        io.horizontalsystems.bank-wallet.dev
Widget:     io.horizontalsystems.bank-wallet.widget
Intent:     io.horizontalsystems.bank-wallet.intent
```

**❌ BLOCKER**: Bundle IDs still reference "horizontalsystems.bank-wallet"

**Required New Bundle IDs**:
```
Production: io.fueki.wallet
Dev:        io.fueki.wallet.dev
Widget:     io.fueki.wallet.widget
Intent:     io.fueki.wallet.intent
```

**Update Locations**:
1. `UnstoppableWallet.xcodeproj/project.pbxproj` (lines showing PRODUCT_BUNDLE_IDENTIFIER)
2. Apple Developer Portal (create new App IDs)
3. Provisioning profiles (regenerate for new bundle IDs)
4. Xcode project settings (all targets)

**IMPORTANT**: This requires a **COMPLETELY NEW App Store listing**. You **CANNOT** reuse Unstoppable Wallet's existing listing.

**Priority**: 🔴 **CRITICAL BLOCKER**

---

### 2.2 App Display Name

**Current Status**:
- Info.plist uses variable: `$(PRODUCT_NAME)`
- Likely resolves to "UnstoppableWallet" or "Unstoppable"

**Required Update**:
```xml
<key>CFBundleDisplayName</key>
<string>Fueki Wallet</string>
```

**Also Update**:
- Xcode project settings: Product Name = "Fueki Wallet"
- Marketing name in build settings
- All user-facing strings referencing app name

**Priority**: 🔴 **CRITICAL**

---

### 2.3 App Store Metadata (iTunes Connect)

**App Information**:
```
Name: Fueki Wallet
Subtitle: Institutional-Grade Digital Securities
(Max 30 characters - current subtitle is 41 chars, needs shortening)

Alternative Subtitles:
- "Institutional Digital Assets" (30 chars)
- "Pro Digital Asset Wallet" (24 chars)
- "Enterprise Crypto Wallet" (24 chars)
```

**Description** (Max 4000 characters):
```
Fueki Wallet - Institutional-Grade Digital Securities Platform

Fueki Wallet is a non-custodial cryptocurrency wallet designed for institutional
investors and professionals who demand the highest standards of security and
regulatory compliance.

KEY FEATURES:

🔐 Bank-Grade Security
• Non-custodial: You control your private keys
• Biometric authentication (Face ID / Touch ID)
• Hardware wallet support
• Multi-signature capabilities
• Secure enclave integration

💼 Institutional Features
• Multi-asset support (Bitcoin, Ethereum, 20+ blockchains)
• Regulatory-compliant token handling
• Advanced transaction management
• Institutional-grade backup systems
• KYC/AML integration ready

📊 Professional Tools
• Real-time market data and analytics
• Advanced charting and portfolio tracking
• Custom token management
• Transaction history and reporting
• Multi-wallet management

🌐 Multi-Blockchain Support
• Bitcoin (BTC)
• Ethereum (ETH) and ERC-20 tokens
• Binance Smart Chain (BSC)
• Polygon, Avalanche, Arbitrum
• Solana, TON, and more
• NFT support

🔄 DeFi Integration
• Decentralized exchange (DEX) integration
• Token swaps with best pricing
• Liquidity pool access
• Staking capabilities
• DApp browser

🎯 Enterprise Ready
• White-label solutions available
• API integration support
• Custom blockchain integrations
• Dedicated support channels
• Compliance documentation

SECURITY YOU CAN TRUST
Fueki Wallet never has access to your funds. All private keys are stored
securely on your device using industry-standard encryption. Your security
is our top priority.

DESIGNED FOR INSTITUTIONS
Built for hedge funds, family offices, and professional investors who
need a secure, compliant solution for managing digital assets.

Download Fueki Wallet today and experience institutional-grade
cryptocurrency management.

---

Visit fueki.money for more information.
Support: support@fueki.money
```

**Keywords** (Max 100 characters, comma-separated):
```
crypto,wallet,bitcoin,ethereum,defi,institutional,security,nft,blockchain,finance
```
(Current: 87 characters)

**Category**:
- Primary: Finance
- Secondary: Utilities (if applicable)

**Age Rating**: 4+ (No objectionable content)

**Priority**: 🔴 **CRITICAL**

---

## 3. INFO.PLIST COMPLIANCE - Status: ⚠️ NEEDS UPDATES

### 3.1 Usage Descriptions (Privacy Strings)

**Current Status** (PARTIALLY COMPLIANT):
```xml
✅ NSCameraUsageDescription: "Fueki needs access to camera to scan QR codes."
✅ NSFaceIDUsageDescription: "Fueki uses Face ID to unlock your wallet."
✅ NSLocalNetworkUsageDescription: "Fueki needs access to local network to discover blockchain nodes"
✅ NSPhotoLibraryAddUsageDescription: "Fueki needs access to photo library to save NFT images"
```

**✅ GOOD NEWS**: Privacy descriptions already updated with "Fueki" branding!

**Additional Recommended Descriptions**:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Fueki needs access to your photo library to select images for NFT uploads and profile customization.</string>

<key>NSContactsUsageDescription</key>
<string>Fueki can access your contacts to easily send cryptocurrency to saved addresses.</string>
(Only if contacts feature is implemented)
```

**Priority**: 🟢 **MINOR** (mostly complete)

---

### 3.2 URL Schemes

**Current Status**:
```xml
CFBundleURLName: io.fueki.wallet ✅ (UPDATED)
CFBundleURLSchemes: fueki.money ✅ (UPDATED)
```

**✅ GOOD NEWS**: URL schemes already updated!

**Verify Deep Linking**:
- Test URL: `fueki.money://wallet/send?address=0x...`
- Verify app opens from Safari/Messages
- Test Universal Links (if configured)

**Priority**: 🟢 **COMPLETE**

---

### 3.3 iCloud Container Identifiers

**Current Status**:
```xml
❌ iCloud.io.horizontalsystems.bank-wallet.shared
❌ iCloud.io.horizontalsystems.bank-wallet.shared.dev
```

**✅ PARTIALLY UPDATED** in Info.plist:
```xml
✅ iCloud.io.fueki.wallet.shared
✅ iCloud.io.fueki.wallet.shared.dev
```

**Required Action**:
1. Create new iCloud containers in Apple Developer Portal:
   - `iCloud.io.fueki.wallet.shared`
   - `iCloud.io.fueki.wallet.shared.dev`
2. Update provisioning profiles
3. Update entitlements files
4. Test iCloud sync functionality

**Priority**: 🔴 **CRITICAL** (if using iCloud)

---

### 3.4 Encryption Compliance

**Current Status**:
```xml
✅ ITSAppUsesNonExemptEncryption = false
```

**Interpretation**:
- App uses standard iOS encryption only
- No custom encryption algorithms
- Qualifies for exemption from export compliance documentation

**Required Action**:
- Verify this is accurate for your crypto wallet implementation
- If using custom encryption (likely for key storage), may need to change to `true`
- Provide Export Compliance documentation if required

**Crypto Wallets Typically Require**:
- Encryption self-classification: Category 5, Part 2 (encryption for authentication)
- May require ERN (Encryption Registration Number)

**Priority**: 🟡 **REVIEW REQUIRED** (legal/compliance decision)

---

## 4. LEGAL & COMPLIANCE - Status: ⚠️ ACTION REQUIRED

### 4.1 Trademark Verification

**Required Checks**:
- [ ] USPTO trademark search for "FUEKI" (United States)
- [ ] EUIPO trademark search (European Union)
- [ ] WIPO trademark search (International)
- [ ] App Store name availability check
- [ ] Domain ownership: fueki.money, fueki.com, fueki.io

**Recommendation**: Conduct comprehensive trademark search before submission to avoid rejection/legal issues.

**Priority**: 🔴 **CRITICAL** (legal blocker)

---

### 4.2 Privacy Policy

**Required Content**:
```
URL: https://fueki.money/privacy-policy

Must Include:
✓ Data collection practices (minimal for non-custodial wallet)
✓ Third-party API usage (price feeds, blockchain explorers)
✓ Analytics tools (if any)
✓ Crash reporting services
✓ User rights (GDPR, CCPA compliance)
✓ Data retention policies
✓ Security measures
✓ Contact information for privacy inquiries
✓ Last updated date
```

**Current Status**: ❌ **UNKNOWN** (not provided in project)

**Priority**: 🔴 **CRITICAL BLOCKER**

---

### 4.3 Terms of Service

**Required Content**:
```
URL: https://fueki.money/terms-of-service

Must Include:
✓ User responsibilities (self-custody warnings)
✓ Liability limitations
✓ Service description
✓ Prohibited uses
✓ Intellectual property rights
✓ Dispute resolution
✓ Governing law
✓ Changes to terms notice
✓ Non-custodial disclaimer
✓ Cryptocurrency risk warnings
```

**Priority**: 🔴 **CRITICAL BLOCKER**

---

### 4.4 Copyright Notices

**Current Status**: ⚠️ **NEEDS REVIEW**

**Required Updates**:
```
Update all copyright notices from:
❌ © Horizontal Systems LLC
To:
✅ © 2025 Fueki Technologies (or appropriate entity)

Locations to Update:
- About screen
- Settings screen
- README files
- License files
- Source code headers
- App Store description
```

**Priority**: 🔴 **CRITICAL**

---

### 4.5 Financial Services Compliance

**Regulatory Considerations**:

**United States**:
- ⚠️ FinCEN registration may be required if app facilitates exchange
- ⚠️ State-by-state money transmitter licenses (if applicable)
- ⚠️ SEC regulations for security tokens (Fueki focuses on security tokens!)

**European Union**:
- ⚠️ MiCA (Markets in Crypto-Assets) regulation compliance
- ⚠️ GDPR data protection requirements

**Other Jurisdictions**:
- Verify compliance in target markets

**CRITICAL NOTE**:
**Fueki's focus on "Institutional-Grade Digital Securities" may trigger:**
- SEC securities laws compliance
- FINRA broker-dealer registration requirements
- State securities registration (Blue Sky laws)
- AML/KYC requirements

**Recommendation**:
**OBTAIN LEGAL COUNSEL** from securities attorney before App Store submission. This is NOT a standard crypto wallet - it markets itself as a securities platform.

**Priority**: 🔴🔴🔴 **HIGHEST PRIORITY - LEGAL REVIEW REQUIRED**

---

## 5. APP STORE REVIEW GUIDELINES COMPLIANCE

### 5.1 Guideline 2.1 - App Completeness

**Requirements**:
- ✅ App must be fully functional (demo apps not allowed)
- ⚠️ All features advertised must work
- ⚠️ No "coming soon" or placeholder content
- ⚠️ No crashes or major bugs

**Testing Checklist**:
- [ ] Create new wallet
- [ ] Import existing wallet (12/24 word seed)
- [ ] Send transaction (testnet)
- [ ] Receive transaction
- [ ] View transaction history
- [ ] Access settings
- [ ] Enable biometric security
- [ ] Backup wallet
- [ ] Swap tokens (if feature exists)
- [ ] Browse DApps (if feature exists)
- [ ] View NFTs (if feature exists)

**Priority**: 🔴 **CRITICAL**

---

### 5.2 Guideline 3.1.1 - In-App Purchase

**Crypto Wallet Exemption**:
✅ Non-custodial wallets are exempt from IAP requirements
✅ Direct cryptocurrency transactions allowed
✅ DEX/swap features allowed

**Prohibited**:
❌ Cannot sell "credits" or "tokens" via IAP
❌ Cannot require subscription for basic wallet functionality
❌ Cannot charge for cryptocurrency transfers outside Apple's system

**Current Status**: ✅ **COMPLIANT** (non-custodial wallet)

**Priority**: 🟢 **COMPLIANT**

---

### 5.3 Guideline 4.0 - Design

**Human Interface Guidelines (HIG) Compliance**:
- ✅ Native iOS design patterns
- ⚠️ Dark mode support (verify)
- ⚠️ Dynamic Type support (accessibility)
- ⚠️ VoiceOver accessibility
- ⚠️ Keyboard navigation
- ⚠️ Safe area layout for notch devices

**Testing Required**:
- [ ] Test on iPhone SE (small screen)
- [ ] Test on iPhone 15 Pro Max (large screen)
- [ ] Test in Dark Mode
- [ ] Test with Large Text accessibility setting
- [ ] Test VoiceOver navigation

**Priority**: 🟡 **IMPORTANT**

---

### 5.4 Guideline 5.1.1 - Data Collection and Storage

**Privacy Manifest Required (iOS 17+)**:
```
Create PrivacyInfo.xcprivacy file documenting:
- Data types collected
- Tracking practices
- Required reason APIs used
- Third-party SDK tracking
```

**Non-Custodial Wallet Data Handling**:
✅ Private keys stored locally (Keychain)
✅ No server-side user data storage
⚠️ Analytics data (if using Firebase, Mixpanel, etc.)
⚠️ Crash reporting (if using Crashlytics, Sentry, etc.)

**Priority**: 🔴 **CRITICAL** (iOS 17+ requirement)

---

### 5.5 Guideline 5.3 - Gaming, Gambling, and Lotteries

**Cryptocurrency Considerations**:
⚠️ **WARNING**: Some crypto features may be considered gambling

**Prohibited Without License**:
- Casino games with crypto rewards
- Lotteries/raffles
- Betting/wagering on outcomes

**Allowed**:
- Trading/swapping cryptocurrency
- Viewing price charts
- Portfolio management

**Current Status**: ✅ **LIKELY COMPLIANT** (standard wallet features)

**Priority**: 🟢 **REVIEW COMPLETE**

---

## 6. TESTFLIGHT PREPARATION

### 6.1 Beta Testing Plan

**Internal Testing** (First 14 days):
```
Testers: 1-100 internal testers
Duration: 2 weeks minimum
Focus: Core functionality, critical bugs
```

**External Testing** (Before public release):
```
Testers: Up to 10,000 external testers
Duration: 2-4 weeks
Focus: Real-world usage, edge cases, UX feedback
```

**Test Cases**:
- [ ] Wallet creation (fresh install)
- [ ] Wallet import (12-word seed)
- [ ] Wallet import (24-word seed)
- [ ] Multi-wallet management
- [ ] Send transactions (BTC, ETH, tokens)
- [ ] Receive transactions
- [ ] Token swap functionality
- [ ] NFT viewing and management
- [ ] Security features (PIN, biometrics)
- [ ] Backup and recovery
- [ ] Network switching (mainnet/testnet)
- [ ] App updates (migration from previous version)

**Priority**: 🟡 **IMPORTANT**

---

### 6.2 Crash Reporting & Analytics

**Recommended Tools**:
- Firebase Crashlytics (free, iOS-specific)
- Sentry (cross-platform, detailed errors)
- Apple's native crash reporting (App Store Connect)

**Configuration**:
```swift
// Ensure crash reporting is enabled in release builds
// Verify user consent for analytics (GDPR/CCPA)
// Test crash reporting works in TestFlight
```

**Priority**: 🟡 **RECOMMENDED**

---

## 7. SUBMISSION TIMELINE & RISKS

### 7.1 Estimated Timeline

**Assuming All Assets and Approvals Ready**:

```
Week 1-2: Asset Creation & Code Updates
- Create Fueki app icons (all sizes)
- Generate screenshots (6 devices minimum)
- Update bundle identifiers across project
- Update copyright notices and branding
- Create/update Privacy Policy and Terms of Service

Week 2-3: Testing & QA
- Internal testing (critical path)
- TestFlight beta testing
- Bug fixes and iterations
- Performance optimization

Week 3: App Store Submission Preparation
- Upload app metadata to App Store Connect
- Complete App Privacy questionnaire
- Export compliance classification
- Upload screenshots and preview video
- Write release notes
- Submit for review

Week 4: Apple Review Process
- Standard review: 24-48 hours
- Expedited review: 1-2 days (requires justification)
- Potential rejection and resubmission: +1 week

TOTAL ESTIMATED TIME: 3-4 weeks
```

**⚠️ CRITICAL PATH DEPENDENCIES**:
1. **Legal Review** (securities compliance) - Could delay by weeks/months
2. **Trademark Clearance** - 1-3 weeks
3. **Bundle ID & Provisioning** - 1-2 days
4. **App Icon Design** - 3-5 days (professional designer)
5. **Screenshots** - 2-3 days (all device sizes)

---

### 7.2 High-Risk Rejection Factors

**Most Likely Rejection Reasons**:

1. **Guideline 3.2.1 - Acceptable Business Models**
   - Risk: **HIGH** ⚠️
   - Reason: "Institutional-Grade Digital Securities" phrasing suggests regulated financial product
   - Mitigation: Revise marketing to emphasize "wallet" over "securities platform"

2. **Guideline 5.1.1 - Data Collection**
   - Risk: **MEDIUM** ⚠️
   - Reason: Missing or incomplete Privacy Manifest (iOS 17+)
   - Mitigation: Create comprehensive PrivacyInfo.xcprivacy file

3. **Guideline 2.3.1 - Accurate Metadata**
   - Risk: **MEDIUM** ⚠️
   - Reason: Screenshots or description don't match actual app functionality
   - Mitigation: Ensure all marketing matches implemented features

4. **Guideline 4.0 - Design**
   - Risk: **LOW-MEDIUM** ⚠️
   - Reason: Non-native design patterns or poor accessibility
   - Mitigation: Follow HIG, test accessibility features

5. **Guideline 2.1 - App Completeness**
   - Risk: **LOW** ✅
   - Reason: Crashes or non-functional features
   - Mitigation: Comprehensive TestFlight beta testing

---

### 7.3 Securities Platform Risk Assessment

**🚨 HIGHEST RISK AREA - REQUIRES IMMEDIATE LEGAL REVIEW**

**Problem**:
The CLAUDE.md project instructions describe Fueki as:
- "Tokenized Securities Platform"
- "Institutional-Grade Digital Securities"
- "Regulatory-compliant security token issuance"
- "Transfer restrictions"
- "KYC/AML verification"

**Apple's Stance on Financial Services**:
Apple's App Store Review Guidelines (3.2.1) state:
> "Apps that facilitate trading in financial instruments must be submitted by the financial institution performing such services."

**Risk Analysis**:
If Fueki Wallet is positioned as a **securities trading platform**, Apple will likely require:
1. Proof of SEC registration (broker-dealer license)
2. FINRA membership documentation
3. State securities registrations
4. Institutional backing from licensed financial entity

**Recommended Mitigations**:

**Option 1: Rebrand as "General Crypto Wallet"**
```
Change Marketing From:
❌ "Institutional-Grade Digital Securities"
❌ "Tokenized Securities Platform"
❌ "Regulatory-compliant security token issuance"

To:
✅ "Professional Cryptocurrency Wallet"
✅ "Enterprise Digital Asset Management"
✅ "Advanced Crypto Wallet for Institutions"
```

**Option 2: Partner with Licensed Entity**
- Obtain backing from SEC-registered broker-dealer
- Provide licensing documentation to Apple
- Operate as white-label solution for licensed partner

**Option 3: Limit to Non-Security Tokens**
- Remove all "securities" language
- Focus on utility tokens only
- Explicitly state "not for regulated securities"

**RECOMMENDATION**:
**Option 1** is fastest path to App Store approval. Consult securities attorney before choosing Option 2 or 3.

**Priority**: 🔴🔴🔴 **CRITICAL - LEGAL REVIEW REQUIRED IMMEDIATELY**

---

## 8. ACTION ITEMS SUMMARY

### 🔴 CRITICAL BLOCKERS (Must Complete Before Submission)

1. **Create Fueki App Icons**
   - Owner: Design Team
   - Timeline: 3-5 days
   - Status: NOT STARTED
   - Files: All AppIcon.appiconset folders

2. **Generate App Store Screenshots**
   - Owner: Design/Marketing Team
   - Timeline: 2-3 days
   - Status: NOT STARTED
   - Requirements: 6.7", 6.5", 5.5" iPhone sizes minimum

3. **Update Bundle Identifiers**
   - Owner: iOS Developer
   - Timeline: 1 day
   - Status: NOT STARTED
   - Files: project.pbxproj, Info.plist, entitlements

4. **Create Apple Developer App IDs**
   - Owner: iOS Developer / Admin
   - Timeline: 1 day
   - Status: NOT STARTED
   - IDs: io.fueki.wallet, io.fueki.wallet.widget, io.fueki.wallet.intent

5. **Trademark Search & Clearance**
   - Owner: Legal Team
   - Timeline: 1-3 weeks
   - Status: NOT STARTED
   - Jurisdictions: US, EU, International

6. **Create Privacy Policy**
   - Owner: Legal Team / Compliance
   - Timeline: 3-5 days
   - Status: NOT STARTED
   - URL: https://fueki.money/privacy-policy

7. **Create Terms of Service**
   - Owner: Legal Team
   - Timeline: 3-5 days
   - Status: NOT STARTED
   - URL: https://fueki.money/terms-of-service

8. **Securities Compliance Review**
   - Owner: Legal Counsel (Securities Attorney)
   - Timeline: 1-4 weeks
   - Status: NOT STARTED
   - Decision: Marketing positioning / licensing requirements

---

### 🟡 HIGH PRIORITY (Complete Before TestFlight)

9. **Update Launch Screen**
   - Owner: iOS Developer
   - Timeline: 1 hour
   - Status: NEEDS VERIFICATION
   - File: LaunchScreen.xib

10. **Update Copyright Notices**
    - Owner: iOS Developer
    - Timeline: 2 hours
    - Status: NOT STARTED
    - Locations: About screen, source headers, README

11. **Create Privacy Manifest (iOS 17+)**
    - Owner: iOS Developer
    - Timeline: 1 day
    - Status: NOT STARTED
    - File: PrivacyInfo.xcprivacy

12. **Configure iCloud Containers**
    - Owner: iOS Developer / Admin
    - Timeline: 1 day
    - Status: PARTIAL (Info.plist updated, portal not configured)
    - IDs: iCloud.io.fueki.wallet.shared

13. **Regenerate Provisioning Profiles**
    - Owner: iOS Developer / Admin
    - Timeline: 1 day
    - Status: NOT STARTED
    - Profiles: Dev, AdHoc, App Store, Widget, Intent Extension

14. **TestFlight Beta Testing**
    - Owner: QA Team / Beta Testers
    - Timeline: 2-4 weeks
    - Status: NOT STARTED
    - Testers: Internal + External groups

---

### 🟢 MEDIUM PRIORITY (Complete Before Public Release)

15. **Create App Preview Video**
    - Owner: Marketing / Video Production
    - Timeline: 3-5 days
    - Status: NOT STARTED
    - Specs: 1080p, 15-30 seconds

16. **Accessibility Testing**
    - Owner: QA Team
    - Timeline: 2-3 days
    - Status: NOT STARTED
    - Tests: VoiceOver, Dynamic Type, Keyboard Nav

17. **Finalize App Store Metadata**
    - Owner: Marketing Team
    - Timeline: 1 day
    - Status: DRAFT PROVIDED
    - Items: Description, keywords, subtitle

18. **Export Compliance Documentation**
    - Owner: Legal / Compliance
    - Timeline: 1-2 days
    - Status: NEEDS REVIEW
    - Decision: Encryption classification

---

## 9. RISK MITIGATION STRATEGIES

### Strategy 1: Soft Launch Approach
```
Phase 1: Internal Release (Dev team only)
- Test core functionality
- Identify critical bugs
- Validate asset quality

Phase 2: TestFlight Beta (Limited external)
- 50-100 trusted testers
- Real-world usage scenarios
- Collect feedback and iterate

Phase 3: Phased Rollout (App Store)
- Submit to App Store with limited region (e.g., US only)
- Monitor reviews and crash reports
- Expand globally after stability confirmed
```

### Strategy 2: Pre-Submission Checklist
```
Before clicking "Submit for Review":
✅ All app icons updated with Fueki branding
✅ Launch screen shows Fueki logo
✅ No references to "Unstoppable" in UI
✅ Privacy Policy and Terms live at fueki.money
✅ Bundle IDs match across project and provisioning
✅ App builds successfully on Xcode Cloud
✅ TestFlight testing complete (no critical bugs)
✅ Screenshots match actual app UI
✅ Description accurately reflects features
✅ Legal review complete (especially securities compliance)
✅ Trademark clearance obtained
✅ Export compliance documented
```

### Strategy 3: Expedited Review Preparation
```
Apple allows expedited review for critical issues.

Valid Reasons for Expedited Review:
- Critical bug fix affecting all users
- Time-sensitive event or deadline
- Regulatory requirement deadline

NOT Valid for Expedited Review:
- Marketing launch dates
- Conference demos
- Investor presentations

Recommendation: Do NOT request expedited review for initial Fueki launch.
Use standard review process to minimize scrutiny.
```

---

## 10. FINAL RECOMMENDATIONS

### Immediate Actions (Next 24-48 Hours)
1. **Engage securities attorney** for compliance review (HIGHEST PRIORITY)
2. **Initiate trademark search** for "FUEKI" name
3. **Brief design team** on app icon requirements
4. **Set up project in Apple Developer Portal** with new bundle IDs
5. **Assign owners** to all action items listed above

### Week 1 Priorities
1. Complete asset creation (icons, screenshots)
2. Update all bundle identifiers in code
3. Draft Privacy Policy and Terms of Service
4. Begin internal testing of rebranded app
5. Obtain legal guidance on marketing positioning

### Week 2-3 Priorities
1. Complete TestFlight beta testing
2. Iterate based on feedback
3. Finalize App Store metadata
4. Prepare submission materials
5. Conduct final compliance review

### Submission Readiness
- **DO NOT SUBMIT** until securities compliance review is complete
- **DO NOT SUBMIT** until trademark clearance obtained
- **DO NOT SUBMIT** with any "coming soon" or incomplete features
- **DO SUBMIT** during off-peak times (Tuesday-Thursday) for faster review

---

## 11. APPENDIX: APP STORE CONNECT SETUP

### Account Requirements
```
Apple Developer Program Membership:
- Individual: $99/year
- Organization: $99/year (requires DUNS number)
- Enterprise: $299/year (internal distribution only, not for App Store)

Recommended: Organization account for institutional credibility
```

### App Store Connect Setup Steps
```
1. Log in to App Store Connect (appstoreconnect.apple.com)
2. Navigate to "My Apps"
3. Click "+" to create new app
4. Fill in required information:
   - Platform: iOS
   - Name: Fueki Wallet
   - Primary Language: English (U.S.)
   - Bundle ID: io.fueki.wallet
   - SKU: FUEKI-WALLET-001 (unique identifier)
5. Complete App Information section
6. Upload build from Xcode or Xcode Cloud
7. Configure pricing (free for wallet app)
8. Submit for review
```

### App Privacy Questionnaire
```
Required for App Store submission (iOS 14.3+):

Data Types to Declare:
- Contact Info: Email (if optional sign-up exists)
- Identifiers: Device ID (for crash reporting)
- Usage Data: Analytics data (if enabled)
- Financial Info: Transaction history (stored locally only)

For non-custodial wallet:
✅ Declare data is NOT linked to user identity
✅ Declare data is NOT used for tracking
✅ No third-party advertising
✅ Emphasize local-only storage

Critical: Be transparent and accurate. False declarations = rejection.
```

---

## 12. CONTACTS & RESOURCES

### Apple Resources
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- App Store Connect Help: https://help.apple.com/app-store-connect/
- Apple Developer Support: https://developer.apple.com/contact/

### Legal Resources
- SEC Investor Publications: https://www.sec.gov/investor
- FinCEN Virtual Currency Guidance: https://www.fincen.gov/
- FINRA Crypto Resources: https://www.finra.org/rules-guidance/key-topics/fintech-and-innovation

### Trademark Search Tools
- USPTO TESS: https://tmsearch.uspto.gov/
- EUIPO Search: https://euipo.europa.eu/
- WIPO Global Brand Database: https://www.wipo.int/branddb/

---

## CONCLUSION

The Fueki Wallet rebranding project requires **significant compliance work** before App Store submission. The **highest risk area** is the "Institutional-Grade Digital Securities" positioning, which may require securities licensing or rebranding.

**Recommended Path Forward**:
1. **Immediate legal review** of securities compliance requirements
2. **Rebrand marketing materials** to emphasize "cryptocurrency wallet" over "securities platform"
3. **Complete all critical asset creation** (icons, screenshots, policies)
4. **Conduct thorough TestFlight testing** before public submission
5. **Plan for 3-4 week timeline** from code-complete to App Store approval

With proper preparation and legal guidance, Fueki Wallet can successfully launch on the App Store as a professional, compliant cryptocurrency wallet solution.

---

**Review Completed By**: App Store Compliance Specialist
**Date**: October 22, 2025
**Next Review**: Upon completion of critical action items

---

## APPENDIX B: BUNDLE IDENTIFIER MIGRATION GUIDE

### Current Bundle IDs (Unstoppable Wallet)
```
Production:     io.horizontalsystems.bank-wallet
Development:    io.horizontalsystems.bank-wallet.dev
Widget:         io.horizontalsystems.bank-wallet.widget
Intent:         io.horizontalsystems.bank-wallet.intent
iCloud:         iCloud.io.horizontalsystems.bank-wallet.shared
iCloud Dev:     iCloud.io.horizontalsystems.bank-wallet.shared.dev
```

### New Bundle IDs (Fueki Wallet)
```
Production:     io.fueki.wallet
Development:    io.fueki.wallet.dev
Widget:         io.fueki.wallet.widget
Intent:         io.fueki.wallet.intent
iCloud:         iCloud.io.fueki.wallet.shared
iCloud Dev:     iCloud.io.fueki.wallet.shared.dev
```

### Migration Steps

**Step 1: Apple Developer Portal**
```
1. Log in to developer.apple.com
2. Certificates, IDs & Profiles → Identifiers
3. Create new App IDs:
   - io.fueki.wallet (Explicit App ID)
   - io.fueki.wallet.widget (Explicit App ID)
   - io.fueki.wallet.intent (Explicit App ID)
4. Enable capabilities:
   ✓ iCloud (CloudKit)
   ✓ Push Notifications
   ✓ App Groups
   ✓ Associated Domains (if using Universal Links)
   ✓ Keychain Sharing
5. Create new iCloud containers:
   - iCloud.io.fueki.wallet.shared
   - iCloud.io.fueki.wallet.shared.dev
```

**Step 2: Xcode Project Settings**
```
1. Open UnstoppableWallet.xcodeproj
2. Select UnstoppableWallet target
3. General tab → Identity:
   - Bundle Identifier: io.fueki.wallet
4. Repeat for all targets:
   - Widget target: io.fueki.wallet.widget
   - IntentExtension target: io.fueki.wallet.intent
5. Signing & Capabilities tab:
   - Re-select provisioning profiles
   - Update iCloud container references
   - Update App Groups (if used)
```

**Step 3: Update Info.plist Files**
```
All Info.plist files need updates:

./UnstoppableWallet/UnstoppableWallet/Info.plist
./UnstoppableWallet/Widget/Info.plist
./UnstoppableWallet/IntentExtension/Info.plist

Changes:
1. CFBundleURLName: io.fueki.wallet
2. NSUbiquitousContainers: iCloud.io.fueki.wallet.shared
3. Verify all custom keys reference "fueki" not "unstoppable"
```

**Step 4: Entitlements Files**
```
Update all .entitlements files:

UnstoppableWallet.entitlements
Widget.entitlements
IntentExtension.entitlements

Update:
- iCloud container identifiers
- App group identifiers (if used)
- Keychain access groups
```

**Step 5: Provisioning Profiles**
```
Generate new provisioning profiles for:
- Development (io.fueki.wallet)
- App Store (io.fueki.wallet)
- Widget Development (io.fueki.wallet.widget)
- Widget App Store (io.fueki.wallet.widget)
- Intent Development (io.fueki.wallet.intent)
- Intent App Store (io.fueki.wallet.intent)

Download and install in Xcode.
```

**Step 6: Testing**
```
1. Clean build folder (Cmd+Shift+K)
2. Delete derived data
3. Build all targets
4. Test on physical device:
   ✓ App launches successfully
   ✓ Widget displays correctly
   ✓ iCloud sync works (if applicable)
   ✓ Deep links open app (fueki.money://)
   ✓ Keychain data migrates (if upgrading from Unstoppable)
5. Archive and validate for App Store distribution
```

**⚠️ MIGRATION WARNING**:
Changing bundle IDs means **existing users cannot upgrade** from Unstoppable Wallet to Fueki Wallet via App Store update. This will be a **completely new app**.

**User Data Migration Strategy**:
Users will need to manually:
1. Backup seed phrase from Unstoppable Wallet
2. Download new Fueki Wallet app
3. Import seed phrase into Fueki Wallet
4. Delete old Unstoppable Wallet app

Alternative: Implement custom data migration tool that detects Unstoppable Wallet keychain data and imports it (complex, requires careful security review).

---

**End of Compliance Review Document**
