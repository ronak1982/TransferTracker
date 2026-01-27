import SwiftUI
import CloudKit
import OSLog

extension Logger {
    private static var subsystem: String {
        Bundle.main.bundleIdentifier ?? "TransferTracker"
    }

    static let urlHandling = Logger(subsystem: subsystem, category: "url-handling")
    static let cloudkit = Logger(subsystem: subsystem, category: "cloudkit")
}

@main
struct TransferTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var cloudKitManager = CloudKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentViewWrapper()
                .environmentObject(cloudKitManager)
                // Intake path #1 (most common): iCloud share universal links.
                .onOpenURL { url in
                    Logger.urlHandling.info("🔵 SwiftUI onOpenURL FIRED: \(url.absoluteString, privacy: .public)")
                    print("🔵 SwiftUI onOpenURL FIRED: \(url.absoluteString)")
                    NotificationCenter.default.post(name: .incomingShareURL, object: url)
                }
                // Intake path #2: system continues a browsing activity.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else {
                        Logger.urlHandling.info("🟡 SwiftUI onContinueUserActivity FIRED but no URL")
                        print("🟡 SwiftUI onContinueUserActivity FIRED but no URL")
                        return
                    }
                    Logger.urlHandling.info("🟢 SwiftUI onContinueUserActivity FIRED: \(url.absoluteString, privacy: .public)")
                    print("🟢 SwiftUI onContinueUserActivity FIRED: \(url.absoluteString)")
                    NotificationCenter.default.post(name: .incomingShareURL, object: url)
                }
        }
    }
}
