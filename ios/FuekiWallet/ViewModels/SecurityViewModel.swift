//
//  SecurityViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import LocalAuthentication
import SwiftUI

/// Comprehensive ViewModel for security operations
@MainActor
final class SecurityViewModel: ObservableObject {

    // MARK: - Published Properties

    // MARK: - Biometric Authentication

    @Published var biometricType: BiometricType = .none
    @Published var isBiometricAvailable = false
    @Published var isBiometricEnabled = false
    @Published var biometricError: String?

    // MARK: - PIN/Passcode

    @Published var hasPINSet = false
    @Published var isPINEnabled = true
    @Published var pinLength: Int = 6
    @Published var requirePINOnLaunch = true

    // MARK: - Auto-Lock

    @Published var autoLockEnabled = true
    @Published var autoLockTimeout: TimeInterval = 300 // 5 minutes
    @Published var lastActivityTime: Date = Date()
    @Published var isLocked = true

    // MARK: - Security Status

    @Published var securityScore: Double = 0.0
    @Published var securityIssues: [SecurityIssue] = []
    @Published var jailbreakDetected = false
    @Published var debuggerDetected = false
    @Published var integrityCheckPassed = true

    // MARK: - Two-Factor Authentication

    @Published var twoFactorEnabled = false
    @Published var twoFactorMethod: TwoFactorMethod = .none
    @Published var backupCodes: [String] = []
    @Published var showBackupCodes = false

    // MARK: - Session Management

    @Published var sessionActive = false
    @Published var sessionExpiry: Date?
    @Published var sessionDuration: TimeInterval = 3600 // 1 hour
    @Published var maxConcurrentSessions = 1

    // MARK: - Password/PIN Entry

    @Published var currentPIN = ""
    @Published var newPIN = ""
    @Published var confirmPIN = ""
    @Published var showPINSetup = false
    @Published var showPINChange = false

    // MARK: - Recovery Options

    @Published var securityQuestions: [SecurityQuestion] = []
    @Published var hasSecurityQuestionsSet = false
    @Published var recoveryEmailSet = false
    @Published var recoveryEmail = ""

    // MARK: - UI State

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var successMessage: String?
    @Published var showSuccess = false

    // MARK: - Advanced Security

    @Published var clipboardSecurityEnabled = true
    @Published var screenshotProtectionEnabled = true
    @Published var antiPhishingEnabled = true
    @Published var transactionSigningRequired = true

    // MARK: - Security Logs

    @Published var securityEvents: [SecurityEvent] = []
    @Published var showSecurityLog = false
    @Published var failedAuthAttempts = 0
    @Published var maxFailedAttempts = 5

    // MARK: - Dependencies

    private let biometricService: BiometricAuthManagerProtocol
    private let securityService: SecurityAuditorProtocol
    private let keychainService: KeychainManagerProtocol
    private let encryptionService: EncryptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Timers

    private var autoLockTimer: Timer?
    private var sessionTimer: Timer?

    // MARK: - Initialization

    init(
        biometricService: BiometricAuthManagerProtocol = BiometricAuthManager.shared,
        securityService: SecurityAuditorProtocol = SecurityAuditor.shared,
        keychainService: KeychainManagerProtocol = KeychainManager.shared,
        encryptionService: EncryptionServiceProtocol = EncryptionService.shared
    ) {
        self.biometricService = biometricService
        self.securityService = securityService
        self.keychainService = keychainService
        self.encryptionService = encryptionService
        setupBindings()
        Task { await initialize() }
    }

    deinit {
        autoLockTimer?.invalidate()
        sessionTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Monitor success state
        $successMessage
            .map { $0 != nil }
            .assign(to: &$showSuccess)

        // Auto-lock timer
        Publishers.CombineLatest($autoLockEnabled, $autoLockTimeout)
            .sink { [weak self] enabled, timeout in
                if enabled {
                    self?.startAutoLockTimer()
                } else {
                    self?.stopAutoLockTimer()
                }
            }
            .store(in: &cancellables)

        // Session expiry monitoring
        $sessionExpiry
            .sink { [weak self] expiry in
                guard let expiry = expiry else { return }
                self?.scheduleSessionExpiry(at: expiry)
            }
            .store(in: &cancellables)

        // Calculate security score when issues change
        $securityIssues
            .map { [weak self] issues in
                self?.calculateSecurityScore(issues: issues) ?? 0.0
            }
            .assign(to: &$securityScore)

        // PIN validation
        Publishers.CombineLatest3($newPIN, $confirmPIN, $pinLength)
            .sink { [weak self] newPin, confirmPin, length in
                // Validate PIN criteria
            }
            .store(in: &cancellables)
    }

