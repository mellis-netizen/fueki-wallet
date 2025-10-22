import Foundation

/// Bitcoin Transaction Signing Examples
/// Demonstrates how to create, sign, and verify Bitcoin transactions
/// Supports both SegWit (BIP 141/143) and legacy transactions

public class BitcoinTransactionExample {

    // MARK: - Example 1: Simple P2WPKH Transaction (Native SegWit)

    /// Create and sign a simple Bitcoin transaction spending from a P2WPKH address
    /// - Parameters:
    ///   - privateKey: 32-byte private key
    ///   - publicKey: 33-byte compressed public key
    ///   - fromTxHash: Previous transaction hash (32 bytes)
    ///   - fromOutputIndex: Output index in previous transaction
    ///   - fromAmount: Amount in satoshis from previous output
    ///   - toAddress: Recipient address (20-byte hash)
    ///   - sendAmount: Amount to send in satoshis
    ///   - feeAmount: Network fee in satoshis
    /// - Returns: Signed transaction ready for broadcast
    public static func createP2WPKHTransaction(
        privateKey: Data,
        publicKey: Data,
        fromTxHash: Data,
        fromOutputIndex: UInt32,
        fromAmount: UInt64,
        toAddress: Data,
        sendAmount: UInt64,
        feeAmount: UInt64
    ) throws -> TransactionSigner.SignedTransaction {

        // 1. Calculate change amount
        let changeAmount = fromAmount - sendAmount - feeAmount
        guard changeAmount >= 0 else {
            throw TransactionSigner.SigningError.invalidTransaction
        }

        // 2. Create output point (reference to UTXO we're spending)
        let outpoint = BitcoinTransactionBuilder.OutPoint(
            txHash: fromTxHash,
            index: fromOutputIndex
        )

        // 3. Calculate public key hash for input scriptPubKey
        let publicKeyHash = publicKey.hash160()
        let scriptPubKey = BitcoinTransactionBuilder.createP2WPKHScript(publicKeyHash: publicKeyHash)

        // 4. Create transaction input
        let input = BitcoinTransactionBuilder.TxInput(
            previousOutput: outpoint,
            scriptSig: Data(), // Empty for SegWit
            sequence: 0xFFFFFFFE, // Enable RBF
            amount: fromAmount,
            scriptPubKey: scriptPubKey
        )

        // 5. Create outputs
        // Output 1: Payment to recipient
        let recipientScriptPubKey = BitcoinTransactionBuilder.createP2WPKHScript(publicKeyHash: toAddress)
        let paymentOutput = BitcoinTransactionBuilder.TxOutput(
            amount: sendAmount,
            scriptPubKey: recipientScriptPubKey
        )

        // Output 2: Change back to sender
        let changeScriptPubKey = BitcoinTransactionBuilder.createP2WPKHScript(publicKeyHash: publicKeyHash)
        let changeOutput = BitcoinTransactionBuilder.TxOutput(
            amount: changeAmount,
            scriptPubKey: changeScriptPubKey
        )

        // 6. Build transaction
        let btcTransaction = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 2,
            inputs: [input],
            outputs: [paymentOutput, changeOutput],
            lockTime: 0,
            isSegWit: true
        )

        // 7. Create unsigned transaction wrapper
        let metadata: [String: Any] = [
            "bitcoinTransaction": btcTransaction,
            "inputIndex": 0,
            "amount": fromAmount,
            "scriptPubKey": scriptPubKey,
            "publicKey": publicKey,
            "sigHashType": BitcoinTransactionBuilder.SigHashType.all
        ]

        let unsignedTx = TransactionSigner.UnsignedTransaction(
            blockchain: .bitcoin,
            rawTransaction: Data(),
            metadata: metadata
        )

        // 8. Sign transaction
        let signer = TransactionSigner()
        let context = TransactionSigner.SigningContext(nonce: 0)

        let signedTx = try signer.signTransaction(
            unsignedTx,
            with: privateKey,
            context: context
        )

        // 9. Verify before broadcast
        let isValid = try signer.verifyBitcoinTransaction(signedTx, publicKey: publicKey)
        guard isValid else {
            throw TransactionSigner.SigningError.invalidSignature
        }

        print("✅ Transaction signed and verified!")
        print("TXID: \(signedTx.txHash.hexString)")
        print("Raw TX: \(signedTx.signedRawTransaction.hexString)")

