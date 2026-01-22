import Foundation
import CloudKit
import SwiftUI
import Combine

final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    private let customZoneID: CKRecordZone.ID
    
    @Published var transferLists: [TransferList] = []
    @Published var currentUserName: String = ""
    @Published var currentUserRecordID: String?
    @Published var isLoading = false
    
    private let listsKey = "SavedTransferLists"
    
    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        customZoneID = CKRecordZone.ID(zoneName: "TransferTrackerZone", ownerName: CKCurrentUserDefaultName)
        
        print("🔧 CloudKitManager initialized")
        
        loadFromLocalStorage()
        
        Task(priority: .background) { [weak self] in
            await self?.setupZone()
            await self?.fetchCurrentUserInfo()
        }
    }
    
    // MARK: - User Info
    
    private func fetchCurrentUserInfo() async {
        do {
            let userRecordID = try await container.userRecordID()
            await MainActor.run {
                self.currentUserRecordID = userRecordID.recordName
            }
            print("✅ Got user record ID: \(userRecordID.recordName)")
        } catch {
            print("⚠️ Failed to get user record ID: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cloud Routing
    
    private func database(forScope scope: String?) -> CKDatabase {
        (scope?.lowercased() == "shared") ? sharedDatabase : privateDatabase
    }
    
    private func zoneID(for list: TransferList) -> CKRecordZone.ID {
        let zoneName = list.zoneName ?? customZoneID.zoneName
        let ownerName = list.zoneOwnerName ?? customZoneID.ownerName
        return CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
    }
    
    // MARK: - Local Storage
    
    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: listsKey),
           let decoded = try? JSONDecoder().decode([TransferList].self, from: data) {
            transferLists = decoded
            print("✅ Loaded \(decoded.count) lists from local storage")
        }
    }
    
    // ✅ FIXED: Made public so UserManagerView can call it when leaving a list
    
    // MARK: - Local Activity Feed (Phase 5C Dashboard)

    private let changeEventsKeyPrefix = "SavedChangeEventsKey_"

    private func changeEventsKey(for listID: String) -> String {
        "\(changeEventsKeyPrefix)\(listID)"
    }

    private func appendChangeEvent(_ event: ChangeEvent) {
        let key = changeEventsKey(for: event.transferListID)
        var events = (loadChangeEvents(forListID: event.transferListID) ?? [])
        events.append(event)

        // Keep newest first and cap to avoid unbounded growth
        events.sort { $0.createdAt > $1.createdAt }
        if events.count > 200 { events = Array(events.prefix(200)) }

        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("⚠️ Failed to save activity events: \(error.localizedDescription)")
        }
    }

    private func loadChangeEvents(forListID listID: String) -> [ChangeEvent]? {
        let key = changeEventsKey(for: listID)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([ChangeEvent].self, from: data)
    }

    func fetchRecentChangeEventsLocal(limit: Int = 20) -> [ChangeEvent] {
        let all = UserDefaults.standard.dictionaryRepresentation()
        var merged: [ChangeEvent] = []

        for (key, value) in all {
            guard key.hasPrefix(changeEventsKeyPrefix) else { continue }
            guard let data = value as? Data else { continue }
            if let decoded = try? JSONDecoder().decode([ChangeEvent].self, from: data) {
                merged.append(contentsOf: decoded)
            }
        }

        merged.sort { $0.createdAt > $1.createdAt }
        if merged.count > limit { merged = Array(merged.prefix(limit)) }
        return merged
    }


