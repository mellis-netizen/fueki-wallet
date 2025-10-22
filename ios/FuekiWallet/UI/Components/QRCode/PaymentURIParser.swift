//
//  PaymentURIParser.swift
//  FuekiWallet
//
//  Payment URI parser supporting BIP-21 (Bitcoin) and EIP-681 (Ethereum)
//

import Foundation

struct PaymentURI {
    let scheme: String
    let address: String
    let amount: String?
    let currency: String
    let label: String?
    let message: String?
    let parameters: [String: String]

    func toString() -> String {
        var uri = "\(scheme):\(address)"
        var params: [String] = []

        if let amount = amount {
            params.append("amount=\(amount)")
        }

        if let label = label?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            params.append("label=\(label)")
        }

        if let message = message?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            params.append("message=\(message)")
        }

        for (key, value) in parameters {
            if let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                params.append("\(key)=\(encodedValue)")
            }
        }

        if !params.isEmpty {
            uri += "?" + params.joined(separator: "&")
        }

        return uri
    }
}

class PaymentURIParser {

    // MARK: - Main Parser

    static func parse(_ uriString: String) -> PaymentURI? {
        let trimmed = uriString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for Bitcoin URI (BIP-21)
        if trimmed.lowercased().hasPrefix("bitcoin:") {
            return parseBitcoinURI(trimmed)
        }

        // Check for Ethereum URI (EIP-681)
        if trimmed.lowercased().hasPrefix("ethereum:") {
            return parseEthereumURI(trimmed)
        }

        // Try to validate as plain address
        if let plainAddress = validatePlainAddress(trimmed) {
            return plainAddress
        }

        return nil
    }

    // MARK: - BIP-21 (Bitcoin)

    private static func parseBitcoinURI(_ uri: String) -> PaymentURI? {
        // Format: bitcoin:<address>[?amount=<amount>][&label=<label>][&message=<message>]

        guard let components = URLComponents(string: uri) else {
            return nil
        }

        let address = components.path
        guard AddressValidator.isValidBitcoinAddress(address) else {
            return nil
        }

        var amount: String?
        var label: String?
        var message: String?
        var otherParams: [String: String] = [:]

        if let queryItems = components.queryItems {
            for item in queryItems {
                switch item.name.lowercased() {
                case "amount":
                    amount = item.value
                case "label":
                    label = item.value
                case "message":
                    message = item.value
                default:
                    if let value = item.value {
                        otherParams[item.name] = value
                    }
                }
            }
        }

        return PaymentURI(
            scheme: "bitcoin",
            address: address,
            amount: amount,
            currency: "BTC",
            label: label,
            message: message,
            parameters: otherParams
        )
    }

    // MARK: - EIP-681 (Ethereum)

    private static func parseEthereumURI(_ uri: String) -> PaymentURI? {
        // Format: ethereum:<address>[@<chainId>][?value=<value>][&gas=<gas>][&data=<data>]

        guard let components = URLComponents(string: uri) else {
            return nil
        }

        var pathComponents = components.path.components(separatedBy: "@")
        let address = pathComponents[0]

        guard AddressValidator.isValidEthereumAddress(address) else {
            return nil
        }

        var amount: String?
        var chainId: String?
        var otherParams: [String: String] = [:]

        if pathComponents.count > 1 {
            chainId = pathComponents[1]
        }

        if let queryItems = components.queryItems {
            for item in queryItems {
                switch item.name.lowercased() {
                case "value":
                    // Convert wei to ether
                    if let weiValue = item.value,
                       let wei = Decimal(string: weiValue) {
                        let ether = wei / Decimal(string: "1000000000000000000")!
                        amount = "\(ether)"
                    }
                case "gas", "gasLimit", "gasPrice", "data", "function":
                    if let value = item.value {
                        otherParams[item.name] = value
                    }
                default:
                    if let value = item.value {
                        otherParams[item.name] = value
                    }
                }
            }
        }

        if let chainId = chainId {
            otherParams["chainId"] = chainId
        }

        return PaymentURI(
            scheme: "ethereum",
            address: address,
            amount: amount,
            currency: "ETH",
            label: nil,
            message: nil,
            parameters: otherParams
        )
    }

    // MARK: - Plain Address Validation

    private static func validatePlainAddress(_ address: String) -> PaymentURI? {
        if AddressValidator.isValidBitcoinAddress(address) {
            return PaymentURI(
                scheme: "bitcoin",
                address: address,
                amount: nil,
                currency: "BTC",
                label: nil,
                message: nil,
                parameters: [:]
            )
        }

        if AddressValidator.isValidEthereumAddress(address) {
            return PaymentURI(
                scheme: "ethereum",
                address: address,
                amount: nil,
                currency: "ETH",
                label: nil,
                message: nil,
                parameters: [:]
            )
        }

        return nil
    }
}

// MARK: - Address Validator

class AddressValidator {

    static func isValidBitcoinAddress(_ address: String) -> Bool {
        // Bitcoin addresses can be:
        // - Legacy (P2PKH): starts with 1, 26-35 characters
        // - Script (P2SH): starts with 3, 26-35 characters
        // - SegWit (Bech32): starts with bc1, 42-62 characters

        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)

        // Legacy P2PKH
        if trimmed.hasPrefix("1") {
            return trimmed.count >= 26 && trimmed.count <= 35 && isBase58(trimmed)
        }

        // Script P2SH
        if trimmed.hasPrefix("3") {
            return trimmed.count >= 26 && trimmed.count <= 35 && isBase58(trimmed)
        }

        // SegWit Bech32
        if trimmed.lowercased().hasPrefix("bc1") {
            return trimmed.count >= 42 && trimmed.count <= 62 && isBech32(trimmed)
        }

        // Testnet addresses
        if trimmed.hasPrefix("m") || trimmed.hasPrefix("n") || trimmed.hasPrefix("2") {
            return trimmed.count >= 26 && trimmed.count <= 35 && isBase58(trimmed)
        }

        if trimmed.lowercased().hasPrefix("tb1") {
            return trimmed.count >= 42 && trimmed.count <= 62 && isBech32(trimmed)
        }

        return false
    }

    static func isValidEthereumAddress(_ address: String) -> Bool {
        // Ethereum addresses: 0x followed by 40 hexadecimal characters
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") else {
            return false
        }

        let hex = String(trimmed.dropFirst(2))
        guard hex.count == 40 else {
            return false
        }

        return hex.allSatisfy { $0.isHexDigit }
    }

    private static func isBase58(_ string: String) -> Bool {
        let base58Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        return string.allSatisfy { base58Alphabet.contains($0) }
    }

    private static func isBech32(_ string: String) -> Bool {
        let bech32Alphabet = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
        let lowercased = string.lowercased()

        // Split at last '1'
        guard let separatorIndex = lowercased.lastIndex(of: "1") else {
            return false
        }

        let data = lowercased[lowercased.index(after: separatorIndex)...]
        return data.allSatisfy { bech32Alphabet.contains($0) }
    }
}