        return signedTx
    }

    // MARK: - Example 2: Legacy P2PKH Transaction

    /// Create and sign a legacy Bitcoin transaction (pre-SegWit)
    public static func createLegacyP2PKHTransaction(
        privateKey: Data,
        publicKey: Data,
        fromTxHash: Data,
        fromOutputIndex: UInt32,
        fromAmount: UInt64,
        toAddress: Data,
        sendAmount: UInt64,
        feeAmount: UInt64
    ) throws -> TransactionSigner.SignedTransaction {

        let changeAmount = fromAmount - sendAmount - feeAmount

        let outpoint = BitcoinTransactionBuilder.OutPoint(
            txHash: fromTxHash,
            index: fromOutputIndex
        )

        let publicKeyHash = publicKey.hash160()
        let scriptPubKey = BitcoinTransactionBuilder.createP2PKHScript(publicKeyHash: publicKeyHash)

        let input = BitcoinTransactionBuilder.TxInput(
            previousOutput: outpoint,
            scriptSig: Data(), // Will be filled during signing
            sequence: 0xFFFFFFFF
        )

        let recipientScriptPubKey = BitcoinTransactionBuilder.createP2PKHScript(publicKeyHash: toAddress)
        let paymentOutput = BitcoinTransactionBuilder.TxOutput(
            amount: sendAmount,
            scriptPubKey: recipientScriptPubKey
        )

        let changeScriptPubKey = BitcoinTransactionBuilder.createP2PKHScript(publicKeyHash: publicKeyHash)
        let changeOutput = BitcoinTransactionBuilder.TxOutput(
            amount: changeAmount,
            scriptPubKey: changeScriptPubKey
        )

        let btcTransaction = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 1,
            inputs: [input],
            outputs: [paymentOutput, changeOutput],
            lockTime: 0,
            isSegWit: false // Legacy transaction
        )

        let metadata: [String: Any] = [
            "bitcoinTransaction": btcTransaction,
            "inputIndex": 0,
            "amount": fromAmount,
            "scriptPubKey": scriptPubKey,
            "publicKey": publicKey,
            "sigHashType": BitcoinTransactionBuilder.SigHashType.all
        ]

        let unsignedTx = TransactionSigner.UnsignedTransaction(
            blockchain: .bitcoin,
            rawTransaction: Data(),
            metadata: metadata
        )

        let signer = TransactionSigner()
        let context = TransactionSigner.SigningContext(nonce: 0)

        let signedTx = try signer.signTransaction(unsignedTx, with: privateKey, context: context)

        return signedTx
    }

    // MARK: - Example 3: Multiple Inputs (Consolidation)

    /// Consolidate multiple UTXOs into one output
    public static func createConsolidationTransaction(
        privateKey: Data,
        publicKey: Data,
        utxos: [(txHash: Data, index: UInt32, amount: UInt64, scriptPubKey: Data)],
        toAddress: Data,
        feeAmount: UInt64
    ) throws -> TransactionSigner.SignedTransaction {

        // 1. Calculate total input amount
        let totalInput = utxos.reduce(0) { $0 + $1.amount }
        let sendAmount = totalInput - feeAmount

        // 2. Create inputs for each UTXO
        var inputs: [BitcoinTransactionBuilder.TxInput] = []
        for utxo in utxos {
            let outpoint = BitcoinTransactionBuilder.OutPoint(
                txHash: utxo.txHash,
                index: utxo.index
            )
            let input = BitcoinTransactionBuilder.TxInput(
                previousOutput: outpoint,
                scriptSig: Data(),
                sequence: 0xFFFFFFFE,
                amount: utxo.amount,
                scriptPubKey: utxo.scriptPubKey
            )
            inputs.append(input)
        }

        // 3. Create single output
        let recipientScriptPubKey = BitcoinTransactionBuilder.createP2WPKHScript(publicKeyHash: toAddress)
        let output = BitcoinTransactionBuilder.TxOutput(
            amount: sendAmount,
            scriptPubKey: recipientScriptPubKey
        )

        // 4. Build transaction
        let btcTransaction = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 2,
            inputs: inputs,
            outputs: [output],
            lockTime: 0,
            isSegWit: true
        )

        // 5. Sign each input
        let signer = TransactionSigner()
        var signatures: [Data] = []

        for (index, utxo) in utxos.enumerated() {
            let metadata: [String: Any] = [
                "bitcoinTransaction": btcTransaction,
                "inputIndex": index,
                "amount": utxo.amount,
                "scriptPubKey": utxo.scriptPubKey,
                "publicKey": publicKey,
                "sigHashType": BitcoinTransactionBuilder.SigHashType.all
            ]

            let unsignedTx = TransactionSigner.UnsignedTransaction(
                blockchain: .bitcoin,
                rawTransaction: Data(),
                metadata: metadata
            )

            let context = TransactionSigner.SigningContext(nonce: 0)
            let signedTx = try signer.signTransaction(unsignedTx, with: privateKey, context: context)

            if let sig = signedTx.signatures.first {
                signatures.append(sig)
            }
        }

        print("✅ Consolidated \(utxos.count) UTXOs")

        // Return the last signed transaction (contains all signatures)
        let finalMetadata: [String: Any] = [
            "bitcoinTransaction": btcTransaction,
            "inputIndex": 0,
            "amount": utxos[0].amount,
            "scriptPubKey": utxos[0].scriptPubKey,
            "publicKey": publicKey
        ]

        let unsignedTx = TransactionSigner.UnsignedTransaction(
            blockchain: .bitcoin,
            rawTransaction: Data(),
            metadata: finalMetadata
        )

        let context = TransactionSigner.SigningContext(nonce: 0)
        return try signer.signTransaction(unsignedTx, with: privateKey, context: context)
    }

    // MARK: - Example 4: Different SIGHASH Types

    /// Demonstrate different SIGHASH types
    public static func demonstrateSigHashTypes() {
        print("📝 SIGHASH Type Examples:")
        print("")
        print("SIGHASH_ALL (0x01):")
        print("  - Signs all inputs and outputs")
        print("  - Most secure and common")
        print("  - Transaction cannot be modified")
        print("")
        print("SIGHASH_NONE (0x02):")
        print("  - Signs all inputs but no outputs")
        print("  - Allows outputs to be changed")
        print("  - Use case: Blank check")
        print("")
        print("SIGHASH_SINGLE (0x03):")
        print("  - Signs all inputs and one output at same index")
        print("  - Other outputs can be added")
        print("  - Use case: Partial payment")
        print("")
        print("SIGHASH_ANYONECANPAY (0x80):")
        print("  - Only signs one input")
        print("  - Can be combined with ALL/NONE/SINGLE")
        print("  - Use case: Crowdfunding, donations")
        print("")
    }

    // MARK: - Example 5: Transaction Verification

    /// Verify a Bitcoin transaction comprehensively
    public static func verifyTransaction(_ signedTx: TransactionSigner.SignedTransaction, publicKey: Data) {
        print("🔍 Verifying Bitcoin Transaction...")

        do {
            let signer = TransactionSigner()

            // 1. Verify signature
            let isValidSignature = try signer.verifySignature(signedTx, publicKey: publicKey)
            print("Signature Valid: \(isValidSignature ? "✅" : "❌")")

            // 2. Verify full transaction
            let isValidTransaction = try signer.verifyBitcoinTransaction(signedTx, publicKey: publicKey)
            print("Transaction Valid: \(isValidTransaction ? "✅" : "❌")")

            // 3. Check transaction size
            let txSize = signedTx.signedRawTransaction.count
            print("Transaction Size: \(txSize) bytes")

            // 4. Estimate fee rate
            if let btcTx = signedTx.unsignedTx.metadata["bitcoinTransaction"] as? BitcoinTransactionBuilder.BitcoinTransaction {
                let inputAmount = btcTx.inputs.compactMap { $0.amount }.reduce(0, +)
                let outputAmount = btcTx.outputs.map { $0.amount }.reduce(0, +)
                let fee = inputAmount - outputAmount
                let feeRate = Double(fee) / Double(txSize)
                print("Fee Rate: \(String(format: "%.2f", feeRate)) sat/byte")
            }

            // 5. Display TXID
            print("TXID: \(signedTx.txHash.hexString)")

        } catch {
            print("❌ Verification failed: \(error)")
        }
    }
}

// MARK: - Helper Extensions

fileprivate extension Data {
    var hexString: String {
        return self.map { String(format: "%02x", $0) }.joined()
    }

    func hash160() -> Data {
        return sha256().ripemd160()
    }

    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: 32)
        self.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }

    func ripemd160() -> Data {
        var hash = [UInt8](repeating: 0, count: 20)
        self.withUnsafeBytes { ptr in
            _ = CC_RIPEMD160(ptr.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}

import CommonCrypto
