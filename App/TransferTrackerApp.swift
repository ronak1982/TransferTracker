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

    // When the app is opened via a shared CloudKit URL, we store the incoming metadata here
    // and present the Join sheet.
    @State private var shareMetadataToPresent: CKShare.Metadata?
    @State private var selectedList: TransferList?

    /// Two-way binding used by the JoinListView sheet.
    private var isShowingJoinSheet: Binding<Bool> {
        Binding(
            get: { shareMetadataToPresent != nil },
            set: { newValue in
                // When sheet dismisses, clear the metadata.
                if !newValue { shareMetadataToPresent = nil }
            }
        )
    }

    var body: some View {
        NavigationStack {
            // DashboardView in this project is the root and manages its own selection/navigation.
            DashboardView()
                .environmentObject(cloudKitManager)
        }
        .sheet(isPresented: isShowingJoinSheet) {
            if let metadata = shareMetadataToPresent {
                JoinListView(
                    shareMetadata: metadata,
                    isPresented: isShowingJoinSheet
                )
                .environmentObject(cloudKitManager)
            }
        }
        // Handle incoming share URLs: capture metadata and present JoinListView
        .onOpenURL { url in
            Task {
                do {
                    let metadata = try await CKContainer.default().shareMetadata(for: url)
                    await MainActor.run {
                        shareMetadataToPresent = metadata
                    }
                } catch {
                    // If metadata parsing fails, do nothing (user can still join manually via Join sheet).
                    print("Failed to parse CKShare metadata from URL: \(error)")
                }
            }
        }
    }
}


