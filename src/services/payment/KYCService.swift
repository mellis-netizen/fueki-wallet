//
//  KYCService.swift
//  Fueki Wallet
//
//  Complete KYC (Know Your Customer) verification integration
//  Supports identity verification through payment providers
//

import Foundation
import Combine

/// Service for managing KYC verification and compliance
class KYCService: ObservableObject {

    static let shared = KYCService()

    // MARK: - Published Properties
    @Published var currentKYCStatus: KYCStatus?
    @Published var isVerifying = false
    @Published var verificationProgress: Double = 0.0

    // MARK: - Configuration
    private let baseURL = "https://api.ramp.network/api/host-api"
    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "RampAPIKey") as? String ?? ""
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - User Data Storage
    private var userId: String {
        UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
    }

    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Public Methods

    /// Get current KYC status
    func getKYCStatus() async throws -> KYCStatus {
        isVerifying = true
        defer { isVerifying = false }

        // Check cache first
        if let cached = currentKYCStatus, !isExpired(cached) {
            return cached
        }

        // Fetch from Ramp Network
        let endpoint = "/users/\(userId)/kyc"

        do {
            let data = try await performRequest(endpoint: endpoint, method: "GET")
            let response = try decoder.decode(RampKYCResponse.self, from: data)

            let status = mapToKYCStatus(response)

            await MainActor.run {
                self.currentKYCStatus = status
            }

            return status

        } catch {
            // Return default tier 1 (unverified)
            let defaultStatus = KYCStatus(
                tier: .tier1,
                isVerified: false,
                limits: KYCLimits(daily: 200, weekly: 1000, monthly: 2000),
                verificationURL: nil,
                requiredDocuments: ["government_id", "proof_of_address"],
                rejectionReason: nil
            )

            await MainActor.run {
                self.currentKYCStatus = defaultStatus
            }

            return defaultStatus
        }
    }

    /// Initiate KYC verification flow
    func initiateKYCVerification(tier: KYCStatus.KYCTier = .tier2) async throws -> KYCVerificationURL {
        isVerifying = true
        verificationProgress = 0.1
        defer { isVerifying = false }

        // Create verification session with Ramp
        let endpoint = "/users/\(userId)/kyc/verification"

        let requestBody: [String: Any] = [
            "tier": tier.rawValue,
            "redirectURL": "fueki://kyc-complete",
            "callbackURL": "https://api.fueki.app/webhooks/kyc"
        ]

        do {
            let data = try await performRequest(
                endpoint: endpoint,
                method: "POST",
                body: requestBody
            )

            let response = try decoder.decode(RampVerificationResponse.self, from: data)

            let verificationURL = KYCVerificationURL(
                url: URL(string: response.verificationURL)!,
                sessionId: response.sessionId,
                expiresAt: Date().addingTimeInterval(3600)
            )

            await MainActor.run {
                self.verificationProgress = 0.3
            }

            // Store session ID for tracking
            UserDefaults.standard.set(response.sessionId, forKey: "kycSessionId")

            return verificationURL

        } catch {
            throw PaymentError.kycRequired
        }
    }

    /// Check verification progress
    func checkVerificationProgress(sessionId: String) async throws -> KYCVerificationProgress {
        let endpoint = "/users/\(userId)/kyc/sessions/\(sessionId)"

        let data = try await performRequest(endpoint: endpoint, method: "GET")
        let response = try decoder.decode(RampVerificationSessionResponse.self, from: data)

        let progress = KYCVerificationProgress(
            sessionId: sessionId,
            status: mapVerificationStatus(response.status),
            completedSteps: response.completedSteps,
            totalSteps: response.totalSteps,
            currentStep: response.currentStep,
            estimatedTimeRemaining: response.estimatedTimeRemaining
        )

        await MainActor.run {
            self.verificationProgress = Double(response.completedSteps) / Double(response.totalSteps)
        }

        return progress
    }

    /// Upload KYC document
    func uploadDocument(
        type: KYCDocumentType,
        imageData: Data,
        sessionId: String
    ) async throws -> KYCDocumentUploadResponse {
        let endpoint = "/users/\(userId)/kyc/documents"

        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // Add session ID
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(sessionId)\r\n".data(using: .utf8)!)

        // Add document type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"documentType\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(type.rawValue)\r\n".data(using: .utf8)!)

        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"document.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let data = try await performMultipartRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            boundary: boundary
        )

        let response = try decoder.decode(RampDocumentUploadResponse.self, from: data)

        return KYCDocumentUploadResponse(
            documentId: response.documentId,
            status: response.status,
            verificationStatus: response.verificationStatus
        )
    }

    /// Verify phone number
    func verifyPhoneNumber(
        phoneNumber: String,
        countryCode: String
    ) async throws -> PhoneVerificationSession {
        let endpoint = "/users/\(userId)/kyc/phone/verify"

        let requestBody: [String: Any] = [
            "phoneNumber": phoneNumber,
            "countryCode": countryCode
        ]

        let data = try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: requestBody
        )

        let response = try decoder.decode(RampPhoneVerificationResponse.self, from: data)

        return PhoneVerificationSession(
            sessionId: response.sessionId,
            expiresAt: Date().addingTimeInterval(300), // 5 minutes
            attemptsRemaining: 3
        )
    }

    /// Confirm phone verification code
    func confirmPhoneVerification(
        sessionId: String,
        code: String
    ) async throws -> Bool {
        let endpoint = "/users/\(userId)/kyc/phone/confirm"

        let requestBody: [String: Any] = [
            "sessionId": sessionId,
            "code": code
        ]

        let data = try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: requestBody
        )

        let response = try decoder.decode(RampPhoneConfirmationResponse.self, from: data)
        return response.verified
    }

    /// Submit additional information
    func submitAdditionalInfo(
        _ info: [String: Any],
        sessionId: String
    ) async throws {
        let endpoint = "/users/\(userId)/kyc/sessions/\(sessionId)/info"

        _ = try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: info
        )
    }

    /// Get required documents for tier
    func getRequiredDocuments(for tier: KYCStatus.KYCTier) -> [KYCDocumentType] {
        switch tier {
        case .tier1:
            return [.governmentId]
        case .tier2:
            return [.governmentId, .proofOfAddress]
        case .tier3:
            return [.governmentId, .proofOfAddress, .selfie]
        }
    }

    /// Check if additional verification is needed
    func needsAdditionalVerification() async throws -> Bool {
        let status = try await getKYCStatus()
        return !status.isVerified || status.tier == .tier1
    }

    // MARK: - Private Methods

    private func performRequest(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw PaymentError.providerError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PaymentError.providerError("HTTP \(httpResponse.statusCode)")
        }

        return data
    }

    private func performMultipartRequest(
        endpoint: String,
        method: String,
        body: Data,
        boundary: String
    ) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw PaymentError.providerError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PaymentError.providerError("Upload failed")
        }

        return data
    }

    private func mapToKYCStatus(_ response: RampKYCResponse) -> KYCStatus {
        let tier = KYCStatus.KYCTier(rawValue: response.tier) ?? .tier1

        return KYCStatus(
            tier: tier,
            isVerified: response.verified,
            limits: KYCLimits(
                daily: response.limits.daily,
                weekly: response.limits.weekly,
                monthly: response.limits.monthly
            ),
            verificationURL: response.verificationURL.flatMap { URL(string: $0) },
            requiredDocuments: response.requiredDocuments,
            rejectionReason: response.rejectionReason
        )
    }

    private func mapVerificationStatus(_ status: String) -> KYCVerificationStatus {
        switch status.lowercased() {
        case "pending":
            return .pending
        case "in_progress":
            return .inProgress
        case "under_review":
            return .underReview
        case "approved":
            return .approved
        case "rejected":
            return .rejected
        case "expired":
            return .expired
        default:
            return .pending
        }
    }

    private func isExpired(_ status: KYCStatus) -> Bool {
        // KYC status should be refreshed daily
        guard let lastCheck = UserDefaults.standard.object(forKey: "lastKYCCheck") as? Date else {
            return true
        }

        return Date().timeIntervalSince(lastCheck) > 86400 // 24 hours
    }
}

