//
//  SolanaAdapter.swift
//  FuekiWallet
//
//  Production-grade Solana blockchain adapter
//

import Foundation
import Solana
import TweetNacl

/// Production-grade Solana blockchain adapter
public final class SolanaAdapter {

    // MARK: - Properties

    private let solana: Solana
    private let network: NetworkType
    private let splTokenHandler: SPLTokenHandler

    // Network configurations
    public enum NetworkType {
        case mainnet
        case testnet
        case devnet
        case custom(String)

        var endpoint: String {
            switch self {
            case .mainnet:
                return "https://api.mainnet-beta.solana.com"
            case .testnet:
                return "https://api.testnet.solana.com"
            case .devnet:
                return "https://api.devnet.solana.com"
            case .custom(let url):
                return url
            }
        }
    }

    // MARK: - Initialization

    public init(network: NetworkType, apiKey: String? = nil) throws {
        self.network = network

        var endpoint = network.endpoint
        if let apiKey = apiKey {
            endpoint += "?api-key=\(apiKey)"
        }

        guard let url = URL(string: endpoint) else {
            throw SolanaAdapterError.invalidEndpoint
        }

        self.solana = Solana(router: NetworkingRouter(endpoint: url))
        self.splTokenHandler = SPLTokenHandler(solana: solana)
    }

    // MARK: - Account Operations

