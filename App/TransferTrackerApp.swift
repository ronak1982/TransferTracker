import SwiftUI
import CloudKit
import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let urlHandling = Logger(subsystem: subsystem, category: "url-handling")
    static let cloudkit = Logger(subsystem: subsystem, category: "cloudkit")
}

@main
struct TransferTrackerApp: App {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentViewWrapper()
                    .environmentObject(cloudKitManager)
                
                // Debug overlay
                DebugOverlay(logger: DebugLogger.shared)
            }
        }
    }
}

struct ContentViewWrapper: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @State private var selectedList: TransferList?
    @State private var shareMetadataToPresent: CKShare.Metadata?
    
    var body: some View {
        NavigationStack {
            DashboardView(selectedList: $selectedList)
        }
        .sheet(item: Binding(
            get: { shareMetadataToPresent.map { ShareMetadataWrapper(metadata: $0) } },
            set: { shareMetadataToPresent = $0?.metadata }
        )) { wrapper in
            JoinListView(
                shareMetadata: wrapper.metadata,
                isPresented: Binding(
                    get: { shareMetadataToPresent != nil },
                    set: { if !$0 { shareMetadataToPresent = nil } }
                )
            )
            .environmentObject(cloudKitManager)
        }
        .onChange(of: shareMetadataToPresent) { oldValue, newValue in
            // Refresh dashboard when join sheet closes (goes from non-nil to nil)
            if oldValue != nil && newValue == nil {
                Task {
                    await cloudKitManager.fetchTransferLists()
                }
            }
        }
        .onOpenURL { url in
            DebugLogger.shared.log("APP RECEIVED URL")
            DebugLogger.shared.log("   \(url.absoluteString)")
            handleIncomingURL(url)
        }
        .onAppear {
            DebugLogger.shared.log("ContentWrapper appeared")
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        DebugLogger.shared.log("HANDLE INCOMING URL CALLED")
        
        guard url.absoluteString.contains("icloud.com/share") else {
            DebugLogger.shared.log("NOT A CLOUDKIT SHARE URL")
            return
        }
        
        DebugLogger.shared.log("CLOUDKIT SHARE URL DETECTED")
        
        Task {
            do {
                DebugLogger.shared.log("FETCHING SHARE METADATA...")
                let metadata = try await CKContainer.default().shareMetadata(for: url)
                
                let title = metadata.share[CKShare.SystemFieldKey.title] as? String ?? "Unknown"
                DebugLogger.shared.log("GOT METADATA: \(title)")
                
                await MainActor.run {
                    DebugLogger.shared.log("SETTING shareMetadataToPresent")
                    shareMetadataToPresent = metadata
                    DebugLogger.shared.log("   shareMetadataToPresent is now: \(shareMetadataToPresent != nil ? "SET" : "nil")")
                }
            } catch {
                DebugLogger.shared.log("ERROR: \(error.localizedDescription)")
            }
        }
    }
}

// Wrapper to make CKShare.Metadata Identifiable for sheet(item:)
struct ShareMetadataWrapper: Identifiable {
    let id = UUID()
    let metadata: CKShare.Metadata
}

#Preview {
    ContentViewWrapper()
        .environmentObject(CloudKitManager.shared)
}
