import Foundation

enum ErrorMessage {
    static func userFriendly(_ error: Error) -> String {
        // Prefer the stable code token the KMP DomainException carries; it's
        // immune to translatable-text changes. `display` strips the token.
        let display = DomainErrorCode.displayMessage(of: error)
        if let code = DomainErrorCode.code(of: error) {
            // Laravel "Page Expired" (HTTP 419) surfaces as an Unknown-coded
            // mutation failure whose message embeds "HTTP 419". Hint re-login.
            if display.contains("419") || display.lowercased().contains("page expired") {
                let base = display.isEmpty ? String(localized: "error.generic") : display
                return base + "\n" + String(localized: "error.page_expired.relogin_hint")
            }
            switch code {
            case "cloudflare", "network:403":
                return String(localized: "error.cloudflare")
            case "auth":
                let base = display.isEmpty ? String(localized: "error.generic") : display
                return base + "\n" + String(localized: "error.page_expired.relogin_hint")
            default:
                if code.hasPrefix("network") {
                    return String(localized: "error.network")
                }
                return display.isEmpty ? String(localized: "error.generic") : display
            }
        }

        // Fallback for non-DomainException bridges (Ktor timeouts, raw
        // connection failures) that carry no code token.
        let raw = error.localizedDescription
        let lowercased = raw.lowercased()
        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return String(localized: "error.timeout")
        }
        if lowercased.contains("cloudflare") || lowercased.contains("forbidden") {
            return String(localized: "error.cloudflare")
        }
        if lowercased.contains("could not connect") || lowercased.contains("network") || lowercased.contains("offline") {
            return String(localized: "error.network")
        }
        return raw.isEmpty ? String(localized: "error.generic") : raw
    }
}
