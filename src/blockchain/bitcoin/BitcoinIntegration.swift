import Foundation
import CryptoKit

/// Bitcoin Blockchain Integration Module
/// Handles Bitcoin transaction creation, signing, and broadcasting
public class BitcoinIntegration {

    // MARK: - Types

    public struct BitcoinAddress {
        let address: String
        let publicKey: Data
        let type: AddressType

        public enum AddressType {
            case legacy // P2PKH (1...)
            case segwit // P2WPKH (bc1q...)
            case nestedSegwit // P2SH-P2WPKH (3...)
        }

        public init(address: String, publicKey: Data, type: AddressType) {
            self.address = address
            self.publicKey = publicKey
            self.type = type
        }
    }

    public struct UTXO {
        let txHash: Data
        let outputIndex: UInt32
        let amount: UInt64 // satoshis
        let script: Data
        let confirmations: UInt32

        public init(txHash: Data, outputIndex: UInt32, amount: UInt64,
                   script: Data, confirmations: UInt32 = 0) {
            self.txHash = txHash
            self.outputIndex = outputIndex
            self.amount = amount
            self.script = script
            self.confirmations = confirmations
        }
    }

    public struct BitcoinTransaction {
        let version: UInt32
        let inputs: [TransactionInput]
        let outputs: [TransactionOutput]
        let locktime: UInt32

        public init(version: UInt32 = 2, inputs: [TransactionInput],
                   outputs: [TransactionOutput], locktime: UInt32 = 0) {
            self.version = version
            self.inputs = inputs
            self.outputs = outputs
            self.locktime = locktime
        }
    }

    public struct TransactionInput {
        let previousOutput: (txHash: Data, index: UInt32)
        let scriptSig: Data
        let sequence: UInt32
        let witness: [Data]? // For SegWit

        public init(previousOutput: (Data, UInt32), scriptSig: Data = Data(),
                   sequence: UInt32 = 0xFFFFFFFF, witness: [Data]? = nil) {
            self.previousOutput = previousOutput
            self.scriptSig = scriptSig
            self.sequence = sequence
            self.witness = witness
        }
    }

    public struct TransactionOutput {
        let amount: UInt64 // satoshis
        let scriptPubKey: Data

        public init(amount: UInt64, scriptPubKey: Data) {
            self.amount = amount
            self.scriptPubKey = scriptPubKey
        }
    }

    public struct TransactionFee {
        let feeRate: UInt64 // satoshis per byte
        let totalFee: UInt64
        let priority: Priority

        public enum Priority {
            case low
            case medium
            case high
            case custom(UInt64)
        }

        public init(feeRate: UInt64, totalFee: UInt64, priority: Priority = .medium) {
            self.feeRate = feeRate
            self.totalFee = totalFee
            self.priority = priority
        }
    }

    public enum BitcoinError: Error {
        case invalidAddress
        case insufficientBalance
        case invalidTransaction
        case networkError(String)
        case broadcastFailed
        case utxoFetchFailed
    }

    // MARK: - Properties

    private let networkManager: BitcoinNetworkManager
    private let addressGenerator: BitcoinAddressGenerator
    private let utxoManager: UTXOManager

    // Current network (mainnet/testnet)
    public var network: Network

    public enum Network {
        case mainnet
        case testnet
    }

    // MARK: - Initialization

    public init(network: Network = .mainnet) {
        self.network = network
        self.networkManager = BitcoinNetworkManager(network: network)
        self.addressGenerator = BitcoinAddressGenerator(network: network)
        self.utxoManager = UTXOManager(network: network)
    }

    // MARK: - Address Generation

    /// Generate Bitcoin address from public key
    /// - Parameters:
    ///   - publicKey: Compressed public key (33 bytes)
    ///   - type: Address type (legacy, segwit, nested segwit)
    /// - Returns: Bitcoin address
    public func generateAddress(from publicKey: Data,
                               type: BitcoinAddress.AddressType = .segwit) throws -> BitcoinAddress {
        return try addressGenerator.generate(from: publicKey, type: type)
    }

