import XCTest
@testable import FuekiWallet

/// Comprehensive tests for Bitcoin transaction signing and verification
/// Tests BIP 141/143 (SegWit), legacy signing, SIGHASH types, and DER encoding
class BitcoinTransactionSignerTests: XCTestCase {

    var signer: TransactionSigner!

    override func setUp() {
        super.setUp()
        signer = TransactionSigner()
    }

    override func tearDown() {
        signer = nil
        super.tearDown()
    }

    // MARK: - Transaction Serialization Tests

    func testBasicTransactionSerialization() {
        // Create a simple transaction
        let outpoint = BitcoinTransactionBuilder.OutPoint(
            txHash: Data(repeating: 0x01, count: 32),
            index: 0
        )

        let input = BitcoinTransactionBuilder.TxInput(
            previousOutput: outpoint,
            scriptSig: Data(),
            sequence: 0xFFFFFFFF
        )

        let output = BitcoinTransactionBuilder.TxOutput(
            amount: 50000,
            scriptPubKey: Data([0x76, 0xA9, 0x14]) + Data(repeating: 0x00, count: 20) + Data([0x88, 0xAC])
        )

        let tx = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 2,
            inputs: [input],
            outputs: [output],
            lockTime: 0,
            isSegWit: false
        )

        let serialized = BitcoinTransactionBuilder.serialize(tx, includeWitness: false)

        XCTAssertGreaterThan(serialized.count, 0, "Serialized transaction should not be empty")