func saveToLocalStorage() {
        if let encoded = try? JSONEncoder().encode(transferLists) {
            UserDefaults.standard.set(encoded, forKey: listsKey)
            print("✅ Saved \(transferLists.count) lists to local storage")
        }
    }
    
    // MARK: - CloudKit Setup
    
    private func setupZone() async {
        do {
            let zone = CKRecordZone(zoneID: customZoneID)
            _ = try await privateDatabase.save(zone)
            print("✅ CloudKit zone ready")
        } catch {
            print("⚠️ CloudKit zone setup: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Transfer Lists
    
    func createTransferList(title: String, transferEntities: [String] = []) async throws -> TransferList {
        print("📝 Creating list: \(title)")
        
        let list = TransferList(
            title: title,
            createdBy: currentUserName.isEmpty ? "Me" : currentUserName,
            createdByUserRecordID: currentUserRecordID,
            transferEntities: transferEntities
        )
        
        // Save locally first
        await MainActor.run {
            transferLists.append(list)
            saveToLocalStorage()
        appendChangeEvent(ChangeEvent(transferListID: list.id, transferListTitle: list.title, entityType: .list, action: .create, summary: "Created list", actorName: currentUserName.isEmpty ? nil : currentUserName))
        }
        
        print("✅ List saved locally")
        
        // Sync to CloudKit
        Task(priority: .background) { [weak self] in
            await self?.syncListToCloudKit(list)
        }
        
        return list
    }
    
    private func syncListToCloudKit(_ list: TransferList) async {
        do {
            let db = database(forScope: list.databaseScope)
            let recordID = CKRecord.ID(recordName: list.id, zoneID: zoneID(for: list))
            let record = CKRecord(recordType: "TransferListV2", recordID: recordID)
            
            record["title"] = list.title as CKRecordValue
            record["createdAt"] = list.createdAt as CKRecordValue
            record["createdBy"] = list.createdBy as CKRecordValue
            record["transferEntities"] = list.transferEntities as CKRecordValue
            
            // Only add createdByUserRecordID if it exists (graceful handling for production schema)
            if let userRecordID = list.createdByUserRecordID {
                record["createdByUserRecordID"] = userRecordID as CKRecordValue
            }
            
            _ = try await db.save(record)
            print("☁️ List synced to CloudKit")
        } catch {
            print("⚠️ CloudKit sync failed: \(error.localizedDescription)")
        }
    }
    
    func fetchTransferLists() async {
        // Phase 5C stability choice:
        // Load from local storage synchronously for UI responsiveness, and do NOT run
        // background CloudKit queries at launch. Those queries can emit noisy CloudKit
        // console errors (e.g., 'recordName is not marked queryable') depending on the
        // container schema and CloudKit server-side query planner.
        await MainActor.run {
            loadFromLocalStorage()
        }
    }

    /// Optional manual refresh hook (not called automatically).
    func refreshFromCloudKit() async {
        await syncFromCloudKit()
        await syncFromSharedCloudKit()
    }
    
    private func syncFromCloudKit() async {
        do {
            let query = CKQuery(
                recordType: "TransferListV2",
                predicate: NSPredicate(value: true)
            )

            // Don't sort in CloudKit query - sort locally instead to avoid "not queryable" errors
            let results = try await privateDatabase.records(
                matching: query,
                inZoneWith: customZoneID
            )

            var lists: [TransferList] = []

            for (_, result) in results.matchResults {
                if let record = try? result.get() {
                    var list = TransferList.fromCKRecord(record)
                    list.databaseScope = "private"
                    lists.append(list)
                }
            }
            
            // Sort locally by createdAt (newest first)
            lists.sort { $0.createdAt > $1.createdAt }

            await MainActor.run {
                self.transferLists = lists
                saveToLocalStorage()
            }
            
            print("✅ Loaded \(lists.count) private lists from CloudKit")

        } catch {
            print("⚠️ Private CloudKit sync failed: \(error)")
        }
    }
    
    // ✅ FIXED: Removed zone iteration, query shared database directly
    private func syncFromSharedCloudKit() async {
        do {
            // Query shared database directly (no zone iteration needed)
            let query = CKQuery(
                recordType: "TransferListV2",
                predicate: NSPredicate(value: true)
            )

            // Don't sort in CloudKit query - sort locally instead
            let results = try await sharedDatabase.records(matching: query)
            
            var allSharedLists: [TransferList] = []
            
            for (_, result) in results.matchResults {
                if let record = try? result.get() {
                    var list = TransferList.fromCKRecord(record)
                    list.databaseScope = "shared"
                    list.zoneName = record.recordID.zoneID.zoneName
                    list.zoneOwnerName = record.recordID.zoneID.ownerName
                    allSharedLists.append(list)
                }
            }
            
            // Sort all shared lists locally by createdAt (newest first)
            allSharedLists.sort { $0.createdAt > $1.createdAt }
            
            await MainActor.run {
                for incoming in allSharedLists {
                    if let idx = transferLists.firstIndex(where: { $0.id == incoming.id }) {
                        transferLists[idx] = incoming
                    } else {
                        transferLists.append(incoming)
                    }
                }
                saveToLocalStorage()
            }
            
            print("✅ Loaded \(allSharedLists.count) shared lists from CloudKit")
        } catch {
            print("⚠️ Shared CloudKit sync failed: \(error.localizedDescription)")
        }
    }
    
    func fetchSharedTransferList(recordID: CKRecord.ID) async throws -> TransferList {
        let record = try await sharedDatabase.record(for: recordID)
        var list = TransferList.fromCKRecord(record)
        list.databaseScope = "shared"
        return list
    }
    
    func upsertSharedListLocally(_ list: TransferList) async throws {
        await MainActor.run {
            var incoming = list
            incoming.databaseScope = "shared"
            
            if let idx = transferLists.firstIndex(where: { $0.id == incoming.id }) {
                transferLists[idx] = incoming
            } else {
                transferLists.append(incoming)
            }
            saveToLocalStorage()
        }
    }
    
    func updateTransferList(_ list: TransferList) async throws {
        await MainActor.run {
            if let index = transferLists.firstIndex(where: { $0.id == list.id }) {
                transferLists[index] = list
                saveToLocalStorage()
        appendChangeEvent(ChangeEvent(transferListID: list.id, transferListTitle: list.title, entityType: .list, action: .update, summary: "Updated list", actorName: currentUserName.isEmpty ? nil : currentUserName))
            }
        }
        
        Task(priority: .background) { [weak self] in
            await self?.syncListToCloudKit(list)
        }
    }
    
    func deleteTransferList(_ list: TransferList) async throws {
        // Remove from local storage
        await MainActor.run {
            transferLists.removeAll { $0.id == list.id }
            appendChangeEvent(ChangeEvent(transferListID: list.id, transferListTitle: list.title, entityType: .list, action: .delete, summary: "Deleted list", actorName: currentUserName.isEmpty ? nil : currentUserName))
            saveToLocalStorage()
        }
        
        // Delete from CloudKit
        let db = database(forScope: list.databaseScope)
        let recordID = CKRecord.ID(recordName: list.id, zoneID: zoneID(for: list))
        
        do {
            _ = try await db.deleteRecord(withID: recordID)
            print("☁️ List deleted from CloudKit")
        } catch {
            print("⚠️ CloudKit delete failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Products
    
    private func productsKey(for listID: String) -> String {
        "Products_\(listID)"
    }
    
    func fetchProducts(for list: TransferList) async throws -> [Product] {
        let key = productsKey(for: list.id)
        
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Product].self, from: data) {
            
            Task(priority: .background) { [weak self] in
                await self?.syncProductsFromCloudKit(for: list)
            }
            
            return decoded
        }
        
        Task(priority: .background) { [weak self] in
            await self?.syncProductsFromCloudKit(for: list)
        }
        
        return []
    }
    
    func addProduct(_ product: Product, to list: TransferList) async throws {
        var productToSave = product
        productToSave.databaseScope = list.databaseScope ?? "private"
        productToSave.zoneName = list.zoneName ?? customZoneID.zoneName
        productToSave.zoneOwnerName = list.zoneOwnerName ?? customZoneID.ownerName
        
        var products = try await fetchProducts(for: list)
        products.append(productToSave)
        
        let key = productsKey(for: list.id)
        if let encoded = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encoded, forKey: key)
            print("✅ Product saved locally")
        }
        
        Task(priority: .background) { [weak self] in
            await self?.syncProductToCloudKit(productToSave, in: list)
        }
    }
    
    private func syncProductToCloudKit(_ product: Product, in list: TransferList) async {
        do {
            let db = database(forScope: list.databaseScope)
            let zone = zoneID(for: list)
            
            let productRecordID = CKRecord.ID(recordName: product.id, zoneID: zone)
            let record = CKRecord(recordType: "ProductV2", recordID: productRecordID)
            
            record["name"] = product.name as CKRecordValue
            record["bottles"] = product.bottles as CKRecordValue
            record["cases"] = product.cases as CKRecordValue
            record["costPerUnit"] = product.costPerUnit as CKRecordValue
            record["notes"] = product.notes as CKRecordValue
            record["fromUser"] = product.fromUser as CKRecordValue
            record["toUser"] = product.toUser as CKRecordValue
            record["addedBy"] = product.addedBy as CKRecordValue
            record["addedAt"] = product.addedAt as CKRecordValue
            
            // IMPORTANT (SharedDB writes): a participant can only create records that belong to the share.
            // Setting both a reference field AND the CKRecord.parent ties this record into the share tree.
            let parentRecordID = CKRecord.ID(recordName: list.id, zoneID: zone)
            let parentRef = CKRecord.Reference(recordID: parentRecordID, action: .none)
            record["transferList"] = parentRef as CKRecordValue
            record.parent = parentRef
            
            _ = try await db.save(record)
            print("☁️ Product synced to CloudKit")
        } catch {
            print("⚠️ Product CloudKit sync failed: \(error.localizedDescription)")
        }
    }
    
    func updateProduct(_ product: Product, in list: TransferList) async throws {
        var products = try await fetchProducts(for: list)
        
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
            
            let key = productsKey(for: list.id)
            if let encoded = try? JSONEncoder().encode(products) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
            
            Task(priority: .background) { [weak self] in
                await self?.syncProductToCloudKit(product, in: list)
            }
        }
    }
    
    func deleteProduct(_ product: Product, from list: TransferList) async throws {
        var products = try await fetchProducts(for: list)
        products.removeAll { $0.id == product.id }
        
        let key = productsKey(for: list.id)
        if let encoded = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
        
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            do {
                let db = self.database(forScope: list.databaseScope)
                let zone = self.zoneID(for: list)
                let recordID = CKRecord.ID(recordName: product.id, zoneID: zone)
                _ = try await db.deleteRecord(withID: recordID)
                print("☁️ Product deleted from CloudKit")
            } catch {
                print("⚠️ CloudKit delete failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncProductsFromCloudKit(for list: TransferList) async {
        let db = database(forScope: list.databaseScope)
        let zone = zoneID(for: list)
        
        do {
            let parentID = CKRecord.ID(recordName: list.id, zoneID: zone)
            let ref = CKRecord.Reference(recordID: parentID, action: .none)
            let predicate = NSPredicate(format: "transferList == %@", ref)
            let query = CKQuery(recordType: "ProductV2", predicate: predicate)
            
            var cloudProducts: [Product] = []
            
            // SharedDB does not allow zone-wide queries. Always scope queries to a known zone.
            let results = try await db.records(matching: query, inZoneWith: zone)
            
            for (_, result) in results.matchResults {
                if let record = try? result.get() {
                    var p = Product.fromCKRecord(record, transferListID: list.id)
                    p.databaseScope = list.databaseScope
                    p.zoneName = record.recordID.zoneID.zoneName
                    p.zoneOwnerName = record.recordID.zoneID.ownerName
                    cloudProducts.append(p)
                }
            }
            
            let key = productsKey(for: list.id)
            let local: [Product]
            if let data = UserDefaults.standard.data(forKey: key),
               let decoded = try? JSONDecoder().decode([Product].self, from: data) {
                local = decoded
            } else {
                local = []
            }
            
            var merged = local
            for cp in cloudProducts {
                if let idx = merged.firstIndex(where: { $0.id == cp.id }) {
                    merged[idx] = cp
                } else {
                    merged.append(cp)
                }
            }
            
            if let encoded = try? JSONEncoder().encode(merged) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        } catch {
            print("⚠️ Product cloud sync failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sharing
    
    func createShare(for list: TransferList) async throws -> CKShare {
        print("📤 Creating share for list: \(list.title)")
        
        let recordID = CKRecord.ID(recordName: list.id, zoneID: customZoneID)
        
        let listRecord: CKRecord
        do {
            listRecord = try await privateDatabase.record(for: recordID)
        } catch {
            listRecord = CKRecord(recordType: "TransferListV2", recordID: recordID)
            listRecord["title"] = list.title as CKRecordValue
            listRecord["createdAt"] = list.createdAt as CKRecordValue
            listRecord["createdBy"] = list.createdBy as CKRecordValue
            listRecord["transferEntities"] = list.transferEntities as CKRecordValue
            
            // Only add createdByUserRecordID if it exists (graceful handling)
            if let userRecordID = list.createdByUserRecordID {
                listRecord["createdByUserRecordID"] = userRecordID as CKRecordValue
            }
            
            _ = try await privateDatabase.save(listRecord)
        }
        
        let share = CKShare(rootRecord: listRecord)
        share[CKShare.SystemFieldKey.title] = list.title as CKRecordValue
        share.publicPermission = .readWrite
        
        let saveResult = try await privateDatabase.modifyRecords(
            saving: [listRecord, share],
            deleting: []
        )
        
        for (_, result) in saveResult.saveResults {
            switch result {
            case .success(let record):
                if let savedShare = record as? CKShare {
                    print("✅ Share created successfully!")
                    return savedShare
                }
            case .failure(let error):
                print("❌ Failed to save record: \(error)")
            }
        }
        
        throw NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No share was created"])
    }
    
    // MARK: - Participant Management
    
    func fetchShareParticipants(for list: TransferList) async throws -> [ShareParticipant] {
        let recordID = CKRecord.ID(recordName: list.id, zoneID: zoneID(for: list))
        let db = database(forScope: list.databaseScope)
        
        // Fetch the share for this list
        let record = try await db.record(for: recordID)
        
        guard let shareReference = record.share else {
            return [] // Not shared
        }
        
        let share = try await db.record(for: shareReference.recordID) as? CKShare
        
        guard let share = share else {
            return []
        }
        
        var participants: [ShareParticipant] = []
        
        // Add owner (owner is not optional - always exists on a share)
        let owner = share.owner
        participants.append(ShareParticipant(
            id: owner.userIdentity.userRecordID?.recordName ?? "owner",
            name: "Owner",
            role: .owner,
            permission: .readWrite
        ))
        
        // Add other participants
        for participant in share.participants {
            if participant.role != .owner {
                participants.append(ShareParticipant(
                    id: participant.userIdentity.userRecordID?.recordName ?? UUID().uuidString,
                    name: participant.userIdentity.nameComponents?.formatted() ?? "Participant",
                    role: participant.role,
                    permission: participant.permission
                ))
            }
        }
        
        return participants
    }
}



