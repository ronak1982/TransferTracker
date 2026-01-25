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
            ContentViewWrapper()
                .environmentObject(cloudKitManager)
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
            Logger.urlHandling.info("App received URL: \(url.absoluteString, privacy: .public)")
            handleIncomingURL(url)
        }
        .onAppear {
            Logger.urlHandling.debug("ContentViewWrapper appeared")
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        Logger.urlHandling.debug("handleIncomingURL called")
        
        guard url.absoluteString.contains("icloud.com/share") else {
            Logger.urlHandling.debug("Ignoring non-CloudKit share URL")
            return
        }
        
        Logger.urlHandling.info("CloudKit share URL detected")
        
        Task {
            do {
                Logger.urlHandling.debug("Fetching CKShare metadata...")
                let metadata = try await CKContainer.default().shareMetadata(for: url)
                
                let title = metadata.share[CKShare.SystemFieldKey.title] as? String ?? "Unknown"
                Logger.urlHandling.info("Fetched share metadata. title=\(title, privacy: .public)")
                
                await MainActor.run {
                    shareMetadataToPresent = metadata
                    Logger.urlHandling.debug("shareMetadataToPresent set")
                }
            } catch {
                Logger.urlHandling.error("Error fetching share metadata: \(error.localizedDescription, privacy: .public)")
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

