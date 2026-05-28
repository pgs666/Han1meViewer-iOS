import Foundation

enum ErrorMessage {
    static func userFriendly(_ error: Error) -> String {
        let raw = error.localizedDescription
        let lowercased = raw.lowercased()

        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return String(localized: "error.timeout")
        }
        // Laravel "Page Expired" — server-side CSRF token / session no
        // longer matches what we have. We try one transparent refresh-and-
        // retry inside the repository; if that still fails the user
        // probably needs to log back in.
        if lowercased.contains("419") || lowercased.contains("page expired") {
            let base = raw.isEmpty ? String(localized: "error.generic") : raw
            return base + "\n您可能需要重新登录。"
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
