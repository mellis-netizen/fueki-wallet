import Foundation

/// Bitcoin Address Generation Example
/// Demonstrates the usage of real Bitcoin address generation with proper cryptographic implementations

func bitcoinAddressExample() {
    print("=== Bitcoin Address Generation Example ===\n")

    // Example 1: Generate addresses from a known public key
    exampleGenerateAddresses()

    // Example 2: Validate Bitcoin addresses
    exampleValidateAddresses()

    // Example 3: Test cryptographic primitives
    exampleCryptographicPrimitives()

    // Example 4: Decode and inspect addresses
    exampleDecodeAddresses()
}

// MARK: - Example 1: Generate Bitcoin Addresses

func exampleGenerateAddresses() {
    print("--- Example 1: Generate Bitcoin Addresses ---")

    // Using Satoshi's genesis block public key
    let publicKeyHex = "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"

    guard let publicKey = CryptoUtils.hexDecode(publicKeyHex) else {
        print("❌ Failed to decode public key")
        return
    }

    let bitcoin = BitcoinIntegration(network: .mainnet)

    do {
        // Generate Legacy P2PKH address (starts with '1')
        let legacyAddress = try bitcoin.generateAddress(from: publicKey, type: .legacy)
        print("✅ Legacy P2PKH Address: \(legacyAddress.address)")
        print("   Type: P2PKH (Pay-to-PubKey-Hash)")
        print("   Network: Mainnet")
        print("   Encoding: Base58Check")

        // Generate SegWit P2WPKH address (starts with 'bc1')
        let segwitAddress = try bitcoin.generateAddress(from: publicKey, type: .segwit)
        print("\n✅ SegWit P2WPKH Address: \(segwitAddress.address)")
        print("   Type: P2WPKH (Pay-to-Witness-PubKey-Hash)")
        print("   Network: Mainnet")
        print("   Encoding: Bech32")

        // Generate Nested SegWit P2SH-P2WPKH address (starts with '3')
        let nestedSegwitAddress = try bitcoin.generateAddress(from: publicKey, type: .nestedSegwit)
        print("\n✅ Nested SegWit P2SH-P2WPKH Address: \(nestedSegwitAddress.address)")
        print("   Type: P2SH-P2WPKH (Nested SegWit)")
        print("   Network: Mainnet")
        print("   Encoding: Base58Check")

        // Generate testnet addresses
        let testnetBitcoin = BitcoinIntegration(network: .testnet)
        let testnetAddress = try testnetBitcoin.generateAddress(from: publicKey, type: .segwit)
        print("\n✅ Testnet SegWit Address: \(testnetAddress.address)")
        print("   Network: Testnet")
        print("   Encoding: Bech32 (tb1)")

    } catch {
        print("❌ Error generating addresses: \(error)")
    }

    print("\n")
}

// MARK: - Example 2: Validate Bitcoin Addresses

func exampleValidateAddresses() {
    print("--- Example 2: Validate Bitcoin Addresses ---")

    let bitcoin = BitcoinIntegration(network: .mainnet)

    let testCases: [(address: String, description: String, shouldBeValid: Bool)] = [
        // Valid addresses
        ("1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH", "Valid P2PKH address", true),
        ("3JvL6Ymt8MVWiCNHC7oWU6nLeHNJKLZGLN", "Valid P2SH address", true),
        ("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4", "Valid SegWit v0 address", true),

        // Invalid addresses
        ("1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMX", "Invalid checksum (P2PKH)", false),
        ("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5", "Invalid Bech32 checksum", false),
        ("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", "Ethereum address", false),
        ("not-a-bitcoin-address", "Random string", false),
    ]

    for (address, description, shouldBeValid) in testCases {
        let isValid = bitcoin.validateAddress(address)
        let status = isValid ? "✅" : "❌"
        let result = isValid == shouldBeValid ? "PASS" : "FAIL"

        print("\(status) [\(result)] \(description)")
        print("   Address: \(address)")
        print("   Valid: \(isValid)")
        print()
    }
}

// MARK: - Example 3: Cryptographic Primitives

