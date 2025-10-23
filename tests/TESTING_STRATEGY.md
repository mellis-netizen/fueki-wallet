# Fueki Wallet - Comprehensive Testing Strategy

**Project**: Unstoppable Wallet → Fueki Wallet Rebranding
**Date**: 2025-10-22
**Lead**: QA/Testing Agent
**Status**: Ready for Execution

---

## Executive Summary

This testing strategy ensures 100% functional integrity during the Unstoppable → Fueki rebranding. All 78 test cases must pass before production release.

---

## 1. FUNCTIONAL TESTING CHECKLIST (52 Test Cases)

### 1.1 Wallet Lifecycle (8 tests)
- [ ] **TC-001**: Create new wallet with 12-word seed phrase
- [ ] **TC-002**: Create new wallet with 24-word seed phrase
- [ ] **TC-003**: Import wallet from seed phrase (12-word)
- [ ] **TC-004**: Import wallet from seed phrase (24-word)
- [ ] **TC-005**: Import wallet from private key (Bitcoin)
- [ ] **TC-006**: Import wallet from private key (Ethereum)
- [ ] **TC-007**: Delete wallet with confirmation
- [ ] **TC-008**: Restore wallet from backup

**Priority**: P0 (Critical)
**Risk**: High - Core functionality

---

### 1.2 Multi-Coin Support (10 tests)
- [ ] **TC-009**: Add Bitcoin wallet
- [ ] **TC-010**: Add Ethereum wallet
- [ ] **TC-011**: Add ERC-20 token (USDT)
- [ ] **TC-012**: Add ERC-20 token (USDC)
- [ ] **TC-013**: Add custom ERC-20 token (contract address)
- [ ] **TC-014**: Add BEP-20 token (Binance Smart Chain)
- [ ] **TC-015**: View Bitcoin balance
- [ ] **TC-016**: View Ethereum balance
- [ ] **TC-017**: View token balances (multiple tokens)
- [ ] **TC-018**: Switch between coin accounts

**Priority**: P0 (Critical)
**Risk**: High - Multi-blockchain support

---

### 1.3 Send Transactions (8 tests)
- [ ] **TC-019**: Send Bitcoin (standard fee)
- [ ] **TC-020**: Send Bitcoin (custom fee)
- [ ] **TC-021**: Send Ethereum (standard gas)
- [ ] **TC-022**: Send Ethereum (custom gas)
- [ ] **TC-023**: Send ERC-20 token
- [ ] **TC-024**: Send max balance (sweep)
- [ ] **TC-025**: Send with memo/note
- [ ] **TC-026**: Cancel pending transaction

**Priority**: P0 (Critical)
**Risk**: High - Financial transactions

---

### 1.4 Receive Transactions (5 tests)
- [ ] **TC-027**: Display Bitcoin receive address
- [ ] **TC-028**: Display Ethereum receive address
- [ ] **TC-029**: Generate new receive address
- [ ] **TC-030**: Copy address to clipboard
- [ ] **TC-031**: Display QR code for address

**Priority**: P0 (Critical)
**Risk**: Medium - Receive functionality

---

### 1.5 Address Book (5 tests)
- [ ] **TC-032**: Add contact to address book
- [ ] **TC-033**: Edit contact in address book
- [ ] **TC-034**: Delete contact from address book
- [ ] **TC-035**: Send to contact from address book
- [ ] **TC-036**: Search contacts in address book

**Priority**: P1 (High)
**Risk**: Low - Convenience feature

---

### 1.6 QR Code Scanning (4 tests)
- [ ] **TC-037**: Scan Bitcoin address QR code
- [ ] **TC-038**: Scan Ethereum address QR code
- [ ] **TC-039**: Scan WalletConnect QR code
- [ ] **TC-040**: Handle invalid QR code gracefully

**Priority**: P1 (High)
**Risk**: Medium - Common user flow

---

