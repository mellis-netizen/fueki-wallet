# Known Issues - Fueki Wallet iOS

**Version:** 1.0 (Build 1)
**Last Updated:** October 21, 2025
**Status:** Pre-Production

---

## Critical Issues (Blocking Production) 🔴

### CRIT-001: Privacy Manifest Missing
**Severity:** CRITICAL
**Status:** Open
**Impact:** App Store rejection
**Discovered:** 2025-10-21

**Description:**
iOS requires a privacy manifest file (`PrivacyInfo.xcprivacy`) since iOS 17.0. This file is completely missing from the project.

**Affected Components:**
- App Store submission
- iOS 17+ compliance

**Reproduction:**
```bash
ls ios/FuekiWallet/PrivacyInfo.xcprivacy
# File does not exist
```

**Expected Behavior:**
Privacy manifest should exist and declare:
- Privacy-impacting APIs used
- Data collection practices
- Tracking domains (if any)

**Workaround:**
None - must be fixed for App Store submission

**Fix Required:**
Create `PrivacyInfo.xcprivacy` with complete privacy declarations

**Estimated Effort:** 4 hours
**Priority:** P0 (Must fix before submission)

**Related:**
- APP_STORE_SUBMISSION.md Section 2.1
- PRODUCTION_READINESS_REPORT.md Section 4

---

### CRIT-002: Debug Logging in Production Code
**Severity:** CRITICAL
**Status:** Open
**Impact:** Security risk, performance degradation
**Discovered:** 2025-10-21

**Description:**
75 instances of `print()`, `NSLog()`, or `debugPrint()` found in production source code across 22 files. These statements may:
- Expose sensitive data in device logs
- Impact performance
- Drain battery
- Leak cryptographic operations

**Affected Files:**
```
PaymentRampService.swift: 3 instances
BiometricAuthView.swift: 2 instances
WalletViewModel.swift: 1 instance
SendCryptoViewModel.swift: 2 instances
+ 18 other files
Total: 75 instances
```

**Example:**
```swift
// WRONG - in production code
print("Private key: \(privateKey)")
print("Transaction hash: \(txHash)")
```

**Expected Behavior:**
- No debug logging in production builds
- Use OSLog for production logging with proper log levels
- Sensitive data should never be logged

**Security Impact:**
Private keys, seed phrases, or transaction data could be leaked to:
- Device system logs
- Crash reports
- Debugging tools

**Workaround:**
None - must remove all debug statements

**Fix Required:**
1. Remove all `print()` statements
2. Implement OSLog framework
3. Use conditional compilation for debug builds

**Proposed Solution:**
```swift
import OSLog

extension Logger {
    static let wallet = Logger(subsystem: "com.fueki.wallet", category: "wallet")
}

// Usage
#if DEBUG
Logger.wallet.debug("Debug info: \(info)")
#endif

Logger.wallet.info("User action completed")
```

**Estimated Effort:** 3 hours
**Priority:** P0 (Security risk)

**Related:**
- PRODUCTION_READINESS_REPORT.md Section 2

---

### CRIT-003: App Store Assets Incomplete
**Severity:** CRITICAL
**Status:** Open
**Impact:** App Store submission blocked
**Discovered:** 2025-10-21

**Description:**
Required App Store assets are missing or incomplete:
- App icons may be incomplete (only AppIcon.appiconset found)
- No screenshots for App Store listing
- No app description prepared
- No keywords defined

**Missing Assets:**
1. App Store screenshots (5 required sizes)
2. App icon verification (all sizes)
3. Marketing materials
4. App preview video (optional but recommended)

**Impact:**
Cannot complete App Store Connect listing

**Workaround:**
None - required for submission

**Fix Required:**
Generate all required assets per App Store guidelines

**Estimated Effort:** 8 hours
**Priority:** P0 (Blocks submission)

**Related:**
- APP_STORE_SUBMISSION.md Section 1.4

---

### CRIT-004: Production Code Signing Not Configured
**Severity:** CRITICAL
**Status:** Open
**Impact:** Cannot create App Store build
**Discovered:** 2025-10-21

**Description:**
Current build configuration uses development signing:
```
CODE_SIGN_IDENTITY = Apple Development
aps-environment = development
```

Production builds require:
```
CODE_SIGN_IDENTITY = Apple Distribution
aps-environment = production
```

**Affected Components:**
- App Store archive creation
- Push notifications
- Production deployment

**Workaround:**
Continue using development builds (not for App Store)

**Fix Required:**
1. Create production provisioning profiles
2. Configure distribution certificates
3. Update entitlements for production
4. Test archive creation

**Estimated Effort:** 2 hours
**Priority:** P0 (Required for production)

**Related:**
- APP_STORE_SUBMISSION.md Section 2.4

---

## High Priority Issues (Should Fix) 🟠

