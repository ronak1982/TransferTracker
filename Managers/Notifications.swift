import Foundation

extension Notification.Name {
    /// Posted when CloudKit share metadata is delivered (best path).
    static let incomingShareMetadata = Notification.Name("IncomingShareMetadata")

    /// Posted when we only receive a URL (custom scheme or non-CloudKit link).
    static let incomingShareURL = Notification.Name("IncomingShareURL")

    /// Posted when we fail resolving iCloud share URL to metadata.
    static let incomingShareResolveError = Notification.Name("IncomingShareResolveError")
    static let shareResolutionFailed = Notification.Name("ShareResolutionFailed")
}