    // MARK: - Initialization

    func initialize() async {
        await checkBiometricAvailability()
        await loadSecuritySettings()
        await performSecurityAudit()
        startActivityMonitoring()
    }

    // MARK: - Biometric Authentication

    func checkBiometricAvailability() async {
        do {
            let (available, type) = try await biometricService.checkAvailability()
            isBiometricAvailable = available
            biometricType = type
        } catch {
            biometricError = error.localizedDescription
            isBiometricAvailable = false
        }
    }

    func enableBiometric() async -> Bool {
        guard isBiometricAvailable else {
            errorMessage = "Biometric authentication is not available"
            return false
        }

        isLoading = true

        do {
            let success = try await biometricService.authenticate(
                reason: "Enable biometric authentication for wallet access"
            )

            if success {
                isBiometricEnabled = true
                try await saveSecuritySettings()
                logSecurityEvent(.biometricEnabled)
                successMessage = "Biometric authentication enabled"
                return true
            } else {
                errorMessage = "Biometric authentication failed"
                return false
            }
        } catch {
            errorMessage = "Failed to enable biometric: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func disableBiometric() async -> Bool {
        // Require current authentication
        let authenticated = await authenticateUser(reason: "Disable biometric authentication")
        guard authenticated else { return false }

        isBiometricEnabled = false

        do {
            try await saveSecuritySettings()
            logSecurityEvent(.biometricDisabled)
            successMessage = "Biometric authentication disabled"
            return true
        } catch {
            errorMessage = "Failed to disable biometric: \(error.localizedDescription)"
            return false
        }
    }

    func authenticateWithBiometric() async -> Bool {
        guard isBiometricEnabled else { return false }

        do {
            let success = try await biometricService.authenticate(
                reason: "Authenticate to access wallet"
            )

            if success {
                await unlockWallet()
                logSecurityEvent(.biometricAuthSuccess)
                return true
            } else {
                failedAuthAttempts += 1
                logSecurityEvent(.biometricAuthFailed)

                if failedAuthAttempts >= maxFailedAttempts {
                    await handleMaxFailedAttempts()
                }

                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            logSecurityEvent(.biometricAuthError)
            return false
        }
    }

    // MARK: - PIN Management

    func setupPIN() async -> Bool {
        guard newPIN.count == pinLength else {
            errorMessage = "PIN must be \(pinLength) digits"
            return false
        }

        guard newPIN == confirmPIN else {
            errorMessage = "PINs do not match"
            return false
        }

        // Validate PIN strength
        guard validatePINStrength(newPIN) else {
            errorMessage = "PIN is too weak. Avoid sequential or repeated digits"
            return false
        }

        isLoading = true

        do {
            // Hash and encrypt PIN
            let hashedPIN = try await encryptionService.hashPIN(newPIN)

            // Store in Keychain
            try await keychainService.savePIN(hashedPIN)

            hasPINSet = true
            isPINEnabled = true
            logSecurityEvent(.pinCreated)

            successMessage = "PIN created successfully"
            resetPINFields()
            showPINSetup = false

            return true
        } catch {
            errorMessage = "Failed to create PIN: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func changePIN() async -> Bool {
        // Verify current PIN
        guard await verifyPIN(currentPIN) else {
            errorMessage = "Current PIN is incorrect"
            failedAuthAttempts += 1
            return false
        }

        // Setup new PIN
        return await setupPIN()
    }

    func verifyPIN(_ pin: String) async -> Bool {
        do {
            let storedHash = try await keychainService.loadPIN()
            let inputHash = try await encryptionService.hashPIN(pin)

            if inputHash == storedHash {
                failedAuthAttempts = 0
                await unlockWallet()
                logSecurityEvent(.pinAuthSuccess)
                return true
            } else {
                failedAuthAttempts += 1
                logSecurityEvent(.pinAuthFailed)

                if failedAuthAttempts >= maxFailedAttempts {
                    await handleMaxFailedAttempts()
                }

                return false
            }
        } catch {
            errorMessage = "Failed to verify PIN: \(error.localizedDescription)"
            return false
        }
    }

    private func validatePINStrength(_ pin: String) -> Bool {
        // Check for sequential digits
        let sequential = ["0123456789", "9876543210"]
        for seq in sequential {
            if seq.contains(pin) {
                return false
            }
        }

        // Check for repeated digits
        let uniqueDigits = Set(pin)
        if uniqueDigits.count < 3 {
            return false
        }

        return true
    }

    // MARK: - Auto-Lock

    func updateActivity() {
        lastActivityTime = Date()

        if isLocked {
            // Activity detected while locked is suspicious
            logSecurityEvent(.suspiciousActivity)
        }
    }

    private func startAutoLockTimer() {
        stopAutoLockTimer()

        guard autoLockEnabled else { return }

        autoLockTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.checkAutoLock()
        }
    }

    private func stopAutoLockTimer() {
        autoLockTimer?.invalidate()
        autoLockTimer = nil
    }

    private func checkAutoLock() {
        let timeSinceActivity = Date().timeIntervalSince(lastActivityTime)

        if timeSinceActivity >= autoLockTimeout && !isLocked {
            Task { await lockWallet() }
        }
    }

    func lockWallet() async {
        isLocked = true
        sessionActive = false
        logSecurityEvent(.walletLocked)

        // Clear sensitive data from memory
        await clearSensitiveData()
    }

    func unlockWallet() async {
        isLocked = false
        sessionActive = true
        sessionExpiry = Date().addingTimeInterval(sessionDuration)
        failedAuthAttempts = 0

        logSecurityEvent(.walletUnlocked)
        updateActivity()
    }

    // MARK: - Security Audit

    func performSecurityAudit() async {
        isLoading = true
        securityIssues.removeAll()

        do {
            // Check for jailbreak
            jailbreakDetected = try await securityService.detectJailbreak()
            if jailbreakDetected {
                securityIssues.append(
                    SecurityIssue(
                        type: .jailbreakDetected,
                        severity: .critical,
                        description: "Device appears to be jailbroken"
                    )
                )
            }

            // Check for debugger
            debuggerDetected = try await securityService.detectDebugger()
            if debuggerDetected {
                securityIssues.append(
                    SecurityIssue(
                        type: .debuggerDetected,
                        severity: .high,
                        description: "Debugger attached to application"
                    )
                )
            }

            // Check app integrity
            integrityCheckPassed = try await securityService.verifyIntegrity()
            if !integrityCheckPassed {
                securityIssues.append(
                    SecurityIssue(
                        type: .integrityCheckFailed,
                        severity: .critical,
                        description: "Application integrity check failed"
                    )
                )
            }

            // Check biometric enrollment
            if isBiometricAvailable && !isBiometricEnabled {
                securityIssues.append(
                    SecurityIssue(
                        type: .biometricNotEnabled,
                        severity: .medium,
                        description: "Biometric authentication not enabled"
                    )
                )
            }

            // Check PIN strength
            if hasPINSet && pinLength < 6 {
                securityIssues.append(
                    SecurityIssue(
                        type: .weakPIN,
                        severity: .medium,
                        description: "PIN length is below recommended 6 digits"
                    )
                )
            }

            // Check auto-lock
            if !autoLockEnabled {
                securityIssues.append(
                    SecurityIssue(
                        type: .autoLockDisabled,
                        severity: .low,
                        description: "Auto-lock is disabled"
                    )
                )
            }

            // Check 2FA
            if !twoFactorEnabled {
                securityIssues.append(
                    SecurityIssue(
                        type: .twoFactorNotEnabled,
                        severity: .medium,
                        description: "Two-factor authentication not enabled"
                    )
                )
            }

        } catch {
            errorMessage = "Security audit failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func calculateSecurityScore(issues: [SecurityIssue]) -> Double {
        var score = 100.0

        for issue in issues {
            switch issue.severity {
            case .critical:
                score -= 30.0
            case .high:
                score -= 20.0
            case .medium:
                score -= 10.0
            case .low:
                score -= 5.0
            }
        }

        return max(0, min(100, score))
    }

    // MARK: - Two-Factor Authentication

    func enableTwoFactor(method: TwoFactorMethod) async -> Bool {
        isLoading = true

        do {
            // Generate backup codes
            backupCodes = generateBackupCodes()

            twoFactorEnabled = true
            twoFactorMethod = method

            try await saveSecuritySettings()
            logSecurityEvent(.twoFactorEnabled)

            showBackupCodes = true
            successMessage = "Two-factor authentication enabled"

            return true
        } catch {
            errorMessage = "Failed to enable 2FA: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func disableTwoFactor() async -> Bool {
        // Require authentication
        let authenticated = await authenticateUser(reason: "Disable two-factor authentication")
        guard authenticated else { return false }

        twoFactorEnabled = false
        twoFactorMethod = .none
        backupCodes.removeAll()

        do {
            try await saveSecuritySettings()
            logSecurityEvent(.twoFactorDisabled)
            successMessage = "Two-factor authentication disabled"
            return true
        } catch {
            errorMessage = "Failed to disable 2FA: \(error.localizedDescription)"
            return false
        }
    }

    private func generateBackupCodes() -> [String] {
        (0..<10).map { _ in
            String(format: "%08d", Int.random(in: 0...99999999))
        }
    }

    // MARK: - Session Management

    private func scheduleSessionExpiry(at expiry: Date) {
        sessionTimer?.invalidate()

        let timeUntilExpiry = expiry.timeIntervalSinceNow

        if timeUntilExpiry > 0 {
            sessionTimer = Timer.scheduledTimer(
                withTimeInterval: timeUntilExpiry,
                repeats: false
            ) { [weak self] _ in
                Task { await self?.handleSessionExpiry() }
            }
        } else {
            Task { await handleSessionExpiry() }
        }
    }

    private func handleSessionExpiry() async {
        await lockWallet()
        errorMessage = "Session expired. Please authenticate again."
    }

    func extendSession() {
        guard sessionActive else { return }
        sessionExpiry = Date().addingTimeInterval(sessionDuration)
    }

    // MARK: - Security Events

    private func logSecurityEvent(_ type: SecurityEventType) {
        let event = SecurityEvent(
            type: type,
            timestamp: Date(),
            details: type.description
        )
        securityEvents.insert(event, at: 0)

        // Keep only last 100 events
        if securityEvents.count > 100 {
            securityEvents.removeLast()
        }
    }

    func clearSecurityLog() {
        securityEvents.removeAll()
    }

    // MARK: - Recovery

    func setupSecurityQuestions(_ questions: [SecurityQuestion]) async -> Bool {
        guard questions.count >= 3 else {
            errorMessage = "At least 3 security questions are required"
            return false
        }

        do {
            // Encrypt and store answers
            for question in questions {
                let encryptedAnswer = try await encryptionService.encrypt(question.answer)
                try await keychainService.saveSecurityAnswer(
                    encryptedAnswer,
                    for: question.question
                )
            }

            securityQuestions = questions
            hasSecurityQuestionsSet = true

            try await saveSecuritySettings()
            successMessage = "Security questions set successfully"

            return true
        } catch {
            errorMessage = "Failed to set security questions: \(error.localizedDescription)"
            return false
        }
    }

    func setRecoveryEmail(_ email: String) async -> Bool {
        // Validate email
        guard isValidEmail(email) else {
            errorMessage = "Invalid email address"
            return false
        }

        recoveryEmail = email
        recoveryEmailSet = true

        do {
            try await saveSecuritySettings()
            successMessage = "Recovery email set"
            return true
        } catch {
            errorMessage = "Failed to set recovery email: \(error.localizedDescription)"
            return false
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // MARK: - Helpers

    private func authenticateUser(reason: String) async -> Bool {
        if isBiometricEnabled {
            return await authenticateWithBiometric()
        } else if hasPINSet {
            // Show PIN entry dialog
            return true // Would show UI and verify
        }
        return false
    }

    private func handleMaxFailedAttempts() async {
        await lockWallet()
        logSecurityEvent(.maxAuthAttemptsExceeded)

        // Implement additional security measures
        // e.g., temporary lockout, require recovery
    }

    private func clearSensitiveData() async {
        // Clear any cached sensitive data
        currentPIN = ""
        newPIN = ""
        confirmPIN = ""
    }

    private func startActivityMonitoring() {
        // Monitor user activity
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.updateActivity()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { await self?.handleAppBackground() }
            }
            .store(in: &cancellables)
    }

    private func handleAppBackground() async {
        if autoLockEnabled {
            await lockWallet()
        }
    }

    private func loadSecuritySettings() async {
        do {
            // Load from secure storage
            let settings = try await keychainService.loadSecuritySettings()

            isBiometricEnabled = settings.biometricEnabled
            isPINEnabled = settings.pinEnabled
            hasPINSet = settings.hasPIN
            pinLength = settings.pinLength
            autoLockEnabled = settings.autoLockEnabled
            autoLockTimeout = settings.autoLockTimeout
            twoFactorEnabled = settings.twoFactorEnabled
            twoFactorMethod = settings.twoFactorMethod ?? .none
        } catch {
            print("Failed to load security settings: \(error)")
        }
    }

    private func saveSecuritySettings() async throws {
        let settings = SecuritySettings(
            biometricEnabled: isBiometricEnabled,
            pinEnabled: isPINEnabled,
            hasPIN: hasPINSet,
            pinLength: pinLength,
            autoLockEnabled: autoLockEnabled,
            autoLockTimeout: autoLockTimeout,
            twoFactorEnabled: twoFactorEnabled,
            twoFactorMethod: twoFactorEnabled ? twoFactorMethod : nil
        )

        try await keychainService.saveSecuritySettings(settings)
    }

    private func resetPINFields() {
        currentPIN = ""
        newPIN = ""
        confirmPIN = ""
    }

    // MARK: - Computed Properties

    var securityScoreColor: Color {
        if securityScore >= 80 {
            return .green
        } else if securityScore >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    var securityScoreText: String {
        if securityScore >= 80 {
            return "Excellent"
        } else if securityScore >= 60 {
            return "Good"
        } else if securityScore >= 40 {
            return "Fair"
        } else {
            return "Poor"
        }
    }

    var criticalIssuesCount: Int {
        securityIssues.filter { $0.severity == .critical }.count
    }

    var formattedAutoLockTimeout: String {
        let minutes = Int(autoLockTimeout) / 60
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}

// MARK: - Supporting Types

enum BiometricType {
    case none
    case touchID
    case faceID
}

enum TwoFactorMethod: String, Codable {
    case none
    case authenticator = "Authenticator App"
    case sms = "SMS"
    case email = "Email"
}

struct SecurityIssue: Identifiable {
    let id = UUID()
    let type: SecurityIssueType
    let severity: SecuritySeverity
    let description: String
}

enum SecurityIssueType {
    case jailbreakDetected
    case debuggerDetected
    case integrityCheckFailed
    case biometricNotEnabled
    case weakPIN
    case autoLockDisabled
    case twoFactorNotEnabled
}

enum SecuritySeverity {
    case critical
    case high
    case medium
    case low
}

struct SecurityEvent: Identifiable {
    let id = UUID()
    let type: SecurityEventType
    let timestamp: Date
    let details: String
}

enum SecurityEventType {
    case biometricEnabled
    case biometricDisabled
    case biometricAuthSuccess
    case biometricAuthFailed
    case biometricAuthError
    case pinCreated
    case pinChanged
    case pinAuthSuccess
    case pinAuthFailed
    case twoFactorEnabled
    case twoFactorDisabled
    case walletLocked
    case walletUnlocked
    case maxAuthAttemptsExceeded
    case suspiciousActivity

    var description: String {
        switch self {
        case .biometricEnabled: return "Biometric authentication enabled"
        case .biometricDisabled: return "Biometric authentication disabled"
        case .biometricAuthSuccess: return "Biometric authentication successful"
        case .biometricAuthFailed: return "Biometric authentication failed"
        case .biometricAuthError: return "Biometric authentication error"
        case .pinCreated: return "PIN created"
        case .pinChanged: return "PIN changed"
        case .pinAuthSuccess: return "PIN authentication successful"
        case .pinAuthFailed: return "PIN authentication failed"
        case .twoFactorEnabled: return "Two-factor authentication enabled"
        case .twoFactorDisabled: return "Two-factor authentication disabled"
        case .walletLocked: return "Wallet locked"
        case .walletUnlocked: return "Wallet unlocked"
        case .maxAuthAttemptsExceeded: return "Maximum authentication attempts exceeded"
        case .suspiciousActivity: return "Suspicious activity detected"
        }
    }
}

struct SecurityQuestion: Identifiable {
    let id = UUID()
    let question: String
    var answer: String
}

struct SecuritySettings {
    let biometricEnabled: Bool
    let pinEnabled: Bool
    let hasPIN: Bool
    let pinLength: Int
    let autoLockEnabled: Bool
    let autoLockTimeout: TimeInterval
    let twoFactorEnabled: Bool
    let twoFactorMethod: TwoFactorMethod?
}

// MARK: - Service Protocols

protocol BiometricAuthManagerProtocol {
    func checkAvailability() async throws -> (Bool, BiometricType)
    func authenticate(reason: String) async throws -> Bool
}

protocol SecurityAuditorProtocol {
    func detectJailbreak() async throws -> Bool
    func detectDebugger() async throws -> Bool
    func verifyIntegrity() async throws -> Bool
}

protocol KeychainManagerProtocol {
    func savePIN(_ hashedPIN: String) async throws
    func loadPIN() async throws -> String
    func saveSecurityAnswer(_ encryptedAnswer: String, for question: String) async throws
    func saveSecuritySettings(_ settings: SecuritySettings) async throws
    func loadSecuritySettings() async throws -> SecuritySettings
}

protocol EncryptionServiceProtocol {
    func hashPIN(_ pin: String) async throws -> String
    func encrypt(_ data: String) async throws -> String
}
