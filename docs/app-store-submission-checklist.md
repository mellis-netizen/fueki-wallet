# Fueki Wallet - App Store Submission Checklist

**Last Updated**: October 22, 2025
**Status**: 🔴 NOT READY FOR SUBMISSION

---

## Pre-Submission Requirements

### 🔴 CRITICAL BLOCKERS (Must Complete Before Submission)

- [ ] **1. Legal & Compliance**
  - [ ] Securities attorney review of "Institutional-Grade Digital Securities" positioning
  - [ ] Trademark search for "FUEKI" completed (US, EU, International)
  - [ ] Decision: Rebrand as crypto wallet OR obtain securities licensing
  - [ ] Privacy Policy created and hosted at fueki.money/privacy-policy
  - [ ] Terms of Service created and hosted at fueki.money/terms-of-service
  - [ ] Export compliance classification documented

- [ ] **2. App Assets**
  - [ ] App icon 1024x1024px created with Fueki branding (no alpha channel)
  - [ ] All app icon sizes generated (60@2x, 60@3x, 76, 83.5@2x, etc.)
  - [ ] Launch screen updated with Fueki logo
  - [ ] Widget icon updated (if applicable)
  - [ ] All references to "Unstoppable" removed from UI

- [ ] **3. Screenshots (Required)**
  - [ ] iPhone 6.7" (1290 x 2796) - Minimum 3 screenshots
  - [ ] iPhone 6.5" (1284 x 2778) - Minimum 3 screenshots
  - [ ] iPhone 5.5" (1242 x 2208) - Optional, for older devices
  - [ ] iPad Pro 12.9" (2048 x 2732) - If supporting iPad
  - [ ] Screenshots show Fueki branding consistently
  - [ ] Screenshots match actual app functionality

- [ ] **4. Bundle Identifiers**
  - [ ] Apple Developer Portal: Create io.fueki.wallet App ID
  - [ ] Apple Developer Portal: Create io.fueki.wallet.widget App ID
  - [ ] Apple Developer Portal: Create io.fueki.wallet.intent App ID
  - [ ] Xcode: Update main app bundle ID to io.fueki.wallet
  - [ ] Xcode: Update widget bundle ID to io.fueki.wallet.widget
  - [ ] Xcode: Update intent bundle ID to io.fueki.wallet.intent
  - [ ] project.pbxproj: Update PRODUCT_BUNDLE_IDENTIFIER for all targets
  - [ ] Info.plist: Update CFBundleURLName to io.fueki.wallet
  - [ ] Info.plist: Update URL scheme to fueki.money

- [ ] **5. iCloud Configuration**
  - [ ] Apple Developer Portal: Create iCloud.io.fueki.wallet.shared container
  - [ ] Apple Developer Portal: Create iCloud.io.fueki.wallet.shared.dev container
  - [ ] Info.plist: Update iCloud container identifiers
  - [ ] Entitlements: Update iCloud container references
  - [ ] Test iCloud sync functionality

- [ ] **6. Provisioning Profiles**
  - [ ] Generate Development profile for io.fueki.wallet
  - [ ] Generate App Store profile for io.fueki.wallet
  - [ ] Generate Widget Development profile
  - [ ] Generate Widget App Store profile
  - [ ] Generate Intent Extension Development profile
  - [ ] Generate Intent Extension App Store profile
  - [ ] Download and install all profiles in Xcode
  - [ ] Verify code signing works for all targets

- [ ] **7. Copyright & Branding**
  - [ ] Update copyright notices from "Horizontal Systems" to "Fueki Technologies"
  - [ ] Update About screen with Fueki branding
  - [ ] Update Settings screen with Fueki information
  - [ ] Update README files
  - [ ] Update license files
  - [ ] Verify no "Unstoppable" references in source code comments

---

## 🟡 HIGH PRIORITY (Before TestFlight Beta)

- [ ] **8. Privacy Manifest (iOS 17+)**
  - [ ] Create PrivacyInfo.xcprivacy file
  - [ ] Document data types collected
  - [ ] Document tracking practices (if any)
  - [ ] Document required reason APIs
  - [ ] Document third-party SDK tracking

- [ ] **9. App Store Metadata**
  - [ ] App Name: "Fueki Wallet" (max 30 characters)
  - [ ] Subtitle: Choose from:
    - "Institutional Digital Assets" (30 chars)
    - "Pro Digital Asset Wallet" (24 chars)
    - "Enterprise Crypto Wallet" (24 chars)
  - [ ] Description: Finalized (4000 character max)
  - [ ] Keywords: "crypto,wallet,bitcoin,ethereum,defi,institutional,security,nft,blockchain,finance"
  - [ ] Category: Finance
  - [ ] Age Rating: 4+
  - [ ] Support URL: fueki.money/support
  - [ ] Marketing URL: fueki.money

- [ ] **10. App Privacy Questionnaire (App Store Connect)**
  - [ ] Complete data collection disclosure
  - [ ] Declare data NOT linked to user identity (for non-custodial wallet)
  - [ ] Declare data NOT used for tracking
  - [ ] Confirm no third-party advertising
  - [ ] Emphasize local-only storage

