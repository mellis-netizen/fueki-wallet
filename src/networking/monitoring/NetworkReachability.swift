import Foundation
import Network
import Combine

/// Network reachability monitoring
final class NetworkReachability: ObservableObject {

    static let shared = NetworkReachability()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.fueki.network-monitor")

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown

        var isCellular: Bool {
            if case .cellular = self { return true }
            return false
        }

        var isExpensive: Bool {
            switch self {
            case .cellular:
                return true
            case .wifi, .wired, .unknown:
                return false
            }
        }
    }

    private init() {
        setupMonitoring()
    }

    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.determineConnectionType(from: path) ?? .unknown

                // Post notification for connection changes
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: [
                        "isConnected": self?.isConnected ?? false,
                        "connectionType": self?.connectionType ?? .unknown
                    ]
                )
            }
        }

        monitor.start(queue: queue)
    }

    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        }
        return .unknown
    }

    /// Wait for network connection to become available
    func waitForConnection(timeout: TimeInterval = 10.0) async throws {
        if isConnected { return }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NetworkError.timeout
            }

            group.addTask { [weak self] in
                while self?.isConnected == false {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            }

            try await group.next()
            group.cancelAll()
        }
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}
