//
//  RPCRequest.swift
//  FuekiWallet
//
//  Created by Backend API Developer
//

import Foundation

/// JSON-RPC 2.0 request structure
public struct RPCRequest<Params: Encodable>: Encodable {
    public let jsonrpc: String = "2.0"
    public let id: Int
    public let method: String
    public let params: Params

    public init(id: Int, method: String, params: Params) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 response structure
public struct RPCResponse<Result: Decodable>: Decodable {
    public let jsonrpc: String
    public let id: Int
    public let result: Result?
    public let error: RPCError?

    public struct RPCError: Decodable, Error {
        public let code: Int
        public let message: String
        public let data: String?

        public init(code: Int, message: String, data: String? = nil) {
            self.code = code
            self.message = message
            self.data = data
        }
    }

    public var unwrappedResult: Result {
        get throws {
            if let error = error {
                throw NetworkError.rpcError(
                    code: error.code,
                    message: error.message,
                    data: error.data
                )
            }
            guard let result = result else {
                throw NetworkError.invalidRPCResponse
            }
            return result
        }
    }
}

/// Batch RPC request
public struct RPCBatchRequest: Encodable {
    public let requests: [AnyEncodable]

    public init(requests: [AnyEncodable]) {
        self.requests = requests
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for request in requests {
            try container.encode(request)
        }
    }
}

/// Type-erased encodable wrapper
public struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    public init<T: Encodable>(_ value: T) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

/// WebSocket subscription request
public struct SubscriptionRequest: Encodable {
    public let jsonrpc: String = "2.0"
    public let id: Int
    public let method: String
    public let params: [String]

    public init(id: Int, method: String, params: [String]) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// WebSocket subscription response
public struct SubscriptionResponse: Decodable {
    public let jsonrpc: String
    public let method: String?
    public let params: SubscriptionParams?

    public struct SubscriptionParams: Decodable {
        public let subscription: String
        public let result: AnyCodable
    }
}

/// Type-erased decodable wrapper
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
