import Foundation

enum ErrorMessage {
    static func userFriendly(_ error: Error) -> String {
        let raw = error.localizedDescription
        let lowercased = raw.lowercased()

        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return String(localized: "error.timeout")
        }
        if lowercased.contains("cloudflare") || lowercased.contains("forbidden") || lowercased.contains("403") {
            return String(localized: "error.cloudflare")
        }
        if lowercased.contains("could not connect") || lowercased.contains("network") || lowercased.contains("offline") {
            return String(localized: "error.network")
        }
        if raw.isEmpty {
            return String(localized: "error.generic")
        }
        return raw
    }
}
