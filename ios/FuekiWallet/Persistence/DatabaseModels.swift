//
//  DatabaseModels.swift
//  FuekiWallet
//
//  Core Data entity definitions and extensions
//  Note: This represents the schema. Actual .xcdatamodeld file should be created in Xcode
//

import Foundation
import CoreData

// MARK: - Wallet Entity

@objc(WalletEntity)
public class WalletEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var address: String?
    @NSManaged public var type: String? // imported, generated, watch_only, hardware
    @NSManaged public var balance: Double
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?

    // Relationships
    @NSManaged public var assets: NSSet?
    @NSManaged public var transactions: NSSet?
}

extension WalletEntity {
    @objc(addAssetsObject:)
    @NSManaged public func addToAssets(_ value: AssetEntity)

    @objc(removeAssetsObject:)
    @NSManaged public func removeFromAssets(_ value: AssetEntity)

    @objc(addAssets:)
    @NSManaged public func addToAssets(_ values: NSSet)

    @objc(removeAssets:)
    @NSManaged public func removeFromAssets(_ values: NSSet)

    @objc(addTransactionsObject:)
    @NSManaged public func addToTransactions(_ value: TransactionEntity)

    @objc(removeTransactionsObject:)
    @NSManaged public func removeFromTransactions(_ value: TransactionEntity)

    @objc(addTransactions:)
    @NSManaged public func addToTransactions(_ values: NSSet)

    @objc(removeTransactions:)
    @NSManaged public func removeFromTransactions(_ values: NSSet)
}

extension WalletEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WalletEntity> {
        return NSFetchRequest<WalletEntity>(entityName: "Wallet")
    }
}

// MARK: - Transaction Entity

@objc(TransactionEntity)
public class TransactionEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var hash: String?
    @NSManaged public var fromAddress: String?
    @NSManaged public var toAddress: String?
    @NSManaged public var amount: Double
    @NSManaged public var fee: Double
    @NSManaged public var type: String? // send, receive, swap, contract
    @NSManaged public var status: String? // pending, confirmed, failed, dropped
    @NSManaged public var confirmations: Int32
    @NSManaged public var timestamp: Date?
    @NSManaged public var confirmedAt: Date?
    @NSManaged public var metadata: [String: String]?

    // Relationships
    @NSManaged public var wallet: WalletEntity?
}

extension TransactionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionEntity> {
        return NSFetchRequest<TransactionEntity>(entityName: "Transaction")
    }
}

// MARK: - Asset Entity

@objc(AssetEntity)
public class AssetEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var symbol: String?
    @NSManaged public var name: String?
    @NSManaged public var contractAddress: String?
    @NSManaged public var decimals: Int16
    @NSManaged public var balance: Double
    @NSManaged public var priceUSD: Double
    @NSManaged public var lastPriceUpdate: Date?
    @NSManaged public var isEnabled: Bool
    @NSManaged public var metadata: [String: String]?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?

    // Relationships
    @NSManaged public var wallet: WalletEntity?
}

extension AssetEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AssetEntity> {
        return NSFetchRequest<AssetEntity>(entityName: "Asset")
    }

    var totalValueUSD: Double {
        return balance * priceUSD
    }
}

// MARK: - Contact Entity (for address book)

@objc(ContactEntity)
public class ContactEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var address: String?
    @NSManaged public var note: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension ContactEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ContactEntity> {
        return NSFetchRequest<ContactEntity>(entityName: "Contact")
    }
}

// MARK: - Core Data Entity Descriptions

/// Core Data Model Schema Definition
/// This should be replicated in the .xcdatamodeld file in Xcode
struct CoreDataSchema {
    static let modelName = "FuekiWallet"
    static let currentVersion = 2

    /// Wallet Entity Schema
    static let walletEntity = EntitySchema(
        name: "Wallet",
        className: "WalletEntity",
        attributes: [
            AttributeSchema(name: "id", type: .uuid, isOptional: false, isIndexed: true),
            AttributeSchema(name: "name", type: .string, isOptional: true),
            AttributeSchema(name: "address", type: .string, isOptional: true, isIndexed: true),
            AttributeSchema(name: "type", type: .string, isOptional: true),
            AttributeSchema(name: "balance", type: .double, isOptional: false, defaultValue: 0.0),
            AttributeSchema(name: "isActive", type: .boolean, isOptional: false, defaultValue: true),
            AttributeSchema(name: "createdAt", type: .date, isOptional: true),
            AttributeSchema(name: "updatedAt", type: .date, isOptional: true)
        ],
        relationships: [
            RelationshipSchema(name: "assets", destinationEntity: "Asset", isToMany: true, deleteRule: .cascade),
            RelationshipSchema(name: "transactions", destinationEntity: "Transaction", isToMany: true, deleteRule: .cascade)
        ]
    )