    /// Validate Bitcoin address
    /// - Parameter address: Address string to validate
    /// - Returns: True if valid
    public func validateAddress(_ address: String) -> Bool {
        return addressGenerator.validate(address)
    }

    // MARK: - Balance and UTXO Management

    /// Get balance for address
    /// - Parameter address: Bitcoin address
    /// - Returns: Balance in satoshis
    public func getBalance(for address: String) async throws -> UInt64 {
        let utxos = try await fetchUTXOs(for: address)
        return utxos.reduce(0) { $0 + $1.amount }
    }

    /// Fetch UTXOs for address
    /// - Parameter address: Bitcoin address
    /// - Returns: Array of UTXOs
    public func fetchUTXOs(for address: String) async throws -> [UTXO] {
        return try await utxoManager.fetchUTXOs(for: address)
    }

    // MARK: - Transaction Creation

    /// Create a simple send transaction
    /// - Parameters:
    ///   - from: Sender address
    ///   - to: Recipient address
    ///   - amount: Amount in satoshis
    ///   - feeRate: Fee rate in satoshis per byte
    /// - Returns: Unsigned transaction
    public func createSendTransaction(from: String,
                                     to: String,
                                     amount: UInt64,
                                     feeRate: UInt64 = 10) async throws -> BitcoinTransaction {
        // Validate addresses
        guard validateAddress(from) && validateAddress(to) else {
            throw BitcoinError.invalidAddress
        }

        // Fetch UTXOs for sender
        let utxos = try await fetchUTXOs(for: from)

        // Select UTXOs for transaction
        let (selectedUTXOs, totalInput) = try selectUTXOs(utxos, targetAmount: amount, feeRate: feeRate)

        // Calculate fee
        let estimatedSize = estimateTransactionSize(
            inputCount: selectedUTXOs.count,
            outputCount: 2 // recipient + change
        )
        let fee = feeRate * UInt64(estimatedSize)

        // Check sufficient balance
        guard totalInput >= amount + fee else {
            throw BitcoinError.insufficientBalance
        }

        // Create inputs
        let inputs = selectedUTXOs.map { utxo in
            TransactionInput(
                previousOutput: (utxo.txHash, utxo.outputIndex),
                scriptSig: Data(),
                sequence: 0xFFFFFFFF
            )
        }

        // Create outputs
        var outputs: [TransactionOutput] = []

        // Recipient output
        let recipientScript = try createScriptPubKey(for: to)
        outputs.append(TransactionOutput(amount: amount, scriptPubKey: recipientScript))

        // Change output
        let changeAmount = totalInput - amount - fee
        if changeAmount > 546 { // Dust threshold
            let changeScript = try createScriptPubKey(for: from)
            outputs.append(TransactionOutput(amount: changeAmount, scriptPubKey: changeScript))
        }

        return BitcoinTransaction(
            version: 2,
            inputs: inputs,
            outputs: outputs,
            locktime: 0
        )
    }

    /// Create multi-recipient transaction
    /// - Parameters:
    ///   - from: Sender address
    ///   - recipients: Array of (address, amount) tuples
    ///   - feeRate: Fee rate in satoshis per byte
    /// - Returns: Unsigned transaction
    public func createMultiRecipientTransaction(from: String,
                                               recipients: [(String, UInt64)],
                                               feeRate: UInt64 = 10) async throws -> BitcoinTransaction {
        guard validateAddress(from) else {
            throw BitcoinError.invalidAddress
        }

        guard recipients.allSatisfy({ validateAddress($0.0) }) else {
            throw BitcoinError.invalidAddress
        }

        let totalAmount = recipients.reduce(0) { $0 + $1.1 }

        // Fetch UTXOs
        let utxos = try await fetchUTXOs(for: from)

        // Select UTXOs
        let (selectedUTXOs, totalInput) = try selectUTXOs(utxos, targetAmount: totalAmount, feeRate: feeRate)

        // Calculate fee
        let estimatedSize = estimateTransactionSize(
            inputCount: selectedUTXOs.count,
            outputCount: recipients.count + 1 // recipients + change
        )
        let fee = feeRate * UInt64(estimatedSize)

        guard totalInput >= totalAmount + fee else {
            throw BitcoinError.insufficientBalance
        }

        // Create inputs
        let inputs = selectedUTXOs.map { utxo in
            TransactionInput(
                previousOutput: (utxo.txHash, utxo.outputIndex),
                scriptSig: Data()
            )
        }

        // Create outputs
        var outputs: [TransactionOutput] = []

        for (address, amount) in recipients {
            let script = try createScriptPubKey(for: address)
            outputs.append(TransactionOutput(amount: amount, scriptPubKey: script))
        }

        // Change output
        let changeAmount = totalInput - totalAmount - fee
        if changeAmount > 546 {
            let changeScript = try createScriptPubKey(for: from)
            outputs.append(TransactionOutput(amount: changeAmount, scriptPubKey: changeScript))
        }

        return BitcoinTransaction(
            version: 2,
            inputs: inputs,
            outputs: outputs
        )
    }

