# Fueki Wallet - Rollback Plan

**Project**: Unstoppable Wallet → Fueki Wallet Rebranding
**Document Type**: Emergency Rollback Procedures
**Status**: Active
**Last Updated**: 2025-10-22

---

## Executive Summary

This document provides step-by-step procedures for rolling back the Fueki rebranding if critical issues are discovered during testing or post-release. The plan covers both code-level rollbacks (pre-release) and user-facing rollbacks (post-release).

---

## Rollback Decision Matrix

| Issue Severity | Action | Timeline | Approval Required |
|----------------|--------|----------|-------------------|
| **P0 - Critical** | Immediate rollback | 0-1 hour | QA Lead + Architect |
| **P1 - High** | Evaluate → Rollback | 1-4 hours | QA Lead + Product Manager |
| **P2 - Medium** | Fix forward | 4-24 hours | Developer discretion |
| **P3 - Low** | Next release | No rollback | None |

### Critical Issues (P0) Requiring Immediate Rollback:
- ❌ **Transaction failures** (send/receive broken)
- ❌ **Wallet backup/restore corruption**
- ❌ **App crashes on launch**
- ❌ **Complete loss of user funds access**
- ❌ **Security vulnerability** (private key exposure)
- ❌ **Biometric authentication completely broken**

### High Issues (P1) Requiring Evaluation:
- ⚠️ App Store rejection (legal/trademark)
- ⚠️ Deep linking completely broken
- ⚠️ WalletConnect integration failure
- ⚠️ Critical UI rendering issues (app unusable)
- ⚠️ Major localization errors (50%+ strings broken)

---

## Phase 1: Pre-Release Rollback (Development/Testing)

**Use Case**: Critical issues found during internal testing or TestFlight beta.

### 1.1 Immediate Actions (0-15 minutes)

**Step 1: Stop All Deployment**
```bash
# Cancel any ongoing App Store submission
# Contact Apple Developer Support if already in review

# Stop TestFlight distribution
# Revoke beta access to current build
```

**Step 2: Document the Issue**
```bash
# Create incident report
Date: [timestamp]
Severity: P0/P1/P2
Description: [detailed issue description]
Steps to Reproduce:
1. [step 1]
2. [step 2]
3. [observed behavior]

Expected Behavior: [what should happen]
Actual Behavior: [what actually happened]

Screenshots/Logs: [attach evidence]
Affected Components: [list files/systems]
```

**Step 3: Notify Stakeholders**
```bash
# Send alert to:
- QA Lead
- iOS Developer
- Project Architect
- Product Manager
- Marketing Team (if post-launch)

Subject: CRITICAL: Fueki Rollback Required - [Issue Summary]
Priority: URGENT
```

---

### 1.2 Code-Level Rollback (15-60 minutes)

**Prerequisite**: Git repository with clean commit history.

#### Rollback Option A: Revert Specific Commits (Recommended)

```bash
# Navigate to project directory
cd /Users/computer/Downloads/unstoppable-wallet-ios-master

# View recent commits
git log --oneline --graph --decorate -20

# Identify the commit before Fueki changes
# Example: commit abc1234 was last good commit

# Create rollback branch
git checkout -b rollback/fueki-revert

# Revert the Fueki rebrand commits (in reverse order)
git revert <commit-hash-1>  # Most recent Fueki commit
git revert <commit-hash-2>  # Previous Fueki commit
git revert <commit-hash-3>  # And so on...

# Verify rollback
git diff HEAD~3 HEAD  # Check what changed

# Test the rollback
# 1. Clean build
# 2. Run on simulator
# 3. Verify original branding restored

# If successful, merge to main
git checkout main
git merge rollback/fueki-revert
git push origin main
```

#### Rollback Option B: Hard Reset (Nuclear Option - Use with Caution)

```bash
# ⚠️ WARNING: This will permanently delete Fueki commits
# Only use if revert fails or history is too complex

# Backup current state first
git branch backup/fueki-before-rollback

# Find last good commit
git log --oneline -20

# Hard reset to that commit
git reset --hard <last-good-commit-hash>

# Force push (requires team coordination)
git push origin main --force

# Verify rollback successful
git log --oneline -10
```

---

### 1.3 Manual File Restoration (60-90 minutes)

If Git rollback is not feasible, manually restore critical files:

#### Core Configuration Files