    /// Transaction Entity Schema
    static let transactionEntity = EntitySchema(
        name: "Transaction",
        className: "TransactionEntity",
        attributes: [
            AttributeSchema(name: "id", type: .uuid, isOptional: false, isIndexed: true),
            AttributeSchema(name: "hash", type: .string, isOptional: true, isIndexed: true),
            AttributeSchema(name: "fromAddress", type: .string, isOptional: true),
            AttributeSchema(name: "toAddress", type: .string, isOptional: true),
            AttributeSchema(name: "amount", type: .double, isOptional: false, defaultValue: 0.0),
            AttributeSchema(name: "fee", type: .double, isOptional: false, defaultValue: 0.0),
            AttributeSchema(name: "type", type: .string, isOptional: true),
            AttributeSchema(name: "status", type: .string, isOptional: true),
            AttributeSchema(name: "confirmations", type: .integer32, isOptional: false, defaultValue: 0),
            AttributeSchema(name: "timestamp", type: .date, isOptional: true, isIndexed: true),
            AttributeSchema(name: "confirmedAt", type: .date, isOptional: true),
            AttributeSchema(name: "metadata", type: .transformable, isOptional: true)
        ],
        relationships: [
            RelationshipSchema(name: "wallet", destinationEntity: "Wallet", isToMany: false, deleteRule: .nullify, inverseRelationship: "transactions")
        ]
    )

    /// Asset Entity Schema
    static let assetEntity = EntitySchema(
        name: "Asset",
        className: "AssetEntity",
        attributes: [
            AttributeSchema(name: "id", type: .uuid, isOptional: false, isIndexed: true),
            AttributeSchema(name: "symbol", type: .string, isOptional: true, isIndexed: true),
            AttributeSchema(name: "name", type: .string, isOptional: true),
            AttributeSchema(name: "contractAddress", type: .string, isOptional: true, isIndexed: true),
            AttributeSchema(name: "decimals", type: .integer16, isOptional: false, defaultValue: 18),
            AttributeSchema(name: "balance", type: .double, isOptional: false, defaultValue: 0.0),
            AttributeSchema(name: "priceUSD", type: .double, isOptional: false, defaultValue: 0.0),
            AttributeSchema(name: "lastPriceUpdate", type: .date, isOptional: true),
            AttributeSchema(name: "isEnabled", type: .boolean, isOptional: false, defaultValue: true),
            AttributeSchema(name: "metadata", type: .transformable, isOptional: true),
            AttributeSchema(name: "createdAt", type: .date, isOptional: true),
            AttributeSchema(name: "updatedAt", type: .date, isOptional: true)
        ],
        relationships: [
            RelationshipSchema(name: "wallet", destinationEntity: "Wallet", isToMany: false, deleteRule: .nullify, inverseRelationship: "assets")
        ]
    )

    /// Contact Entity Schema
    static let contactEntity = EntitySchema(
        name: "Contact",
        className: "ContactEntity",
        attributes: [
            AttributeSchema(name: "id", type: .uuid, isOptional: false, isIndexed: true),
            AttributeSchema(name: "name", type: .string, isOptional: true, isIndexed: true),
            AttributeSchema(name: "address", type: .string, isOptional: true, isIndexed: true),
            AttributeSchema(name: "note", type: .string, isOptional: true),
            AttributeSchema(name: "createdAt", type: .date, isOptional: true),
            AttributeSchema(name: "updatedAt", type: .date, isOptional: true)
        ],
        relationships: []
    )
}

// MARK: - Schema Helper Types

struct EntitySchema {
    let name: String
    let className: String
    let attributes: [AttributeSchema]
    let relationships: [RelationshipSchema]
}

struct AttributeSchema {
    let name: String
    let type: AttributeType
    let isOptional: Bool
    let isIndexed: Bool
    let defaultValue: Any?

    init(
        name: String,
        type: AttributeType,
        isOptional: Bool = false,
        isIndexed: Bool = false,
        defaultValue: Any? = nil
    ) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.isIndexed = isIndexed
        self.defaultValue = defaultValue
    }
}

struct RelationshipSchema {
    let name: String
    let destinationEntity: String
    let isToMany: Bool
    let deleteRule: DeleteRule
    let inverseRelationship: String?

    init(
        name: String,
        destinationEntity: String,
        isToMany: Bool,
        deleteRule: DeleteRule,
        inverseRelationship: String? = nil
    ) {
        self.name = name
        self.destinationEntity = destinationEntity
        self.isToMany = isToMany
        self.deleteRule = deleteRule
        self.inverseRelationship = inverseRelationship
    }
}

enum AttributeType {
    case string
    case integer16
    case integer32
    case integer64
    case double
    case boolean
    case date
    case uuid
    case transformable
}

enum DeleteRule {
    case cascade
    case nullify
    case deny
    case noAction
}
