import Foundation
import CloudKit
import SwiftUI
import Combine

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let customZoneID: CKRecordZone.ID
    
    @Published var transferLists: [TransferList] = []
    @Published var currentUserName: String = "User"
    @Published var isLoading = false
    
    // UserDefaults keys
    private let listsKey = "SavedTransferLists"
    
    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        customZoneID = CKRecordZone.ID(zoneName: "TransferTrackerZone", ownerName: CKCurrentUserDefaultName)
        
        print("🔵 CloudKitManager initialized")
        
        // Load from local storage immediately
        loadFromLocalStorage()
        
        // Setup CloudKit zone in background
        Task {
            await setupZone()
        }
    }
    
    // MARK: - Local Storage (Primary)
    
    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: listsKey),
           let decoded = try? JSONDecoder().decode([TransferList].self, from: data) {
            transferLists = decoded
            print("✅ Loaded \(decoded.count) lists from LOCAL storage")
        } else {
            print("📝 No local lists found")
        }
    }
    
    private func saveToLocalStorage() {
        if let encoded = try? JSONEncoder().encode(transferLists) {
            UserDefaults.standard.set(encoded, forKey: listsKey)
            print("✅ Saved \(transferLists.count) lists to LOCAL storage")
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
    
    func createTransferList(title: String, authorizedUsers: [String]) async throws -> TransferList {
        print("🔵 Creating list: \(title)")
        
        // Create list object
        let list = TransferList(
            title: title,
            authorizedUsers: authorizedUsers,
            createdBy: currentUserName
        )
        
        // Save to LOCAL storage FIRST (instant)
        await MainActor.run {
            transferLists.append(list)
            saveToLocalStorage()
        }
        
        print("✅ List saved LOCALLY")
        
        // Sync to CloudKit in background (optional)
        Task.detached(priority: .background) {
            await self.syncListToCloudKit(list)
        }
        
        return list
    }
    
    private func syncListToCloudKit(_ list: TransferList) async {
        do {
            let recordID = CKRecord.ID(recordName: list.id, zoneID: customZoneID)
            let record = CKRecord(recordType: "TransferList", recordID: recordID)
            record["title"] = list.title as CKRecordValue
            record["authorizedUsers"] = list.authorizedUsers as CKRecordValue
            record["createdAt"] = list.createdAt as CKRecordValue
            record["createdBy"] = list.createdBy as CKRecordValue
            
            _ = try await privateDatabase.save(record)
            print("☁️ List synced to CloudKit")
        } catch {
            print("⚠️ CloudKit sync failed (list still saved locally): \(error.localizedDescription)")
        }
    }
    
    func fetchTransferLists() async {
        print("🔍 Loading lists from LOCAL storage...")
        
        // Just reload from local storage (instant)
        await MainActor.run {
            loadFromLocalStorage()
        }
        
        // Optionally sync with CloudKit in background
        Task.detached(priority: .background) {
            await self.syncFromCloudKit()
        }
    }
    
    private func syncFromCloudKit() async {
        print("☁️ Syncing from CloudKit...")
        
        do {
            let query = CKQuery(recordType: "TransferList", predicate: NSPredicate(value: true))
            let results = try await privateDatabase.records(matching: query, inZoneWith: customZoneID)
            
            var cloudLists: [TransferList] = []
            for (_, result) in results.matchResults {
                if let record = try? result.get() {
                    cloudLists.append(TransferList.fromCKRecord(record))
                }
            }
            
            print("☁️ Found \(cloudLists.count) lists in CloudKit")
            
            // Merge with local (keep local as truth)
            await MainActor.run {
                // Add any lists from CloudKit that aren't local
                for cloudList in cloudLists {
                    if !transferLists.contains(where: { $0.id == cloudList.id }) {
                        transferLists.append(cloudList)
                    }
                }
                saveToLocalStorage()
            }
        } catch {
            print("⚠️ CloudKit sync failed: \(error.localizedDescription)")
            // Don't worry - we have local data
        }
    }
    
    func updateTransferList(_ list: TransferList) async throws {
        // Update local first
        await MainActor.run {
            if let index = transferLists.firstIndex(where: { $0.id == list.id }) {
                transferLists[index] = list
                saveToLocalStorage()
            }
        }
        
        print("✅ List updated LOCALLY")
        
        // Sync to CloudKit in background
        Task.detached(priority: .background) {
            await self.syncListToCloudKit(list)
        }
    }
    
    // MARK: - Products (Local Storage)
    
    private func productsKey(for listID: String) -> String {
        return "Products_\(listID)"
    }
    
    func fetchProducts(for list: TransferList) async throws -> [Product] {
        print("🔍 Loading products from LOCAL storage...")
        
        let key = productsKey(for: list.id)
        
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Product].self, from: data) {
            print("✅ Loaded \(decoded.count) products from LOCAL storage")
            return decoded
        }
        
        print("📝 No local products found")
        return []
    }
    
    func addProduct(_ product: Product, to list: TransferList) async throws {
        print("🔵 Saving product: \(product.name)")
        
        // Load current products
        var products = try await fetchProducts(for: list)
        
        // Add new product
        products.append(product)
        
        // Save to local storage
        let key = productsKey(for: list.id)
        if let encoded = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encoded, forKey: key)
            print("✅ Product saved LOCALLY")
        }
        
        // Sync to CloudKit in background
        Task.detached(priority: .background) {
            await self.syncProductToCloudKit(product, listID: list.id)
        }
    }
    
    private func syncProductToCloudKit(_ product: Product, listID: String) async {
        do {
            let productRecordID = CKRecord.ID(recordName: product.id, zoneID: customZoneID)
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
            
            // Create parent reference
            let parentRecordID = CKRecord.ID(recordName: listID, zoneID: customZoneID)
            let reference = CKRecord.Reference(recordID: parentRecordID, action: .deleteSelf)
            record["transferList"] = reference as CKRecordValue
            
            _ = try await privateDatabase.save(record)
            print("☁️ Product synced to CloudKit")
        } catch {
            print("⚠️ CloudKit sync failed (product still saved locally): \(error.localizedDescription)")
        }
    }
    
    func updateProduct(_ product: Product, in list: TransferList) async throws {
        // Load current products
        var products = try await fetchProducts(for: list)
        
        // Update product
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
            
            // Save to local storage
            let key = productsKey(for: list.id)
            if let encoded = try? JSONEncoder().encode(products) {
                UserDefaults.standard.set(encoded, forKey: key)
                print("✅ Product updated LOCALLY")
            }
            
            // Sync to CloudKit in background
            Task.detached(priority: .background) {
                await self.syncProductToCloudKit(product, listID: list.id)
            }
        }
    }
    
    func deleteProduct(_ product: Product, from list: TransferList) async throws {
        // Load current products
        var products = try await fetchProducts(for: list)
        
        // Remove product
        products.removeAll { $0.id == product.id }
        
        // Save to local storage
        let key = productsKey(for: list.id)
        if let encoded = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encoded, forKey: key)
            print("✅ Product deleted LOCALLY")
        }
        
        // Delete from CloudKit in background
        Task.detached(priority: .background) {
            do {
                let recordID = CKRecord.ID(recordName: product.id, zoneID: self.customZoneID)
                _ = try await self.privateDatabase.deleteRecord(withID: recordID)
                print("☁️ Product deleted from CloudKit")
            } catch {
                print("⚠️ CloudKit delete failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Sharing (CloudKit Only)
    
    func createShare(for list: TransferList) async throws -> CKShare {
        let recordID = CKRecord.ID(recordName: list.id, zoneID: customZoneID)
        let listRecord = try await privateDatabase.record(for: recordID)
        
        let share = CKShare(rootRecord: listRecord)
        share[CKShare.SystemFieldKey.title] = list.title as CKRecordValue
        share.publicPermission = .readWrite
        
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: [listRecord, share], recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            
            var savedShare: CKShare?
            
            operation.perRecordSaveBlock = { _, result in
                if case .success(let record) = result, let s = record as? CKShare {
                    savedShare = s
                }
            }
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    if let s = savedShare {
                        continuation.resume(returning: s)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CloudKit", code: 2, userInfo: nil))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            privateDatabase.add(operation)
        }
    }
    
    func validateUserAccess(userName: String, for list: TransferList) -> Bool {
        return list.authorizedUsers.contains { user in
            user.lowercased().contains(userName.lowercased()) ||
            userName.lowercased().contains(user.lowercased())
        }
    }
}