    // MARK: - Transaction Broadcasting

    /// Broadcast signed transaction to network
    /// - Parameter signedTransaction: Signed transaction data
    /// - Returns: Transaction hash
    public func broadcastTransaction(_ signedTransaction: Data) async throws -> String {
        return try await networkManager.broadcast(signedTransaction)
    }

    // MARK: - Transaction History

    /// Fetch transaction history for address
    /// - Parameters:
    ///   - address: Bitcoin address
    ///   - limit: Maximum number of transactions to fetch
    /// - Returns: Array of transaction hashes
    public func fetchTransactionHistory(for address: String,
                                       limit: Int = 50) async throws -> [String] {
        return try await networkManager.fetchHistory(for: address, limit: limit)
    }

    /// Get transaction details
    /// - Parameter txHash: Transaction hash
    /// - Returns: Transaction details
    public func getTransactionDetails(_ txHash: String) async throws -> BitcoinTransaction {
        return try await networkManager.fetchTransaction(txHash)
    }

    // MARK: - Fee Estimation

    /// Estimate optimal fee rate
    /// - Parameter priority: Transaction priority
    /// - Returns: Fee rate in satoshis per byte
    public func estimateFeeRate(priority: TransactionFee.Priority = .medium) async throws -> UInt64 {
        return try await networkManager.estimateFee(priority: priority)
    }

    // MARK: - Private Helper Methods

    private func selectUTXOs(_ utxos: [UTXO],
                            targetAmount: UInt64,
                            feeRate: UInt64) throws -> ([UTXO], UInt64) {
        // Sort UTXOs by amount (largest first) for simple selection
        let sortedUTXOs = utxos.sorted { $0.amount > $1.amount }

        var selected: [UTXO] = []
        var totalAmount: UInt64 = 0

        for utxo in sortedUTXOs {
            selected.append(utxo)
            totalAmount += utxo.amount

            // Estimate fee with current selection
            let estimatedSize = estimateTransactionSize(
                inputCount: selected.count,
                outputCount: 2
            )
            let estimatedFee = feeRate * UInt64(estimatedSize)

            // Check if we have enough
            if totalAmount >= targetAmount + estimatedFee + 1000 { // +1000 for buffer
                break
            }
        }

        guard !selected.isEmpty else {
            throw BitcoinError.insufficientBalance
        }

        return (selected, totalAmount)
    }

    private func estimateTransactionSize(inputCount: Int, outputCount: Int) -> Int {
        // Rough estimation for SegWit transaction
        // Base size: 10 bytes
        // Input: ~68 bytes (SegWit)
        // Output: ~31 bytes
        return 10 + (inputCount * 68) + (outputCount * 31)
    }

    private func createScriptPubKey(for address: String) throws -> Data {
        return try addressGenerator.createScriptPubKey(for: address)
    }
}

// MARK: - Supporting Classes

private class BitcoinNetworkManager {
    let network: BitcoinIntegration.Network
    let baseURL: String

    init(network: BitcoinIntegration.Network) {
        self.network = network
        self.baseURL = network == .mainnet ?
            "https://blockstream.info/api" :
            "https://blockstream.info/testnet/api"
    }

