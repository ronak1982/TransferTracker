import SwiftUI
import CloudKit
import OSLog

struct ContentViewWrapper: View {
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    
    @State private var shareMetadataToPresent: CKShare.Metadata?
    @State private var isPresentingJoinSheet: Bool = false
    
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TransferTracker",
                             category: "share-join")
    
    var body: some View {
        // ✅ CRITICAL FIX: Wrap DashboardView in NavigationStack!
        NavigationStack {
            DashboardView(selectedList: .constant(nil))
                .environmentObject(cloudKitManager)
                
                // Join sheet - presents when we have metadata
                .sheet(isPresented: $isPresentingJoinSheet, onDismiss: {
                    shareMetadataToPresent = nil
                }) {
                    if let metadata = shareMetadataToPresent {
                        JoinListView(
                            shareMetadata: metadata,
                            isPresented: $isPresentingJoinSheet
                        )
                        .environmentObject(cloudKitManager)
                    }
                }
                
                // Listen for incoming share URLs (from universal links, SceneDelegate, etc.)
                .onReceive(NotificationCenter.default.publisher(for: .incomingShareURL)) { note in
                    guard let url = note.object as? URL else { return }
                    handleIncomingShareURL(url)
                }
        }
    }
    
    // MARK: - Share URL Handling
    
    func handleIncomingShareURL(_ url: URL) {
        let canonical = canonicalizeShareURL(url)
        
        log.info("📥 Processing share URL: \(canonical.absoluteString, privacy: .public)")
        
        let container = CKContainer.default()
        
        container.fetchShareMetadata(with: canonical) { metadata, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.log.error("❌ fetchShareMetadata failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                
                guard let metadata = metadata else {
                    self.log.error("❌ fetchShareMetadata returned nil metadata")
                    return
                }
                
                self.log.info("✅ Got share metadata, presenting join sheet")
                self.shareMetadataToPresent = metadata
                self.isPresentingJoinSheet = true
            }
        }
    }
    
    private func canonicalizeShareURL(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        // Strip fragment which can break CloudKit metadata fetch
        comps.fragment = nil
        return comps.url ?? url
    }
}
