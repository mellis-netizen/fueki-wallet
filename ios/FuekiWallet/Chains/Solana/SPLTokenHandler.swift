//
//  SPLTokenHandler.swift
//  FuekiWallet
//
//  Production-grade SPL Token handler
//

import Foundation
import Solana

/// Handles SPL Token operations
public final class SPLTokenHandler {

    // MARK: - Properties

    private let solana: Solana

    // SPL Token Program ID
    private let tokenProgramId = PublicKey(string: "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")!

    // Associated Token Program ID
    private let associatedTokenProgramId = PublicKey(string: "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL")!

    // MARK: - Initialization

    public init(solana: Solana) {
        self.solana = solana
    }

    // MARK: - Token Account Operations

    /// Get or create associated token account
    public func getOrCreateAssociatedTokenAccount(
        mint: String,
        owner: String,
        payer: Account
    ) async throws -> (address: String, instruction: TransactionInstruction?) {

        guard let mintPubkey = try? PublicKey(string: mint),
              let ownerPubkey = try? PublicKey(string: owner) else {
            throw SPLTokenError.invalidAddress
        }

        let associatedTokenAddress = try getAssociatedTokenAddress(
            mint: mintPubkey,
            owner: ownerPubkey
        )

        // Check if account exists
        let accountExists = try await checkAccountExists(address: associatedTokenAddress.base58EncodedString)

        if accountExists {
            return (associatedTokenAddress.base58EncodedString, nil)
        }

        // Create instruction to create associated token account
        let instruction = try createAssociatedTokenAccountInstruction(
            mint: mintPubkey,
            owner: ownerPubkey,
            payer: payer.publicKey
        )

        return (associatedTokenAddress.base58EncodedString, instruction)
    }

    /// Get associated token address
    public func getAssociatedTokenAddress(
        mint: PublicKey,
        owner: PublicKey
    ) throws -> PublicKey {

        let seeds: [Data] = [
            owner.data,
            tokenProgramId.data,
            mint.data
        ]

        return try PublicKey.findProgramAddress(
            seeds: seeds,
            programId: associatedTokenProgramId
        ).0
    }

    // MARK: - Balance Operations