**Info.plist Rollback**
```xml
<!-- Restore original values in UnstoppableWallet/UnstoppableWallet/Info.plist -->

<!-- 1. Bundle Identifier -->
<key>CFBundleIdentifier</key>
<string>io.horizontalsystems.bank-wallet</string>

<!-- 2. Display Name -->
<key>CFBundleDisplayName</key>
<string>Unstoppable</string>

<!-- 3. Bundle Name -->
<key>CFBundleName</key>
<string>Unstoppable Wallet</string>

<!-- 4. URL Schemes -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>unstoppable.money</string>
        </array>
    </dict>
</array>

<!-- 5. Version (optional - increment if needed) -->
<key>CFBundleShortVersionString</key>
<string>0.38.1</string>
```

**Localizable.strings Rollback**

Restore original strings in all language directories:
```bash
# English (en.lproj/Localizable.strings)
"app.name" = "Unstoppable";
"app.title" = "Unstoppable Wallet";

# Russian (ru.lproj/Localizable.strings)
"app.name" = "Unstoppable";
"app.title" = "Unstoppable Кошелёк";

# Spanish (es.lproj/Localizable.strings)
"app.name" = "Unstoppable";
"app.title" = "Unstoppable Wallet";

# Repeat for: fr, de, pt-BR, zh-Hans, ko, tr
```

**Assets.xcassets Rollback**

```bash
# Restore original app icon
# Replace: UnstoppableWallet/UnstoppableWallet/Assets.xcassets/AppIcon.appiconset/

# Restore original logo
# Replace: Assets.xcassets/logo.imageset/

# Restore original launch screen assets
# Replace: Assets.xcassets/launch-logo.imageset/

# Delete Fueki-specific assets
rm -rf Assets.xcassets/fueki-logo.imageset
rm -rf Assets.xcassets/FuekiColors.colorset

# Verify with Xcode
open UnstoppableWallet.xcworkspace
# Xcode > Editor > Validate Assets Catalog
```

---

### 1.4 Build Verification (30-60 minutes)

**Step 1: Clean Build**
```bash
# Delete all build artifacts
rm -rf ~/Library/Developer/Xcode/DerivedData/UnstoppableWallet-*

# Clean build folder in Xcode
# Product > Clean Build Folder (Cmd+Shift+K)

# Build project
# Product > Build (Cmd+B)

# Verify no build errors
```

**Step 2: Run Automated Tests**
```bash
# Run XCTest suite
# Product > Test (Cmd+U)

# Verify all tests pass
# Check test report for failures

# Run specific test suites
xcodebuild test -scheme UnstoppableWallet -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'
```

**Step 3: Manual Testing Checklist**
- [ ] App launches successfully
- [ ] Original "Unstoppable" branding visible
- [ ] URL scheme `unstoppable.money://` works
- [ ] Wallet creation/import functions
- [ ] Send transaction (testnet)
- [ ] Receive transaction (testnet)
- [ ] Backup wallet
- [ ] Restore wallet
- [ ] Biometric authentication
- [ ] Language switching

**Step 4: Device Testing**
- [ ] Test on physical iPhone (iOS 17)
- [ ] Test on physical iPhone (iOS 16)
- [ ] Test on physical iPhone (iOS 15)
- [ ] Test on iPad (latest iOS)

---

## Phase 2: Post-Release Rollback (Production Emergency)

**Use Case**: Critical issues discovered after App Store release.

### 2.1 Emergency Response (0-30 minutes)

**Step 1: Assess Impact**
```bash
# Check user reports
- App Store reviews
- Support tickets
- Social media mentions
- Crash reporting dashboard (Crashlytics/Sentry)

# Quantify affected users
- How many users affected? (< 1%, 1-10%, > 10%)
- How many devices/OS versions?
- Geographic distribution?

# Determine severity
- Can users access funds? (YES/NO)
- Are transactions working? (YES/NO)
- Is data being lost? (YES/NO)
```

**Step 2: Immediate Communication**
```bash
# Internal notification
Subject: PRODUCTION INCIDENT - Fueki v1.0 Critical Issue
Severity: P0
Status: Investigating
Impact: [X% of users affected]
Issue: [brief description]
Action: Preparing emergency rollback

# External communication (if needed)
Twitter/X: "We are aware of an issue affecting Fueki Wallet v1.0.
Our team is investigating. Do not uninstall the app.
Your funds are safe. Update coming shortly."

# App Store description update
"Important: If you experience issues with v1.0,
please contact support@fueki.io immediately.
Do not delete the app as this may affect wallet access."
```