- [ ] **11. Testing**
  - [ ] Internal testing completed (all core features)
  - [ ] TestFlight beta testing (2-4 weeks minimum)
  - [ ] No critical bugs or crashes
  - [ ] Performance testing on old devices (iPhone SE)
  - [ ] Dark mode testing
  - [ ] Accessibility testing (VoiceOver, Dynamic Type)

---

## 🟢 RECOMMENDED (Before Public Release)

- [ ] **12. Optional Enhancements**
  - [ ] App Preview video (15-30 seconds, 1080p)
  - [ ] Localization for non-English markets
  - [ ] iPad optimization (if targeting iPad)
  - [ ] Apple Watch extension (if planned)

- [ ] **13. Marketing Preparation**
  - [ ] Press kit with app screenshots
  - [ ] Blog post announcing launch
  - [ ] Social media assets
  - [ ] Email announcement to existing users
  - [ ] Landing page updated (fueki.money)

---

## App Store Submission Steps

### Step 1: Prepare Build
```bash
1. Clean build folder (Xcode → Product → Clean Build Folder)
2. Archive app (Xcode → Product → Archive)
3. Validate build (Organizer → Validate App)
4. Upload to App Store Connect (Organizer → Distribute App)
5. Wait for processing (10-30 minutes)
```

### Step 2: Complete App Store Connect Information
```
1. Log in to App Store Connect (appstoreconnect.apple.com)
2. Select your app (Fueki Wallet)
3. Select the build uploaded from Xcode
4. Complete all required metadata:
   ✓ App Information
   ✓ Pricing and Availability
   ✓ App Privacy
   ✓ Screenshots (all device sizes)
   ✓ Description and keywords
   ✓ Support and marketing URLs
   ✓ Contact information
   ✓ Age rating questionnaire
   ✓ Export compliance
5. Review all information for accuracy
```

### Step 3: Submit for Review
```
1. Click "Submit for Review"
2. Wait for Apple's response (typically 24-48 hours)
3. Monitor App Store Connect for status updates
4. Respond promptly to any rejection feedback
```

---

## Common Rejection Reasons & Mitigation

### Rejection: Guideline 3.2.1 - Business Model
**Reason**: App markets itself as securities platform without proper licensing

**Mitigation**:
- Rebrand marketing to emphasize "cryptocurrency wallet" not "securities platform"
- Remove phrases like "Institutional-Grade Digital Securities"
- Focus on wallet functionality, not trading/issuance

### Rejection: Guideline 5.1.1 - Data Collection
**Reason**: Missing or incomplete Privacy Manifest

**Mitigation**:
- Create comprehensive PrivacyInfo.xcprivacy file
- Accurately declare all data collection
- Ensure Privacy Policy matches declared practices

### Rejection: Guideline 2.3 - Metadata
**Reason**: Screenshots don't match actual app

**Mitigation**:
- Use actual app screenshots, not mockups
- Ensure UI shown in screenshots is implemented
- Remove any "coming soon" features from marketing

### Rejection: Guideline 4.0 - Design
**Reason**: Poor accessibility or non-native design

**Mitigation**:
- Test VoiceOver thoroughly
- Support Dynamic Type
- Follow Human Interface Guidelines
- Test on multiple device sizes

---

## Post-Approval Checklist

- [ ] Monitor crash reports (App Store Connect)
- [ ] Monitor user reviews (respond within 48 hours)
- [ ] Track download metrics and analytics
- [ ] Prepare for first update (bug fixes, improvements)
- [ ] Set up customer support channels
- [ ] Monitor social media mentions
- [ ] Collect user feedback for roadmap

---

## Emergency Contacts

**Apple Developer Support**: https://developer.apple.com/contact/
**App Store Review Status**: https://developer.apple.com/contact/app-store/?topic=expedite
**Expedited Review Request**: Use only for critical bugs affecting all users

---

## Timeline Estimate

**Optimistic Scenario** (everything goes smoothly):
- Asset creation: 1 week
- Code updates: 3-5 days
- Testing: 2 weeks
- App Store review: 24-48 hours
- **Total: 3.5-4 weeks**

**Realistic Scenario** (normal delays):
- Legal review: 1-2 weeks
- Asset creation: 1.5 weeks
- Code updates: 1 week
- Testing & bug fixes: 3 weeks
- App Store review + potential rejection: 1 week
- **Total: 6-8 weeks**

**Worst Case Scenario** (securities licensing required):
- Legal consultation: 1-2 weeks
- Securities licensing process: 3-6 months (or abandon approach)
- **Total: Could delay indefinitely**

---

## Final Pre-Submission Verification

Before clicking "Submit for Review", verify:

✅ App builds and runs without crashes
✅ All app icons show Fueki branding (check all sizes)
✅ Launch screen shows Fueki logo
✅ No "Unstoppable" references visible in UI
✅ Bundle IDs match across project and provisioning
✅ Privacy Policy and Terms of Service are live and accessible
✅ Screenshots accurately represent the app
✅ Description doesn't promise unimplemented features
✅ TestFlight testing completed with no critical bugs
✅ Legal review completed (especially securities positioning)
✅ Export compliance documented
✅ App Privacy questionnaire completed accurately

**DO NOT SUBMIT** if any critical blocker remains unresolved.

---

**Document Prepared By**: App Store Compliance Specialist
**Last Updated**: October 22, 2025
**Next Review**: After critical blockers are resolved
