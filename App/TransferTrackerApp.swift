import SwiftUI
import CloudKit

@main
struct TransferTrackerApp: App {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitManager)
        }
    }
}
