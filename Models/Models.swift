import Foundation
import CloudKit

// MARK: - Transfer List Model
struct TransferList: Identifiable, Codable {
    var id: String
    var title: String
    var createdAt: Date
    var createdBy: String
    var createdByUserRecordID: String? // Store actual CloudKit user record ID
    var transferEntities: [String] // Names/entities involved in transfers (people, warehouses, stores, etc.)
    
    // CloudKit routing metadata
    var databaseScope: String? // "private" or "shared"
    var zoneName: String?
    var zoneOwnerName: String?
    
    init(title: String, createdBy: String, createdByUserRecordID: String? = nil, transferEntities: [String] = []) {
        self.id = UUID().uuidString
        self.title = title
        self.createdAt = Date()
        self.createdBy = createdBy
        self.createdByUserRecordID = createdByUserRecordID
        self.transferEntities = transferEntities
    }
    
    static func fromCKRecord(_ record: CKRecord) -> TransferList {
        var list = TransferList(
            title: record["title"] as? String ?? "Untitled",
            createdBy: record["createdBy"] as? String ?? "Unknown",
            createdByUserRecordID: record["createdByUserRecordID"] as? String,
            transferEntities: record["transferEntities"] as? [String] ?? []
        )
        
        list.id = record.recordID.recordName
        list.createdAt = record["createdAt"] as? Date ?? Date()
        list.zoneName = record.recordID.zoneID.zoneName
        list.zoneOwnerName = record.recordID.zoneID.ownerName
        
        return list
    }
    
    // Check if current user is the owner
    func isOwner(currentUserRecordID: String?) -> Bool {
        guard let currentUserRecordID = currentUserRecordID,
              let createdByID = createdByUserRecordID else {
            return false
        }
        return currentUserRecordID == createdByID
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
    var transferListID: String
    
    // CloudKit routing metadata
    var databaseScope: String?
    var zoneName: String?
    var zoneOwnerName: String?
    
    var totalCost: Double {
        (bottles * costPerUnit) + (cases * costPerUnit)
    }
    
    init(
        name: String,
        bottles: Double,
        cases: Double,
        costPerUnit: Double,
        notes: String,
        fromUser: String,
        toUser: String,
        addedBy: String,
        transferListID: String
    ) {
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
        product.addedAt = record["addedAt"] as? Date ?? Date()
        product.updatedBy = record["updatedBy"] as? String
        product.updatedAt = record["updatedAt"] as? Date
        product.zoneName = record.recordID.zoneID.zoneName
        product.zoneOwnerName = record.recordID.zoneID.ownerName
        
        return product
    }
}

// MARK: - Share Participant Info
struct ShareParticipant: Identifiable {
    let id: String
    let name: String
    let role: CKShare.ParticipantRole
    let permission: CKShare.ParticipantPermission
    
    var roleDescription: String {
        // Simplified: we only care about distinguishing the owner
        role == .owner ? "Owner" : "Participant"
    }
    
    var canDelete: Bool {
        role == .owner
    }
}

// MARK: - Time Filter Enum
enum TimeFilter: String, CaseIterable {
    case all = "All Time"
    case month = "This Month"
    case year = "This Year"
}
// MARK: - Change Event (Activity Log)

struct ChangeEvent: Identifiable, Codable {
    var id: String
    var listRecordName: String
    var eventType: String
    var summary: String
    var actorName: String
    var actorUserRecordID: String?
    var createdAt: Date

    init(listRecordName: String,
         eventType: String,
         summary: String,
         actorName: String,
         actorUserRecordID: String?) {
        self.id = UUID().uuidString
        self.listRecordName = listRecordName
        self.eventType = eventType
        self.summary = summary
        self.actorName = actorName
        self.actorUserRecordID = actorUserRecordID
        self.createdAt = Date()
    }

    static func fromCKRecord(_ record: CKRecord) -> ChangeEvent? {
        guard let listRecordName = record["listRecordName"] as? String,
              let eventType = record["eventType"] as? String,
              let summary = record["summary"] as? String,
              let actorName = record["actorName"] as? String else {
            return nil
        }

        var ev = ChangeEvent(
            listRecordName: listRecordName,
            eventType: eventType,
            summary: summary,
            actorName: actorName,
            actorUserRecordID: record["actorUserRecordID"] as? String
        )
        ev.id = record.recordID.recordName
        ev.createdAt = record["createdAt"] as? Date ?? Date()
        return ev
    }
}

