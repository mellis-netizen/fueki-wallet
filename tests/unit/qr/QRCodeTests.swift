//
//  QRCodeTests.swift
//  FuekiWalletTests
//
//  Comprehensive tests for QR code scanning and generation
//

import XCTest
@testable import FuekiWallet

class QRCodeTests: XCTestCase {

    // MARK: - Address Validation Tests

    func testValidBitcoinLegacyAddress() {
        let address = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
        XCTAssertTrue(AddressValidator.isValidBitcoinAddress(address))
    }

    func testValidBitcoinP2SHAddress() {
        let address = "3J98t1WpEZ73CNmYviecrnyiWrnqRhWNLy"
        XCTAssertTrue(AddressValidator.isValidBitcoinAddress(address))
    }

    func testValidBitcoinSegWitAddress() {
        let address = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
        XCTAssertTrue(AddressValidator.isValidBitcoinAddress(address))
    }

    func testValidBitcoinTestnetAddress() {
        let addresses = [
            "mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn",
            "2MzQwSSnBHWHqSAqtTVQ6v47XtaisrJa1Vc",
            "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"
        ]

        for address in addresses {
            XCTAssertTrue(AddressValidator.isValidBitcoinAddress(address))
        }
    }

    func testInvalidBitcoinAddress() {
        let invalidAddresses = [
            "1234567890",
            "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            "notanaddress",
            "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfN", // Too short
            "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4extra" // Too long
        ]

        for address in invalidAddresses {
            XCTAssertFalse(AddressValidator.isValidBitcoinAddress(address))
        }
    }

    func testValidEthereumAddress() {
        let addresses = [
            "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            "0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359"
        ]

        for address in addresses {
            XCTAssertTrue(AddressValidator.isValidEthereumAddress(address))
        }
    }

    func testInvalidEthereumAddress() {
        let invalidAddresses = [
            "742d35Cc6634C0532925a3b844Bc9e7595f0bEb", // Missing 0x
            "0x742d35Cc6634C0532925a3b844Bc9e7595f0bE", // Too short
            "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEbbb", // Too long
            "0xGGGG35Cc6634C0532925a3b844Bc9e7595f0bEb" // Invalid hex
        ]

        for address in invalidAddresses {
            XCTAssertFalse(AddressValidator.isValidEthereumAddress(address))
        }
    }

    // MARK: - BIP-21 Parsing Tests

    func testParseBitcoinURIWithAddress() {
        let uri = "bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
        let parsed = PaymentURIParser.parse(uri)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.scheme, "bitcoin")
        XCTAssertEqual(parsed?.address, "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
        XCTAssertEqual(parsed?.currency, "BTC")
        XCTAssertNil(parsed?.amount)
    }

    func testParseBitcoinURIWithAmount() {
        let uri = "bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa?amount=0.5"
        let parsed = PaymentURIParser.parse(uri)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.address, "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
        XCTAssertEqual(parsed?.amount, "0.5")
    }

    func testParseBitcoinURIWithAllParameters() {
        let uri = "bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa?amount=0.5&label=Satoshi&message=Payment%20for%20services"
        let parsed = PaymentURIParser.parse(uri)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.address, "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
        XCTAssertEqual(parsed?.amount, "0.5")
        XCTAssertEqual(parsed?.label, "Satoshi")
        XCTAssertEqual(parsed?.message, "Payment for services")
    }

    // MARK: - EIP-681 Parsing Tests

    func testParseEthereumURIWithAddress() {
        let uri = "ethereum:0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let parsed = PaymentURIParser.parse(uri)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.scheme, "ethereum")
        XCTAssertEqual(parsed?.address, "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
        XCTAssertEqual(parsed?.currency, "ETH")
    }

    func testParseEthereumURIWithChainId() {
        let uri = "ethereum:0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb@1"
        let parsed = PaymentURIParser.parse(uri)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.address, "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
        XCTAssertEqual(parsed?.parameters["chainId"], "1")
    }

    func testParseEthereumURIWithValue() {
        let uri = "ethereum:0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb?value=1000000000000000000"
        let parsed = PaymentURIParser.parse(uri)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.address, "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
        XCTAssertNotNil(parsed?.amount)
    }

    // MARK: - Plain Address Parsing Tests

    func testParsePlainBitcoinAddress() {
        let address = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
        let parsed = PaymentURIParser.parse(address)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.scheme, "bitcoin")
        XCTAssertEqual(parsed?.address, address)
    }

