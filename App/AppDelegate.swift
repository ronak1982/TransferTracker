import UIKit
import OSLog

final class AppDelegate: NSObject, UIApplicationDelegate {

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TransferTracker", category: "url-handling")

    // URL-only delivery path (custom URL scheme). Universal links are usually delivered to SceneDelegate.
    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        log.info("🟣 AppDelegate.application(_:open:) FIRED: \(url.absoluteString, privacy: .public)")
        print("🟣 AppDelegate.application(_:open:) FIRED: \(url.absoluteString)")
        NotificationCenter.default.post(name: .incomingShareURL, object: url)
        return true
    }

    // Some system paths deliver as user activity
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            log.info("🟠 AppDelegate.application(_:continue:) FIRED: \(url.absoluteString, privacy: .public)")
            print("🟠 AppDelegate.application(_:continue:) FIRED: \(url.absoluteString)")
            NotificationCenter.default.post(name: .incomingShareURL, object: url)
            return true
        }
        return false
    }
}