        // Verify version is at the start
        let version = serialized.withUnsafeBytes { $0.load(as: Int32.self) }
        XCTAssertEqual(version, 2, "Version should be 2")
    }

    func testSegWitTransactionSerialization() {
        let outpoint = BitcoinTransactionBuilder.OutPoint(
            txHash: Data(repeating: 0x01, count: 32),
            index: 0
        )

        let publicKeyHash = Data(repeating: 0xAB, count: 20)
        let scriptPubKey = BitcoinTransactionBuilder.createP2WPKHScript(publicKeyHash: publicKeyHash)

        let input = BitcoinTransactionBuilder.TxInput(
            previousOutput: outpoint,
            scriptSig: Data(),
            sequence: 0xFFFFFFFE,
            amount: 100000,
            scriptPubKey: scriptPubKey
        )

        let output = BitcoinTransactionBuilder.TxOutput(
            amount: 90000,
            scriptPubKey: scriptPubKey
        )

        let tx = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 2,
            inputs: [input],
            outputs: [output],
            lockTime: 0,
            isSegWit: true
        )

        let serialized = BitcoinTransactionBuilder.serialize(tx, includeWitness: true)

        // Verify SegWit marker and flag
        XCTAssertEqual(serialized[4], 0x00, "SegWit marker should be 0x00")
        XCTAssertEqual(serialized[5], 0x01, "SegWit flag should be 0x01")
    }

    // MARK: - SIGHASH Computation Tests

    func testSegWitSigHashAll() throws {
        let publicKeyHash = Data(repeating: 0x12, count: 20)
        let scriptPubKey = BitcoinTransactionBuilder.createP2WPKHScript(publicKeyHash: publicKeyHash)

        let outpoint = BitcoinTransactionBuilder.OutPoint(
            txHash: Data(repeating: 0x01, count: 32),
            index: 0
        )

        let input = BitcoinTransactionBuilder.TxInput(
            previousOutput: outpoint,
            scriptSig: Data(),
            sequence: 0xFFFFFFFE,
            amount: 100000,
            scriptPubKey: scriptPubKey
        )

        let output = BitcoinTransactionBuilder.TxOutput(
            amount: 90000,
            scriptPubKey: scriptPubKey
        )

        let tx = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 2,
            inputs: [input],
            outputs: [output],
            lockTime: 0,
            isSegWit: true
        )

        // Compute SIGHASH for P2WPKH
        let scriptCode = BitcoinTransactionBuilder.createP2PKHScript(publicKeyHash: publicKeyHash)

        let sighash = try BitcoinTransactionBuilder.computeSegWitSigHash(
            tx: tx,
            inputIndex: 0,
            scriptCode: scriptCode,
            amount: 100000,
            sigHashType: .all
        )

        XCTAssertEqual(sighash.count, 32, "SIGHASH should be 32 bytes")
        XCTAssertNotEqual(sighash, Data(repeating: 0, count: 32), "SIGHASH should not be all zeros")
    }

    func testLegacySigHashAll() throws {
        let publicKeyHash = Data(repeating: 0x34, count: 20)
        let scriptPubKey = BitcoinTransactionBuilder.createP2PKHScript(publicKeyHash: publicKeyHash)

        let outpoint = BitcoinTransactionBuilder.OutPoint(
            txHash: Data(repeating: 0x02, count: 32),
            index: 1
        )

        let input = BitcoinTransactionBuilder.TxInput(
            previousOutput: outpoint,
            scriptSig: Data(),
            sequence: 0xFFFFFFFF
        )

        let output = BitcoinTransactionBuilder.TxOutput(
            amount: 50000,
            scriptPubKey: scriptPubKey
        )

        let tx = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 1,
            inputs: [input],
            outputs: [output],
            lockTime: 0,
            isSegWit: false
        )

        let sighash = try BitcoinTransactionBuilder.computeLegacySigHash(
            tx: tx,
            inputIndex: 0,
            scriptCode: scriptPubKey,
            sigHashType: .all
        )

        XCTAssertEqual(sighash.count, 32, "SIGHASH should be 32 bytes")
    }

    func testSigHashNone() throws {
        let publicKeyHash = Data(repeating: 0x56, count: 20)
        let scriptPubKey = BitcoinTransactionBuilder.createP2WPKHScript(publicKeyHash: publicKeyHash)

        let outpoint = BitcoinTransactionBuilder.OutPoint(
            txHash: Data(repeating: 0x03, count: 32),
            index: 0
        )

        let input = BitcoinTransactionBuilder.TxInput(
            previousOutput: outpoint,
            scriptSig: Data(),
            sequence: 0xFFFFFFFE,
            amount: 100000,
            scriptPubKey: scriptPubKey
        )

        let output = BitcoinTransactionBuilder.TxOutput(
            amount: 90000,
            scriptPubKey: scriptPubKey
        )

        let tx = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 2,
            inputs: [input],
            outputs: [output],
            lockTime: 0,
            isSegWit: true
        )

        let scriptCode = BitcoinTransactionBuilder.createP2PKHScript(publicKeyHash: publicKeyHash)

        let sighash = try BitcoinTransactionBuilder.computeSegWitSigHash(
            tx: tx,
            inputIndex: 0,
            scriptCode: scriptCode,
            amount: 100000,
            sigHashType: .none
        )

        XCTAssertEqual(sighash.count, 32, "SIGHASH_NONE should produce 32-byte hash")
    }

    // MARK: - Script Building Tests

    func testP2PKHScriptGeneration() {
        let publicKeyHash = Data(repeating: 0xAB, count: 20)
        let script = BitcoinTransactionBuilder.createP2PKHScript(publicKeyHash: publicKeyHash)

        // P2PKH: OP_DUP OP_HASH160 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
        XCTAssertEqual(script[0], 0x76, "First byte should be OP_DUP")
        XCTAssertEqual(script[1], 0xA9, "Second byte should be OP_HASH160")
        XCTAssertEqual(script[2], 0x14, "Third byte should be push 20 bytes")
        XCTAssertEqual(script[23], 0x88, "Should contain OP_EQUALVERIFY")
        XCTAssertEqual(script[24], 0xAC, "Should end with OP_CHECKSIG")
        XCTAssertEqual(script.count, 25, "P2PKH script should be 25 bytes")
    }

    func testP2WPKHScriptGeneration() {
        let publicKeyHash = Data(repeating: 0xCD, count: 20)
        let script = BitcoinTransactionBuilder.createP2WPKHScript(publicKeyHash: publicKeyHash)

        // P2WPKH: OP_0 <pubKeyHash>
        XCTAssertEqual(script[0], 0x00, "First byte should be OP_0")
        XCTAssertEqual(script[1], 0x14, "Second byte should be push 20 bytes")
        XCTAssertEqual(script.count, 22, "P2WPKH script should be 22 bytes")
    }

    func testP2SHScriptGeneration() {
        let scriptHash = Data(repeating: 0xEF, count: 20)
        let script = BitcoinTransactionBuilder.createP2SHScript(scriptHash: scriptHash)

        // P2SH: OP_HASH160 <scriptHash> OP_EQUAL
        XCTAssertEqual(script[0], 0xA9, "First byte should be OP_HASH160")
        XCTAssertEqual(script[1], 0x14, "Second byte should be push 20 bytes")
        XCTAssertEqual(script[22], 0x87, "Should end with OP_EQUAL")
        XCTAssertEqual(script.count, 23, "P2SH script should be 23 bytes")
    }

    func testP2WSHScriptGeneration() {
        let scriptHash = Data(repeating: 0x11, count: 32)
        let script = BitcoinTransactionBuilder.createP2WSHScript(scriptHash: scriptHash)

        // P2WSH: OP_0 <scriptHash>
        XCTAssertEqual(script[0], 0x00, "First byte should be OP_0")
        XCTAssertEqual(script[1], 0x20, "Second byte should be push 32 bytes")
        XCTAssertEqual(script.count, 34, "P2WSH script should be 34 bytes")
    }

    // MARK: - VarInt Serialization Tests

    func testVarIntEncoding() {
        // Test different ranges
        let small = BitcoinTransactionBuilder.serializeVarInt(0xFC)
        XCTAssertEqual(small.count, 1, "Small varint should be 1 byte")
        XCTAssertEqual(small[0], 0xFC, "Value should match")

        let medium = BitcoinTransactionBuilder.serializeVarInt(0xFD)
        XCTAssertEqual(medium.count, 3, "Medium varint should be 3 bytes")
        XCTAssertEqual(medium[0], 0xFD, "First byte should be 0xFD marker")

        let large = BitcoinTransactionBuilder.serializeVarInt(0x10000)
        XCTAssertEqual(large.count, 5, "Large varint should be 5 bytes")
        XCTAssertEqual(large[0], 0xFE, "First byte should be 0xFE marker")

        let veryLarge = BitcoinTransactionBuilder.serializeVarInt(0x100000000)
        XCTAssertEqual(veryLarge.count, 9, "Very large varint should be 9 bytes")
        XCTAssertEqual(veryLarge[0], 0xFF, "First byte should be 0xFF marker")
    }

    // MARK: - DER Signature Encoding Tests

    func testDEREncoding() throws {
        // Create test signature (64 bytes: r || s)
        let r = Data(repeating: 0x12, count: 32)
        let s = Data(repeating: 0x34, count: 32)
        var signature = Data()
        signature.append(r)
        signature.append(s)

        let derSignature = try Secp256k1Bridge.signatureToDER(signature)

        // DER signature format: 0x30 [total-length] 0x02 [r-length] [r] 0x02 [s-length] [s]
        XCTAssertEqual(derSignature[0], 0x30, "DER should start with 0x30")
        XCTAssertGreaterThan(derSignature.count, 64, "DER encoding should be larger than raw")
        XCTAssertLessThanOrEqual(derSignature.count, 72, "DER should not exceed 72 bytes")

        // Test round-trip
        let decoded = try Secp256k1Bridge.signatureFromDER(derSignature)
        XCTAssertEqual(decoded.count, 64, "Decoded signature should be 64 bytes")
    }

    // MARK: - Transaction ID Calculation Tests

    func testTxIdCalculation() {
        let outpoint = BitcoinTransactionBuilder.OutPoint(
            txHash: Data(repeating: 0x01, count: 32),
            index: 0
        )

        let input = BitcoinTransactionBuilder.TxInput(
            previousOutput: outpoint,
            scriptSig: Data([0x00]),
            sequence: 0xFFFFFFFF
        )

        let output = BitcoinTransactionBuilder.TxOutput(
            amount: 50000,
            scriptPubKey: Data([0x76, 0xA9, 0x14]) + Data(repeating: 0x00, count: 20) + Data([0x88, 0xAC])
        )

        let tx = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 2,
            inputs: [input],
            outputs: [output],
            lockTime: 0,
            isSegWit: false
        )

        let txid = BitcoinTransactionBuilder.calculateTxId(tx)

        XCTAssertEqual(txid.count, 32, "TXID should be 32 bytes")
        XCTAssertNotEqual(txid, Data(repeating: 0, count: 32), "TXID should not be all zeros")
    }

    // MARK: - Full Transaction Signing Tests

    func testSegWitTransactionSigning() throws {
        // Generate test private key
        let privateKey = Data(repeating: 0x01, count: 32)

        // Derive public key
        let publicKey = try Secp256k1Bridge.derivePublicKey(from: privateKey, compressed: true)
        let publicKeyHash = publicKey.dropFirst().hash160() // Remove 0x02/0x03 prefix

        // Create transaction
        let outpoint = BitcoinTransactionBuilder.OutPoint(
            txHash: Data(repeating: 0xAA, count: 32),
            index: 0
        )

        let scriptPubKey = BitcoinTransactionBuilder.createP2WPKHScript(publicKeyHash: publicKeyHash)

        let input = BitcoinTransactionBuilder.TxInput(
            previousOutput: outpoint,
            scriptSig: Data(),
            sequence: 0xFFFFFFFE,
            amount: 100000,
            scriptPubKey: scriptPubKey
        )

        let output = BitcoinTransactionBuilder.TxOutput(
            amount: 90000,
            scriptPubKey: scriptPubKey
        )

        let btcTx = BitcoinTransactionBuilder.BitcoinTransaction(
            version: 2,
            inputs: [input],
            outputs: [output],
            lockTime: 0,
            isSegWit: true
        )

        let metadata: [String: Any] = [
            "bitcoinTransaction": btcTx,
            "inputIndex": 0,
            "amount": UInt64(100000),
            "scriptPubKey": scriptPubKey,
            "publicKey": publicKey,
            "sigHashType": BitcoinTransactionBuilder.SigHashType.all
        ]

        let unsignedTx = TransactionSigner.UnsignedTransaction(
            blockchain: .bitcoin,
            rawTransaction: Data(),
            metadata: metadata
        )

        let context = TransactionSigner.SigningContext(nonce: 0)

        // Sign transaction
        let signedTx = try signer.signTransaction(unsignedTx, with: privateKey, context: context)

        XCTAssertNotNil(signedTx, "Signed transaction should not be nil")
        XCTAssertFalse(signedTx.signatures.isEmpty, "Should have at least one signature")
        XCTAssertGreaterThan(signedTx.signedRawTransaction.count, 0, "Signed raw transaction should not be empty")

        // Verify transaction
        let isValid = try signer.verifyBitcoinTransaction(signedTx, publicKey: publicKey)
        XCTAssertTrue(isValid, "Transaction should be valid")
    }

    // MARK: - Performance Tests

    func testSigningPerformance() throws {
        let privateKey = Data(repeating: 0x02, count: 32)
        let publicKey = try Secp256k1Bridge.derivePublicKey(from: privateKey, compressed: true)

        measure {
            do {
                let messageHash = Data(repeating: 0xFF, count: 32)
                _ = try Secp256k1Bridge.sign(messageHash: messageHash, privateKey: privateKey)
            } catch {
                XCTFail("Signing should not throw: \(error)")
            }
        }
    }

    func testVerificationPerformance() throws {
        let privateKey = Data(repeating: 0x03, count: 32)
        let publicKey = try Secp256k1Bridge.derivePublicKey(from: privateKey, compressed: true)
        let messageHash = Data(repeating: 0xEE, count: 32)
        let signature = try Secp256k1Bridge.sign(messageHash: messageHash, privateKey: privateKey)

        measure {
            do {
                _ = try Secp256k1Bridge.verify(signature: signature, messageHash: messageHash, publicKey: publicKey)
            } catch {
                XCTFail("Verification should not throw: \(error)")
            }
        }
    }
}

// MARK: - Helper Extensions

fileprivate extension Data {
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