    func testParsePlainEthereumAddress() {
        let address = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let parsed = PaymentURIParser.parse(address)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.scheme, "ethereum")
        XCTAssertEqual(parsed?.address, address)
    }

    // MARK: - Payment URI Builder Tests

    func testBuildBitcoinPaymentURI() throws {
        let uri = try PaymentQRBuilder
            .bitcoin(address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
            .amount("0.5")
            .label("Test Payment")
            .message("Test message")
            .build()

        XCTAssertEqual(uri.scheme, "bitcoin")
        XCTAssertEqual(uri.address, "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
        XCTAssertEqual(uri.amount, "0.5")
        XCTAssertEqual(uri.label, "Test Payment")
        XCTAssertEqual(uri.message, "Test message")
    }

    func testBuildEthereumPaymentURI() throws {
        let uri = try PaymentQRBuilder
            .ethereum(address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
            .amount("1.5")
            .chainId(1)
            .gas("21000")
            .build()

        XCTAssertEqual(uri.scheme, "ethereum")
        XCTAssertEqual(uri.address, "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
        XCTAssertEqual(uri.amount, "1.5")
        XCTAssertEqual(uri.parameters["chainId"], "1")
        XCTAssertEqual(uri.parameters["gas"], "21000")
    }

    func testBuildInvalidAddressThrowsError() {
        XCTAssertThrowsError(try PaymentQRBuilder
            .bitcoin(address: "invalid_address")
            .build()
        ) { error in
            XCTAssertTrue(error is PaymentQRError)
            XCTAssertEqual(error as? PaymentQRError, .invalidAddress)
        }
    }

    func testBuildInvalidAmountThrowsError() {
        XCTAssertThrowsError(try PaymentQRBuilder
            .bitcoin(address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
            .amount("invalid")
            .build()
        ) { error in
            XCTAssertTrue(error is PaymentQRError)
            XCTAssertEqual(error as? PaymentQRError, .invalidAmount)
        }
    }

    // MARK: - URI String Generation Tests

    func testGenerateBitcoinURIString() throws {
        let uri = try PaymentQRBuilder
            .bitcoin(address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
            .amount("0.5")
            .label("Satoshi")
            .build()

        let uriString = uri.toString()
        XCTAssertTrue(uriString.hasPrefix("bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"))
        XCTAssertTrue(uriString.contains("amount=0.5"))
        XCTAssertTrue(uriString.contains("label=Satoshi"))
    }

    func testGenerateEthereumURIString() throws {
        let uri = try PaymentQRBuilder
            .ethereum(address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
            .amount("1.0")
            .chainId(1)
            .build()

        let uriString = uri.toString()
        XCTAssertTrue(uriString.hasPrefix("ethereum:0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"))
        XCTAssertTrue(uriString.contains("amount=1.0"))
    }

    // MARK: - Round-trip Tests

    func testBitcoinURIRoundTrip() throws {
        let original = try PaymentQRBuilder
            .bitcoin(address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
            .amount("0.5")
            .label("Test")
            .build()

        let uriString = original.toString()
        let parsed = PaymentURIParser.parse(uriString)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.address, original.address)
        XCTAssertEqual(parsed?.amount, original.amount)
        XCTAssertEqual(parsed?.label, original.label)
    }

    func testEthereumURIRoundTrip() throws {
        let original = try PaymentQRBuilder
            .ethereum(address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
            .amount("1.5")
            .chainId(1)
            .build()

        let uriString = original.toString()
        let parsed = PaymentURIParser.parse(uriString)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.address, original.address)
    }
}