    func broadcast(_ transaction: Data) async throws -> String {
        let url = URL(string: "\(baseURL)/tx")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = transaction.hexString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BitcoinIntegration.BitcoinError.broadcastFailed
        }

        guard let txHash = String(data: data, encoding: .utf8) else {
            throw BitcoinIntegration.BitcoinError.broadcastFailed
        }

        return txHash
    }

    func fetchHistory(for address: String, limit: Int) async throws -> [String] {
        let url = URL(string: "\(baseURL)/address/\(address)/txs")!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct TxResponse: Codable {
            let txid: String
        }

        let transactions = try JSONDecoder().decode([TxResponse].self, from: data)
        return Array(transactions.prefix(limit).map { $0.txid })
    }

    func fetchTransaction(_ txHash: String) async throws -> BitcoinIntegration.BitcoinTransaction {
        let url = URL(string: "\(baseURL)/tx/\(txHash)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        // Parse transaction (simplified)
        // In production, implement full Bitcoin transaction parsing
        throw BitcoinIntegration.BitcoinError.networkError("Not implemented")
    }

    func estimateFee(priority: BitcoinIntegration.TransactionFee.Priority) async throws -> UInt64 {
        // Fetch current fee estimates
        let url = URL(string: "\(baseURL)/fee-estimates")!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct FeeEstimate: Codable {
            let fastestFee: Int
            let halfHourFee: Int
            let hourFee: Int
        }

        let estimate = try JSONDecoder().decode(FeeEstimate.self, from: data)

        switch priority {
        case .low:
            return UInt64(estimate.hourFee)
        case .medium:
            return UInt64(estimate.halfHourFee)
        case .high:
            return UInt64(estimate.fastestFee)
        case .custom(let rate):
            return rate
        }
    }
}

private class BitcoinAddressGenerator {
    let network: BitcoinIntegration.Network

    init(network: BitcoinIntegration.Network) {
        self.network = network
    }

    func generate(from publicKey: Data,
                 type: BitcoinIntegration.BitcoinAddress.AddressType) throws -> BitcoinIntegration.BitcoinAddress {
        let address: String

        switch type {
        case .legacy:
            address = try generateLegacyAddress(publicKey: publicKey)
        case .segwit:
            address = try generateSegWitAddress(publicKey: publicKey)
        case .nestedSegwit:
            address = try generateNestedSegWitAddress(publicKey: publicKey)
        }

        return BitcoinIntegration.BitcoinAddress(
            address: address,
            publicKey: publicKey,
            type: type
        )
    }

    func validate(_ address: String) -> Bool {
        return CryptoUtils.validateBitcoinAddress(address)
    }

    func createScriptPubKey(for address: String) throws -> Data {
        // Create scriptPubKey based on address type
        if address.starts(with: "bc1") || address.starts(with: "tb1") {
            // SegWit
            return try createSegWitScript(address: address)
        } else if address.starts(with: "1") || address.starts(with: "m") || address.starts(with: "n") {
            // Legacy P2PKH
            return try createP2PKHScript(address: address)
        } else if address.starts(with: "3") || address.starts(with: "2") {
            // P2SH
            return try createP2SHScript(address: address)
        }

        throw BitcoinIntegration.BitcoinError.invalidAddress
    }

    private func generateLegacyAddress(publicKey: Data) throws -> String {
        // P2PKH: OP_DUP OP_HASH160 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
        let pubKeyHash = CryptoUtils.hash160(publicKey)

        var versionedHash = Data()
        versionedHash.append(network == .mainnet ? 0x00 : 0x6F) // Version byte
        versionedHash.append(pubKeyHash)

        return CryptoUtils.base58CheckEncode(versionedHash)
    }

    private func generateSegWitAddress(publicKey: Data) throws -> String {
        // Bech32 encoding for native SegWit (P2WPKH)
        let pubKeyHash = CryptoUtils.hash160(publicKey)
        let hrp = network == .mainnet ? "bc" : "tb"

        return try Bech32.encodeSegWitAddress(
            hrp: hrp,
            witnessVersion: 0,
            witnessProgram: pubKeyHash
        )
    }

