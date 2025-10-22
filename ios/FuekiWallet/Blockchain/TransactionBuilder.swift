//
//  TransactionBuilder.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Multi-Chain Transaction Construction
//

import Foundation

// MARK: - Transaction Builder
class TransactionBuilder {
    private let provider: BlockchainProviderProtocol

    init(provider: BlockchainProviderProtocol) {
        self.provider = provider
    }

    // MARK: - Build Transfer Transaction
    func buildTransferTransaction(
        from: String,
        to: String,
        amount: Decimal,
        data: Data? = nil
    ) async throws -> Data {
        let request = TransactionRequest(
            from: from,
            to: to,
            value: amount,
            data: data,
            gasLimit: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            nonce: nil
        )

        return try await provider.buildTransaction(request)
    }

    // MARK: - Build Token Transfer
    func buildTokenTransferTransaction(
        from: String,
        to: String,
        tokenAddress: String,
        amount: Decimal,
        decimals: Int
    ) async throws -> Data {
        let data: Data

        switch provider.chainType {
        case .ethereum:
            // Build ERC-20 transfer data
            data = try buildERC20TransferData(to: to, amount: amount, decimals: decimals)

        case .solana:
            // Build SPL token transfer instruction
            data = try buildSPLTransferData(to: to, tokenMint: tokenAddress, amount: amount, decimals: decimals)

        case .bitcoin:
            throw BlockchainError.unsupportedOperation
        }

        let request = TransactionRequest(
            from: from,
            to: provider.chainType == .ethereum ? tokenAddress : to,
            value: 0,
            data: data,
            gasLimit: provider.chainType == .ethereum ? NetworkConstants.ethereumGasLimitERC20 : nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            nonce: nil
        )

        return try await provider.buildTransaction(request)
    }

    // MARK: - Build with Custom Gas
    func buildTransactionWithCustomGas(
        from: String,
        to: String,
        amount: Decimal,
        gasLimit: UInt64? = nil,
        maxFeePerGas: Decimal? = nil,
        maxPriorityFeePerGas: Decimal? = nil
    ) async throws -> Data {
        let request = TransactionRequest(
            from: from,
            to: to,
            value: amount,
            data: nil,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            nonce: nil
        )

        return try await provider.buildTransaction(request)
    }

    // MARK: - Build Contract Interaction
    func buildContractTransaction(
        from: String,
        contractAddress: String,
        functionSignature: String,
        parameters: [Any],
        value: Decimal = 0
    ) async throws -> Data {
        let data = try encodeContractCall(
            functionSignature: functionSignature,
            parameters: parameters
        )

        let request = TransactionRequest(
            from: from,
            to: contractAddress,
            value: value,
            data: data,
            gasLimit: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            nonce: nil
        )

        return try await provider.buildTransaction(request)
    }

    // MARK: - Estimate Total Cost
    func estimateTransactionCost(
        from: String,
        to: String,
        amount: Decimal,
        data: Data? = nil
    ) async throws -> GasEstimation {
        let request = TransactionRequest(
            from: from,
            to: to,
            value: amount,
            data: data,
            gasLimit: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            nonce: nil
        )

        return try await provider.estimateGas(for: request)
    }

    // MARK: - Private Helpers - Ethereum
    private func buildERC20TransferData(to: String, amount: Decimal, decimals: Int) throws -> Data {
        // ERC-20 transfer function signature: transfer(address,uint256)
        let functionSignature = "0xa9059cbb"

        // Encode recipient address (padded to 32 bytes)
        guard to.hasPrefix("0x"), to.count == 42 else {
            throw BlockchainError.invalidAddress
        }

        let recipientHex = String(to.dropFirst(2)).leftPadding(toLength: 64, withPad: "0")

        // Encode amount (padded to 32 bytes)
        let amountHex = amount.toHexString(decimals: decimals)
            .dropFirst(2)  // Remove 0x
            .leftPadding(toLength: 64, withPad: "0")

        let dataHex = functionSignature + recipientHex + amountHex

        guard let data = Data.fromHexString(dataHex) else {
            throw BlockchainError.invalidTransaction
        }

        return data
    }