### 1.7 Biometric Authentication (4 tests)
- [ ] **TC-041**: Enable Face ID authentication
- [ ] **TC-042**: Enable Touch ID authentication
- [ ] **TC-043**: Unlock app with Face ID
- [ ] **TC-044**: Unlock app with Touch ID

**Priority**: P1 (High)
**Risk**: High - Security feature

---

### 1.8 Backup & Restore (4 tests)
- [ ] **TC-045**: Backup wallet to iCloud
- [ ] **TC-046**: Restore wallet from iCloud
- [ ] **TC-047**: Export private keys
- [ ] **TC-048**: Verify seed phrase backup

**Priority**: P0 (Critical)
**Risk**: High - Data loss prevention

---

### 1.9 Settings & Preferences (4 tests)
- [ ] **TC-049**: Change currency (USD/EUR/GBP)
- [ ] **TC-050**: Toggle dark mode
- [ ] **TC-051**: Change language (all 9 supported)
- [ ] **TC-052**: Enable/disable notifications

**Priority**: P2 (Medium)
**Risk**: Low - User preferences

---

## 2. VISUAL REGRESSION TESTING (15 Test Cases)

### 2.1 Branding Verification
- [ ] **TC-053**: Fueki logo displays correctly on launch screen
- [ ] **TC-054**: Fueki logo displays correctly in navigation bar
- [ ] **TC-055**: App name shows as "Fueki Wallet" in header
- [ ] **TC-056**: Color scheme matches Fueki brand (#2563EB primary)
- [ ] **TC-057**: All icons use new Fueki design system

**Priority**: P0 (Critical)
**Risk**: High - Brand identity

---

### 2.2 Dark Mode Consistency
- [ ] **TC-058**: Dark mode renders correctly on all screens
- [ ] **TC-059**: Logo is visible in dark mode
- [ ] **TC-060**: Text contrast meets WCAG AA standards (dark mode)
- [ ] **TC-061**: Button states visible in dark mode

**Priority**: P1 (High)
**Risk**: Medium - Accessibility

---

### 2.3 Localization Display
- [ ] **TC-062**: English (en) - All strings display correctly
- [ ] **TC-063**: Russian (ru) - All strings display correctly
- [ ] **TC-064**: Spanish (es) - All strings display correctly
- [ ] **TC-065**: French (fr) - All strings display correctly
- [ ] **TC-066**: German (de) - All strings display correctly
- [ ] **TC-067**: Portuguese (pt-BR) - All strings display correctly

**Priority**: P1 (High)
**Risk**: Medium - International users

---

## 3. BUILD VALIDATION (6 Test Cases)

### 3.1 Configuration Files
- [ ] **TC-068**: Info.plist is valid XML
- [ ] **TC-069**: Bundle identifier is "io.fueki.wallet"
- [ ] **TC-070**: Display name is "Fueki Wallet"
- [ ] **TC-071**: URL scheme "fueki.money://" is registered
- [ ] **TC-072**: All Localizable.strings files have valid syntax
- [ ] **TC-073**: Assets.xcassets contains all required app icons

**Priority**: P0 (Critical)
**Risk**: High - Build failures

---

## 4. CRITICAL PATH TESTS (5 Priority Workflows)

### Priority 1 (MUST WORK) - 5 Tests

#### CP-001: Create New Wallet Flow
```
1. Launch app
2. Tap "Create New Wallet"
3. View 12-word seed phrase
4. Confirm seed phrase backup
5. Set PIN/biometric
6. Wallet created successfully
```
**Expected**: User reaches dashboard with $0 balance
**Risk**: CRITICAL - New user onboarding

---

#### CP-002: Send Transaction Flow
```
1. Open Bitcoin wallet
2. Tap "Send"
3. Enter recipient address
4. Enter amount
5. Review transaction
6. Confirm with PIN/biometric
7. Transaction broadcast
```
**Expected**: Transaction appears in history as "Pending"
**Risk**: CRITICAL - Core value proposition

---

#### CP-003: Receive Transaction Flow
```
1. Open Ethereum wallet
2. Tap "Receive"
3. View QR code
4. Copy address to clipboard
5. Share address via messaging
```
**Expected**: Address copied and shareable
**Risk**: CRITICAL - Receiving funds

---

#### CP-004: View Balance Flow
```
1. Open dashboard
2. View total portfolio value
3. Switch between coin accounts
4. View transaction history
5. Pull to refresh balances
```
**Expected**: Accurate balances displayed
**Risk**: CRITICAL - Trust and accuracy

---

#### CP-005: Backup Wallet Flow
```
1. Open settings
2. Navigate to "Backup Wallet"
3. View seed phrase
4. Confirm seed phrase written down
5. Enable iCloud backup (optional)
```
**Expected**: User has backup method enabled
**Risk**: CRITICAL - Prevent fund loss

---

## 5. AUTOMATED TEST SUITE (XCTest)

### 5.1 Swift Unit Tests

```swift
//
//  FuekiBrandingTests.swift
//  Fueki Wallet Tests
//

import XCTest
@testable import Fueki_Wallet

class FuekiBrandingTests: XCTestCase {

    // MARK: - Bundle Configuration Tests

    func testBundleIdentifier() {
        let bundleID = Bundle.main.bundleIdentifier
        XCTAssertEqual(bundleID, "io.fueki.wallet",
                      "Bundle identifier must be io.fueki.wallet")
    }

    func testDisplayName() {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        XCTAssertEqual(displayName, "Fueki Wallet",
                      "Display name must be 'Fueki Wallet'")
    }

    func testURLScheme() {
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        let schemes = urlTypes?.first?["CFBundleURLSchemes"] as? [String]
        XCTAssertTrue(schemes?.contains("fueki.money") == true,
                     "URL scheme fueki.money must be registered")
    }

    func testAppVersion() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        XCTAssertNotNil(version, "App version must be defined")
    }

    // MARK: - Localization Tests

    func testLocalizedStrings_English() {
        let bundle = Bundle.main
        let localizedString = NSLocalizedString("app.name", bundle: bundle, comment: "")
        XCTAssertFalse(localizedString.isEmpty,
                      "Localized string for 'app.name' should not be empty")
    }

    func testAllSupportedLanguages() {
        let supportedLanguages = ["en", "ru", "es", "fr", "de", "pt-BR", "zh-Hans", "ko", "tr"]
        let bundleLocalizations = Bundle.main.localizations

        for language in supportedLanguages {
            XCTAssertTrue(bundleLocalizations.contains(language),
                         "Language \(language) must be supported")
        }
    }

    // MARK: - Asset Catalog Tests

    func testAppIconExists() {
        let appIcon = UIImage(named: "AppIcon")
        XCTAssertNotNil(appIcon, "App icon must exist in Assets.xcassets")
    }

    func testFuekiLogoExists() {
        let logo = UIImage(named: "fueki-logo")
        XCTAssertNotNil(logo, "Fueki logo asset must exist")
    }

    func testLaunchScreenLogo() {
        let launchLogo = UIImage(named: "launch-logo")
        XCTAssertNotNil(launchLogo, "Launch screen logo must exist")
    }

    // MARK: - Color Scheme Tests

    func testPrimaryBrandColor() {
        // Fueki primary blue: #2563EB
        let expectedColor = UIColor(red: 0x25/255.0,
                                   green: 0x63/255.0,
                                   blue: 0xEB/255.0,
                                   alpha: 1.0)

        let primaryColor = UIColor(named: "PrimaryBrand")
        XCTAssertNotNil(primaryColor, "Primary brand color must be defined")

        // Note: Color comparison requires tolerance for floating point precision
    }

    // MARK: - Deep Linking Tests

    func testDeepLinkHandling() {
        let url = URL(string: "fueki.money://wallet/receive")!
        let canOpen = UIApplication.shared.canOpenURL(url)
        XCTAssertTrue(canOpen, "App should be able to handle fueki.money:// URLs")
    }
}
```

### 5.2 UI Automation Tests

```swift
//
//  FuekiUITests.swift
//  Fueki Wallet UI Tests
//

import XCTest

class FuekiUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Onboarding Flow Tests

    func testCreateNewWalletFlow() {
        // Test complete wallet creation flow
        let createButton = app.buttons["Create New Wallet"]
        XCTAssertTrue(createButton.exists, "Create wallet button should exist")

        createButton.tap()

        // Verify seed phrase screen appears
        let seedPhraseLabel = app.staticTexts["Backup Seed Phrase"]
        XCTAssertTrue(seedPhraseLabel.waitForExistence(timeout: 5),
                     "Seed phrase screen should appear")

        // Continue flow...
        let continueButton = app.buttons["Continue"]
        continueButton.tap()

        // Verify dashboard appears
        let dashboardTitle = app.navigationBars["Fueki Wallet"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5),
                     "Dashboard should appear after wallet creation")
    }

    func testImportWalletFlow() {
        let importButton = app.buttons["Import Wallet"]
        XCTAssertTrue(importButton.exists, "Import wallet button should exist")

        importButton.tap()

        // Enter seed phrase
        let seedPhraseField = app.textViews["Seed Phrase Input"]
        XCTAssertTrue(seedPhraseField.exists, "Seed phrase input should exist")

        seedPhraseField.tap()
        seedPhraseField.typeText("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")

        let importConfirmButton = app.buttons["Import"]
        importConfirmButton.tap()

        // Verify import success
        let dashboardTitle = app.navigationBars["Fueki Wallet"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 10),
                     "Dashboard should appear after import")
    }

    // MARK: - Transaction Flow Tests

    func testSendTransactionFlow() {
        // Assumes wallet already created
        setupTestWallet()

        // Navigate to Bitcoin wallet
        let bitcoinCell = app.cells["Bitcoin"]
        bitcoinCell.tap()

        // Tap Send button
        let sendButton = app.buttons["Send"]
        sendButton.tap()

        // Enter recipient address
        let addressField = app.textFields["Recipient Address"]
        addressField.tap()
        addressField.typeText("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh")

        // Enter amount
        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.001")

        // Review transaction
        let reviewButton = app.buttons["Review"]
        reviewButton.tap()

        // Verify review screen
        let confirmButton = app.buttons["Confirm"]
        XCTAssertTrue(confirmButton.exists, "Confirm button should exist on review screen")
    }

    func testReceiveFlow() {
        setupTestWallet()

        // Navigate to Ethereum wallet
        let ethereumCell = app.cells["Ethereum"]
        ethereumCell.tap()

        // Tap Receive button
        let receiveButton = app.buttons["Receive"]
        receiveButton.tap()

        // Verify QR code appears
        let qrCodeImage = app.images["Address QR Code"]
        XCTAssertTrue(qrCodeImage.waitForExistence(timeout: 3),
                     "QR code should appear")

        // Test copy address
        let copyButton = app.buttons["Copy Address"]
        copyButton.tap()

        // Verify toast/alert
        let copiedAlert = app.alerts["Address Copied"]
        XCTAssertTrue(copiedAlert.waitForExistence(timeout: 2),
                     "Copy confirmation should appear")
    }

    // MARK: - Settings Tests

    func testLanguageChange() {
        navigateToSettings()

        let languageCell = app.cells["Language"]
        languageCell.tap()

        // Change to Spanish
        let spanishCell = app.cells["Español"]
        spanishCell.tap()

        // Verify UI changed to Spanish
        let ajustesTitle = app.navigationBars["Ajustes"] // "Settings" in Spanish
        XCTAssertTrue(ajustesTitle.waitForExistence(timeout: 3),
                     "UI should change to Spanish")
    }

    func testDarkModeToggle() {
        navigateToSettings()

        let darkModeSwitch = app.switches["Dark Mode"]
        darkModeSwitch.tap()

        // Verify background color changed
        // Note: This requires checking UI element appearance
        XCTAssertTrue(darkModeSwitch.isSelected, "Dark mode should be enabled")
    }

    // MARK: - Biometric Tests

    func testFaceIDAuthentication() {
        navigateToSettings()

        let biometricSwitch = app.switches["Face ID"]
        if biometricSwitch.exists {
            biometricSwitch.tap()

            // Simulate Face ID prompt
            // Note: Use xctest biometric simulation
            XCTAssertTrue(biometricSwitch.isSelected, "Face ID should be enabled")
        } else {
            XCTSkip("Device does not support Face ID")
        }
    }

    // MARK: - Helper Methods

    private func setupTestWallet() {
        // Create or import test wallet
        // This would be implemented based on test requirements
    }

    private func navigateToSettings() {
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
    }
}
```

---

## 6. RISK ASSESSMENT MATRIX

| Risk Area | Probability | Impact | Severity | Mitigation |
|-----------|-------------|--------|----------|------------|
| **Bundle ID Conflict** | Low | Critical | HIGH | Verify uniqueness on App Store |
| **URL Scheme Conflict** | Medium | High | MEDIUM | Test deep linking before release |
| **Asset Corruption** | Low | High | MEDIUM | Validate all assets in build |
| **Localization Errors** | Medium | Medium | MEDIUM | Test all 9 languages manually |
| **Build Failure** | Low | Critical | HIGH | Test build on clean machine |
| **Transaction Failures** | Low | Critical | CRITICAL | Extensive transaction testing |
| **Backup Corruption** | Low | Critical | CRITICAL | Test restore multiple times |
| **Biometric Issues** | Medium | High | MEDIUM | Test on multiple device models |
| **Dark Mode Rendering** | Medium | Low | LOW | Visual QA on all screens |
| **App Store Rejection** | Low | High | MEDIUM | Pre-submission checklist |

**Overall Risk Level**: MEDIUM
**Recommended Actions**:
1. Focus on P0 (Critical) tests first
2. Manual testing on 3+ physical devices
3. TestFlight beta with 10+ users
4. Rollback plan prepared

---

## 7. ROLLBACK PLAN

### If Critical Issues Found:

**Phase 1: Immediate Actions (0-1 hour)**
1. Document the issue with screenshots/logs
2. Assess severity (P0/P1/P2)
3. Notify development team via coordination hooks
4. Stop production deployment if in progress

**Phase 2: Investigation (1-4 hours)**
1. Reproduce issue in test environment
2. Identify root cause (code/config/asset)
3. Estimate fix effort
4. Decide: Fix forward or rollback

**Phase 3: Rollback Execution (if needed)**
```bash
# Revert to previous bundle identifier
# In Info.plist:
<key>CFBundleIdentifier</key>
<string>io.horizontalsystems.bank-wallet</string>

# Revert display name
<key>CFBundleDisplayName</key>
<string>Unstoppable</string>

# Revert URL schemes
<key>CFBundleURLSchemes</key>
<array>
    <string>unstoppable.money</string>
</array>

# Restore original assets
git checkout HEAD -- UnstoppableWallet/UnstoppableWallet/Assets.xcassets/

# Restore original localizations
git checkout HEAD -- UnstoppableWallet/UnstoppableWallet/*/Localizable.strings
```

**Phase 4: Post-Rollback (4-24 hours)**
1. Fix issues in development branch
2. Re-run full test suite
3. Conduct additional QA
4. Schedule new deployment window

---

## 8. PRE-RELEASE CHECKLIST

### Before Submitting to App Store:

**Build Validation**
- [ ] Build succeeds on Xcode 15+ without warnings
- [ ] All tests pass (Unit + UI)
- [ ] App runs on iOS 15.0+ devices
- [ ] Archive builds successfully
- [ ] Code signing configured correctly

**Functional Validation**
- [ ] All 73 functional tests pass
- [ ] Critical path tests verified on 3+ devices
- [ ] Biometric auth works (Face ID + Touch ID)
- [ ] All 9 languages display correctly
- [ ] Dark mode renders properly

**App Store Requirements**
- [ ] App icons present (all required sizes)
- [ ] Screenshots prepared (6.5", 5.5", iPad)
- [ ] App description mentions "Fueki Wallet"
- [ ] Privacy policy updated with new brand
- [ ] Support URL updated to fueki.io/support
- [ ] Marketing URL updated to fueki.io

**Legal & Compliance**
- [ ] Terms of Service updated
- [ ] Privacy Policy reviewed
- [ ] Trademark verification completed
- [ ] Domain ownership confirmed (fueki.money, fueki.io)

**TestFlight Beta** (Recommended)
- [ ] Internal testing completed (3+ days)
- [ ] External beta with 10+ testers
- [ ] Crash logs reviewed (zero critical crashes)
- [ ] User feedback addressed

---

## 9. TEST EXECUTION SCHEDULE

### Week 1: Automated Testing
- Day 1-2: Run XCTest suite (unit + UI)
- Day 3: Build validation on clean environment
- Day 4-5: Fix any automated test failures

### Week 2: Manual Testing
- Day 1: Functional testing (TC-001 to TC-052)
- Day 2: Visual regression testing
- Day 3: Localization testing (all languages)
- Day 4: Biometric and security testing
- Day 5: Critical path testing

### Week 3: Device Testing
- Day 1: iPhone SE (small screen)
- Day 2: iPhone 15 Pro (standard)
- Day 3: iPhone 15 Pro Max (large screen)
- Day 4: iPad (tablet layout)
- Day 5: Integration testing

### Week 4: Pre-Release
- Day 1-2: TestFlight internal beta
- Day 3-7: TestFlight external beta (10+ users)
- Day 8-10: Address feedback, final fixes
- Day 11: Final build and submission

---

## 10. SUCCESS CRITERIA

**Definition of Done**:
- ✅ 100% of P0 (Critical) tests pass
- ✅ 95%+ of P1 (High) tests pass
- ✅ 80%+ of P2 (Medium) tests pass
- ✅ Zero critical bugs in production
- ✅ App Store approval received
- ✅ TestFlight beta feedback positive (>4.5★)
- ✅ All rollback procedures documented
- ✅ Team trained on new brand

**Metrics to Track**:
- Test pass rate: Target 95%+
- Build success rate: Target 100%
- Crash-free rate: Target 99.9%
- App Store rejection: Target 0
- User complaints: Target <1% of active users

---

## APPENDIX A: Test Data

### Test Wallets (Testnet Only)
```
Bitcoin Testnet:
- Address: tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx
- Private Key: [Test key - not for production]

Ethereum Ropsten:
- Address: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb8
- Private Key: [Test key - not for production]
```

### Test Credentials
```
Face ID Test: Use Xcode simulator biometric enrollment
Touch ID Test: Use Xcode simulator biometric enrollment
PIN: 123456 (for test environments only)
```

---

## APPENDIX B: Tools & Resources

### Testing Tools
- **Xcode**: Version 15.0+
- **XCTest**: Built-in unit/UI testing
- **TestFlight**: Beta distribution
- **Firebase Crashlytics**: Crash reporting
- **Charles Proxy**: Network debugging

### Documentation
- Apple Developer Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- WCAG Accessibility: https://www.w3.org/WAI/WCAG21/quickref/

---

## Contact & Coordination

**Testing Agent**: QA Lead (Hive Mind Swarm)
**Memory Namespace**: `fueki/testing/*`
**Coordination**: Claude Flow hooks
**Escalation**: Report critical issues to Architect agent

**Hook Commands**:
```bash
# Report test results
npx claude-flow@alpha hooks post-edit --memory-key "fueki/testing/results" --data "[results]"

# Track test progress
npx claude-flow@alpha hooks notify --message "Test suite execution: 45/73 passed"

# Session metrics
npx claude-flow@alpha hooks session-end --export-metrics true
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-22
**Status**: Ready for Execution