// MARK: - Supporting Models

struct KYCVerificationProgress: Codable {
    let sessionId: String
    let status: KYCVerificationStatus
    let completedSteps: Int
    let totalSteps: Int
    let currentStep: String?
    let estimatedTimeRemaining: Int?
}

enum KYCVerificationStatus: String, Codable {
    case pending
    case inProgress = "in_progress"
    case underReview = "under_review"
    case approved
    case rejected
    case expired
}

enum KYCDocumentType: String, Codable {
    case governmentId = "government_id"
    case passport = "passport"
    case driversLicense = "drivers_license"
    case proofOfAddress = "proof_of_address"
    case selfie = "selfie"
    case bankStatement = "bank_statement"
}

struct KYCDocumentUploadResponse: Codable {
    let documentId: String
    let status: String
    let verificationStatus: String?
}

struct PhoneVerificationSession: Codable {
    let sessionId: String
    let expiresAt: Date
    let attemptsRemaining: Int
}

// MARK: - API Response Models

private struct RampKYCResponse: Decodable {
    let tier: Int
    let verified: Bool
    let limits: Limits
    let verificationURL: String?
    let requiredDocuments: [String]?
    let rejectionReason: String?

    struct Limits: Decodable {
        let daily: Decimal
        let weekly: Decimal
        let monthly: Decimal
    }
}

private struct RampVerificationResponse: Decodable {
    let verificationURL: String
    let sessionId: String
}

private struct RampVerificationSessionResponse: Decodable {
    let sessionId: String
    let status: String
    let completedSteps: Int
    let totalSteps: Int
    let currentStep: String?
    let estimatedTimeRemaining: Int?
}

private struct RampDocumentUploadResponse: Decodable {
    let documentId: String
    let status: String
    let verificationStatus: String?
}

private struct RampPhoneVerificationResponse: Decodable {
    let sessionId: String
}

private struct RampPhoneConfirmationResponse: Decodable {
    let verified: Bool
}