    // MARK: - Private Helpers - Solana
    private func buildSPLTransferData(to: String, tokenMint: String, amount: Decimal, decimals: Int) throws -> Data {
        // SPL Token Transfer instruction layout:
        // - Program ID: Token Program
        // - Accounts: source, destination, authority
        // - Data: instruction discriminator + amount

        // Simplified instruction data (actual implementation would use Borsh serialization)
        let instructionDiscriminator: UInt8 = 3  // Transfer instruction

        var data = Data()
        data.append(instructionDiscriminator)

        // Add amount (little-endian u64)
        let amountValue = UInt64((amount as NSDecimalNumber).uint64Value)
        withUnsafeBytes(of: amountValue.littleEndian) { data.append(contentsOf: $0) }

        return data
    }

    // MARK: - Contract Call Encoding
    private func encodeContractCall(functionSignature: String, parameters: [Any]) throws -> Data {
        // Simplified ABI encoding for Ethereum contracts
        // Full implementation would use web3.swift or similar library

        var data = Data()

        // Function selector (first 4 bytes of keccak256 hash)
        if let selectorData = Data.fromHexString(functionSignature) {
            data.append(selectorData.prefix(4))
        }

        // Encode parameters (simplified)
        for param in parameters {
            if let address = param as? String {
                // Encode address
                let addressHex = String(address.dropFirst(2)).leftPadding(toLength: 64, withPad: "0")
                if let addressData = Data.fromHexString(addressHex) {
                    data.append(addressData)
                }
            } else if let uint = param as? UInt64 {
                // Encode uint256
                var value = uint.bigEndian
                withUnsafeBytes(of: &value) { bytes in
                    data.append(contentsOf: bytes)
                }
                // Pad to 32 bytes
                data.append(Data(repeating: 0, count: 24))
            }
        }

        return data
    }
}

// MARK: - Transaction Validator
class TransactionValidator {
    private let provider: BlockchainProviderProtocol

    init(provider: BlockchainProviderProtocol) {
        self.provider = provider
    }

    // MARK: - Validate Transaction
    func validateTransaction(
        from: String,
        to: String,
        amount: Decimal,
        balance: Decimal
    ) throws {
        // Validate addresses
        guard provider.validateAddress(from) else {
            throw BlockchainError.invalidAddress
        }

        guard provider.validateAddress(to) else {
            throw BlockchainError.invalidAddress
        }

        // Validate amount
        guard amount > 0 else {
            throw BlockchainError.invalidTransaction
        }

        // Check balance
        guard balance >= amount else {
            throw BlockchainError.insufficientBalance
        }

        // Chain-specific validations
        switch provider.chainType {
        case .bitcoin:
            // Validate against dust limit
            let amountSatoshis = UInt64((amount as NSDecimalNumber).uint64Value)
            guard amountSatoshis >= NetworkConstants.bitcoinDustLimit else {
                throw BlockchainError.invalidTransaction
            }

        case .ethereum, .solana:
            break
        }
    }

    // MARK: - Validate Gas Parameters
    func validateGasParameters(
        gasLimit: UInt64?,
        maxFeePerGas: Decimal?,
        balance: Decimal
    ) async throws {
        guard provider.chainType == .ethereum else { return }

        if let gasLimit = gasLimit,
           let maxFee = maxFeePerGas {
            let totalCost = Decimal(gasLimit) * maxFee

            guard balance >= totalCost else {
                throw BlockchainError.insufficientBalance
            }
        }
    }
}

// MARK: - String Extension
private extension String {
    func leftPadding(toLength: Int, withPad: Character) -> String {
        let padLength = max(0, toLength - count)
        return String(repeating: withPad, count: padLength) + self
    }
}
