import Foundation

/// Parses the stable `[code]` classification token that the KMP
/// `DomainException` prepends to its message. The shared layer only reaches
/// Swift as a bridged `NSError` (its `localizedDescription` is the Kotlin
/// exception message), so this is how we classify errors by CODE instead of
/// fragile translatable-text matching.
///
/// Errors that aren't `DomainException` (Ktor timeouts, raw connection
/// failures) have no token — `code` is nil and callers fall back to text
/// heuristics for those.
enum DomainErrorCode {
    /// The leading token, e.g. "cloudflare", "network", "network:403",
    /// "auth", "parse", "unknown". Nil when the message has no `[...]` prefix.
    static func code(of error: Error) -> String? {
        let raw = error.localizedDescription
        guard raw.hasPrefix("["), let close = raw.firstIndex(of: "]") else { return nil }
        let token = raw[raw.index(after: raw.startIndex)..<close]
        return token.isEmpty ? nil : String(token)
    }

    /// The message with any leading `[code]` token removed, for display.
    static func displayMessage(of error: Error) -> String {
        let raw = error.localizedDescription
        guard raw.hasPrefix("["), let close = raw.firstIndex(of: "]") else { return raw }
        let after = raw[raw.index(after: close)...]
        return after.trimmingCharacters(in: .whitespaces)
    }

    static func isCloudflare(_ error: Error) -> Bool {
        if let code = code(of: error) { return code == "cloudflare" }
        // Fallback for non-DomainException bridges.
        let l = error.localizedDescription.lowercased()
        return l.contains("cloudflare") || l.contains("cf-mitigated")
    }

    /// HTTP status code carried by a `network:<status>` token, if any.
    static func httpStatus(of error: Error) -> Int? {
        guard let code = code(of: error), code.hasPrefix("network:") else { return nil }
        return Int(code.dropFirst("network:".count))
    }
}
