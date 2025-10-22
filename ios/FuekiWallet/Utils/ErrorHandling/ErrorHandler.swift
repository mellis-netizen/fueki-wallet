//
//  ErrorHandler.swift
//  FuekiWallet
//
//  Centralized error handling and user notification
//

import Foundation
import SwiftUI
import Combine

/// Error handler delegate for custom error processing
protocol ErrorHandlerDelegate: AnyObject {
    func errorHandler(_ handler: ErrorHandler, didHandle error: WalletErrorProtocol)
    func errorHandler(_ handler: ErrorHandler, shouldPresentError error: WalletErrorProtocol) -> Bool
}

/// Centralized error handler
final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published private(set) var currentError: WalletErrorProtocol?
    @Published private(set) var errorHistory: [ErrorRecord] = []

    weak var delegate: ErrorHandlerDelegate?

    private let logger = WalletLogger.shared
    private let maxHistorySize = 100
    private var errorSubject = PassthroughSubject<WalletErrorProtocol, Never>()

    var errorPublisher: AnyPublisher<WalletErrorProtocol, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    private init() {
        setupErrorMonitoring()
    }

    // MARK: - Error Handling

    /// Handle an error with optional user presentation
    func handle(
        _ error: Error,
        severity: ErrorSeverity? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let walletError = convertToWalletError(error)
        let finalSeverity = severity ?? walletError.errorCategory.severity

        // Log the error
        logger.log(
            error: walletError,
            severity: finalSeverity,
            file: file,
            function: function,
            line: line
        )

        // Record in history
        recordError(walletError, severity: finalSeverity)

        // Notify delegate
        delegate?.errorHandler(self, didHandle: walletError)

        // Check if should present to user
        let shouldPresent = delegate?.errorHandler(self, shouldPresentError: walletError) ?? true

        if shouldPresent {
            presentError(walletError)
        }

        // Publish to subscribers
        errorSubject.send(walletError)

        // Handle critical errors
        if finalSeverity == .critical {
            handleCriticalError(walletError)
        }
    }

    /// Handle error without user presentation
    func logError(
        _ error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let walletError = convertToWalletError(error)

        logger.log(
            error: walletError,
            severity: walletError.errorCategory.severity,
            file: file,
            function: function,
            line: line
        )

        recordError(walletError, severity: walletError.errorCategory.severity)
    }

    /// Clear current error
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
        }
    }

    // MARK: - Error Presentation

    private func presentError(_ error: WalletErrorProtocol) {
        DispatchQueue.main.async {
            self.currentError = error
        }
    }

    /// Get user-friendly error alert
    func getErrorAlert(for error: WalletErrorProtocol) -> Alert {
        Alert(
            title: Text("Error"),
            message: Text(error.userMessage),
            primaryButton: .default(Text("OK")) {
                self.clearError()
            },
            secondaryButton: .default(Text("Details")) {
                self.showErrorDetails(error)
            }
        )
    }

    private func showErrorDetails(_ error: WalletErrorProtocol) {
        var details = "Error Code: \(error.errorCode)\n"
        details += "Category: \(error.errorCategory.rawValue)\n"

        if let technical = error.technicalDetails {
            details += "\nDetails: \(technical)"
        }

        if let recovery = error.recoverySuggestion {
            details += "\n\nSuggestion: \(recovery)"
        }

        logger.debug("Error Details", metadata: [
            "code": error.errorCode,
            "details": details
        ])
    }

    // MARK: - Error Conversion

    private func convertToWalletError(_ error: Error) -> WalletErrorProtocol {
        if let walletError = error as? WalletErrorProtocol {
            return walletError
        }

        // Convert common system errors
        if let urlError = error as? URLError {
            return convertURLError(urlError)
        }

        return WalletError.wrap(error)
    }

    private func convertURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .badURL, .unsupportedURL:
            return .invalidURL
        case .secureConnectionFailed:
            return .sslError
        default:
            return .requestFailed(error)
        }
    }

    // MARK: - Error History

    private func recordError(_ error: WalletErrorProtocol, severity: ErrorSeverity) {
        let record = ErrorRecord(
            error: error,
            severity: severity,
            timestamp: Date()
        )

        DispatchQueue.main.async {
            self.errorHistory.insert(record, at: 0)

            // Maintain max history size
            if self.errorHistory.count > self.maxHistorySize {
                self.errorHistory.removeLast(self.errorHistory.count - self.maxHistorySize)
            }
        }
    }

    /// Get recent errors by category
    func getRecentErrors(category: ErrorCategory, limit: Int = 10) -> [ErrorRecord] {
        return Array(errorHistory
            .filter { $0.error.errorCategory == category }
            .prefix(limit))
    }

    /// Get error statistics
    func getErrorStatistics() -> ErrorStatistics {
        var categoryCounts: [ErrorCategory: Int] = [:]
        var severityCounts: [ErrorSeverity: Int] = [:]

        for record in errorHistory {
            categoryCounts[record.error.errorCategory, default: 0] += 1
            severityCounts[record.severity, default: 0] += 1
        }

        return ErrorStatistics(
            totalErrors: errorHistory.count,
            categoryCounts: categoryCounts,
            severityCounts: severityCounts,
            recentErrors: Array(errorHistory.prefix(10))
        )
    }

    // MARK: - Critical Error Handling

    private func handleCriticalError(_ error: WalletErrorProtocol) {
        logger.critical("Critical error occurred", metadata: [
            "code": error.errorCode,
            "message": error.userMessage,
            "category": error.errorCategory.rawValue
        ])

        // Notify analytics
        NotificationCenter.default.post(
            name: .criticalErrorOccurred,
            object: nil,
            userInfo: ["error": error]
        )

        // Consider security lockdown for certain errors
        if error.errorCategory == .security {
            handleSecurityCriticalError(error)
        }
    }

    private func handleSecurityCriticalError(_ error: WalletErrorProtocol) {
        // Could implement:
        // - Automatic logout
        // - Wallet lock
        // - Security alert to user
        // - Wipe sensitive data from memory

        logger.critical("Security critical error - initiating protective measures")
    }

    // MARK: - Error Monitoring

    private func setupErrorMonitoring() {
        // Monitor for patterns of errors that might indicate issues
        errorSubject
            .collect(.byTime(DispatchQueue.main, .seconds(60)))
            .sink { [weak self] errors in
                self?.analyzeErrorPatterns(errors)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func analyzeErrorPatterns(_ errors: [WalletErrorProtocol]) {
        guard !errors.isEmpty else { return }

        // Check for recurring errors
        let errorCodes = errors.map { $0.errorCode }
        let uniqueErrors = Set(errorCodes)

        if errorCodes.count > 5 && uniqueErrors.count < 3 {
            logger.warning("Recurring error pattern detected", metadata: [
                "total": errorCodes.count,
                "unique": uniqueErrors.count,
                "codes": errorCodes.joined(separator: ", ")
            ])
        }

        // Check for high error rate
        if errors.count > 10 {
            logger.warning("High error rate detected", metadata: [
                "count": errors.count,
                "period": "60 seconds"
            ])
        }
    }
}

// MARK: - Supporting Types

struct ErrorRecord: Identifiable {
    let id = UUID()
    let error: WalletErrorProtocol
    let severity: ErrorSeverity
    let timestamp: Date

    var errorCode: String { error.errorCode }
    var category: ErrorCategory { error.errorCategory }
    var message: String { error.userMessage }
}

struct ErrorStatistics {
    let totalErrors: Int
    let categoryCounts: [ErrorCategory: Int]
    let severityCounts: [ErrorSeverity: Int]
    let recentErrors: [ErrorRecord]

    var mostCommonCategory: ErrorCategory? {
        categoryCounts.max(by: { $0.value < $1.value })?.key
    }

    var criticalErrorCount: Int {
        severityCounts[.critical] ?? 0
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let criticalErrorOccurred = Notification.Name("criticalErrorOccurred")
}

// MARK: - Error Handling Extensions

extension Result where Failure == Error {
    /// Handle result with ErrorHandler
    func handleError(
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        if case .failure(let error) = self {
            ErrorHandler.shared.handle(error, file: file, function: function, line: line)
        }
    }
}

extension Publisher where Failure == Error {
    /// Automatically handle errors in Combine pipelines
    func handleError() -> Publishers.Catch<Self, Empty<Output, Never>> {
        self.catch { error -> Empty<Output, Never> in
            ErrorHandler.shared.handle(error)
            return Empty()
        }
    }
}