    /// Get SOL balance for account
    public func getBalance(address: String) async throws -> UInt64 {
        guard let publicKey = try? PublicKey(string: address) else {
            throw SolanaAdapterError.invalidAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getBalance(account: publicKey.base58EncodedString) { result in
                switch result {
                case .success(let balance):
                    continuation.resume(returning: balance)
                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.balanceFetchFailed(error))
                }
            }
        }
    }

    /// Get SPL token balance
    public func getTokenBalance(tokenMint: String, owner: String) async throws -> UInt64 {
        return try await splTokenHandler.getBalance(tokenMint: tokenMint, owner: owner)
    }

    /// Get account info
    public func getAccountInfo(address: String) async throws -> AccountInfo {
        guard let publicKey = try? PublicKey(string: address) else {
            throw SolanaAdapterError.invalidAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getAccountInfo(account: publicKey.base58EncodedString) { result in
                switch result {
                case .success(let info):
                    continuation.resume(returning: info)
                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.accountInfoFetchFailed(error))
                }
            }
        }
    }

    // MARK: - Transaction Building

    /// Build SOL transfer transaction
    public func buildTransaction(
        from: String,
        to: String,
        amount: UInt64,
        recentBlockhash: String? = nil,
        priorityFee: UInt64? = nil
    ) async throws -> Transaction {

        guard let fromPubkey = try? PublicKey(string: from),
              let toPubkey = try? PublicKey(string: to) else {
            throw SolanaAdapterError.invalidAddress
        }

        // Get recent blockhash if not provided
        let blockhash = try await recentBlockhash ?? self.getRecentBlockhash()

        // Create transfer instruction
        let instruction = SystemProgram.transfer(
            from: fromPubkey,
            to: toPubkey,
            lamports: amount
        )

        var instructions = [instruction]

        // Add priority fee if specified
        if let fee = priorityFee {
            let computeBudgetInstruction = ComputeBudgetProgram.setComputeUnitPrice(
                microLamports: fee
            )
            instructions.insert(computeBudgetInstruction, at: 0)
        }

        // Build transaction
        let transaction = Transaction(
            instructions: instructions,
            recentBlockhash: blockhash,
            feePayer: fromPubkey
        )

        return transaction
    }

    /// Build SPL token transfer transaction
    public func buildTokenTransfer(
        tokenMint: String,
        from: String,
        to: String,
        amount: UInt64,
        decimals: UInt8,
        priorityFee: UInt64? = nil
    ) async throws -> Transaction {

        return try await splTokenHandler.buildTransferTransaction(
            tokenMint: tokenMint,
            from: from,
            to: to,
            amount: amount,
            decimals: decimals,
            priorityFee: priorityFee
        )
    }

    // MARK: - Transaction Signing

    /// Sign transaction with keypair
    public func signTransaction(
        _ transaction: inout Transaction,
        signer: Account
    ) throws {
        try transaction.sign(signers: [signer])
    }

    /// Sign transaction with multiple signers
    public func signTransaction(
        _ transaction: inout Transaction,
        signers: [Account]
    ) throws {
        try transaction.sign(signers: signers)
    }

    // MARK: - Transaction Broadcasting

    /// Broadcast transaction to network
    public func broadcastTransaction(_ transaction: Transaction) async throws -> String {
        guard let serialized = transaction.serialize() else {
            throw SolanaAdapterError.serializationFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.sendTransaction(
                serializedTransaction: serialized.base64EncodedString()
            ) { result in
                switch result {
                case .success(let signature):
                    continuation.resume(returning: signature)
                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.broadcastFailed(error))
                }
            }
        }
    }

    /// Send SOL transaction (build, sign, broadcast)
    public func sendTransaction(
        from: String,
        to: String,
        amount: UInt64,
        signer: Account,
        priorityFee: UInt64? = nil
    ) async throws -> String {

        var transaction = try await buildTransaction(
            from: from,
            to: to,
            amount: amount,
            priorityFee: priorityFee
        )

        try signTransaction(&transaction, signer: signer)
        return try await broadcastTransaction(transaction)
    }

    // MARK: - Transaction History

    /// Fetch transaction history for address
    public func getTransactionHistory(
        address: String,
        limit: Int = 50,
        before: String? = nil
    ) async throws -> [TransactionDetails] {

        guard let publicKey = try? PublicKey(string: address) else {
            throw SolanaAdapterError.invalidAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getSignaturesForAddress(
                address: publicKey.base58EncodedString,
                limit: limit,
                before: before
            ) { result in
                switch result {
                case .success(let signatures):
                    Task {
                        do {
                            let details = try await self.fetchTransactionDetails(signatures: signatures)
                            continuation.resume(returning: details)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.historyFetchFailed(error))
                }
            }
        }
    }

    /// Get transaction details by signature
    public func getTransactionDetails(signature: String) async throws -> TransactionDetails {
        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getTransaction(signature: signature) { result in
                switch result {
                case .success(let transaction):
                    guard let tx = transaction else {
                        continuation.resume(throwing: SolanaAdapterError.transactionNotFound)
                        return
                    }

                    let details = TransactionDetails(
                        signature: signature,
                        slot: tx.slot,
                        blockTime: tx.blockTime,
                        fee: tx.meta?.fee ?? 0,
                        status: tx.meta?.err == nil ? .confirmed : .failed,
                        instructions: tx.transaction.message.instructions.count
                    )

                    continuation.resume(returning: details)

                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.transactionFetchFailed(error))
                }
            }
        }
    }

    /// Confirm transaction
    public func confirmTransaction(
        signature: String,
        commitment: Commitment = .finalized
    ) async throws -> Bool {

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getSignatureStatuses(
                signatures: [signature]
            ) { result in
                switch result {
                case .success(let statuses):
                    guard let status = statuses.first else {
                        continuation.resume(returning: false)
                        return
                    }

                    let confirmed = status?.confirmationStatus == commitment.rawValue
                    continuation.resume(returning: confirmed)

                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.confirmationFailed(error))
                }
            }
        }
    }

    // MARK: - Program Interactions

    /// Execute custom program instruction
    public func executeInstruction(
        instruction: TransactionInstruction,
        signer: Account,
        recentBlockhash: String? = nil
    ) async throws -> String {

        let blockhash = try await recentBlockhash ?? self.getRecentBlockhash()

        var transaction = Transaction(
            instructions: [instruction],
            recentBlockhash: blockhash,
            feePayer: signer.publicKey
        )

        try signTransaction(&transaction, signer: signer)
        return try await broadcastTransaction(transaction)
    }

    // MARK: - Account Management

    /// Create new account
    public func createAccount(
        owner: Account,
        space: UInt64,
        programId: PublicKey
    ) async throws -> (account: Account, signature: String) {

        let newAccount = Account()

        // Calculate rent exemption
        let rentExemption = try await getRentExemption(dataLength: space)

        // Build create account instruction
        let instruction = SystemProgram.createAccount(
            from: owner.publicKey,
            to: newAccount.publicKey,
            lamports: rentExemption,
            space: space,
            programId: programId
        )

        let blockhash = try await getRecentBlockhash()

        var transaction = Transaction(
            instructions: [instruction],
            recentBlockhash: blockhash,
            feePayer: owner.publicKey
        )

        try signTransaction(&transaction, signers: [owner, newAccount])
        let signature = try await broadcastTransaction(transaction)

        return (newAccount, signature)
    }

    // MARK: - Fee Estimation

    /// Get recent prioritized fees
    public func getRecentPrioritizationFees() async throws -> [PrioritizationFee] {
        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getRecentPrioritizationFees { result in
                switch result {
                case .success(let fees):
                    continuation.resume(returning: fees)
                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.feeFetchFailed(error))
                }
            }
        }
    }

    /// Estimate compute units for transaction
    public func simulateTransaction(_ transaction: Transaction) async throws -> SimulationResult {
        guard let serialized = transaction.serialize() else {
            throw SolanaAdapterError.serializationFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.simulateTransaction(
                transaction: serialized.base64EncodedString()
            ) { result in
                switch result {
                case .success(let simulation):
                    continuation.resume(returning: simulation)
                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.simulationFailed(error))
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func getRecentBlockhash() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getRecentBlockhash { result in
                switch result {
                case .success(let blockhash):
                    continuation.resume(returning: blockhash)
                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.blockhashFetchFailed(error))
                }
            }
        }
    }

    private func getRentExemption(dataLength: UInt64) async throws -> UInt64 {
        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getMinimumBalanceForRentExemption(dataLength: dataLength) { result in
                switch result {
                case .success(let amount):
                    continuation.resume(returning: amount)
                case .failure(let error):
                    continuation.resume(throwing: SolanaAdapterError.rentFetchFailed(error))
                }
            }
        }
    }

    private func fetchTransactionDetails(
        signatures: [SignatureInfo]
    ) async throws -> [TransactionDetails] {

        return try await withThrowingTaskGroup(of: TransactionDetails?.self) { group in
            for signatureInfo in signatures {
                group.addTask {
                    try? await self.getTransactionDetails(signature: signatureInfo.signature)
                }
            }

            var details: [TransactionDetails] = []
            for try await detail in group {
                if let detail = detail {
                    details.append(detail)
                }
            }
            return details
        }
    }
}

