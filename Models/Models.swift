import Foundation
import CloudKit

// MARK: - Transfer List Model
struct TransferList: Identifiable, Codable {
    var id: String
    var title: String
    var authorizedUsers: [String]
    var createdAt: Date
    var createdBy: String
    var recordName: String?
    
    init(title: String, authorizedUsers: [String], createdBy: String) {
        self.id = UUID().uuidString
        self.title = title
        self.authorizedUsers = authorizedUsers
        self.createdAt = Date()
        self.createdBy = createdBy
        self.recordName = id // Use ID as recordName
    }
    
    static func fromCKRecord(_ record: CKRecord) -> TransferList {
        var list = TransferList(
            title: record["title"] as? String ?? "Untitled",
            authorizedUsers: record["authorizedUsers"] as? [String] ?? [],
            createdBy: record["createdBy"] as? String ?? "Unknown"
        )
        list.id = record.recordID.recordName
        list.recordName = record.recordID.recordName
        list.createdAt = record["createdAt"] as? Date ?? Date()
        return list
    }
}

// MARK: - Product Model
struct Product: Identifiable, Codable {
    var id: String
    var name: String
    var bottles: Double
    var cases: Double
    var costPerUnit: Double
    var notes: String
    var fromUser: String
    var toUser: String
    var addedBy: String
    var addedAt: Date
    var updatedBy: String?
    var updatedAt: Date?
    var recordName: String?
    var transferListID: String
    
    var totalCost: Double {
        // Simple calculation: bottles at costPerUnit + cases at costPerUnit
        // No 12x multiplier for cases!
        return (bottles * costPerUnit) + (cases * costPerUnit)
    }
    
    init(name: String, bottles: Double, cases: Double, costPerUnit: Double, notes: String, fromUser: String, toUser: String, addedBy: String, transferListID: String) {
        self.id = UUID().uuidString
        self.name = name
        self.bottles = bottles
        self.cases = cases
        self.costPerUnit = costPerUnit
        self.notes = notes
        self.fromUser = fromUser
        self.toUser = toUser
        self.addedBy = addedBy
        self.addedAt = Date()
        self.recordName = id
        self.transferListID = transferListID
    }
    
    static func fromCKRecord(_ record: CKRecord, transferListID: String) -> Product {
        var product = Product(
            name: record["name"] as? String ?? "Untitled",
            bottles: record["bottles"] as? Double ?? 0,
            cases: record["cases"] as? Double ?? 0,
            costPerUnit: record["costPerUnit"] as? Double ?? 0,
            notes: record["notes"] as? String ?? "",
            fromUser: record["fromUser"] as? String ?? "Unknown",
            toUser: record["toUser"] as? String ?? "Unknown",
            addedBy: record["addedBy"] as? String ?? "Unknown",
            transferListID: transferListID
        )
        product.id = record.recordID.recordName
        product.recordName = record.recordID.recordName
        product.addedAt = record["addedAt"] as? Date ?? Date()
        product.updatedBy = record["updatedBy"] as? String
        product.updatedAt = record["updatedAt"] as? Date
        return product
    }
}

// MARK: - Time Filter Enum
enum TimeFilter: String, CaseIterable {
    case all = "All Time"
    case month = "This Month"
    case year = "This Year"
}