### HIGH-001: SwiftLint Not Configured
**Severity:** HIGH
**Status:** Open
**Impact:** Code quality, maintainability
**Discovered:** 2025-10-21

**Description:**
SwiftLint is not installed or configured in the build environment. Configuration file exists (`.swiftlint.yml`) but linter is not running.

**Current State:**
```bash
swiftlint lint
# command not found: swiftlint
```

**Impact:**
- No automated code style enforcement
- Potential style inconsistencies
- No automated best practice checks

**Workaround:**
Manual code review

**Fix Required:**
```bash
# Install SwiftLint
brew install swiftlint

# Add to Xcode build phase
# Run Script Phase:
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

**Estimated Effort:** 1 hour
**Priority:** P1

---

### HIGH-002: TODO/FIXME Comments in Code
**Severity:** HIGH
**Status:** Open
**Impact:** Technical debt, incomplete features
**Discovered:** 2025-10-21

**Description:**
30 TODO/FIXME/XXX/HACK comments found in source code indicating:
- Incomplete implementations
- Known bugs
- Future improvements
- Technical debt

**Distribution:**
```
TODO: 18 instances
FIXME: 8 instances
XXX: 3 instances
HACK: 1 instance
```

**Examples:**
```swift
// TODO: Implement proper error handling
// FIXME: This is a temporary workaround
// XXX: Security review needed
// HACK: Quick fix for deadline
```

**Impact:**
- Incomplete features may surface
- Known bugs not addressed
- Technical debt accumulation

**Workaround:**
Track TODOs in issue tracker instead

**Fix Required:**
1. Review all TODO comments
2. Create GitHub issues for legitimate items
3. Fix or remove all comments
4. Document incomplete features

**Estimated Effort:** 4 hours (review and triage)
**Priority:** P1

---

### HIGH-003: Performance Not Validated on Device
**Severity:** HIGH
**Status:** Open
**Impact:** Poor user experience, App Store rejection
**Discovered:** 2025-10-21

**Description:**
No performance profiling has been done on physical devices:
- Launch time unknown (target: < 2 seconds)
- Memory usage unknown (target: < 100MB)
- Frame rate unknown (target: 60 FPS)
- Battery impact unknown

**Required Tests:**
1. Launch time profiling (cold start)
2. Memory leak detection (Instruments)
3. Frame rate monitoring (Core Animation)
4. Battery usage (24-hour test)
5. Network performance (various conditions)

**Risk:**
App may be slow, drain battery, or crash under load

**Workaround:**
None - testing required

**Fix Required:**
Comprehensive device testing with Instruments

**Estimated Effort:** 8 hours
**Priority:** P1

---

### HIGH-004: Marketing Version Not Set
**Severity:** HIGH
**Status:** Open
**Impact:** Build configuration, App Store metadata
**Discovered:** 2025-10-21

**Description:**
`MARKETING_VERSION` is not explicitly set in project settings, relying on variable substitution:
```xml
<key>CFBundleShortVersionString</key>
<string>$(MARKETING_VERSION)</string>
```

**Expected:**
Explicit version in build settings:
```
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1
```

**Impact:**
- Version string may be undefined
- App Store Connect may reject upload
- TestFlight builds unclear

**Workaround:**
Set manually in Xcode before archive

**Fix Required:**
Set explicit version numbers in project settings

**Estimated Effort:** 15 minutes
**Priority:** P1

---

## Medium Priority Issues (Recommended) 🟡

### MED-001: Test Coverage Below Best Practice
**Severity:** MEDIUM
**Status:** Open
**Impact:** Quality assurance, bug risk
**Discovered:** 2025-10-21

**Description:**
Test coverage is approximately 24.5% (7,486 test lines / 30,513 source lines), below industry best practice of 80%.

**Coverage Analysis:**
```
Excellent coverage:
- Crypto operations
- Transaction logic
- Key derivation