---

### 2.2 App Store Expedited Rollback (1-4 hours)

**Option A: Submit Previous Version as Hotfix**

```bash
# Step 1: Prepare rollback build
# Use the last stable version (e.g., Unstoppable 0.38.1)

# Step 2: Increment version number
# In Info.plist:
CFBundleShortVersionString: 0.38.2 (or 1.0.1 if keeping Fueki)
CFBundleVersion: [increment build number]

# Step 3: Add release notes explaining rollback
Release Notes:
"Emergency hotfix: Temporarily reverting to previous stable version
while we address issues reported in v1.0. Your wallet and funds
are safe. We apologize for the inconvenience."

# Step 4: Submit to App Store with expedited review request
```

**Expedited Review Request Template**:
```
To: Apple App Review Team
Subject: Expedited Review Request - Critical Bug Fix

App Name: Fueki Wallet (or Unstoppable)
Version: [rollback version]
Platform: iOS

Reason for Expedited Review:
Our production app (v1.0) has a critical bug affecting [transaction processing/
wallet access/user data]. We are submitting a rollback to the previous stable
version (v0.38.1) to restore functionality for our users.

Impact:
- [Number of] users affected
- [Description of critical functionality broken]
- [Timeline of issue discovery]

This is an emergency hotfix to prevent [financial loss/data corruption/
security vulnerability].

We kindly request expedited review (24-hour) to minimize user impact.

Thank you for your understanding.
```

**Option B: Remove App from Sale (Last Resort)**

```bash
# If rollback submission will take too long:

# Step 1: Log into App Store Connect
# https://appstoreconnect.apple.com

# Step 2: Navigate to app
# My Apps > Fueki Wallet > Pricing and Availability

# Step 3: Remove from sale
# Set availability to: "Remove from Sale"
# This prevents new downloads but allows existing users to keep app

# Step 4: Add temporary message
# Update app description:
"This version is temporarily unavailable while we address
technical issues. If you have already downloaded the app,
please contact support@fueki.io for assistance."

# Step 5: Restore previous version to sale
# If possible, make Unstoppable 0.38.1 available again
# This may require contacting Apple Developer Support
```

---

### 2.3 User Communication Strategy (Ongoing)

**Communication Channels**:

1. **In-App Alert** (if app is functional):
```swift
// Display banner alert to all users
Alert(
    title: "Important Update",
    message: "We've detected an issue with this version. Please update to the latest version in the App Store to ensure optimal performance. Your funds are safe.",
    primaryButton: .default(Text("Update Now")) {
        // Open App Store
    },
    secondaryButton: .cancel(Text("Later"))
)
```

2. **Push Notification** (if configured):
```json
{
  "title": "Fueki Wallet Update Available",
  "body": "A critical update is available. Please update now to restore full functionality.",
  "category": "CRITICAL_UPDATE",
  "data": {
    "action": "force_update",
    "min_version": "0.38.2"
  }
}
```

3. **Email to Users** (if email addresses collected):
```
Subject: Important: Fueki Wallet Update Required

Dear Fueki Wallet User,

We've identified an issue affecting version 1.0 of Fueki Wallet.
To ensure the security and functionality of your wallet,
please update to version 0.38.2 as soon as possible.

Your funds are completely safe, but this update will restore
optimal performance.

How to Update:
1. Open the App Store
2. Navigate to Updates
3. Update Fueki Wallet

If you experience any issues, please contact our support team
at support@fueki.io

We apologize for the inconvenience and thank you for your patience.

Best regards,
The Fueki Team
```

4. **Social Media Updates**:
```
Twitter/X:
"📱 Important: Users experiencing issues with Fueki Wallet v1.0,
an update (v0.38.2) is now available in the App Store.
Your funds are safe. Please update ASAP.
Support: support@fueki.io #FuekiWallet"

Reddit (r/FuekiWallet):
"Emergency Hotfix Released: v0.38.2
If you downloaded v1.0 and are experiencing issues,
please update immediately. This hotfix resolves [issue description].
Your funds are secure. FAQ in comments."
```