// MARK: - Models

public struct TransactionDetails {
    public let signature: String
    public let slot: UInt64
    public let blockTime: Date?
    public let fee: UInt64
    public let status: TransactionStatus
    public let instructions: Int
}

public enum TransactionStatus {
    case confirmed
    case failed
    case pending
}

public enum Commitment: String {
    case processed
    case confirmed
    case finalized
}

public struct PrioritizationFee {
    public let slot: UInt64
    public let prioritizationFee: UInt64
}

public struct SimulationResult {
    public let err: String?
    public let logs: [String]
    public let unitsConsumed: UInt64
}

// MARK: - Errors

public enum SolanaAdapterError: LocalizedError {
    case invalidEndpoint
    case invalidAddress
    case balanceFetchFailed(Error)
    case accountInfoFetchFailed(Error)
    case serializationFailed
    case broadcastFailed(Error)
    case historyFetchFailed(Error)
    case transactionFetchFailed(Error)
    case transactionNotFound
    case confirmationFailed(Error)
    case feeFetchFailed(Error)
    case simulationFailed(Error)
    case blockhashFetchFailed(Error)
    case rentFetchFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid Solana endpoint"
        case .invalidAddress:
            return "Invalid Solana address"
        case .balanceFetchFailed(let error):
            return "Failed to fetch balance: \(error.localizedDescription)"
        case .accountInfoFetchFailed(let error):
            return "Failed to fetch account info: \(error.localizedDescription)"
        case .serializationFailed:
            return "Failed to serialize transaction"
        case .broadcastFailed(let error):
            return "Failed to broadcast transaction: \(error.localizedDescription)"
        case .historyFetchFailed(let error):
            return "Failed to fetch transaction history: \(error.localizedDescription)"
        case .transactionFetchFailed(let error):
            return "Failed to fetch transaction: \(error.localizedDescription)"
        case .transactionNotFound:
            return "Transaction not found"
        case .confirmationFailed(let error):
            return "Failed to confirm transaction: \(error.localizedDescription)"
        case .feeFetchFailed(let error):
            return "Failed to fetch fees: \(error.localizedDescription)"
        case .simulationFailed(let error):
            return "Transaction simulation failed: \(error.localizedDescription)"
        case .blockhashFetchFailed(let error):
            return "Failed to fetch blockhash: \(error.localizedDescription)"
        case .rentFetchFailed(let error):
            return "Failed to fetch rent exemption: \(error.localizedDescription)"
        }
    }
}
