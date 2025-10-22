import Foundation

/// Remote logging service for critical errors and important events
public class RemoteLogger {

    // MARK: - Singleton
    public static let shared = RemoteLogger()

    // MARK: - Properties
    private let queue = DispatchQueue(label: "com.fueki.remotelogger", qos: .utility)
    private var pendingLogs: [RemoteLogEntry] = []
    private let maxPendingLogs = 100
    private var isEnabled = false

    // Remote endpoint configuration (to be set when backend is ready)
    private var remoteEndpoint: URL?
    private var apiKey: String?

    // MARK: - Initialization
    private init() {
        loadPendingLogs()
        scheduleLogUpload()
    }

    // MARK: - Configuration

    /// Configure remote logging
    /// - Parameters:
    ///   - endpoint: Remote logging endpoint URL
    ///   - apiKey: API key for authentication
    public func configure(endpoint: URL, apiKey: String) {
        self.remoteEndpoint = endpoint
        self.apiKey = apiKey
        self.isEnabled = true

        Logger.shared.log("Remote logger configured", level: .info, category: .analytics)

        // Upload any pending logs
        uploadPendingLogs()
    }

    /// Enable or disable remote logging
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    // MARK: - Logging

    /// Log a message to remote service
    /// - Parameters:
    ///   - message: Message to log
    ///   - metadata: Log metadata
    public func log(message: String, metadata: LogMetadata) {
        guard isEnabled else { return }

        let entry = RemoteLogEntry(
            message: message,
            metadata: metadata,
            deviceInfo: collectDeviceInfo(),
            appInfo: collectAppInfo()
        )

        queue.async { [weak self] in
            self?.addLogEntry(entry)
        }
    }

    private func addLogEntry(_ entry: RemoteLogEntry) {
        pendingLogs.append(entry)

        // Limit pending logs
        if pendingLogs.count > maxPendingLogs {
            pendingLogs.removeFirst(pendingLogs.count - maxPendingLogs)
        }

        savePendingLogs()

        // Upload if we have enough logs or if it's critical
        if pendingLogs.count >= 10 || entry.metadata.level >= .critical {
            uploadPendingLogs()
        }
    }

    // MARK: - Upload

    private func uploadPendingLogs() {
        guard isEnabled,
              let endpoint = remoteEndpoint,
              let apiKey = apiKey,
              !pendingLogs.isEmpty else {
            return
        }

        let logsToUpload = pendingLogs

        queue.async { [weak self] in
            self?.uploadLogs(logsToUpload, to: endpoint, apiKey: apiKey)
        }
    }

    private func uploadLogs(_ logs: [RemoteLogEntry], to endpoint: URL, apiKey: String) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "logs": logs.map { $0.toDictionary() },
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "batch_id": UUID().uuidString
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            Logger.shared.log("Failed to serialize remote logs", level: .error, category: .analytics)
            return
        }

        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                Logger.shared.log("Remote log upload failed: \(error.localizedDescription)", level: .error, category: .analytics)
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                self?.queue.async {
                    // Remove uploaded logs
                    self?.pendingLogs.removeAll { log in
                        logs.contains { $0.id == log.id }
                    }
                    self?.savePendingLogs()
                }

                Logger.shared.log("Successfully uploaded \(logs.count) remote logs", level: .debug, category: .analytics)
            }
        }

        task.resume()
    }

    private func scheduleLogUpload() {
        // Upload logs every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.uploadPendingLogs()
        }
    }

    // MARK: - Persistence

    private var pendingLogsFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("pending_remote_logs.json")
    }

    private func savePendingLogs() {
        guard let fileURL = pendingLogsFileURL else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(pendingLogs) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func loadPendingLogs() {
        guard let fileURL = pendingLogsFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: fileURL),
           let logs = try? decoder.decode([RemoteLogEntry].self, from: data) {
            pendingLogs = logs
        }
    }

    // MARK: - Device & App Info

    private func collectDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current

        return DeviceInfo(
            model: device.model,
            systemVersion: device.systemVersion,
            identifier: device.identifierForVendor?.uuidString ?? "unknown"
        )
    }

    private func collectAppInfo() -> AppInfo {
        let bundle = Bundle.main

        return AppInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            bundleId: bundle.bundleIdentifier ?? "unknown"
        )
    }
}

// MARK: - Supporting Types

private struct RemoteLogEntry: Codable {
    let id: String
    let message: String
    let metadata: LogMetadata
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo
    let timestamp: Date

    init(message: String, metadata: LogMetadata, deviceInfo: DeviceInfo, appInfo: AppInfo) {
        self.id = UUID().uuidString
        self.message = message
        self.metadata = metadata
        self.deviceInfo = deviceInfo
        self.appInfo = appInfo
        self.timestamp = Date()
    }

    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "message": message,
            "level": metadata.level.description,
            "category": metadata.category.rawValue,
            "file": metadata.file,
            "function": metadata.function,
            "line": metadata.line,
            "thread": metadata.threadName,
            "device_model": deviceInfo.model,
            "system_version": deviceInfo.systemVersion,
            "device_id": deviceInfo.identifier,
            "app_version": appInfo.version,
            "app_build": appInfo.build,
            "bundle_id": appInfo.bundleId,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
    }
}

private struct DeviceInfo: Codable {
    let model: String
    let systemVersion: String
    let identifier: String
}

private struct AppInfo: Codable {
    let version: String
    let build: String
    let bundleId: String
}