5. **Support Documentation**:
```markdown
# Fueki Wallet v1.0 Rollback FAQ

**Q: Why was v1.0 rolled back?**
A: We discovered a [critical issue] affecting [functionality].
To protect users, we rolled back to the previous stable version.

**Q: Are my funds safe?**
A: Yes. Your funds are stored on the blockchain and are completely safe.

**Q: Do I need to restore my wallet?**
A: No. Your wallet will continue to work normally after updating.

**Q: Will my transaction history be lost?**
A: No. All transaction history is preserved.

**Q: When will the rebrand to Fueki be completed?**
A: We are working to resolve the issues and will relaunch the
Fueki brand once all testing is complete. Estimated [timeframe].
```

---

## Phase 3: Post-Rollback Recovery (4-72 hours)

### 3.1 Root Cause Analysis (4-8 hours)

**Step 1: Reproduce the Issue**
```bash
# Set up test environment matching production
# - Same iOS version
# - Same device model
# - Same app version (Fueki 1.0)

# Reproduce steps
1. [step 1]
2. [step 2]
3. [observed failure]

# Capture logs
- Xcode console output
- Device system logs
- Crash reports
- Network traffic (Charles Proxy)
```

**Step 2: Identify Root Cause**
```bash
# Common root causes:
- [ ] Bundle ID configuration error
- [ ] Keychain access permission issue
- [ ] URL scheme parsing bug
- [ ] Asset loading failure
- [ ] Localization string error
- [ ] Code signing problem
- [ ] Network endpoint misconfiguration
- [ ] Database migration failure

# Document findings
Root Cause: [detailed technical explanation]
Affected Code: [file paths and line numbers]
Why It Happened: [human/process error analysis]
Why It Wasn't Caught: [testing gap identification]
```

**Step 3: Fix Implementation**
```bash
# Create fix branch
git checkout -b fix/fueki-rollback-issue

# Implement fix
[code changes]

# Write regression test
# Ensure this issue can never happen again
[test code]

# Peer review
[2+ developers review fix]

# Merge to development
git checkout develop
git merge fix/fueki-rollback-issue
```

---

### 3.2 Enhanced Testing (24-48 hours)

**Expanded Test Suite**:
```bash
# Add new test cases covering the failure scenario
class FuekiRegressionTests: XCTestCase {

    func testBundleIDMigration() {
        // Test that caused rollback
    }

    func testKeychainAccess() {
        // Verify keychain works across bundle ID change
    }

    func testTransactionFlow() {
        // End-to-end transaction test
    }

    // ... 20+ new tests
}
```

**Extended Beta Testing**:
```bash
# TestFlight beta with expanded scope
- Increased beta testers: 50+ users (was 10)
- Extended beta period: 14 days (was 7)
- Diverse device pool: 10+ device models
- Multiple iOS versions: 15.0, 16.0, 17.0, 17.4

# Beta testing checklist
- [ ] All original test cases pass
- [ ] New regression tests pass
- [ ] No issues reported by beta testers
- [ ] Crash-free rate: 100%
- [ ] Performance metrics acceptable
```

---

### 3.3 Relaunch Decision (48-72 hours)

**Go/No-Go Criteria**:

**GO Criteria** (all must be YES):
- [ ] Root cause identified and fixed
- [ ] Fix verified by 3+ developers
- [ ] All automated tests pass (100%)
- [ ] Extended beta testing completed (14 days, 50+ users)
- [ ] Zero critical bugs reported
- [ ] Crash-free rate: 99.9%+
- [ ] Performance benchmarks met
- [ ] Legal/trademark clearance obtained
- [ ] App Store pre-submission review passed
- [ ] Communication plan ready
- [ ] Rollback plan v2.0 prepared

**NO-GO Criteria** (any ONE is a blocker):
- ❌ Any critical bug still present
- ❌ Beta testers report issues
- ❌ Crash rate > 0.1%
- ❌ Transaction functionality not 100% verified
- ❌ Backup/restore not fully tested
- ❌ Legal concerns unresolved
- ❌ Insufficient testing coverage

**Decision Authority**:
- Technical Lead: [Approve/Deny]
- QA Lead: [Approve/Deny]
- Product Manager: [Approve/Deny]
- Security Engineer: [Approve/Deny]

**Unanimous approval required for relaunch.**

---