    private func generateNestedSegWitAddress(publicKey: Data) throws -> String {
        // P2SH-P2WPKH
        let pubKeyHash = CryptoUtils.hash160(publicKey)

        // Create witness script: OP_0 OP_PUSH20 <pubKeyHash>
        var witnessScript = Data([0x00, 0x14]) // OP_0 OP_PUSH20
        witnessScript.append(pubKeyHash)

        let scriptHash = CryptoUtils.hash160(witnessScript)

        var versionedHash = Data()
        versionedHash.append(network == .mainnet ? 0x05 : 0xC4) // P2SH version
        versionedHash.append(scriptHash)

        return CryptoUtils.base58CheckEncode(versionedHash)
    }

    private func createSegWitScript(address: String) throws -> Data {
        // Decode Bech32 address to get witness program
        let (_, witnessVersion, witnessProgram) = try Bech32.decodeSegWitAddress(address)

        // Create scriptPubKey: OP_0/OP_1/etc <witnessProgram>
        var script = Data()
        script.append(witnessVersion) // OP_0 for v0, OP_1 for v1, etc.
        script.append(UInt8(witnessProgram.count)) // Push data length
        script.append(witnessProgram)

        return script
    }

    private func createP2PKHScript(address: String) throws -> Data {
        // Decode Base58Check address to get pubKeyHash
        guard let decoded = CryptoUtils.base58CheckDecode(address) else {
            throw BitcoinIntegration.BitcoinError.invalidAddress
        }

        guard decoded.count == 21 else {
            throw BitcoinIntegration.BitcoinError.invalidAddress
        }

        let pubKeyHash = decoded.dropFirst() // Remove version byte

        // OP_DUP OP_HASH160 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
        var script = Data([0x76, 0xA9, 0x14]) // OP_DUP OP_HASH160 OP_PUSH20
        script.append(pubKeyHash)
        script.append(contentsOf: [0x88, 0xAC]) // OP_EQUALVERIFY OP_CHECKSIG

        return script
    }

    private func createP2SHScript(address: String) throws -> Data {
        // Decode Base58Check address to get scriptHash
        guard let decoded = CryptoUtils.base58CheckDecode(address) else {
            throw BitcoinIntegration.BitcoinError.invalidAddress
        }

        guard decoded.count == 21 else {
            throw BitcoinIntegration.BitcoinError.invalidAddress
        }

        let scriptHash = decoded.dropFirst() // Remove version byte

        // OP_HASH160 <scriptHash> OP_EQUAL
        var script = Data([0xA9, 0x14]) // OP_HASH160 OP_PUSH20
        script.append(scriptHash)
        script.append(0x87) // OP_EQUAL

        return script
    }
}

private class UTXOManager {
    let network: BitcoinIntegration.Network
    let networkManager: BitcoinNetworkManager

    init(network: BitcoinIntegration.Network) {
        self.network = network
        self.networkManager = BitcoinNetworkManager(network: network)
    }

    func fetchUTXOs(for address: String) async throws -> [BitcoinIntegration.UTXO] {
        let url = URL(string: "\(networkManager.baseURL)/address/\(address)/utxo")!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct UTXOResponse: Codable {
            let txid: String
            let vout: UInt32
            let value: UInt64
            let status: Status

            struct Status: Codable {
                let confirmed: Bool
                let block_height: Int?
            }
        }

        let utxoResponses = try JSONDecoder().decode([UTXOResponse].self, from: data)

        return utxoResponses.map { response in
            BitcoinIntegration.UTXO(
                txHash: Data(hex: response.txid) ?? Data(),
                outputIndex: response.vout,
                amount: response.value,
                script: Data(), // Would need to fetch from transaction
                confirmations: response.status.confirmed ? 6 : 0
            )
        }
    }
}

// MARK: - Data Extensions

private extension Data {
    var hexString: String {
        return CryptoUtils.hexEncode(self)
    }

    init?(hex: String) {
        guard let data = CryptoUtils.hexDecode(hex) else {
            return nil
        }
        self = data
    }
}
