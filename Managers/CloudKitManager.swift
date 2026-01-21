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
            let record = CKRecord(recordType: "TransferList", recordID: recordID)
            
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
        await MainActor.run {
            loadFromLocalStorage()
        }
        
        Task(priority: .background) { [weak self] in
            await self?.syncFromCloudKit()
            await self?.syncFromSharedCloudKit()
        }
    }
    
    private func syncFromCloudKit() async {
        do {
            let query = CKQuery(
                recordType: "TransferList",
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
    
    // ✅ FIXED: Don't query shared database - only refresh lists we already know about
    private func syncFromSharedCloudKit() async {
        // Get list of shared lists from local storage
        let sharedListIDs = await MainActor.run {
            transferLists.filter { $0.databaseScope == "shared" }.map { $0.id }
        }
        
        guard !sharedListIDs.isEmpty else {
            print("ℹ️ No shared lists to sync")
            return
        }
        
        print("🔄 Syncing \(sharedListIDs.count) shared lists...")
        
        var updatedLists: [TransferList] = []
        
        for listID in sharedListIDs {
            // Get the list from local storage to know its zone info
            guard let localList = await MainActor.run(body: {
                transferLists.first(where: { $0.id == listID })
            }) else { continue }
            
            do {
                let zoneID = CKRecordZone.ID(
                    zoneName: localList.zoneName ?? "TransferTrackerZone",
                    ownerName: localList.zoneOwnerName ?? CKCurrentUserDefaultName
                )
                let recordID = CKRecord.ID(recordName: listID, zoneID: zoneID)
                
                // Fetch this specific record
                let record = try await sharedDatabase.record(for: recordID)
                
                var list = TransferList.fromCKRecord(record)
                list.databaseScope = "shared"
                list.zoneName = record.recordID.zoneID.zoneName
                list.zoneOwnerName = record.recordID.zoneID.ownerName
                updatedLists.append(list)
                
            } catch {
                print("⚠️ Failed to sync shared list \(listID): \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            for updated in updatedLists {
                if let idx = transferLists.firstIndex(where: { $0.id == updated.id }) {
                    transferLists[idx] = updated
                }
            }
            saveToLocalStorage()
        }
        
        print("✅ Synced \(updatedLists.count) shared lists from CloudKit")
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
            let record = CKRecord(recordType: "Product", recordID: productRecordID)
            
            record["name"] = product.name as CKRecordValue
            record["bottles"] = product.bottles as CKRecordValue
            record["cases"] = product.cases as CKRecordValue
            record["costPerUnit"] = product.costPerUnit as CKRecordValue
            record["notes"] = product.notes as CKRecordValue
            record["fromUser"] = product.fromUser as CKRecordValue
            record["toUser"] = product.toUser as CKRecordValue
            record["addedBy"] = product.addedBy as CKRecordValue
            record["addedAt"] = product.addedAt as CKRecordValue
            
            let parentRecordID = CKRecord.ID(recordName: list.id, zoneID: zone)
            let reference = CKRecord.Reference(recordID: parentRecordID, action: .deleteSelf)
            record["transferList"] = reference as CKRecordValue
            
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
            let query = CKQuery(recordType: "Product", predicate: predicate)
            
            var cloudProducts: [Product] = []
            
            if list.databaseScope?.lowercased() == "shared" {
                // SharedDB does not support zone-wide queries; you must query within the shared record zone.
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
            } else {
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
            listRecord = CKRecord(recordType: "TransferList", recordID: recordID)
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
        let ownerName = owner.userIdentity.nameComponents?.formatted() ?? list.createdBy
        
        participants.append(ShareParticipant(
            id: owner.userIdentity.userRecordID?.recordName ?? "owner",
            name: ownerName,  // ✅ Use actual name instead of "Owner"
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