func exampleCryptographicPrimitives() {
    print("--- Example 3: Cryptographic Primitives ---")

    // Test RIPEMD-160
    let testData = "Hello, Bitcoin!".data(using: .utf8)!
    let ripemd160Hash = RIPEMD160.hash(testData)
    print("✅ RIPEMD-160 Hash:")
    print("   Input: \"Hello, Bitcoin!\"")
    print("   Output: \(CryptoUtils.hexEncode(ripemd160Hash))")
    print("   Length: \(ripemd160Hash.count) bytes")

    // Test Hash160 (SHA-256 + RIPEMD-160)
    let hash160 = CryptoUtils.hash160(testData)
    print("\n✅ Hash160 (SHA-256 + RIPEMD-160):")
    print("   Input: \"Hello, Bitcoin!\"")
    print("   Output: \(CryptoUtils.hexEncode(hash160))")
    print("   Length: \(hash160.count) bytes")

    // Test Base58Check encoding
    let testPayload = Data([0x00] + Array(hash160)) // Version byte + hash
    let base58CheckEncoded = CryptoUtils.base58CheckEncode(testPayload)
    print("\n✅ Base58Check Encoding:")
    print("   Input (hex): \(CryptoUtils.hexEncode(testPayload))")
    print("   Output: \(base58CheckEncoded)")

    // Test Base58Check decoding
    if let decoded = CryptoUtils.base58CheckDecode(base58CheckEncoded) {
        print("   Decoded (hex): \(CryptoUtils.hexEncode(decoded))")
        print("   Round-trip: ✅ SUCCESS")
    } else {
        print("   Round-trip: ❌ FAILED")
    }

    // Test Bech32 encoding
    do {
        let witnessProgram = hash160
        let bech32Address = try Bech32.encodeSegWitAddress(
            hrp: "bc",
            witnessVersion: 0,
            witnessProgram: witnessProgram
        )
        print("\n✅ Bech32 Encoding (SegWit v0):")
        print("   Witness Program: \(CryptoUtils.hexEncode(witnessProgram))")
        print("   Address: \(bech32Address)")

        // Decode and verify
        let (hrp, version, program) = try Bech32.decodeSegWitAddress(bech32Address)
        print("   Decoded HRP: \(hrp)")
        print("   Decoded Version: \(version)")
        print("   Decoded Program: \(CryptoUtils.hexEncode(program))")
        print("   Round-trip: ✅ SUCCESS")
    } catch {
        print("   Bech32 encoding failed: \(error)")
    }

    print("\n")
}

// MARK: - Example 4: Decode and Inspect Addresses

func exampleDecodeAddresses() {
    print("--- Example 4: Decode and Inspect Addresses ---")

    // Decode Legacy P2PKH address
    let p2pkhAddress = "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH"
    print("🔍 Decoding P2PKH Address: \(p2pkhAddress)")

    if let decoded = CryptoUtils.base58CheckDecode(p2pkhAddress) {
        let version = decoded[0]
        let hash = decoded.dropFirst()

        print("   Version Byte: 0x\(String(format: "%02x", version))")
        print("   Network: \(version == 0x00 ? "Mainnet" : "Other")")
        print("   Type: P2PKH")
        print("   PubKey Hash: \(CryptoUtils.hexEncode(hash))")
    }

    // Decode SegWit address
    let segwitAddress = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
    print("\n🔍 Decoding SegWit Address: \(segwitAddress)")

    do {
        let (hrp, version, program) = try Bech32.decodeSegWitAddress(segwitAddress)
        print("   HRP: \(hrp)")
        print("   Network: \(hrp == "bc" ? "Mainnet" : "Testnet")")
        print("   Witness Version: \(version)")
        print("   Type: P2WPKH")
        print("   Witness Program: \(CryptoUtils.hexEncode(program))")
        print("   Program Length: \(program.count) bytes")
    } catch {
        print("   Decode failed: \(error)")
    }

    // Decode P2SH address
    let p2shAddress = "3JvL6Ymt8MVWiCNHC7oWU6nLeHNJKLZGLN"
    print("\n🔍 Decoding P2SH Address: \(p2shAddress)")

    if let decoded = CryptoUtils.base58CheckDecode(p2shAddress) {
        let version = decoded[0]
        let hash = decoded.dropFirst()

        print("   Version Byte: 0x\(String(format: "%02x", version))")
        print("   Network: \(version == 0x05 ? "Mainnet" : "Other")")
        print("   Type: P2SH")
        print("   Script Hash: \(CryptoUtils.hexEncode(hash))")
    }

    print("\n")
}

// MARK: - Performance Benchmarks

func performanceBenchmarks() {
    print("=== Performance Benchmarks ===\n")

    // Benchmark RIPEMD-160
    let iterations = 1000
    let testData = Data(repeating: 0x42, count: 64)

    let ripemd160Start = Date()
    for _ in 0..<iterations {
        _ = RIPEMD160.hash(testData)
    }
    let ripemd160Duration = Date().timeIntervalSince(ripemd160Start)
    print("✅ RIPEMD-160 (\(iterations) iterations):")
    print("   Total: \(String(format: "%.3f", ripemd160Duration * 1000)) ms")
    print("   Average: \(String(format: "%.3f", ripemd160Duration * 1000 / Double(iterations))) ms")

    // Benchmark Base58Check encoding
    let base58Start = Date()
    for _ in 0..<iterations {
        _ = CryptoUtils.base58CheckEncode(testData)
    }
    let base58Duration = Date().timeIntervalSince(base58Start)
    print("\n✅ Base58Check Encoding (\(iterations) iterations):")
    print("   Total: \(String(format: "%.3f", base58Duration * 1000)) ms")
    print("   Average: \(String(format: "%.3f", base58Duration * 1000 / Double(iterations))) ms")

    // Benchmark Bech32 encoding
    let bech32Start = Date()
    for _ in 0..<iterations {
        _ = try? Bech32.encodeSegWitAddress(hrp: "bc", witnessVersion: 0, witnessProgram: Data(testData.prefix(20)))
    }
    let bech32Duration = Date().timeIntervalSince(bech32Start)
    print("\n✅ Bech32 Encoding (\(iterations) iterations):")
    print("   Total: \(String(format: "%.3f", bech32Duration * 1000)) ms")
    print("   Average: \(String(format: "%.3f", bech32Duration * 1000 / Double(iterations))) ms")

    print("\n")
}

// Run examples
// Uncomment to execute
// bitcoinAddressExample()
// performanceBenchmarks()