    /// Get SPL token balance
    public func getBalance(tokenMint: String, owner: String) async throws -> UInt64 {
        guard let mintPubkey = try? PublicKey(string: tokenMint),
              let ownerPubkey = try? PublicKey(string: owner) else {
            throw SPLTokenError.invalidAddress
        }

        let associatedTokenAddress = try getAssociatedTokenAddress(
            mint: mintPubkey,
            owner: ownerPubkey
        )

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getTokenAccountBalance(
                pubkey: associatedTokenAddress.base58EncodedString
            ) { result in
                switch result {
                case .success(let balance):
                    continuation.resume(returning: balance.uiAmount ?? 0)
                case .failure(let error):
                    continuation.resume(throwing: SPLTokenError.balanceFetchFailed(error))
                }
            }
        }
    }

    /// Get all token accounts for owner
    public func getTokenAccounts(owner: String) async throws -> [TokenAccount] {
        guard let ownerPubkey = try? PublicKey(string: owner) else {
            throw SPLTokenError.invalidAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getTokenAccountsByOwner(
                pubkey: ownerPubkey.base58EncodedString,
                programId: tokenProgramId.base58EncodedString
            ) { result in
                switch result {
                case .success(let accounts):
                    let tokenAccounts = accounts.compactMap { account -> TokenAccount? in
                        guard let data = account.account.data,
                              let parsed = try? self.parseTokenAccountData(data) else {
                            return nil
                        }
                        return TokenAccount(
                            address: account.pubkey,
                            mint: parsed.mint,
                            owner: parsed.owner,
                            amount: parsed.amount,
                            decimals: parsed.decimals
                        )
                    }
                    continuation.resume(returning: tokenAccounts)

                case .failure(let error):
                    continuation.resume(throwing: SPLTokenError.tokenAccountsFetchFailed(error))
                }
            }
        }
    }

    // MARK: - Token Information

    /// Get token metadata
    public func getTokenMetadata(mint: String) async throws -> TokenMetadata {
        guard let mintPubkey = try? PublicKey(string: mint) else {
            throw SPLTokenError.invalidAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getAccountInfo(account: mintPubkey.base58EncodedString) { result in
                switch result {
                case .success(let accountInfo):
                    guard let data = accountInfo.data else {
                        continuation.resume(throwing: SPLTokenError.invalidMintData)
                        return
                    }

                    do {
                        let metadata = try self.parseMintData(data)
                        continuation.resume(returning: metadata)
                    } catch {
                        continuation.resume(throwing: error)
                    }

                case .failure(let error):
                    continuation.resume(throwing: SPLTokenError.metadataFetchFailed(error))
                }
            }
        }
    }

    // MARK: - Transfer Operations

    /// Build SPL token transfer transaction
    public func buildTransferTransaction(
        tokenMint: String,
        from: String,
        to: String,
        amount: UInt64,
        decimals: UInt8,
        priorityFee: UInt64? = nil
    ) async throws -> Transaction {

        guard let mintPubkey = try? PublicKey(string: tokenMint),
              let fromPubkey = try? PublicKey(string: from),
              let toPubkey = try? PublicKey(string: to) else {
            throw SPLTokenError.invalidAddress
        }

        // Get source token account
        let sourceTokenAccount = try getAssociatedTokenAddress(
            mint: mintPubkey,
            owner: fromPubkey
        )

        // Get or create destination token account
        let (destinationTokenAccount, createAccountInstruction) = try await getOrCreateAssociatedTokenAccount(
            mint: tokenMint,
            owner: to,
            payer: Account() // Will be replaced with actual payer
        )

        guard let destPubkey = try? PublicKey(string: destinationTokenAccount) else {
            throw SPLTokenError.invalidAddress
        }

        // Build transfer instruction
        let transferInstruction = try TokenProgram.transfer(
            source: sourceTokenAccount,
            destination: destPubkey,
            owner: fromPubkey,
            amount: amount
        )

        var instructions = [TransactionInstruction]()

        // Add priority fee if specified
        if let fee = priorityFee {
            let computeBudgetInstruction = ComputeBudgetProgram.setComputeUnitPrice(
                microLamports: fee
            )
            instructions.append(computeBudgetInstruction)
        }

        // Add create account instruction if needed
        if let createInstruction = createAccountInstruction {
            instructions.append(createInstruction)
        }

        instructions.append(transferInstruction)

        // Get recent blockhash
        let blockhash = try await getRecentBlockhash()

        let transaction = Transaction(
            instructions: instructions,
            recentBlockhash: blockhash,
            feePayer: fromPubkey
        )

        return transaction
    }

    /// Build token approval instruction
    public func buildApproveInstruction(
        tokenAccount: String,
        delegate: String,
        owner: String,
        amount: UInt64
    ) throws -> TransactionInstruction {

        guard let tokenAccountPubkey = try? PublicKey(string: tokenAccount),
              let delegatePubkey = try? PublicKey(string: delegate),
              let ownerPubkey = try? PublicKey(string: owner) else {
            throw SPLTokenError.invalidAddress
        }

        return try TokenProgram.approve(
            account: tokenAccountPubkey,
            delegate: delegatePubkey,
            owner: ownerPubkey,
            amount: amount
        )
    }

    /// Build token revoke instruction
    public func buildRevokeInstruction(
        tokenAccount: String,
        owner: String
    ) throws -> TransactionInstruction {

        guard let tokenAccountPubkey = try? PublicKey(string: tokenAccount),
              let ownerPubkey = try? PublicKey(string: owner) else {
            throw SPLTokenError.invalidAddress
        }

        return try TokenProgram.revoke(
            account: tokenAccountPubkey,
            owner: ownerPubkey
        )
    }

    // MARK: - Token Creation

    /// Create new SPL token
    public func createToken(
        payer: Account,
        decimals: UInt8,
        mintAuthority: PublicKey,
        freezeAuthority: PublicKey?
    ) async throws -> (mint: Account, signature: String) {

        let mintAccount = Account()

        // Get rent exemption for mint account
        let rentExemption = try await getRentExemption(dataLength: 82) // Mint account size

        // Create account instruction
        let createAccountInstruction = SystemProgram.createAccount(
            from: payer.publicKey,
            to: mintAccount.publicKey,
            lamports: rentExemption,
            space: 82,
            programId: tokenProgramId
        )

        // Initialize mint instruction
        let initializeMintInstruction = try TokenProgram.initializeMint(
            mint: mintAccount.publicKey,
            decimals: decimals,
            mintAuthority: mintAuthority,
            freezeAuthority: freezeAuthority
        )

        let blockhash = try await getRecentBlockhash()

        var transaction = Transaction(
            instructions: [createAccountInstruction, initializeMintInstruction],
            recentBlockhash: blockhash,
            feePayer: payer.publicKey
        )

        try transaction.sign(signers: [payer, mintAccount])

        let signature = try await broadcastTransaction(transaction)

        return (mintAccount, signature)
    }

    /// Mint tokens to account
    public func mintTo(
        mint: String,
        destination: String,
        authority: Account,
        amount: UInt64
    ) async throws -> String {

        guard let mintPubkey = try? PublicKey(string: mint),
              let destPubkey = try? PublicKey(string: destination) else {
            throw SPLTokenError.invalidAddress
        }

        let instruction = try TokenProgram.mintTo(
            mint: mintPubkey,
            destination: destPubkey,
            authority: authority.publicKey,
            amount: amount
        )

        let blockhash = try await getRecentBlockhash()

        var transaction = Transaction(
            instructions: [instruction],
            recentBlockhash: blockhash,
            feePayer: authority.publicKey
        )

        try transaction.sign(signers: [authority])

        return try await broadcastTransaction(transaction)
    }

    // MARK: - Private Helpers

    private func createAssociatedTokenAccountInstruction(
        mint: PublicKey,
        owner: PublicKey,
        payer: PublicKey
    ) throws -> TransactionInstruction {

        let associatedTokenAddress = try getAssociatedTokenAddress(mint: mint, owner: owner)

        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: payer, isSigner: true, isWritable: true),
                AccountMeta(publicKey: associatedTokenAddress, isSigner: false, isWritable: true),
                AccountMeta(publicKey: owner, isSigner: false, isWritable: false),
                AccountMeta(publicKey: mint, isSigner: false, isWritable: false),
                AccountMeta(publicKey: PublicKey.systemProgramId, isSigner: false, isWritable: false),
                AccountMeta(publicKey: tokenProgramId, isSigner: false, isWritable: false)
            ],
            programId: associatedTokenProgramId,
            data: Data()
        )
    }

    private func checkAccountExists(address: String) async throws -> Bool {
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AccountInfo, Error>) in
                solana.api.getAccountInfo(account: address) { result in
                    switch result {
                    case .success(let info):
                        continuation.resume(returning: info)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            return true
        } catch {
            return false
        }
    }

    private func parseTokenAccountData(_ data: Data) throws -> TokenAccountData {
        guard data.count >= 165 else {
            throw SPLTokenError.invalidTokenAccountData
        }

        let mint = try PublicKey(data: data.subdata(in: 0..<32))
        let owner = try PublicKey(data: data.subdata(in: 32..<64))
        let amount = data.subdata(in: 64..<72).withUnsafeBytes { $0.load(as: UInt64.self) }
        let decimals = data[72]

        return TokenAccountData(mint: mint.base58EncodedString, owner: owner.base58EncodedString, amount: amount, decimals: decimals)
    }

    private func parseMintData(_ data: Data) throws -> TokenMetadata {
        guard data.count >= 82 else {
            throw SPLTokenError.invalidMintData
        }

        let decimals = data[44]
        let isInitialized = data[45] == 1
        let supply = data.subdata(in: 36..<44).withUnsafeBytes { $0.load(as: UInt64.self) }

        return TokenMetadata(
            decimals: decimals,
            supply: supply,
            isInitialized: isInitialized
        )
    }

    private func getRecentBlockhash() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            solana.api.getRecentBlockhash { result in
                switch result {
                case .success(let blockhash):
                    continuation.resume(returning: blockhash)
                case .failure(let error):
                    continuation.resume(throwing: SPLTokenError.blockhashFetchFailed(error))
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
                    continuation.resume(throwing: SPLTokenError.rentFetchFailed(error))
                }
            }
        }
    }

    private func broadcastTransaction(_ transaction: Transaction) async throws -> String {
        guard let serialized = transaction.serialize() else {
            throw SPLTokenError.serializationFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            solana.api.sendTransaction(
                serializedTransaction: serialized.base64EncodedString()
            ) { result in
                switch result {
                case .success(let signature):
                    continuation.resume(returning: signature)
                case .failure(let error):
                    continuation.resume(throwing: SPLTokenError.broadcastFailed(error))
                }
            }
        }
    }
}