## Phase 4: Lessons Learned & Process Improvements

### 4.1 Post-Mortem Document

```markdown
# Fueki Wallet Rollback Post-Mortem

## Incident Summary
- **Date**: [incident date]
- **Duration**: [time from detection to resolution]
- **Severity**: P0 Critical
- **Impact**: [number of users affected]
- **Root Cause**: [technical root cause]

## Timeline
- [Time]: Issue first reported
- [Time]: Incident declared
- [Time]: Rollback initiated
- [Time]: Rollback completed
- [Time]: Issue resolved
- [Time]: Post-mortem completed

## What Went Well
- ✅ [positive action 1]
- ✅ [positive action 2]
- ✅ [positive action 3]

## What Went Wrong
- ❌ [failure point 1]
- ❌ [failure point 2]
- ❌ [failure point 3]

## Action Items
| Action | Owner | Deadline | Status |
|--------|-------|----------|--------|
| [improvement 1] | [person] | [date] | [status] |
| [improvement 2] | [person] | [date] | [status] |

## Process Changes
- 📋 [process improvement 1]
- 📋 [process improvement 2]
```

### 4.2 Process Improvements

**Enhanced Testing Requirements**:
```bash
# Add to CI/CD pipeline
1. Automated bundle ID validation
2. Keychain migration tests
3. End-to-end transaction tests (testnet)
4. Visual regression testing (screenshots)
5. Localization validation
6. Asset catalog integrity checks
7. URL scheme validation
8. Build configuration verification

# Require sign-off from:
- QA Lead (testing complete)
- Security Engineer (security review)
- iOS Developer (code review)
- Product Manager (business requirements)
```

**Staging Environment**:
```bash
# Implement staging release process
1. Deploy to internal TestFlight (3 days)
2. Deploy to external beta (7 days)
3. Deploy to limited rollout (20% of users, 7 days)
4. Deploy to full release (100% of users)

# Rollback triggers at each stage
- Critical bugs → immediate rollback to previous stage
- Crash rate > 1% → pause rollout
- User complaints > 5% → investigate
```

---

## Rollback Checklist Summary

### Pre-Release Rollback
- [ ] Stop all deployment immediately
- [ ] Document issue with evidence
- [ ] Notify all stakeholders
- [ ] Execute code rollback (git revert or manual)
- [ ] Restore configuration files (Info.plist, strings, assets)
- [ ] Clean build and test
- [ ] Run full test suite (automated + manual)
- [ ] Test on multiple devices
- [ ] Verify original branding restored
- [ ] Get approval from QA Lead + Architect

### Post-Release Rollback
- [ ] Assess user impact (number of users, severity)
- [ ] Communicate internally (URGENT notification)
- [ ] Communicate externally (social media, email)
- [ ] Submit rollback build to App Store
- [ ] Request expedited review from Apple
- [ ] Send push notification to users (if configured)
- [ ] Update App Store description
- [ ] Monitor crash reports and user feedback
- [ ] Prepare FAQ and support documentation
- [ ] Consider removing app from sale (if necessary)

### Post-Rollback Recovery
- [ ] Conduct root cause analysis (4-8 hours)
- [ ] Implement fix with regression test
- [ ] Expand test suite with new cases
- [ ] Extended beta testing (14 days, 50+ users)
- [ ] Go/No-Go decision (unanimous approval required)
- [ ] Prepare relaunch communication
- [ ] Write post-mortem document
- [ ] Implement process improvements

---

## Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| QA Lead | [email] | 24/7 |
| iOS Developer | [email] | 24/7 |
| Project Architect | [email] | 24/7 |
| Product Manager | [email] | Business hours |
| Security Engineer | [email] | On-call |
| Apple Developer Support | developer.apple.com/support | Business hours |

---

## Final Notes

**Key Principles**:
1. **User safety first**: Protect user funds and data above all else
2. **Fail fast**: Don't hesitate to rollback if critical issues found
3. **Transparent communication**: Keep users informed throughout
4. **Learn and improve**: Every rollback makes the next release stronger
5. **Test exhaustively**: Better to delay than to release broken code

**Remember**: A successful rollback is better than a failed launch.
User trust is earned slowly and lost quickly.

---

**Document Version**: 1.0
**Last Updated**: 2025-10-22
**Next Review**: After any rollback event
**Owner**: QA Lead + Project Architect