Poor coverage:
- UI components
- Network error handling
- Edge cases
- Payment integrations
```

**Missing Tests:**
1. End-to-end user flows
2. Payment ramp integration (MoonPay, Ramp Network)
3. Multi-chain wallet switching
4. Network failure recovery
5. Biometric authentication edge cases
6. Memory leak tests
7. Performance regression tests

**Impact:**
Higher risk of production bugs

**Workaround:**
Manual testing for uncovered areas

**Fix Required:**
Increase test coverage to 80%+

**Estimated Effort:** 40 hours
**Priority:** P2

---

### MED-002: No End-to-End Tests
**Severity:** MEDIUM
**Status:** Open
**Impact:** Integration bugs, user experience
**Discovered:** 2025-10-21

**Description:**
Only unit tests and basic UI tests exist. No comprehensive end-to-end tests covering complete user workflows.

**Missing E2E Tests:**
1. Complete onboarding flow
2. Create wallet → backup → recover
3. Send transaction flow (real blockchain)
4. Buy crypto flow (with payment ramp)
5. Multi-chain wallet switching
6. Biometric authentication throughout app

**Impact:**
Integration bugs may not be caught until production

**Workaround:**
Thorough manual testing

**Fix Required:**
Implement comprehensive E2E test suite

**Estimated Effort:** 16 hours
**Priority:** P2

---

### MED-003: Payment Ramp Integration Untested
**Severity:** MEDIUM
**Status:** Open
**Impact:** Financial operations risk
**Discovered:** 2025-10-21

**Description:**
MoonPay and Ramp Network integrations exist in code but have no test coverage:
- `MoonPayProvider.swift` - No tests
- `RampNetworkProvider.swift` - No tests
- `PaymentRampService.swift` - No tests
- `PaymentWebhookService.swift` - No tests

**Risk:**
- Payment failures in production
- Webhook handling bugs
- Fraud detection issues
- User fund loss

**Workaround:**
Extensive manual testing on testnet

**Fix Required:**
1. Create mock payment provider tests
2. Test webhook handling
3. Test fraud detection logic
4. Integration tests with testnet

**Estimated Effort:** 8 hours
**Priority:** P2

---

### MED-004: No Jailbreak Detection
**Severity:** MEDIUM
**Status:** Open
**Impact:** Security on compromised devices
**Discovered:** 2025-10-21

**Description:**
App does not detect or warn when running on jailbroken devices. Jailbroken devices have:
- Disabled security features
- Potential keychain access
- Compromised Secure Enclave

**Risk:**
Private keys may be extractable on jailbroken devices

**Workaround:**
User education about device security

**Fix Required:**
Implement jailbreak detection:
```swift
class JailbreakDetector {
    static func isJailbroken() -> Bool {
        // Check for jailbreak indicators
        // Show warning to user
        // Optionally restrict features
    }
}
```

**Estimated Effort:** 4 hours
**Priority:** P2

---

### MED-005: Memory Management Not Validated
**Severity:** MEDIUM
**Status:** Open
**Impact:** Crashes, memory leaks
**Discovered:** 2025-10-21

**Description:**
No memory leak detection has been performed:
- Potential retain cycles
- Memory leaks in async operations
- Large data structure handling
- Image caching issues

**Required Testing:**
1. Run Instruments Memory Graph
2. Check for retain cycles
3. Profile memory usage over time
4. Test with large transaction history

**Risk:**
App may crash or slow down over time

**Workaround:**
None - testing required

**Fix Required:**
Memory profiling with Instruments

**Estimated Effort:** 4 hours
**Priority:** P2

---

## Low Priority Issues (Nice to Have) 🟢

### LOW-001: Single Language Only
**Severity:** LOW
**Status:** Open
**Impact:** Market reach
**Discovered:** 2025-10-21

**Description:**
App only supports English. No localization for other languages.

**Impact:**
Reduced market in non-English speaking countries

**Workaround:**
Focus on English-speaking markets initially

**Fix Required:**
Implement localization for:
- Spanish
- Chinese (Simplified & Traditional)
- Japanese
- Korean
- French
- German

**Estimated Effort:** 24 hours
**Priority:** P3

---

### LOW-002: No App Preview Video
**Severity:** LOW
**Status:** Open
**Impact:** App Store conversion rate
**Discovered:** 2025-10-21

**Description:**
No app preview video for App Store listing. Preview videos can increase download conversion by 20-30%.

**Impact:**
Lower App Store conversion rate

**Workaround:**
Good screenshots can compensate

**Fix Required:**
Create 15-30 second app preview video

**Estimated Effort:** 8 hours
**Priority:** P3

---

### LOW-003: No Accessibility Audit
**Severity:** LOW
**Status:** Open
**Impact:** ADA compliance, accessibility
**Discovered:** 2025-10-21

**Description:**
No accessibility audit performed:
- VoiceOver support unknown
- Dynamic Type support unknown
- Color contrast validation needed
- Accessibility labels missing

**Impact:**
App may not be usable for users with disabilities

**Workaround:**
Basic SwiftUI accessibility is decent by default

**Fix Required:**
1. Accessibility audit with VoiceOver
2. Add accessibility labels
3. Test with Dynamic Type
4. Verify color contrast

**Estimated Effort:** 8 hours
**Priority:** P3

---

### LOW-004: No Marketing Website
**Severity:** LOW
**Status:** Open
**Impact:** User trust, App Store requirements
**Discovered:** 2025-10-21

**Description:**
No marketing website exists for:
- Privacy policy hosting
- Terms of service
- Support documentation
- Marketing materials

**Required URLs:**
- https://fueki.com (marketing)
- https://fueki.com/privacy (privacy policy)
- https://fueki.com/terms (terms of service)
- https://support.fueki.com (support)

**Impact:**
- Required for App Store submission
- Reduced user trust
- No marketing presence

**Workaround:**
Use placeholder pages initially

**Fix Required:**
Create complete marketing website

**Estimated Effort:** 40 hours
**Priority:** P3

---

### LOW-005: No Analytics Implementation
**Severity:** LOW
**Status:** Open
**Impact:** Product insights, optimization
**Discovered:** 2025-10-21

**Description:**
No analytics tracking implemented:
- User behavior unknown
- Feature usage unknown
- Conversion funnels unknown
- Crash analytics basic

**Impact:**
Cannot optimize user experience based on data

**Workaround:**
Manual user feedback

**Fix Required:**
Implement privacy-respecting analytics:
- Firebase Analytics (optional)
- App Store Connect analytics
- Custom event tracking

**Estimated Effort:** 8 hours
**Priority:** P3

---

## Resolved Issues ✅

None yet - initial release

---

## Issue Statistics

### By Severity
```
CRITICAL: 4 issues (🔴)
HIGH:     4 issues (🟠)
MEDIUM:   5 issues (🟡)
LOW:      5 issues (🟢)
Total:   18 issues
```

### By Status
```
Open:      18 issues
In Progress: 0 issues
Resolved:    0 issues
```

### By Category
```
App Store Compliance: 4 issues
Security:             3 issues
Performance:          3 issues
Testing:              4 issues
Code Quality:         2 issues
Accessibility:        1 issue
Localization:         1 issue
```

---

## Priority Definitions

### P0 - Critical (Blocking)
- Blocks App Store submission or production deployment
- Security vulnerabilities
- Data loss risks
- Must fix before release

### P1 - High Priority
- Impacts user experience significantly
- Performance issues
- Should fix before release
- Affects quality

### P2 - Medium Priority
- Recommended improvements
- Quality enhancements
- Can ship without, but should address soon
- Next release candidates

### P3 - Low Priority
- Nice to have features
- Future enhancements
- Competitive advantages
- Backlog items

---

## Fix Timeline

### Week 1 (Pre-Submission)
**Focus:** Critical issues only

- [x] Document all issues (this file)
- [ ] CRIT-001: Create privacy manifest (4 hours)
- [ ] CRIT-002: Remove debug logging (3 hours)
- [ ] CRIT-003: Generate App Store assets (8 hours)
- [ ] CRIT-004: Configure production signing (2 hours)
- [ ] HIGH-001: Install SwiftLint (1 hour)
- [ ] HIGH-004: Set marketing version (15 min)

**Total Effort:** ~18 hours
**Status:** Ready for submission

### Week 2 (Post-Submission)
**Focus:** High priority issues

- [ ] HIGH-002: Address TODO comments (4 hours)
- [ ] HIGH-003: Device performance testing (8 hours)
- [ ] MED-001: Improve test coverage (16 hours)
- [ ] MED-002: End-to-end tests (8 hours)

**Total Effort:** ~36 hours
**Status:** Quality improvements

### Week 3-4 (Refinement)
**Focus:** Medium/Low priority

- [ ] MED-003: Test payment integrations (8 hours)
- [ ] MED-004: Jailbreak detection (4 hours)
- [ ] MED-005: Memory profiling (4 hours)
- [ ] LOW-001: Localization (24 hours)
- [ ] LOW-003: Accessibility audit (8 hours)

**Total Effort:** ~48 hours
**Status:** Feature complete

---

## How to Report New Issues

### Issue Template

```markdown
### ISSUE-XXX: [Brief Title]
**Severity:** CRITICAL | HIGH | MEDIUM | LOW
**Status:** Open | In Progress | Resolved
**Impact:** [Business/technical impact]
**Discovered:** [Date]

**Description:**
[Detailed description of the issue]

**Affected Components:**
- [Component 1]
- [Component 2]

**Reproduction Steps:**
1. Step 1
2. Step 2
3. Observe issue

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Workaround:**
[Temporary solution if available]

**Fix Required:**
[Proposed solution]

**Estimated Effort:** [Hours]
**Priority:** P0 | P1 | P2 | P3
```

### Submission Process

1. Create issue in GitHub repository
2. Add to this document
3. Update statistics
4. Notify production validation team
5. Add to appropriate sprint/milestone

---

## Contact & Support

**Production Validation Team:**
- Email: production@fueki.com
- Slack: #fueki-production
- On-call: +1-XXX-XXX-XXXX

**Issue Escalation:**
- P0: Immediate escalation to CTO
- P1: Daily standup discussion
- P2: Weekly sprint planning
- P3: Backlog grooming

---

**Document Version:** 1.0
**Last Updated:** October 21, 2025
**Next Review:** October 28, 2025
**Owner:** Production Validation Agent