// MARK: - Models

public struct TokenAccount {
    public let address: String
    public let mint: String
    public let owner: String
    public let amount: UInt64
    public let decimals: UInt8
}

private struct TokenAccountData {
    let mint: String
    let owner: String
    let amount: UInt64
    let decimals: UInt8
}

public struct TokenMetadata {
    public let decimals: UInt8
    public let supply: UInt64
    public let isInitialized: Bool
}

// MARK: - Errors

public enum SPLTokenError: LocalizedError {
    case invalidAddress
    case invalidTokenAccountData
    case invalidMintData
    case balanceFetchFailed(Error)
    case tokenAccountsFetchFailed(Error)
    case metadataFetchFailed(Error)
    case serializationFailed
    case broadcastFailed(Error)
    case blockhashFetchFailed(Error)
    case rentFetchFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid Solana address"
        case .invalidTokenAccountData:
            return "Invalid token account data"
        case .invalidMintData:
            return "Invalid mint data"
        case .balanceFetchFailed(let error):
            return "Failed to fetch token balance: \(error.localizedDescription)"
        case .tokenAccountsFetchFailed(let error):
            return "Failed to fetch token accounts: \(error.localizedDescription)"
        case .metadataFetchFailed(let error):
            return "Failed to fetch token metadata: \(error.localizedDescription)"
        case .serializationFailed:
            return "Failed to serialize transaction"
        case .broadcastFailed(let error):
            return "Failed to broadcast transaction: \(error.localizedDescription)"
        case .blockhashFetchFailed(let error):
            return "Failed to fetch blockhash: \(error.localizedDescription)"
        case .rentFetchFailed(let error):
            return "Failed to fetch rent exemption: \(error.localizedDescription)"
        }
    }
}
