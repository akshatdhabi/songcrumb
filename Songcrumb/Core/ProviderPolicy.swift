import Foundation

/// Boundaries shared by the network client and its offline regression checks.
enum ProviderPolicy {
    static func sameHTTPSOrigin(_ original: URL, _ destination: URL) -> Bool {
        guard let originalHost = original.host, let destinationHost = destination.host else { return false }
        return original.scheme?.lowercased() == "https" && destination.scheme?.lowercased() == "https"
            && originalHost.lowercased() == destinationHost.lowercased()
            && (original.port ?? 443) == (destination.port ?? 443)
            && destination.user == nil && destination.password == nil
    }

}
