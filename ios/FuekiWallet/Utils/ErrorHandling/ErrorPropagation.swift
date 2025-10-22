//
//  ErrorPropagation.swift
//  FuekiWallet
//
//  Error propagation patterns and utilities
//

import Foundation
import Combine

// MARK: - Result Extensions

extension Result {
    /// Map error to WalletError
    func mapError(
        code: String,
        category: ErrorCategory,
        userMessage: String
    ) -> Result<Success, WalletError> {
        mapError { error in
            WalletError(
                code: code,
                category: category,
                userMessage: userMessage,
                technicalDetails: error.localizedDescription,
                recoverySuggestion: nil,
                underlyingError: error
            )
        }
    }

    /// Handle success and error cases
    func handle(
        onSuccess: (Success) -> Void,
        onFailure: (Failure) -> Void
    ) {
        switch self {
        case .success(let value):
            onSuccess(value)
        case .failure(let error):
            onFailure(error)
        }
    }

    /// Log error and continue with default value
    func recoverWithDefault(
        _ defaultValue: Success,
        logError: Bool = true
    ) -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            if logError {
                ErrorHandler.shared.logError(error)
            }
            return defaultValue
        }
    }
}

// MARK: - Async Result

/// Result type for async operations
typealias AsyncResult<T> = Result<T, Error>

extension AsyncResult {
    /// Create from throwing async operation
    static func from(_ operation: () async throws -> Success) async -> AsyncResult<Success> {
        do {
            let value = try await operation()
            return .success(value)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - Publisher Extensions

extension Publisher {
    /// Map errors to WalletError
    func mapToWalletError(
        code: String,
        category: ErrorCategory,
        userMessage: String
    ) -> Publishers.MapError<Self, WalletError> {
        mapError { error in
            WalletError(
                code: code,
                category: category,
                userMessage: userMessage,
                technicalDetails: error.localizedDescription,
                underlyingError: error
            )
        }
    }

    /// Handle errors and provide default value
    func handleErrorWithDefault(_ defaultValue: Output) -> AnyPublisher<Output, Never> {
        catch { error in
            ErrorHandler.shared.logError(error)
            return Just(defaultValue)
        }
        .eraseToAnyPublisher()
    }

    /// Retry with exponential backoff
    func retryWithBackoff(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0
    ) -> AnyPublisher<Output, Failure> {
        self.catch { error -> AnyPublisher<Output, Failure> in
            var attempt = 0

            return self.catch { _ -> AnyPublisher<Output, Failure> in
                attempt += 1

                guard attempt < maxAttempts else {
                    return Fail(error: error).eraseToAnyPublisher()
                }

                let delay = initialDelay * pow(2.0, Double(attempt - 1))

                return Just(())
                    .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                    .flatMap { _ in self }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Error Context

/// Provides context for error propagation
struct ErrorContext {
    let operation: String
    let file: String
    let function: String
    let line: Int
    let userInfo: [String: Any]?

    init(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        userInfo: [String: Any]? = nil
    ) {
        self.operation = operation
        self.file = file
        self.function = function
        self.line = line
        self.userInfo = userInfo
    }
}

// MARK: - Error Propagation Patterns

/// Execute operation with error handling
func withErrorHandling<T>(
    _ context: ErrorContext,
    operation: () throws -> T
) -> Result<T, Error> {
    do {
        let result = try operation()
        return .success(result)
    } catch {
        ErrorHandler.shared.handle(
            error,
            file: context.file,
            function: context.function,
            line: context.line
        )
        return .failure(error)
    }
}

/// Execute async operation with error handling
func withErrorHandling<T>(
    _ context: ErrorContext,
    operation: () async throws -> T
) async -> Result<T, Error> {
    do {
        let result = try await operation()
        return .success(result)
    } catch {
        ErrorHandler.shared.handle(
            error,
            file: context.file,
            function: context.function,
            line: context.line
        )
        return .failure(error)
    }
}

// MARK: - Error Boundary

/// Error boundary for SwiftUI views
final class ErrorBoundary: ObservableObject {
    @Published private(set) var error: WalletErrorProtocol?
    @Published private(set) var hasError = false

    private let errorHandler = ErrorHandler.shared

    func catchError(_ error: Error) {
        let walletError = WalletError.wrap(error)

        DispatchQueue.main.async {
            self.error = walletError
            self.hasError = true
        }

        errorHandler.handle(error)
    }

    func clearError() {
        DispatchQueue.main.async {
            self.error = nil
            self.hasError = false
        }
    }

    func retry<T>(
        operation: @escaping () async throws -> T
    ) async {
        clearError()

        do {
            _ = try await operation()
        } catch {
            catchError(error)
        }
    }
}

// MARK: - Error Recovery

protocol ErrorRecoverable {
    func recover(from error: Error) async throws
    func canRecover(from error: Error) -> Bool
}

extension ErrorRecoverable {
    func attemptRecovery(from error: Error) async -> Bool {
        guard canRecover(from: error) else {
            return false
        }

        do {
            try await recover(from: error)
            return true
        } catch {
            ErrorHandler.shared.logError(error)
            return false
        }
    }
}

// MARK: - Error Transformation

protocol ErrorTransformable {
    func transform(_ error: Error) -> WalletErrorProtocol
}

class ErrorTransformer: ErrorTransformable {
    func transform(_ error: Error) -> WalletErrorProtocol {
        // Check if already a wallet error
        if let walletError = error as? WalletErrorProtocol {
            return walletError
        }

        // Transform common errors
        if let urlError = error as? URLError {
            return transformURLError(urlError)
        }

        if let decodingError = error as? DecodingError {
            return transformDecodingError(decodingError)
        }

        // Default transformation
        return WalletError.wrap(error)
    }

    private func transformURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet:
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

    private func transformDecodingError(_ error: DecodingError) -> ValidationError {
        switch error {
        case .keyNotFound(let key, _):
            return .requiredFieldMissing(field: key.stringValue)
        case .typeMismatch(_, let context):
            return .formatError(
                field: context.codingPath.last?.stringValue ?? "unknown",
                expectedFormat: "correct type"
            )
        case .dataCorrupted(let context):
            return .invalidInput(
                field: context.codingPath.last?.stringValue ?? "data",
                reason: "corrupted or invalid format"
            )
        case .valueNotFound(_, let context):
            return .requiredFieldMissing(
                field: context.codingPath.last?.stringValue ?? "unknown"
            )
        @unknown default:
            return .invalidInput(field: "unknown", reason: error.localizedDescription)
        }
    }
}

// MARK: - Error Chain

/// Maintains error chain for debugging
final class ErrorChain {
    private var errors: [Error] = []

    func append(_ error: Error) {
        errors.append(error)
    }

    func getChain() -> [Error] {
        return errors
    }

    func getRootCause() -> Error? {
        return errors.first
    }

    func getImmediateCause() -> Error? {
        return errors.last
    }

    func clear() {
        errors.removeAll()
    }
}
