import Foundation
import MachO

/// Detects debugger attachment and anti-debugging attempts
/// Uses multiple techniques to detect both static and dynamic debugging
public class DebuggerDetector {

    // MARK: - Properties

    private var isMonitoring = false
    private var monitoringTimer: Timer?

    // MARK: - Public Methods

    /// Check if debugger is currently attached
    public func isDebuggerAttached() -> Bool {
        #if DEBUG
        // Allow debugging in debug builds
        return false
        #else
        return checkPTrace() || checkSysctl() || checkGetppid() || checkExceptionPorts()
        #endif
    }

    /// Start continuous debugger monitoring
    public func startMonitoring(interval: TimeInterval = 1.0) {
        guard !isMonitoring else { return }

        isMonitoring = true

        // Periodic checks
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            if self?.isDebuggerAttached() == true {
                self?.handleDebuggerDetection()
            }
        }

        // Set up anti-debugging measures
        setupAntiDebugging()
    }

    /// Stop debugger monitoring
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    // MARK: - Detection Methods

    /// Check using ptrace system call
    private func checkPTrace() -> Bool {
        // ptrace(PT_DENY_ATTACH, 0, 0, 0) prevents debugger attachment
        // If already attached, this call fails
        typealias PTraceFunc = @convention(c) (CInt, pid_t, caddr_t?, CInt) -> CInt

        guard let ptraceHandle = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ptrace") else {
            return false
        }

        let ptrace = unsafeBitCast(ptraceHandle, to: PTraceFunc.self)

        // PT_DENY_ATTACH = 31
        let result = ptrace(31, 0, nil, 0)

        return result == -1
    }

    /// Check using sysctl process info
    private func checkSysctl() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride

        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

        guard result == 0 else { return false }

        // Check if P_TRACED flag is set
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    /// Check parent process ID (debuggers often spawn child processes)
    private func checkGetppid() -> Bool {
        // In normal execution, parent process ID is launchd (1)
        // Under debugger, parent might be different
        let ppid = getppid()
        return ppid != 1
    }

    /// Check Mach exception ports (debuggers register exception handlers)
    private func checkExceptionPorts() -> Bool {
        var masks = [exception_mask_t](repeating: 0, count: EXC_TYPES_COUNT)
        var ports = [mach_port_t](repeating: 0, count: EXC_TYPES_COUNT)
        var behaviors = [exception_behavior_t](repeating: 0, count: EXC_TYPES_COUNT)
        var flavors = [thread_state_flavor_t](repeating: 0, count: EXC_TYPES_COUNT)
        var count = mach_msg_type_number_t(EXC_TYPES_COUNT)

        let result = task_get_exception_ports(
            mach_task_self_,
            EXC_MASK_ALL,
            &masks,
            &count,
            &ports,
            &behaviors,
            &flavors
        )

        guard result == KERN_SUCCESS else { return false }

        // If exception ports are registered, debugger might be attached
        return count > 0
    }

    /// Check for common debugger process names
    private func checkDebuggerProcesses() -> Bool {
        let debuggerNames = [
            "lldb",
            "gdb",
            "debugserver",
            "frida-server"
        ]

        // This is a heuristic check - not foolproof
        // In production, you'd scan running processes
        return false // Placeholder
    }

    /// Detect DTrace instrumentation
    private func checkDTrace() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride

        sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

        // Check if process is being traced by DTrace
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    // MARK: - Anti-Debugging Measures

    /// Set up anti-debugging protections
    private func setupAntiDebugging() {
        // Deny debugger attachment
        denyDebuggerAttachment()

        // Obfuscate function pointers
        obfuscateFunctionPointers()

        // Set up integrity checks
        performIntegrityCheck()
    }

    /// Deny debugger attachment using ptrace
    private func denyDebuggerAttachment() {
        #if !DEBUG
        typealias PTraceFunc = @convention(c) (CInt, pid_t, caddr_t?, CInt) -> CInt

        guard let ptraceHandle = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ptrace") else {
            return
        }

        let ptrace = unsafeBitCast(ptraceHandle, to: PTraceFunc.self)
        ptrace(31, 0, nil, 0) // PT_DENY_ATTACH
        #endif
    }

    /// Obfuscate critical function pointers
    private func obfuscateFunctionPointers() {
        // Implementation would involve runtime code modification
        // to make reverse engineering harder
    }

    /// Perform runtime integrity checks
    private func performIntegrityCheck() {
        // Check code section checksums
        // Detect runtime modifications
    }

    // MARK: - Anti-Instrumentation

    /// Detect Frida framework
    public func detectFrida() -> Bool {
        // Check for Frida-related libraries
        for i in 0..<_dyld_image_count() {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName).lowercased()
                if name.contains("frida") ||
                   name.contains("gadget") ||
                   name.contains("inject") {
                    return true
                }
            }
        }

        // Check for Frida server port
        return checkFridaPort()
    }

    /// Check for Frida server listening port
    private func checkFridaPort() -> Bool {
        // Frida typically uses port 27042
        // This is a simplified check
        return false // Placeholder
    }

    /// Detect method swizzling
    public func detectMethodSwizzling() -> Bool {
        // Check if critical methods have been swizzled
        // Compare method implementations with expected values
        return false // Placeholder
    }

    // MARK: - Event Handling

    private func handleDebuggerDetection() {
        SecurityLogger.shared.log(
            event: .debuggerDetected,
            level: .critical,
            message: "Debugger attachment detected"
        )

        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("DebuggerDetected"),
            object: nil
        )

        #if !DEBUG
        // In production, take defensive action
        // Options: exit app, lock wallet, clear sensitive data
        exitApp()
        #endif
    }

    private func exitApp() {
        // Clear sensitive data before exit
        SecureMemory.zeroMemory()

        // Exit application
        exit(0)
    }

    // MARK: - Timing Attack Detection

    /// Detect timing attacks by monitoring execution patterns
    public func detectTimingAnomaly(expectedDuration: TimeInterval, actualDuration: TimeInterval) -> Bool {
        // If execution is significantly slower, might indicate debugging
        let threshold = expectedDuration * 1.5
        return actualDuration > threshold
    }

    /// Measure and verify code execution timing
    public func verifyExecutionTiming(_ block: () -> Void) -> Bool {
        let start = Date()
        block()
        let duration = Date().timeIntervalSince(start)

        // Expected duration should be consistent
        // Large variations suggest debugging/instrumentation
        return duration < 0.1 // Adjust threshold as needed
    }
}
