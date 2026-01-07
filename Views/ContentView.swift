import SwiftUI
import CloudKit

struct ContentView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @State private var selectedList: TransferList?
    @State private var showingNamePrompt = false
    @State private var pendingShare: CKShare.Metadata?
    
    var body: some View {
        NavigationStack {
            DashboardView(selectedList: $selectedList)
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .sheet(isPresented: $showingNamePrompt) {
            if let metadata = pendingShare {
                JoinListView(shareMetadata: metadata, isPresented: $showingNamePrompt)
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle CloudKit share URL
        if url.scheme == "https" && url.host == "www.icloud.com" {
            CKContainer.default().fetchShareMetadata(with: url) { metadata, error in
                if let metadata = metadata {
                    pendingShare = metadata
                    showingNamePrompt = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CloudKitManager.shared)
}
