//
//  NetworkReachability.swift
//  FuekiWallet
//
//  Network connectivity monitoring
//

import Foundation
import Network
import Combine

/// Network reachability monitor
public final class NetworkReachability {

    // MARK: - Types

    public enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }

    public enum Status {
        case connected(ConnectionType)
        case disconnected
        case connecting
    }

    // MARK: - Properties

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    @Published public private(set) var status: Status = .disconnected
    @Published public private(set) var isReachable: Bool = false
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var isConstrained: Bool = false

    public var statusPublisher: AnyPublisher<Status, Never> {
        $status.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "io.fueki.wallet.reachability", qos: .utility)

        setupMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Start monitoring network status
    public func startMonitoring() {
        monitor.start(queue: queue)
    }

    /// Stop monitoring network status
    public func stopMonitoring() {
        monitor.cancel()
    }

    /// Check if connection is suitable for large downloads
    public var isSuitableForLargeDownloads: Bool {
        return isReachable && !isExpensive && !isConstrained
    }

    // MARK: - Private Methods

    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.updateStatus(for: path)
            }
        }

        startMonitoring()
    }

    private func updateStatus(for path: NWPath) {
        // Update reachability
        isReachable = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        // Determine status
        switch path.status {
        case .satisfied:
            let connectionType = determineConnectionType(from: path)
            status = .connected(connectionType)

        case .unsatisfied:
            status = .disconnected

        case .requiresConnection:
            status = .connecting

        @unknown default:
            status = .disconnected
        }
    }

    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .unknown
        }
    }
}

// MARK: - Convenience Methods
public extension NetworkReachability {
    /// Wait for network to become available
    func waitForConnection(timeout: TimeInterval = 30.0) async throws {
        guard !isReachable else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var cancellable: AnyCancellable?
            var timeoutTask: Task<Void, Never>?
            var hasResumed = false

            // Setup timeout
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !hasResumed {
                    hasResumed = true
                    cancellable?.cancel()
                    continuation.resume(throwing: NetworkError.timeout)
                }
            }

            // Wait for connection
            cancellable = statusPublisher
                .filter { status in
                    if case .connected = status {
                        return true
                    }
                    return false
                }
                .first()
                .sink { _ in
                    if !hasResumed {
                        hasResumed = true
                        timeoutTask?.cancel()
                        continuation.resume()
                    }
                }
        }
    }
}

// MARK: - Status Description
extension NetworkReachability.Status: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connected(let type):
            return "Connected (\(type))"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        }
    }
}

extension NetworkReachability.ConnectionType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .unknown:
            return "Unknown"
        }
    }
}
