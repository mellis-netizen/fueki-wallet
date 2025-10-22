//
//  PaymentQRBuilder.swift
//  FuekiWallet
//
//  Builder for creating payment URIs with validation
//

import Foundation

class PaymentQRBuilder {

    private var scheme: String = "bitcoin"
    private var address: String = ""
    private var amount: String?
    private var currency: String = "BTC"
    private var label: String?
    private var message: String?
    private var parameters: [String: String] = [:]

    // MARK: - Bitcoin Builder

    static func bitcoin(address: String) -> PaymentQRBuilder {
        let builder = PaymentQRBuilder()
        builder.scheme = "bitcoin"
        builder.address = address
        builder.currency = "BTC"
        return builder
    }

    // MARK: - Ethereum Builder

    static func ethereum(address: String) -> PaymentQRBuilder {
        let builder = PaymentQRBuilder()
        builder.scheme = "ethereum"
        builder.address = address
        builder.currency = "ETH"
        return builder
    }

    // MARK: - Configuration Methods

    func amount(_ amount: String) -> PaymentQRBuilder {
        self.amount = amount
        return self
    }

    func amount(_ amount: Decimal) -> PaymentQRBuilder {
        self.amount = "\(amount)"
        return self
    }

    func label(_ label: String) -> PaymentQRBuilder {
        self.label = label
        return self
    }

    func message(_ message: String) -> PaymentQRBuilder {
        self.message = message
        return self
    }

    func parameter(_ key: String, value: String) -> PaymentQRBuilder {
        parameters[key] = value
        return self
    }

    // Ethereum-specific
    func chainId(_ chainId: Int) -> PaymentQRBuilder {
        if scheme == "ethereum" {
            parameters["chainId"] = "\(chainId)"
        }
        return self
    }

    func gas(_ gas: String) -> PaymentQRBuilder {
        if scheme == "ethereum" {
            parameters["gas"] = gas
        }
        return self
    }

    func gasPrice(_ gasPrice: String) -> PaymentQRBuilder {
        if scheme == "ethereum" {
            parameters["gasPrice"] = gasPrice
        }
        return self
    }

    func data(_ data: String) -> PaymentQRBuilder {
        if scheme == "ethereum" {
            parameters["data"] = data
        }
        return self
    }

    // MARK: - Build

    func build() throws -> PaymentURI {
        // Validate address
        if scheme == "bitcoin" {
            guard AddressValidator.isValidBitcoinAddress(address) else {
                throw PaymentQRError.invalidAddress
            }
        } else if scheme == "ethereum" {
            guard AddressValidator.isValidEthereumAddress(address) else {
                throw PaymentQRError.invalidAddress
            }
        }

        // Validate amount if provided
        if let amount = amount {
            guard Decimal(string: amount) != nil else {
                throw PaymentQRError.invalidAmount
            }
        }

        return PaymentURI(
            scheme: scheme,
            address: address,
            amount: amount,
            currency: currency,
            label: label,
            message: message,
            parameters: parameters
        )
    }
}

// MARK: - Errors

enum PaymentQRError: Error, LocalizedError {
    case invalidAddress
    case invalidAmount
    case invalidScheme
    case missingRequiredField

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid cryptocurrency address"
        case .invalidAmount:
            return "Invalid amount format"
        case .invalidScheme:
            return "Unsupported payment scheme"
        case .missingRequiredField:
            return "Required field is missing"
        }
    }
}
