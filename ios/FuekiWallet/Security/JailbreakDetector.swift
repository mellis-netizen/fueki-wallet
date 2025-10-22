import Foundation
import UIKit

/// Detects jailbroken iOS devices using multiple detection methods
/// Employs file system checks, API availability, and behavioral analysis
public class JailbreakDetector {

    // MARK: - Properties

    private let suspiciousPaths = [
        "/Applications/Cydia.app",
        "/Applications/blackra1n.app",
        "/Applications/FakeCarrier.app",
        "/Applications/Icy.app",
        "/Applications/IntelliScreen.app",
        "/Applications/MxTube.app",
        "/Applications/RockApp.app",
        "/Applications/SBSettings.app",
        "/Applications/WinterBoard.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
        "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
        "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
        "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
        "/private/var/lib/apt",
        "/private/var/lib/cydia",
        "/private/var/mobile/Library/SBSettings/Themes",
        "/private/var/stash",
        "/private/var/tmp/cydia.log",
        "/usr/bin/sshd",
        "/usr/libexec/sftp-server",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/bin/bash",
        "/bin/sh",
        "/usr/libexec/ssh-keysign",
        "/usr/bin/ssh",
        "/var/cache/apt",
        "/var/lib/apt",
        "/var/log/syslog",
        "/etc/ssh/sshd_config",
        "/private/jailbreak.txt"
    ]

    private let suspiciousSchemes = [
        "cydia://",
        "sileo://",
        "zbra://",
        "installer://",
        "undecimus://",
        "checkra1n://"
    ]

    // MARK: - Public Methods

    /// Primary jailbreak detection method (combines all checks)
    public func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        // Skip jailbreak detection in simulator
        return false
        #else
        // Perform multiple detection methods
        return checkSuspiciousFiles() ||
               checkSuspiciousURLSchemes() ||
               checkSandboxViolation() ||
               checkSymbolicLinks() ||
               checkForkAvailability() ||
               checkDynamicLibraries() ||
               checkSystemWriteAccess()
        #endif
    }

    // MARK: - Detection Methods

    /// Check for suspicious files and directories
    private func checkSuspiciousFiles() -> Bool {
        for path in suspiciousPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }

            // Try to open file
            if let file = fopen(path, "r") {
                fclose(file)
                return true
            }
        }
        return false
    }

    /// Check for jailbreak-related URL schemes
    private func checkSuspiciousURLSchemes() -> Bool {
        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        return false
    }

    /// Check sandbox integrity by attempting to write outside sandbox
    private func checkSandboxViolation() -> Bool {
        let testString = "fueki_jailbreak_test"
        let testPath = "/private/jailbreak_test.txt"

        do {
            try testString.write(toFile: testPath, atomically: true, encoding: .utf8)
            // If write succeeds, sandbox is violated
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // Expected behavior - sandbox prevents write
            return false
        }
    }

    /// Check for symbolic links (common in jailbroken devices)
    private func checkSymbolicLinks() -> Bool {
        let paths = [
            "/Applications",
            "/Library/Ringtones",
            "/Library/Wallpaper",
            "/usr/arm-apple-darwin9",
            "/usr/include",
            "/usr/libexec",
            "/usr/share"
        ]

        for path in paths {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: path)
                if let type = attributes[.type] as? FileAttributeType,
                   type == .typeSymbolicLink {
                    return true
                }
            } catch {
                // Continue checking
            }
        }

        return false
    }

    /// Check if fork() is available (disabled on non-jailbroken devices)
    private func checkForkAvailability() -> Bool {
        let result = fork()
        if result >= 0 {
            if result > 0 {
                // Parent process - kill child
                kill(result, SIGKILL)
            }
            return true
        }
        return false
    }

    /// Check for suspicious dynamic libraries
    private func checkDynamicLibraries() -> Bool {
        let suspiciousLibraries = [
            "MobileSubstrate",
            "SubstrateLoader",
            "SSLKillSwitch",
            "PreferenceLoader",
            "CydiaSubstrate"
        ]

        for i in 0..<_dyld_image_count() {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                for library in suspiciousLibraries {
                    if name.contains(library) {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// Check for write access to system directories
    private func checkSystemWriteAccess() -> Bool {
        let paths = [
            "/",
            "/root/",
            "/private/",
            "/jb/"
        ]

        for path in paths {
            let testPath = path + "fueki_test_" + UUID().uuidString + ".txt"
            do {
                try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
                try? FileManager.default.removeItem(atPath: testPath)
                return true
            } catch {
                // Expected - continue checking
            }
        }

        return false
    }

    /// Check environment variables for jailbreak indicators
    public func checkEnvironmentVariables() -> Bool {
        let suspiciousVars = ["DYLD_INSERT_LIBRARIES", "DYLD_LIBRARY_PATH"]

        for variable in suspiciousVars {
            if getenv(variable) != nil {
                return true
            }
        }

        return false
    }

    /// Get jailbreak detection confidence level
    public func getJailbreakConfidence() -> JailbreakConfidence {
        var positiveChecks = 0
        let totalChecks = 7

        if checkSuspiciousFiles() { positiveChecks += 1 }
        if checkSuspiciousURLSchemes() { positiveChecks += 1 }
        if checkSandboxViolation() { positiveChecks += 1 }
        if checkSymbolicLinks() { positiveChecks += 1 }
        if checkForkAvailability() { positiveChecks += 1 }
        if checkDynamicLibraries() { positiveChecks += 1 }
        if checkSystemWriteAccess() { positiveChecks += 1 }

        let ratio = Double(positiveChecks) / Double(totalChecks)

        switch ratio {
        case 0.0:
            return .notJailbroken
        case 0.01..<0.3:
            return .low
        case 0.3..<0.6:
            return .medium
        case 0.6..<0.9:
            return .high
        default:
            return .certain
        }
    }

    // MARK: - Types

    public enum JailbreakConfidence {
        case notJailbroken
        case low
        case medium
        case high
        case certain

        var description: String {
            switch self {
            case .notJailbroken: return "Device is not jailbroken"
            case .low: return "Low confidence - possible jailbreak"
            case .medium: return "Medium confidence - likely jailbroken"
            case .high: return "High confidence - jailbroken"
            case .certain: return "Certain - device is jailbroken"
            }
        }
    }
}
